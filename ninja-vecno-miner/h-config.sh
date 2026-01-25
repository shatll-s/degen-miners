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

# Build command line arguments for ninja-vecno
# CUSTOM_URL: pool address (host:port)
# CUSTOM_TEMPLATE: wallet address

MINER_ARGS=""

# Take first URL from CUSTOM_URL
URL=$(echo $CUSTOM_URL | awk '{print $1}')

if [[ -z "$URL" ]]; then
    echo -e "${RED}No URL configured${NOCOLOR}"
    exit 1
fi

if [[ -z "$CUSTOM_TEMPLATE" ]]; then
    echo -e "${RED}No wallet address configured${NOCOLOR}"
    exit 1
fi

# Pool mode: split host:port
STRATUM_SERVER=$(echo "$URL" | cut -d':' -f1)
STRATUM_PORT=$(echo "$URL" | cut -d':' -f2)

MINER_ARGS="--mining-address $CUSTOM_TEMPLATE --stratum-server $STRATUM_SERVER --stratum-port $STRATUM_PORT"

# Add worker name if available
if [[ ! -z "$WORKER_NAME" ]]; then
    MINER_ARGS="$MINER_ARGS --stratum-worker $WORKER_NAME"
fi

echo "Pool mode: $STRATUM_SERVER:$STRATUM_PORT"

# API port for stats
API_PORT=38083
MINER_ARGS="$MINER_ARGS --api-port $API_PORT"

# Add any extra user config arguments
if [[ ! -z "$CUSTOM_USER_CONFIG" ]]; then
    MINER_ARGS="$MINER_ARGS $CUSTOM_USER_CONFIG"
fi

# Save arguments and API port for h-run.sh and h-stats.sh
echo "$MINER_ARGS" > "$MINER_PATH/miner_args.txt"
echo "$API_PORT" > "$MINER_PATH/api_port.txt"

echo "Miner arguments: $MINER_ARGS"
