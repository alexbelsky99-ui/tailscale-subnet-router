variable "tailscale_api_key" {
  description = "Tailscale API key"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Your Tailnet name (e.g. 'you@gmail.com')"
  type        = string
}

variable "multipass_network_cidr" {
  description = "CIDR of the Multipass VM network — advertised to the Tailnet"
  type        = string
  default     = "192.168.64.0/24"
}

variable "vm_cpus" {
  description = "Number of CPUs per VM"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "RAM per VM"
  type        = string
  default     = "512M"
}

variable "vm_disk" {
  description = "Disk size per VM"
  type        = string
  default     = "5G"
}
