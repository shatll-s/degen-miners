#!/usr/bin/env bash

# Get script directory for standalone testing
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Use HiveOS paths if available, otherwise use script directory
if [[ -z "$MINER_DIR" || -z "$CUSTOM_MINER" ]]; then
    MINER_PATH="$SCRIPT_DIR"
else
    MINER_PATH="$MINER_DIR/$CUSTOM_MINER"
fi

. "$MINER_PATH/h-manifest.conf"

# Read API port
API_PORT_FILE="$MINER_PATH/api_port.txt"
if [[ -f "$API_PORT_FILE" ]]; then
    API_PORT=$(cat "$API_PORT_FILE")
else
    API_PORT=45545
fi

# Fetch stats from API
API_RESPONSE=$(curl -s --connect-timeout 2 --max-time 5 "http://localhost:$API_PORT/" 2>/dev/null)

if [[ -z "$API_RESPONSE" ]] || ! echo "$API_RESPONSE" | jq -e . >/dev/null 2>&1; then
    khs=0
    stats="null"
    exit 1
fi

# Parse API response
miner_version=$(echo "$API_RESPONSE" | jq -r '.version // "unknown"')
uptime=$(echo "$API_RESPONSE" | jq -r '.uptime // 0')
algo=$(echo "$API_RESPONSE" | jq -r '.algo // "unknown"')

# Build per-GPU hashrate array and totals
dev_count=$(echo "$API_RESPONSE" | jq '.devices | length')
hs_array="["
bus_array="["
total_hs=0
total_ac=0
total_rj=0

for ((i=0; i<dev_count; i++)); do
    dev=$(echo "$API_RESPONSE" | jq ".devices[$i]")
    hr=$(echo "$dev" | jq -r '.hashrate // 0' | cut -d'.' -f1)
    ac=$(echo "$dev" | jq -r '.accepted // 0')
    rj=$(echo "$dev" | jq -r '.rejected // 0')
    bus_id=$(echo "$dev" | jq -r '.bus_id // "00:00.0"')

    # Convert bus_id "01:00.0" to decimal
    bus_hex=$(echo "$bus_id" | grep -oP '^[0-9A-Fa-f]+' | head -1)
    bus_dec=$((16#${bus_hex:-0}))

    total_hs=$((total_hs + hr))
    total_ac=$((total_ac + ac))
    total_rj=$((total_rj + rj))

    [[ $i -gt 0 ]] && hs_array+="," && bus_array+=","
    hs_array+="$hr"
    bus_array+="$bus_dec"
done

hs_array+="]"
bus_array+="]"

# Convert total H/s to kH/s for HiveOS
khs=$(awk "BEGIN {printf \"%.3f\", $total_hs / 1000}")

# Get GPU temperatures and fans from nvidia-smi
temps_array="["
fans_array="["

if command -v nvidia-smi &> /dev/null; then
    gpu_temps=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    gpu_fans=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null)

    i=0
    while IFS= read -r temp; do
        [[ $i -gt 0 ]] && temps_array+=","
        [[ "$temp" == *"N/A"* || -z "$temp" ]] && temp="null"
        temps_array+="$temp"
        ((i++))
    done <<< "$gpu_temps"

    i=0
    while IFS= read -r fan; do
        [[ $i -gt 0 ]] && fans_array+=","
        [[ "$fan" == *"N/A"* || -z "$fan" ]] && fan="null"
        fans_array+="$fan"
        ((i++))
    done <<< "$gpu_fans"
else
    for ((i=0; i<dev_count; i++)); do
        [[ $i -gt 0 ]] && temps_array+="," && fans_array+=","
        temps_array+="null"
        fans_array+="null"
    done
fi

temps_array+="]"
fans_array+="]"

# Build stats JSON for HiveOS
stats=$(jq -n \
    --argjson hs "$hs_array" \
    --arg hs_units "hs" \
    --arg algo "$algo" \
    --argjson temp "$temps_array" \
    --argjson fan "$fans_array" \
    --argjson uptime "$uptime" \
    --arg ac "$total_ac" \
    --arg rj "$total_rj" \
    --argjson bus_numbers "$bus_array" \
    --arg ver "nekominer $miner_version" \
    '{hs: $hs, hs_units: $hs_units, algo: $algo, temp: $temp, fan: $fan, uptime: $uptime, ar: [$ac, $rj], bus_numbers: $bus_numbers, ver: $ver}')

[[ -z "$khs" ]] && khs=0
[[ -z "$stats" ]] && stats="null"
echo $stats | jq '.'
