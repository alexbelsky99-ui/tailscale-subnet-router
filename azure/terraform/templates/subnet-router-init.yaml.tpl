#cloud-config
package_update: true
package_upgrade: false
packages:
  - curl
  - iptables
  - iptables-persistent
write_files:
  - path: /etc/sysctl.d/99-tailscale.conf
    owner: root:root
    permissions: "0644"
    content: |
      net.ipv4.ip_forward = 1
      net.ipv6.conf.all.forwarding = 1
runcmd:
  - sysctl -p /etc/sysctl.d/99-tailscale.conf
  - curl -fsSL https://tailscale.com/install.sh | sh
  - >-
    tailscale up
    --authkey="${authkey}"
    --advertise-routes="${private_cidr}"
    --accept-routes
  - tailscale status
