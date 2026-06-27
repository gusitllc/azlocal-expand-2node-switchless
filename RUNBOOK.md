# RUNBOOK — upgrade an existing 1-node Azure Local cluster to 2-node switchless

Adds a second node to a **live** cluster. Steps 1–4 are physical/manual; 5–7 are scripted.

## ⚠️ This touches a cluster that may be serving workloads

Unlike a greenfield build, here the existing node is **in use**. Treat the add as a maintenance
operation: pick a window, have a rollback plan, and expect the cluster to keep serving throughout
(the add is online, but storage rebalance adds load).

## 0. Pre-flight (gate)

- [ ] Identify the existing node's serial and the new node's serial — they **must differ**
      (`./discover/match-clusters.sh <cluster>:<rg>` + `./discover/inventory.sh`). **Never add a node
      into itself** (the most common mistake — a host IS its own cluster).
- [ ] New node **healthy** and **homogeneous** with the existing node (same model; **GPU must match**
      if the existing node has one).
- [ ] New node carries **no critical data** — joining wipes it.
- [ ] A **witness** is in place (a 2-node cluster requires one; a 1-node cluster usually has none yet).

## 1–4. Physical / OS (manual)

1. Rack the new node; connect management (iDRAC) + host NIC.
2. **Cross-cable the storage NICs** from the new node to the existing node (two cables). Confirm links up.
3. Image the new node with the **same Azure Local OS build** as the existing node; set host name + IP.
4. Register the new node with Azure Arc; confirm `Connected`.

## 5–7. Add the node (az, switchless) + witness

5. Add a **witness** to the cluster first if it doesn't have one (1→2 node makes quorum mandatory).
6. Run the Azure Local **add-node** (validate → add). The switchless storage intent picks up the
   cross-cabled NICs. Confirm the node joins and **S2D storage rebalances** to healthy.
7. `build/upgrade-to-2node.sh` (with `ACK_LIVE=yes` if live) then **extends the AKS-Arc nodepool**
   onto the new node so workloads can schedule on the new capacity.

## Gotcha catalog

- **Adding a node into itself** → guard on serial != existing serial (the script enforces this).
- **Heterogeneous node** → Azure Local rejects/degrades on mismatched hardware/firmware; match first.
- **GPU mismatch** → if the existing node has a GPU and the new one doesn't, GPU workloads won't
  spread; match the GPU (or accept CPU-only on the new node deliberately).
- **No witness on 1→2** → quorum becomes mandatory at 2 nodes; add the witness as part of the add.
- **`ScalingUp` timeout** when extending the nodepool = host full; check the new node actually joined.
- **ACR `--admin-enabled`, numeric `runAsUser`, pin tags, poll `.properties.provisioningState`,
  retry `ResourceNotFound`** — same AKS-Arc gotchas as a fresh build.

## Validate done

- [ ] `az stack-hci cluster show` → 2 nodes, `provisioningState=Succeeded`, storage healthy, witness set.
- [ ] `kubectl get nodes` → 2 Ready; existing workloads undisturbed; new pods can land on the new node.
