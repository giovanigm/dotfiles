#!/bin/sh
# Quickshell bar poller — prints one JSON line per invocation with
# cpu %, cpu temp °C, ram % + GiB strings, disk % + free, and network
# rx/tx bitrates (sysfs deltas between invocations).
# Polled every 2s by SysInfo.qml. State lives in a tmp cache (impermanence-safe).
# Pure POSIX sh: the UWSM service environment has no awk/ip in PATH.

CACHE="/tmp/quickshell-sysinfo.cache"

# ── CPU: /proc/stat first line (busy = total - idle - iowait) ──
read -r _ user nice sys idle iowait irq softirq steal rest < /proc/stat
total=$((user + nice + sys + idle + iowait + irq + softirq + steal))
busy=$((total - idle - iowait))

# ── RAM: /proc/meminfo (KiB) ──
memtotal=0
memavail=0
while read -r key val rest; do
  case "$key" in
    MemTotal:) memtotal=$val ;;
    MemAvailable:) memavail=$val ;;
  esac
done < /proc/meminfo

# ── Temperature: max across the CPU hwmon chip (prefer coretemp/k10temp) ──
chip=""
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    coretemp|k10temp|zenpower) chip=$h; break ;;
  esac
done
[ -z "$chip" ] && chip=$(ls -d /sys/class/hwmon/hwmon* 2>/dev/null | head -1)
maxt=0
for f in "$chip"/temp*_input; do
  [ -r "$f" ] || continue
  v=$(cat "$f" 2>/dev/null) || continue
  # ignore implausible sensors (disabled sensors read negative/huge values)
  case "$v" in
    ''|*[!0-9-]*) continue ;;
  esac
  [ "$v" -ge 0 ] && [ "$v" -le 150000 ] && [ "$v" -gt "$maxt" ] && maxt=$v
done
temp=$((maxt / 1000))

# ── Disk: / usage ──
set -- $(df -Pk / | tail -1)
disktotal=$2
diskused=$3
diskpct=$((100 * diskused / disktotal))
diskfree=$(df -hP / | tail -1 | { read -r _ _ _ free rest; printf '%s' "$free"; })

# ── Network: default-route interface + rx/tx byte deltas ──
iface=""
while read -r i dest rest; do
  if [ "$dest" = "00000000" ]; then iface=$i; break; fi
done < /proc/net/route
[ -z "$iface" ] && iface=$(ls /sys/class/net 2>/dev/null | head -1)
rx=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || printf 0)
tx=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || printf 0)
now=$(date +%s%N)

# previous values from the cache
set -- $(cat "$CACHE" 2>/dev/null)
ptotal=${1:-0}
pbusy=${2:-0}
prx=${3:-0}
ptx=${4:-0}
pnow=${5:-0}
printf '%s %s %s %s %s\n' "$total" "$busy" "$rx" "$tx" "$now" > "$CACHE"

# ── Deltas ──
if [ "$total" -gt "$ptotal" ] && [ "$busy" -ge "$pbusy" ]; then
  dcpu=$((100 * (busy - pbusy) / (total - ptotal)))
else
  dcpu=0
fi
dt=$((now - pnow))
if [ "$dt" -gt 0 ]; then
  if [ "$rx" -ge "$prx" ]; then down=$(((rx - prx) * 8000000000 / dt)); else down=0; fi
  if [ "$tx" -ge "$ptx" ]; then up=$(((tx - ptx) * 8000000000 / dt)); else up=0; fi
else
  down=0
  up=0
fi

# ── Output ──
used=$((memtotal - memavail))
[ "$memtotal" -gt 0 ] || memtotal=1
rampct=$((1000 * used / memtotal))          # 1 decimal, fixed-point
ramused=$((used * 10 / 1048576))            # GiB, 1 decimal
ramtotal=$((memtotal * 10 / 1048576))

printf '{"cpu":%d,"temp":%d,"ram":%d.%d,"ramUsed":"%d.%d","ramTotal":"%d.%d","disk":%d,"diskFree":"%s","netDown":%d,"netUp":%d}\n' \
  "$dcpu" "$temp" \
  "$((rampct / 10))" "$((rampct % 10))" \
  "$((ramused / 10))" "$((ramused % 10))" \
  "$((ramtotal / 10))" "$((ramtotal % 10))" \
  "$diskpct" "$diskfree" "$down" "$up"
