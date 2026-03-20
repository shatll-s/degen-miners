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

# CUSTOM_URL: pool stratum host:port
# CUSTOM_TEMPLATE: address.worker
# CUSTOM_USER_CONFIG: extra CLI args

if [[ -z "$CUSTOM_URL" ]]; then
    echo -e "${RED}No pool URL configured${NOCOLOR}"
    exit 1
fi

if [[ -z "$CUSTOM_TEMPLATE" ]]; then
    echo -e "${RED}No wallet configured${NOCOLOR}"
    exit 1
fi

POOL=$(echo $CUSTOM_URL | awk '{print $1}')

MINER_ARGS="-o $POOL -u $CUSTOM_TEMPLATE"

# Algo from CUSTOM_USER_CONFIG if specified with -a, otherwise omit
if [[ "$CUSTOM_USER_CONFIG" == *"-a "* || "$CUSTOM_USER_CONFIG" == *"--algo "* ]]; then
    MINER_ARGS="$MINER_ARGS"
else
    # No algo in user config — don't add -a flag
    :
fi

# API port
API_PORT=45545
MINER_ARGS="$MINER_ARGS --api-port $API_PORT"

# Add any extra user config arguments
if [[ -n "$CUSTOM_USER_CONFIG" ]]; then
    MINER_ARGS="$MINER_ARGS $CUSTOM_USER_CONFIG"
fi

# Save arguments and API port
echo "$MINER_ARGS" > "$MINER_PATH/miner_args.txt"
echo "$API_PORT" > "$MINER_PATH/api_port.txt"

echo "Miner arguments: $MINER_ARGS"
