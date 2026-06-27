#!/usr/bin/env bash
# Match physical hosts (iDRAC service tags) to the Azure-Local clusters they belong to.
# Answers "which hosts are in use and by what cluster" before you expand one.
# Usage: ./match-clusters.sh   (requires az logged in; edit the cluster list below)
set -u
AZ="${AZ:-az}"
echo "=== HCI clusters + node serials (match these to iDRAC service tags) ==="
"$AZ" stack-hci cluster list --query "[].{name:name,rg:resourceGroup,conn:connectivityStatus}" -o table
for spec in "${@:-}"; do :; done
# Pass cluster "name:rg" pairs as args, e.g. ./match-clusters.sh fl-small-gpu:rg-avd-1node-gpu fl-1xa2-2node:rg-azurelocal-prod
for pair in "$@"; do
  name="${pair%%:*}"; rg="${pair##*:}"
  echo "--- $name ($rg) ---"
  "$AZ" stack-hci cluster show -n "$name" -g "$rg" \
    --query "reportedProperties.nodes[].{node:name,serial:serialNumber,model:model}" -o table 2>/dev/null \
    || echo "  (no node detail)"
done
echo "Tip: get iDRAC service tags via ./inventory.sh, then match serial==service-tag."
