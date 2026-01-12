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
# CUSTOM_URL: pool address (host:port) or solo node address (host:port or just host)
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

# Check if URL contains "stratum" -> pool mode
# Otherwise -> solo mode
if [[ "$URL" == *"stratum"* ]]; then
    # Pool mode: parse stratum+tcp://host:port format
    # Remove stratum+tcp:// prefix
    URL_CLEAN=$(echo "$URL" | sed 's|stratum+tcp://||' | sed 's|stratum://||')

    STRATUM_SERVER=$(echo "$URL_CLEAN" | cut -d':' -f1)
    STRATUM_PORT=$(echo "$URL_CLEAN" | cut -d':' -f2 | cut -d'/' -f1)

    MINER_ARGS="--mining-address $CUSTOM_TEMPLATE --stratum-server $STRATUM_SERVER --stratum-port $STRATUM_PORT"

    # Add worker name if available
    if [[ ! -z "$WORKER_NAME" ]]; then
        MINER_ARGS="$MINER_ARGS --stratum-worker $WORKER_NAME"
    fi

    echo "Pool mode: $STRATUM_SERVER:$STRATUM_PORT"
elif [[ "$URL" == *":"* ]]; then
    # Has port - could be pool or solo with port
    HOST=$(echo "$URL" | cut -d':' -f1)
    PORT=$(echo "$URL" | cut -d':' -f2)

    # Assume pool mode if port looks like stratum port (not vecno node port)
    if [[ "$PORT" -lt 10000 ]]; then
        # Pool mode
        MINER_ARGS="--mining-address $CUSTOM_TEMPLATE --stratum-server $HOST --stratum-port $PORT"

        if [[ ! -z "$WORKER_NAME" ]]; then
            MINER_ARGS="$MINER_ARGS --stratum-worker $WORKER_NAME"
        fi

        echo "Pool mode: $HOST:$PORT"
    else
        # Solo mode with port
        MINER_ARGS="--mining-address $CUSTOM_TEMPLATE --vecno-address $HOST --port $PORT"
        echo "Solo mode: $HOST:$PORT"
    fi
else
    # Solo mode: URL is the vecno node address without port
    MINER_ARGS="--mining-address $CUSTOM_TEMPLATE --vecno-address $URL"
    echo "Solo mode: $URL"
fi

# Add any extra user config arguments
if [[ ! -z "$CUSTOM_USER_CONFIG" ]]; then
    MINER_ARGS="$MINER_ARGS $CUSTOM_USER_CONFIG"
fi

# Save arguments to file for h-run.sh
echo "$MINER_ARGS" > "$MINER_PATH/miner_args.txt"

echo "Miner arguments: $MINER_ARGS"
