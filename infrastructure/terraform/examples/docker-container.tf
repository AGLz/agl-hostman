# Example: Create Docker-enabled LXC container
# This example demonstrates container provisioning with Docker support

module "docker_host" {
  source = "../modules/proxmox_lxc"

  container_name = "docker-host"
  container_id   = 201
  node_name      = "AGLSRV1"

  cpu_cores = 4
  memory_mb = 8192

  template = {
    storage        = "local-lvm"
    template_file = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }

  storage = {
    storage = "local-lvm"
    size_gb = 64
  }

  features = {
    nesting = true  # Required for Docker-in-LXC
    keyctl  = true
    fuse    = true
  }

  unprivileged = false  # Docker requires privileged container

  network_interfaces = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      ip     = "dhcp"
    }
  ]

  ssh_public_keys = [
    "ssh-rsa AAAAB3...",
    "ssh-rsa AAAAB3..."
  ]

  tags = ["docker", "development"]

  # Automatically configure Docker after creation
  ansible_playbook = "../../ansible/playbooks/docker-setup.yml"
}

output "docker_host_id" {
  value = module.docker_host.container_id
}
