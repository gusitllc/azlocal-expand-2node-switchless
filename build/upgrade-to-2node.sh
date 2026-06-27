#!/usr/bin/env bash
# Upgrade an existing 1-node Azure Local cluster to 2-node switchless by adding a node,
# then extend the AKS-Arc nodepool onto it. Scriptable az steps only; physical/OS steps in RUNBOOK.md.
#
# Usage:  SPEC=specs/my-cluster.local.yaml ./build/upgrade-to-2node.sh [--dry-run]
#
# SAFETY: this touches a LIVE cluster. If has_live_workloads=true, run in a maintenance window.
set -euo pipefail
SPEC="${SPEC:?set SPEC=path/to/spec.yaml}"
DRY="${1:-}"; AZ="${AZ:-az}"
y() { python - "$SPEC" "$1" <<'PY'
import sys,yaml
d=yaml.safe_load(open(sys.argv[1]))
for p in sys.argv[2].strip('.').split('.'): d=d[p]
print(d)
PY
}
NAME=$(y .existing_cluster.name); RG=$(y .existing_cluster.resource_group)
CUR=$(y .existing_cluster.current_node_serial); NEW=$(y .new_node.serial)
SWLESS=$(y .network.switchless); LIVE=$(y .existing_cluster.has_live_workloads)
run() { echo "+ $*"; [ "$DRY" = "--dry-run" ] || "$@"; }

echo "== upgrade $NAME 1 -> 2 node (switchless) =="
[ "$SWLESS" = "True" ] || [ "$SWLESS" = "true" ] || { echo "switchless must be true for this repo"; exit 2; }

# GUARD 1: never add a node into itself.
[ "$CUR" = "$NEW" ] && { echo "FATAL: new_node.serial == existing node serial — that host IS the cluster. Pick a different host."; exit 3; }
echo "guard ok: existing=$CUR  new=$NEW (distinct)"

# GUARD 2: live workloads -> require explicit window ack.
if [ "$LIVE" = "True" ] || [ "$LIVE" = "true" ]; then
  echo "WARNING: existing cluster has LIVE workloads. The add-node is online but risky —"
  echo "         run in a maintenance window and have a rollback plan. See RUNBOOK.md."
  [ "${ACK_LIVE:-}" = "yes" ] || { echo "set ACK_LIVE=yes to proceed against a live cluster."; exit 4; }
fi

# Add-node: the new node must already be imaged with Azure Local OS + cross-cabled + Arc-registered
# (RUNBOOK.md steps 1-4). The az stack-hci add-node call is environment-specific (network intents,
# storage) and is driven from the spec + secrets — see RUNBOOK.md steps 5-7.
echo "NOTE: the add-node (az stack-hci) is owner/runbook-driven — see RUNBOOK.md steps 5-7."

# After the node joins + storage rebalances, extend the AKS-Arc nodepool onto the new capacity.
if [ "$(y .aks_arc.extend_nodepool)" = "True" ] || [ "$(y .aks_arc.extend_nodepool)" = "true" ]; then
  AK=$(y .aks_arc.cluster_name); NP=$(y .aks_arc.nodepool)
  echo "== extend AKS-Arc nodepool $NP on $AK =="
  run "$AZ" aksarc nodepool scale -n "$NP" --cluster-name "$AK" -g "$RG" --node-count 2
fi
echo "done. Validate: az stack-hci cluster show (2 nodes Succeeded) ; kubectl get nodes."
