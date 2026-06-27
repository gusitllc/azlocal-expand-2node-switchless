# azlocal-expand-2node-switchless

**Upgrade a single-node Azure Local cluster to a 2-node *switchless* cluster — repeatably.**

Adding a second node to an Azure Local (Azure Stack HCI) cluster is a fiddly, easy-to-get-wrong
operation: you have to identify the right physical host, confirm the storage interconnect, pick a
witness, and step around a pile of AKS-Arc / Azure Local gotchas. This repo turns that into a
spec-driven, checklist-backed procedure so the next time takes minutes of decisions instead of hours
of trial and error.

> Companion repo: **azlocal-new-2node-switchless** (build a *new* 2-node switchless cluster).

## What "switchless" means here

In a 2-node Azure Local cluster you can skip a top-of-rack switch for storage/cluster traffic by
**directly cabling the two nodes** (back-to-back on the storage NIC pair) and using a **cloud or
file-share witness** for quorum. Cheaper, simpler, fewer moving parts — ideal for small edge/lab
clusters. This repo assumes (and validates) that switchless layout.

## Flow

```
1. discover/   inventory.sh  -> see your hosts (CPU/RAM/GPU/serial/health)
               match-clusters.sh -> which host belongs to which cluster (don't expand a node into itself!)
2. specs/      copy example.yaml -> describe: existing cluster + the new node + witness
3. validate    (in RUNBOOK) host reachable, storage cross-cabled, hardware homogeneity, witness reachable
4. build/      upgrade-to-2node.sh -> drives the az / Azure Local add-node + extends the AKS-Arc nodepool
5. RUNBOOK.md  the manual physical/portal steps that stay hands-on, as a precise checklist
```

## Quickstart

```bash
# 1. inventory your hosts (creds via env — never hardcoded)
IDRAC_USER=root IDRAC_PASS="$YOUR_IDRAC_PASS" ./discover/inventory.sh 192.168.10 2 12

# 2. confirm the target cluster's current node (so you add a DIFFERENT host)
./discover/match-clusters.sh my-cluster:my-rg

# 3. write your spec
cp specs/example.yaml specs/my-cluster.local.yaml   # *.local.yaml is gitignored
$EDITOR specs/my-cluster.local.yaml

# 4. follow RUNBOOK.md; the scriptable parts:
SPEC=specs/my-cluster.local.yaml ./build/upgrade-to-2node.sh
```

## Honest scope

The **az / stack-hci / AKS-Arc software steps are scripted**. The **physical steps** (racking,
cabling the storage interconnect, the initial Azure Local OS image on bare metal) stay manual — but
`RUNBOOK.md` captures them as an exact checklist, including the gotcha catalog (`lib/gotchas.md`).

## Contributing

PRs welcome — this is community infra tooling (MIT). See [CONTRIBUTING.md](CONTRIBUTING.md). Never
commit secrets, real iDRAC creds, internal IPs, service tags, or subscription IDs (`*.local.yaml`
and `.env` are gitignored for that reason).
