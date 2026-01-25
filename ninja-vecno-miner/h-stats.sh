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
    API_PORT=38080
fi

# Fetch stats from API
API_RESPONSE=$(curl -s --connect-timeout 2 --max-time 5 "http://localhost:$API_PORT/stats" 2>/dev/null)

if [[ -z "$API_RESPONSE" ]] || ! echo "$API_RESPONSE" | jq -e . >/dev/null 2>&1; then
    khs=0
    stats="null"
    exit 1
fi

# Parse API response
miner_version=$(echo "$API_RESPONSE" | jq -r '.version // "unknown"')
uptime=$(echo "$API_RESPONSE" | jq -r '.uptime_seconds // 0')
total_hashrate=$(echo "$API_RESPONSE" | jq -r '.total_hashrate // 0')
total_unit=$(echo "$API_RESPONSE" | jq -r '.total_hashrate_unit // "H/s"')
ac=$(echo "$API_RESPONSE" | jq -r '.shares.accepted // 0')
rj=$(echo "$API_RESPONSE" | jq -r '.shares.rejected // 0')

# Convert total hashrate to kH/s for HiveOS
case "$total_unit" in
    "H/s")  khs=$(echo "$total_hashrate" | awk '{printf "%.3f", $1 / 1000}') ;;
    "KH/s") khs=$(echo "$total_hashrate" | awk '{printf "%.3f", $1}') ;;
    "MH/s") khs=$(echo "$total_hashrate" | awk '{printf "%.3f", $1 * 1000}') ;;
    "GH/s") khs=$(echo "$total_hashrate" | awk '{printf "%.3f", $1 * 1000000}') ;;
    "TH/s") khs=$(echo "$total_hashrate" | awk '{printf "%.3f", $1 * 1000000000}') ;;
    *)      khs=0 ;;
esac

# Build per-GPU hashrate array (in H/s for HiveOS)
gpu_count=$(echo "$API_RESPONSE" | jq '.gpus | length')
hs_array="["
bus_array="["

for ((i=0; i<gpu_count; i++)); do
    gpu=$(echo "$API_RESPONSE" | jq ".gpus[$i]")
    hr=$(echo "$gpu" | jq -r '.hashrate // 0')
    hr_unit=$(echo "$gpu" | jq -r '.hashrate_unit // "H/s"')
    bus_id=$(echo "$gpu" | jq -r '.bus_id // "00:00.0"')

    # Convert hashrate to H/s
    case "$hr_unit" in
        "H/s")  hs_val=$(echo "$hr" | awk '{printf "%.0f", $1}') ;;
        "KH/s") hs_val=$(echo "$hr" | awk '{printf "%.0f", $1 * 1000}') ;;
        "MH/s") hs_val=$(echo "$hr" | awk '{printf "%.0f", $1 * 1000000}') ;;
        "GH/s") hs_val=$(echo "$hr" | awk '{printf "%.0f", $1 * 1000000000}') ;;
        "TH/s") hs_val=$(echo "$hr" | awk '{printf "%.0f", $1 * 1000000000000}') ;;
        *)      hs_val=0 ;;
    esac

    # Convert bus_id "00:06.0" to decimal
    bus_hex=$(echo "$bus_id" | grep -oP '^[0-9A-Fa-f]+' | head -1)
    bus_dec=$((16#${bus_hex:-0}))

    [[ $i -gt 0 ]] && hs_array+="," && bus_array+=","
    hs_array+="$hs_val"
    bus_array+="$bus_dec"
done

hs_array+="]"
bus_array+="]"

# Get GPU temperatures and fans from nvidia-smi (API doesn't provide these)
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
    for ((i=0; i<gpu_count; i++)); do
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
    --arg algo "vecno" \
    --argjson temp "$temps_array" \
    --argjson fan "$fans_array" \
    --argjson uptime "$uptime" \
    --arg ac "$ac" \
    --arg rj "$rj" \
    --argjson bus_numbers "$bus_array" \
    --arg ver "ninja-vecno $miner_version" \
    '{hs: $hs, hs_units: $hs_units, algo: $algo, temp: $temp, fan: $fan, uptime: $uptime, ar: [$ac, $rj], bus_numbers: $bus_numbers, ver: $ver}')

[[ -z "$khs" ]] && khs=0
[[ -z "$stats" ]] && stats="null"
