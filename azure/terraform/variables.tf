variable "tailscale_api_key" {
  description = "Tailscale API key"
  type        = string
  sensitive   = true
}
variable "tailscale_tailnet" {
  description = "Your Tailnet name"
  type        = string
}
variable "admin_username" {
  type    = string
  default = "azureuser"
}
variable "admin_ssh_public_key" {
  type = string
}
variable "location" {
  type    = string
  default = "eastus"
}
variable "resource_group_name" {
  type    = string
  default = "rg-tailscale-demo"
}
variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}
variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}
variable "tags" {
  type = map(string)
  default = {
    project     = "tailscale-demo"
    environment = "interview"
    managed-by  = "terraform"
  }
}
