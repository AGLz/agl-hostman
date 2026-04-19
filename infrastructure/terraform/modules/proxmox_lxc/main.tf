# Proxmox LXC Container Module - Main Configuration
# This module creates and manages LXC containers on Proxmox VE

locals {
  container_full_name = "${var.project_name}-${var.environment}-${var.container_name}"
  container_tags = concat(
    var.default_tags,
    var.tags,
    [var.environment, "lxc"]
  )
  container_labels = merge(
    var.default_labels,
    var.labels,
    {
      "name"        = var.container_name
      "environment" = var.environment
      "type"        = "container"
    }
  )
  container_hostname = coalesce(var.hostname, var.container_name)
}

resource "proxmox_lxc" "this" {
  lifecycle {
    prevent_destroy = var.protection
  }

  # Basic Configuration
  name        = local.container_full_name
  description = var.description
  target_node = var.node_name
  vmid        = var.container_id
  onboot      = var.onboot

  # Template
  ostemplate = var.template.template_file
  storage     = var.template.storage

  # CPU Configuration
  cores   = var.cpu_cores
  cpuunits = var.cpu_units
  cpulimit = var.cpu_limit

  # Memory Configuration
  memory = var.memory_mb
  swap   = var.swap_mb

  # Root Filesystem
  rootfs {
    storage = var.storage.storage
    size    = "${var.storage.size_gb}G"
    type    = var.storage.type
  }

  # Network Configuration
  dynamic "network" {
    for_each = var.network_interfaces
    content {
      name    = network.value.name
      bridge  = network.value.bridge
      tag     = network.value.vlan_tag
      firewall = network.value.firewall
      ip      = network.value.ip
      gateway = network.value.gateway
      ip6     = network.value.ip6
      gateway6 = network.value.gateway6
      mtu     = network.value.mtu
      hwaddr  = null # Auto-assign
    }
  }

  # Container Features
  dynamic "features" {
    for_each = length(var.features) > 0 ? [1] : []
    content {
      nesting = var.features.nesting
      keyctl  = var.features.keyctl
      fuse    = var.features.fuse
      netns   = var.features.netns
    }
  }

  # Unprivileged Container
  unprivileged = var.unprivileged

  # Container User
  username = var.username
  password = var.password

  # SSH Keys
  ssh_public_keys = length(var.ssh_public_keys) > 0 ? join("\n", var.ssh_public_keys) : null

  # Hostname
  hostname = local.container_hostname

  # DNS
  nameserver   = var.nameserver
  searchdomain = var.search_domain

  # Startup Order
  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order = var.startup_order
      up    = var.onboot ? 60 : 0
      down  = 60
    }
  }

  # Console
  console = var.console
  tty     = var.tty

  # CGroup
  cgroup_mode = var.cgroup_mode

  # Additional Mounts
  dynamic "mount_point" {
    for_each = var.additional_mounts
    content {
      slot      = mount_point.value.slot
      storage   = mount_point.value.storage
      mp        = mount_point.value.path
      size      = mount_point.value.size
      backup    = mount_point.value.backup
      acl       = mount_point.value.acl
      replicate = mount_point.value.replicate
      shared    = mount_point.value.shared
      ro        = mount_point.value.ro
      quota     = mount_point.value.quota
    }
  }

  # Tags and Labels
  tags = join(";", local.container_tags)
  dynamic "labels" {
    for_each = length(local.container_labels) > 0 ? [1] : []
    content {
      for_each = local.container_labels
      content {
        key   = labels.key
        value = labels.value
      }
    }
  }

  # Protection
  protection = var.protection

  # Template
  template = var.is_template

  # High Availability
  dynamic "ha" {
    for_each = var.ha.enabled ? [1] : []
    content {
      enabled = var.ha.enabled
      group   = var.ha.group
      state   = var.ha.state
    }
  }

  # Timeout
  timeout = var.proxmox_timeout
}

# Start container after creation (if not template)
resource "null_resource" "start_container" {
  count = var.is_template ? 0 : 1

  provisioner "local-exec" {
    command = "pct start ${proxmox_lxc.this.vmid}"
  }

  depends_on = [proxmox_lxc.this]
}

# Wait for container to be running
resource "null_resource" "wait_for_running" {
  count = var.is_template ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for container to start
      timeout 300 bash -c 'until pct status ${proxmox_lxc.this.vmid} | grep -q "status: running"; do sleep 5; done'
    EOT
  }

  depends_on = [null_resource.start_container]
}

# Ansible Provisioner
resource "null_resource" "ansible_provisioner" {
  count = var.ansible_playbook != null && !var.is_template ? 1 : 0

  triggers = {
    container_id    = proxmox_lxc.this.vmid
    playbook        = var.ansible_playbook
    extra_vars_hash = sha256(jsonencode(var.ansible_extra_vars))
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get container IP
      CONTAINER_IP=$(pct exec ${proxmox_lxc.this.vmid} -- ip -4 addr show dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)

      if [ -z "$CONTAINER_IP" ]; then
        echo "Failed to get container IP"
        exit 1
      fi

      # Update Ansible inventory
      cat > ${path.module}/inventory.ini <<EOF
      [${var.container_name}]
      $CONTAINER_IP ansible_user=${var.username} ansible_python_interpreter=/usr/bin/python3
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

  depends_on = [null_resource.wait_for_running]
}
