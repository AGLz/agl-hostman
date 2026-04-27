# Proxmox VM Module - Main Configuration
# This module creates and manages QEMU virtual machines on Proxmox VE

locals {
  vm_full_name = "${var.project_name}-${var.environment}-${var.vm_name}"
  vm_tags = concat(
    var.default_tags,
    var.tags,
    [var.environment]
  )
  vm_labels = merge(
    var.default_labels,
    var.labels,
    {
      "name"        = var.vm_name
      "environment" = var.environment
      "type"        = "vm"
    }
  )
}

resource "proxmox_vm_qemu" "this" {
  lifecycle {
    # Prevent accidental deletion of protected VMs
    prevent_destroy = var.protection

    # Ignore changes to volatile fields
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
    ]
  }

  # Basic Configuration
  name        = local.vm_full_name
  desc        = var.description
  target_node = var.node_name
  vmid        = var.vm_id
  onboot      = var.onboot

  # CPU Configuration
  cores   = var.cpu_cores
  sockets = var.cpu_sockets
  cpu     = var.cpu_type
  cpuunits = var.cpu_units
  vcpus   = var.vcpu_percentage

  # Memory Configuration
  memory  = var.memory_gb * 1024 # Convert GB to MB
  balloon = var.memory_minimum
  dynamic "cpu" {
    for_each = var.ballooning ? [1] : []
    content {
      ballooning = var.ballooning
    }
  }

  # Disk Configuration
  dynamic "disk" {
    for_each = var.disks
    content {
      type    = disk.value.type
      storage = disk.value.storage
      size    = "${disk.value.size_gb}G"
      ssd     = disk.value.ssd
      discard = disk.value.discard
      iothread = disk.value.iothread
      cache   = disk.value.cache
      backup  = disk.value.backup
      # Dynamic storage type specific options
      dynamic "emulatessd" {
        for_each = disk.value.storage_type == "directory" ? [1] : []
        content {
          emulatessd = disk.value.ssd
        }
      }
    }
  }
  scsihw = var.scsi_hardware

  # Network Configuration
  dynamic "network" {
    for_each = var.network_interfaces
    content {
      model      = network.value.model
      bridge     = network.value.bridge
      tag        = network.value.vlan_tag
      firewall   = network.value.firewall
      link_down  = network.value.link_down
      macaddr    = network.value.mac_address
      queues     = var.cpu_cores * 2 # Optimal for virtio
    }
  }

  # Operating System
  ostype = var.os_type
  bios   = var.bios

  # EFI Disk
  dynamic "efidisk" {
    for_each = var.efi_disk.enabled ? [1] : []
    content {
      storage             = var.efi_disk.storage
      pre_enrolled_keys   = var.efi_disk.pre_enrolled_keys
    }
  }

  # QEMU Guest Agent
  agent      = var.qemu_agent
  qemu_agent = var.qemu_agent

  # Boot Configuration
  boot = var.boot_order

  # VGA/Display
  vga {
    type = var.vga_type
  }

  # Serial Console
  serial {
    device = var.serial_device
  }

  # CD-ROM (ISO)
  dynamic "iso" {
    for_each = var.iso_file != null ? [1] : []
    content {
      type    = "ide2"
      storage = var.iso_storage
      iso     = var.iso_file
    }
  }

  # Cloud-Init Configuration
  dynamic "cicustom" {
    for_each = var.cloud_init.enabled && var.cloud_init.ciuser != null ? [1] : []
    content {
      user    = "snippets=${var.cloud_init.ciuser}"
      network = "snippets=${var.cloud_init.ciuser}"
      meta    = "snippets=${var.cloud_init.ciuser}"
    }
  }

  ciuser       = var.cloud_init.enabled ? var.cloud_init.user : null
  cipassword   = var.cloud_init.enabled ? var.cloud_init.password : null
  sshkeys      = var.cloud_init.enabled && length(var.cloud_init.ssh_keys) > 0 ? join("\n", var.cloud_init.ssh_keys) : null
  ipconfig0    = var.cloud_init.enabled ? coalesce(var.cloud_init.ipconfig0, "ip=dhcp") : null
  nameserver   = var.cloud_init.enabled ? coalesce(var.cloud_init.nameserver, var.cloud_init.nameserver0) : null
  searchdomain = var.cloud_init.enabled ? coalesce(var.cloud_init.searchdomain, var.cloud_init.searchdomain0) : null

  dynamic "cloudinit" {
    for_each = var.cloud_init.enabled ? [1] : []
    content {
      type        = var.cloud_init.ciuser == null ? "ide2" : null
      storage     = var.cloud_init.storage
    }
  }

  # High Availability
  dynamic "ha" {
    for_each = var.ha.enabled ? [1] : []
    content {
      enabled    = var.ha.enabled
      group      = var.ha.group
      state      = var.ha.state
    }
  }

  # Startup Order
  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order = var.startup_order
      up    = var.onboot ? 60 : 0
      down  = 60
    }
  }

  # Tags and Labels
  tags   = join(";", local.vm_tags)
  dynamic "labels" {
    for_each = length(local.vm_labels) > 0 ? [1] : []
    content {
      for_each = local.vm_labels
      content {
        key   = labels.key
        value = labels.value
      }
    }
  }

  # Resource Limits
  cpulimit = var.cpu_limit
  outboundbandwidth = var.outbound_bandwidth

  # Protection
  protection = var.protection

  # Template
  template = var.is_template

  # Delete VM on destroy (vs. stop)
  force_create = true

  # Full clone when creating from template
  full_clone = true

  # Timeout for operations
  timeout = var.proxmox_timeout
}

