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

# Read miner arguments from config
MINER_ARGS=$(cat "$MINER_PATH/miner_args.txt" 2>/dev/null)

if [[ -z "$MINER_ARGS" ]]; then
    echo -e "${RED}No miner arguments found. Run h-config.sh first.${NOCOLOR}"
    exit 1
fi

cd "$MINER_PATH"

# Log to file for h-stats.sh to parse
./ninja-vecno $MINER_ARGS 2>&1 | tee "${CUSTOM_LOG_BASENAME}.log"
