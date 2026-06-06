#!/usr/bin/env bash
# Generate the miner config from the HiveOS flight sheet.
#
# Flight-sheet mapping:
#   "Wallet and worker template"  -> $CUSTOM_TEMPLATE     = your prl1... payout address (%WAL%)
#   "Pool URL"                    -> $CUSTOM_URL          = OPTIONAL host:port override (blank = built-in)
#   "Extra config arguments"      -> $CUSTOM_USER_CONFIG  = extra CLI flags, e.g. --worker %WORKER_NAME% --gpus 0,1
#   rig worker name               -> $WORKER_NAME
#
# The generated file is *sourced* by h-run.sh, so EVERY line here must be a quoted shell
# assignment. Extra flight-sheet flags are stored as the value of MINER_ARGS (NOT written as a
# bare line) and later passed to the miner as argv -- otherwise a value like "--worker rig07"
# would be executed as a command on source -> "--worker: command not found".

[[ -z $CUSTOM_CONFIG_FILENAME ]] && echo "no CUSTOM_CONFIG_FILENAME" && return 1

# The wallet template may be "prl1...." or "prl1.....%WORKER_NAME%" — keep only the address part.
WALLET="${CUSTOM_TEMPLATE%%.*}"
[[ -z $WALLET ]] && WALLET="$CUSTOM_TEMPLATE"

conf="WALLET=\"$WALLET\""$'\n'
conf+="WORKER=\"${WORKER_NAME:-$(hostname -s)}\""$'\n'

# Extra flight-sheet flags -> miner argv (stored quoted so sourcing is safe).
conf+="MINER_ARGS=\"${CUSTOM_USER_CONFIG}\""$'\n'

# Optional pool override from the "Pool URL" field (env vars the binary understands). Strip any
# scheme (stratum+tcp://...) and split. Skipped for the built-in pool so we don't fight the
# pinned-cert default (the binary logs "ignoring POOL_HOST/POOL_PORT" for its own endpoint).
if [[ -n $CUSTOM_URL && $CUSTOM_URL != pearl.tw-pool.com:* ]]; then
  url="${CUSTOM_URL##*://}"
  host="${url%%:*}"
  port="${url##*:}"
  [[ -n $host ]] && conf+="POOL_HOST=\"$host\""$'\n'
  [[ -n $port && $port != "$host" ]] && conf+="POOL_PORT=\"$port\""$'\n'
fi

echo "$conf" > "$CUSTOM_CONFIG_FILENAME"
