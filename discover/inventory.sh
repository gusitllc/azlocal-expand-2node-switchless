#!/usr/bin/env bash
# iDRAC / Redfish hardware inventory for a range of Dell hosts.
# Proven against PowerEdge R640 + iDRAC 9 (Redfish 1.17). Read-only.
#
# Usage:  IDRAC_USER=root IDRAC_PASS="$YOUR_IDRAC_PASS" ./inventory.sh 192.168.10 2 12
#         (base-octet, first, last)  -> prints power/model/RAM/CPU/GPU/serial/health per host
set -u
BASE="${1:-192.168.10}"; FIRST="${2:-2}"; LAST="${3:-12}"
U="${IDRAC_USER:-root}"; P="${IDRAC_PASS:-}"; P2="${IDRAC_PASS2:-}"
[ -z "$P" ] && { echo "ERROR: set IDRAC_PASS (and optionally IDRAC_PASS2) in your env. Never hardcode iDRAC creds." >&2; exit 1; }
au() { local r; r=$(curl -sk --max-time 8 -u "$U:$P" "$1" 2>/dev/null)
       echo "$r" | grep -q "Unauthorized\|RedfishError" && r=$(curl -sk --max-time 8 -u "$U:$P2" "$1" 2>/dev/null)
       echo "$r"; }
printf "%-15s %-5s %-16s %-9s %-6s %-14s %-9s %s\n" IP PWR MODEL RAM(GiB) vCPU GPU HEALTH "HOST/SERIAL"
for n in $(seq "$FIRST" "$LAST"); do
  ip="$BASE.$n"
  root=$(curl -sk --max-time 5 "https://$ip/redfish/v1/" 2>/dev/null)
  [ -z "$root" ] && { printf "%-15s %s\n" "$ip" "-- (no iDRAC)"; continue; }
  sys=$(au "https://$ip/redfish/v1/Systems/System.Embedded.1")
  procs=$(au "https://$ip/redfish/v1/Systems/System.Embedded.1/Processors?\$expand=*(\$levels=1)")
  GPU=$(echo "$procs" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const g=(o.Members||[]).filter(p=>/GPU/i.test(p.ProcessorType||"")||/nvidia|tesla|a2|a10|t4|a100/i.test(p.Model||"")).map(p=>(p.Model||"").trim());console.log(g.length?g.join("+"):"none")}catch(e){console.log("?")}})' 2>/dev/null)
  echo "$sys" | IP="$ip" GPU="$GPU" node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);
    console.log(require("util").format("%s %s %s %s %s %s %s %s",
      process.env.IP.padEnd(15), String(o.PowerState||"?").padEnd(5),
      String(o.Model||"?").replace("PowerEdge ","").padEnd(16),
      String(o.MemorySummary?.TotalSystemMemoryGiB||"?").padEnd(9),
      String(o.ProcessorSummary?.LogicalProcessorCount||"?").padEnd(6),
      String(process.env.GPU).padEnd(14), String(o.Status?.HealthRollup||"?").padEnd(9),
      (o.HostName||"")+" / "+(o.SKU||o.SerialNumber||"?")));
  }catch(e){console.log(process.env.IP+" parse-err")}})' 2>/dev/null
done
