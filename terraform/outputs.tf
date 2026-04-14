output "advertised_cidr" {
  value = "192.168.64.0/24"
}

output "get_backend_ip" {
  value = "multipass info vm-backend | grep IPv4"
}

output "tailscale_admin_url" {
  value = "https://login.tailscale.com/admin/machines"
}
