resource "tailscale_tailnet_key" "main" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 86400
  description   = "Terraform multipass demo"
}

resource "null_resource" "router_vm" {
  provisioner "local-exec" {
    command = "multipass launch --name vm-subnet-router --cpus 1 --memory 512M --disk 5G 22.04"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "multipass delete vm-subnet-router --purge || true"
  }
}

resource "null_resource" "backend_vm" {
  provisioner "local-exec" {
    command = "multipass launch --name vm-backend --cpus 1 --memory 512M --disk 5G 22.04"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "multipass delete vm-backend --purge || true"
  }
}

resource "null_resource" "router_config" {
  depends_on = [null_resource.router_vm, tailscale_tailnet_key.main]
  provisioner "local-exec" {
    command = <<-SCRIPT
      sleep 30
      multipass exec vm-subnet-router -- sudo bash -c "
        echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-tailscale.conf
        sysctl -p /etc/sysctl.d/99-tailscale.conf
        curl -fsSL https://tailscale.com/install.sh | sh
        tailscale up --authkey='${tailscale_tailnet_key.main.key}' --advertise-routes='${var.multipass_network_cidr}' --accept-routes
      "
    SCRIPT
  }
}

resource "null_resource" "backend_config" {
  depends_on = [null_resource.backend_vm]
  provisioner "local-exec" {
    command = <<-SCRIPT
      sleep 30
      multipass exec vm-backend -- sudo bash -c "
        apt-get update -qq
        apt-get install -y nginx
        systemctl enable nginx
        systemctl start nginx
        echo '<h1>Subnet routing works!</h1><p>Host: \$(hostname)</p><p>IP: \$(hostname -I)</p>' > /var/www/html/index.html
      "
    SCRIPT
  }
}
