#!/bin/bash

nvmVersion=$(nvm --version 2>/dev/null)
if [[ ! $nvmVersion ]]; then
	echo -e "> Install nvm"
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

	export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

	source ~/.bashrc
else
	echo "${GREEN}> nodejs already installed${NOCOLOR}"
fi
NODE_MAJOR=16
nvm use $NODE_MAJOR

cd miner
args=$@
[[ "$@" != *"--givers"* ]] && args+=" --givers 1000"
[[ "$@" != *"--api"* ]] && args+=" --api tonhub"
[[ "$@" != *"--gpu-count"* ]] && args+=" --gpu-count $(gpu-detect NVIDIA)"

node send_multigpu.js --bin ./pow-miner-cuda $args

tail -f /dev/null