# Import Cloud-Init Image if URL provided
resource "null_resource" "cloud_init_image" {
  count = var.cloud_init.enabled && var.cloud_init_image_url != null ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      # Download cloud-init image
      wget -O /tmp/cloud-init.img ${var.cloud_init_image_url}

      # Import to Proxmox storage
      ssh root@${var.proxmox_api_host} \
        "qm importdisk ${proxmox_vm_qemu.this.vmid} /tmp/cloud-init.img ${var.cloud_init_storage} -format qcow2"

      # Clean up
      rm /tmp/cloud-init.img
    EOT
  }

  depends_on = [proxmox_vm_qemu.this]
}

# Ansible Provisioner
resource "null_resource" "ansible_provisioner" {
  count = var.ansible_playbook != null ? 1 : 0

  triggers = {
    vm_id           = proxmox_vm_qemu.this.vmid
    playbook        = var.ansible_playbook
    extra_vars_hash = sha256(jsonencode(var.ansible_extra_vars))
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update Ansible inventory
      cat > ${path.module}/inventory.ini <<EOF
      [${var.vm_name}]
      ${proxmox_vm_qemu.this.ipconfig0 != null ? regex("ip=(\\d+\\.\\d+\\.\\d+\\.\\d+)", proxmox_vm_qemu.this.ipconfig0)[0] : proxmox_vm_qemu.this.name} ansible_user=${coalesce(var.cloud_init.user, "root")}
      EOF

      # Run Ansible playbook
      cd ${var.ansible_playbook_path}

      ansible-playbook \
        -i ${path.module}/inventory.ini \
        ${var.ansible_playbook} \
        ${length(var.ansible_extra_vars) > 0 ? "--extra-vars '${jsonencode(var.ansible_extra_vars)}'" : ""} \
        --timeout ${var.ansible_ssh_timeout}
    EOT

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_PYTHON_INTERPRETER = "auto_silent"
    }
  }

  depends_on = [proxmox_vm_qemu.this]
}

# VM IP Address (for Ansible/inventory)
data "external" "vm_ip" {
  count = var.ansible_playbook != null && var.ansible_wait_for_ssh ? 1 : 0

  program = [
    "bash", "-c", <<-EOT
      # Wait for QEMU agent to report IP
      for i in {1..60}; do
        IP=$(ssh root@${var.proxmox_api_host} \
          "qm agent ${proxmox_vm_qemu.this.vmid} network-get-interfaces 2>/dev/null" \
          | jq -r '.result[] | select(.name=="ens18" or .name=="eth0") | .["ip-addresses"][] | select(.scope=="global") | .address' \
          | head -n1)

        if [ -n "$IP" ]; then
          echo "{\"ip\":\"$IP\"}"
          exit 0
        fi

        sleep 5
      done

      # Fallback: try cloud-init config
      echo "{\"ip\":\"unknown\"}"
    EOT
  ]

  depends_on = [proxmox_vm_qemu.this]
}
