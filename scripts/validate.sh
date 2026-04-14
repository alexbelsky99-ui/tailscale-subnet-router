#!/usr/bin/env bash
# validate.sh — end-to-end connectivity check for Tailscale subnet routing
# Usage: ./scripts/validate.sh <backend-ip>
# Or:    ./scripts/validate.sh $(cd terraform && terraform output -raw backend_ip)

set -euo pipefail

BACKEND_IP="${1:-}"

if [[ -z "$BACKEND_IP" ]]; then
  echo "Usage: $0 <backend-ip>"
  echo "  Get the IP: cd terraform && terraform output backend_ip"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tailscale Subnet Router — Connectivity Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[1/4] Checking local Tailscale status..."
if ! command -v tailscale &>/dev/null; then
  echo "  ✗ tailscale not found. Install: https://tailscale.com/download"
  exit 1
fi
TS_STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState','unknown'))" 2>/dev/null || echo "unknown")
if [[ "$TS_STATUS" != "Running" ]]; then
  echo "  ✗ Tailscale not running (state: $TS_STATUS). Run: tailscale up"
  exit 1
fi
echo "  ✓ Tailscale is running"

echo "[2/4] Checking accepted routes..."
ROUTES=$(tailscale status --json 2>/dev/null | python3 -c "
import sys,json
peers = json.load(sys.stdin).get('Peer',{})
print(' '.join(r for p in peers.values() for r in (p.get('PrimaryRoutes') or [])))
" 2>/dev/null || echo "")
if echo "$ROUTES" | grep -q "192.168.64"; then
  echo "  ✓ Subnet route 192.168.64.0/24 is accepted"
else
  echo "  ⚠  Route not found — approve it at: https://login.tailscale.com/admin/machines"
  echo "     Continuing anyway..."
fi

echo "[3/4] Pinging $BACKEND_IP..."
if ping -c 3 -W 3 "$BACKEND_IP" &>/dev/null; then
  echo "  ✓ Ping successful"
else
  echo "  ✗ Ping failed — check route approval"
  exit 1
fi

echo "[4/4] HTTP check..."
HTTP_RESPONSE=$(curl --silent --max-time 10 --write-out "\nHTTP_STATUS:%{http_code}" "http://$BACKEND_IP")
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | grep -v "HTTP_STATUS:")

if [[ "$HTTP_STATUS" == "200" ]]; then
  echo "  ✓ HTTP 200 OK — nginx is reachable through Tailscale!"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ALL CHECKS PASSED ✓"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$HTTP_BODY" | head -10
else
  echo "  ✗ HTTP $HTTP_STATUS — expected 200"
  exit 1
fi
