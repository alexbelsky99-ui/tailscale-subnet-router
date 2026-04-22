output "router_public_ip" {
  value = azurerm_public_ip.router.ip_address
}
output "backend_private_ip" {
  value = azurerm_network_interface.backend.private_ip_address
}
output "private_subnet_cidr" {
  value = var.private_subnet_cidr
}
output "validation_curl_command" {
  value = "curl http://${azurerm_network_interface.backend.private_ip_address}"
}
output "router_ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.router.ip_address}"
}
output "tailscale_admin_url" {
  value = "https://login.tailscale.com/admin/machines"
}
