terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
  }
}

###############################################################################
# Basic project setup
###############################################################################

resource "equinix_metal_project" "project" {
  name            = "Alex Sandbox"
  organization_id = var.organization_id
}

###############################################################################
# SSH key management: Generate and store a new keypair in the local state,
#   write to filesystem for CLI usage
# TODO: Manage SSH keys externally, pass in as variable
###############################################################################

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "equinix_metal_project_ssh_key" "project_public_key" {
  name       = "Terraform SSH Key"
  project_id = equinix_metal_project.project.id
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "local_file" "private_key" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("~/.ssh/%s", "equinix-metal-terraform-rsa"))
  file_permission = "0600"
}

###############################################################################
# Basic server setup
###############################################################################

resource "equinix_metal_device" "server" {
  plan = var.server_plan
  metro = var.server_metro
  operating_system = "ubuntu_22_04"
  project_id = equinix_metal_project.project.id
  project_ssh_key_ids = [
    equinix_metal_project_ssh_key.project_public_key.id
  ]

  # TODO: Most of the Metal examples have this running with a null_resource
  #   provisioner rather than with user_data.
  user_data = <<-EOT
    #!/bin/bash
    apt-get update && apt-get upgrade -y
    apt-get install -y jq ca-certificates curl gnupg

    url="$(curl https://metadata.platformequinix.com/metadata | jq -r .user_state_url)"

    send_user_state_event() {
        data=$(
            echo "{}" \
                | jq '.state = $state | .code = ($code | tonumber) | .message = $message' \
                --arg state "$1" \
                --arg code "$2" \
                --arg message "$3"
        )
        curl -v -X POST -d "$data" "$url"
    }

    send_user_state_event running 1000 "Installing Docker..."

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli

    send_user_state_event succeeded 1001 "Docker installation complete."
  EOT
}

# Once the server is deployed, wait for the user-data script to finish
# installing Docker before continuing.
resource "null_resource" "verify_docker" {
  connection {
    type = "ssh"
    user = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host = equinix_metal_device.server.access_public_ipv4
  }

  provisioner "remote-exec" {
    inline = [
        "timeout 5m bash -c 'until which docker; do sleep 5; done'"
    ]
  }
}

###############################################################################
# Outputs
###############################################################################

output "server_public_ip" {
  value = equinix_metal_device.server.access_public_ipv4
}