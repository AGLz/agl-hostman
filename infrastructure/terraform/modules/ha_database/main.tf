# =============================================================================
# Terraform Module: MySQL Master-Slave Replication
# AGL Hostman - High Availability Database Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================
variable "master_vm_id" {
  description = "VM ID for MySQL master"
  type        = number
}

variable "slave_vm_ids" {
  description = "List of VM IDs for MySQL slaves"
  type        = list(number)
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "master_ip" {
  description = "IP address for MySQL master"
  type        = string
}

variable "slave_ips" {
  description = "IP addresses for MySQL slaves"
  type        = list(string)
}

variable "gateway" {
  description = "Gateway address"
  type        = string
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_repl_password" {
  description = "MySQL replication user password"
  type        = string
  sensitive   = true
}

variable "server_id_start" {
  description = "Starting server ID for MySQL servers"
  type        = number
  default     = 1
}

# =============================================================================
# MySQL Master VM
# =============================================================================
resource "proxmox_vm_qemu" "mysql_master" {
  name        = "mysql-master"
  vmid        = var.master_vm_id
  target_node = var.node_name
  clone       = "ubuntu-22.04-template"
  full_clone  = true

  # CPU Configuration
  cores   = 4
  sockets = 1
  cpu     = "host"

  # Memory Configuration (4GB for better performance)
  memory = 4096

  # Disk Configuration
  disks {
    type         = "scsi0"
    storage      = "local-lvm"
    storage_type = "lvm"
    size_gb      = 64
    ssd          = true
  }

  # Network Configuration
  network {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  # IP Configuration
  ipconfig0 = "ip=${var.master_ip}/24,gw=${var.gateway}"

  # Tags
  tags = "database;mysql;master;production"

  # Agent
  agent = 1

  lifecycle {
    ignore_changes = [network, sshkeys]
  }
}

# =============================================================================
# MySQL Slave VMs
# =============================================================================
resource "proxmox_vm_qemu" "mysql_slaves" {
  count = length(var.slave_vm_ids)

  name        = "mysql-slave-${count.index + 1}"
  vmid        = var.slave_vm_ids[count.index]
  target_node = var.node_name
  clone       = "ubuntu-22.04-template"
  full_clone  = true

  # CPU Configuration
  cores   = 4
  sockets = 1
  cpu     = "host"

  # Memory Configuration
  memory = 4096

  # Disk Configuration
  disks {
    type         = "scsi0"
    storage      = "local-lvm"
    storage_type = "lvm"
    size_gb      = 64
    ssd          = true
  }

  # Network Configuration
  network {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  # IP Configuration
  ipconfig0 = "ip=${var.slave_ips[count.index]}/24,gw=${var.gateway}"

  # Tags
  tags = "database;mysql;slave;production"

  # Agent
  agent = 1

  lifecycle {
    ignore_changes = [network, sshkeys]
  }
}

# =============================================================================
# Configuration Templates
# =============================================================================
data "template_file" "mysql_master_config" {
  template = file("${path.module}/templates/my-master.cnf.tmpl")

  vars = {
    server_id = var.server_id_start
  }
}

data "template_file" "mysql_slave_config" {
  count = length(var.slave_vm_ids)

  template = file("${path.module}/templates/my-slave.cnf.tmpl")

  vars = {
    server_id = var.server_id_start + count.index + 1
  }
}

# =============================================================================
# Provisioning - Master
# =============================================================================
resource "null_resource" "configure_mysql_master" {
  depends_on = [proxmox_vm_qemu.mysql_master]

  connection {
    type     = "ssh"
    host     = var.master_ip
    user     = "root"
    password = var.ssh_password
  }

  # Install MySQL
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get install -y mysql-server",
      "systemctl enable mysql"
    ]
  }

  # Upload configuration
  provisioner "file" {
    content     = data.template_file.mysql_master_config.rendered
    destination = "/etc/mysql/conf.d/replication.cnf"
  }

  # Configure replication
  provisioner "remote-exec" {
    inline = [
      "systemctl restart mysql",
      # Create replication user
      "mysql -u root -e \"CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY '${var.mysql_repl_password}';\"",
      "mysql -u root -e \"GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';\"",
      "mysql -u root -e \"FLUSH PRIVILEGES;\""
    ]
  }
}

# =============================================================================
# Provisioning - Slaves
# =============================================================================
resource "null_resource" "configure_mysql_slaves" {
  count = length(var.slave_vm_ids)

  depends_on = [
    proxmox_vm_qemu.mysql_slaves,
    null_resource.configure_mysql_master
  ]

  connection {
    type     = "ssh"
    host     = var.slave_ips[count.index]
    user     = "root"
    password = var.ssh_password
  }

  # Install MySQL
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get install -y mysql-server",
      "systemctl enable mysql"
    ]
  }

  # Upload configuration
  provisioner "file" {
    content     = data.template_file.mysql_slave_config[count.index].rendered
    destination = "/etc/mysql/conf.d/replication.cnf"
  }

  # Configure replication
  provisioner "remote-exec" {
    inline = [
      "systemctl restart mysql",
      # Configure slave
      "mysql -u root -e \"STOP SLAVE;\"",
      "mysql -u root -e \"CHANGE MASTER TO MASTER_HOST='${var.master_ip}', MASTER_USER='repl_user', MASTER_PASSWORD='${var.mysql_repl_password}', MASTER_AUTO_POSITION=1;\"",
      "mysql -u root -e \"START SLAVE;\"",
      "mysql -u root -e \"SET GLOBAL read_only = ON;\""
    ]
  }
}

# =============================================================================
# Outputs
# =============================================================================
output "master_ip" {
  description = "MySQL master IP address"
  value       = var.master_ip
}

output "slave_ips" {
  description = "MySQL slave IP addresses"
  value       = var.slave_ips
}

output "replication_status" {
  description = "Replication status"
  value = {
    master = "configured"
    slaves = [for ip in var.slave_ips : "${ip}: configured"]
  }
}
