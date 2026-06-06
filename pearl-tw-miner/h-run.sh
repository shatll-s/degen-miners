#!/usr/bin/env bash
cd "$(dirname "$0")"
MINER_DIR="$(pwd)"

. h-manifest.conf
[[ -e $CUSTOM_CONFIG_FILENAME ]] && . "$CUSTOM_CONFIG_FILENAME"

# Fallbacks if the generated config didn't set things (e.g. config written to a different CWD,
# or h-config didn't run): derive straight from the HiveOS flight-sheet env.
[[ -z $WALLET && -n $CUSTOM_TEMPLATE ]] && WALLET="${CUSTOM_TEMPLATE%%.*}"
[[ -z $MINER_ARGS && -n $CUSTOM_USER_CONFIG ]] && MINER_ARGS="$CUSTOM_USER_CONFIG"

# ---------------------------------------------------------------------------
# Pick the right CUDA build. We ship two complete sets (binary + libpearlkernel + libcudart),
# because the binary itself is linked against a fixed soname (libcudart.so.12 vs .so.13) -- you
# cannot mix a cuda12 binary with cuda13 libs. RUNPATH is $ORIGIN, so each binary loads the .so
# files sitting next to it inside its own subdir.
#
# Rule: CUDA 13 runtime needs NVIDIA driver >= 580; CUDA 12 runs on driver >= 525. So we prefer
# cuda13 only when the driver is new enough, and fall back to cuda12 (which works everywhere) --
# with an ldd sanity check + automatic switch if the preferred set has an unresolved lib.
#
# Override: set CUDA_VARIANT=cuda12|cuda13 in the flight-sheet "Extra config arguments"
# (e.g. CUDA_VARIANT=cuda12) to force a specific build.
# ---------------------------------------------------------------------------
variant_ok() {                              # $1 = subdir; true if binary exists and all libs resolve
  local d="$MINER_DIR/$1"
  [[ -x $d/pearl-gpu-miner ]] || return 1
  LD_LIBRARY_PATH="$d" ldd "$d/pearl-gpu-miner" 2>/dev/null | grep -q 'not found' && return 1
  return 0
}

# Allow CUDA_VARIANT=cuda12|cuda13 to arrive either as a real env var or as a token inside the
# flight-sheet extra args; if it's in MINER_ARGS, pull it out so it isn't passed to the binary.
if [[ " $MINER_ARGS " == *" CUDA_VARIANT="* ]]; then
  CUDA_VARIANT=$(printf '%s\n' "$MINER_ARGS" | grep -oE 'CUDA_VARIANT=[a-zA-Z0-9]+' | tail -1 | cut -d= -f2)
  MINER_ARGS=$(printf '%s\n' "$MINER_ARGS" | sed -E 's/[[:space:]]*CUDA_VARIANT=[a-zA-Z0-9]+//g')
fi

VARIANT="${CUDA_VARIANT:-}"
if [[ -z $VARIANT ]]; then
  drv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | cut -d. -f1)
  [[ $drv =~ ^[0-9]+$ ]] || drv=0
  if (( drv >= 580 )); then VARIANT=cuda13; else VARIANT=cuda12; fi
  echo "pearl-tw-miner: driver ${drv:-?} -> $VARIANT"
else
  echo "pearl-tw-miner: CUDA_VARIANT override -> $VARIANT"
fi

# Sanity check + fall back to the other set if the chosen one can't load its libs.
if ! variant_ok "$VARIANT"; then
  other=cuda12; [[ $VARIANT == cuda12 ]] && other=cuda13
  echo "pearl-tw-miner: $VARIANT libs unresolved, falling back to $other"
  VARIANT="$other"
fi
BIN_DIR="$MINER_DIR/$VARIANT"

export LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}"
[[ -n $POOL_HOST ]] && export POOL_HOST
[[ -n $POOL_PORT ]] && export POOL_PORT
[[ -n $POOL_TLS  ]] && export POOL_TLS
# CN2=1 in the flight-sheet "Extra config arguments" enables the alternate obfuscated path.
[[ -n $CN2 ]] && export CN2
mkdir -p "$(dirname "$CUSTOM_LOG_BASENAME")"

[[ -z $WALLET ]] && { echo "pearl-tw-miner: set your prl1... payout address in the flight sheet 'Wallet and worker template' field"; sleep 10; exit 1; }

# Add --worker only when the flight-sheet extra flags didn't already provide a worker/user.
WORKER_ARG=()
if [[ " $MINER_ARGS " != *" --worker "* && " $MINER_ARGS " != *" -u "* ]]; then
  WORKER_ARG=(--worker "${WORKER:-$(hostname -s)}")
fi

echo "Launching: $BIN_DIR/pearl-gpu-miner --wallet $WALLET ${WORKER_ARG[*]} $MINER_ARGS"
"$BIN_DIR/pearl-gpu-miner" --wallet "$WALLET" "${WORKER_ARG[@]}" $MINER_ARGS 2>&1 | tee "${CUSTOM_LOG_BASENAME}.log"
