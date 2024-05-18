#!/usr/bin/env bash
[ -t 1 ] && . colors

GIT_REPO='https://github.com/ChipiCoin/ChipiCoinGpuMiner'

function NeedToInstall() {
	local ver=`apt-cache policy $1 | grep Installed | sed 's/Installed://; s/\s*//'`
	if [[ ! $2 ]]; then
    [[ $ver && $ver != '(none)' ]] && echo 0 || echo 1
  else
    pureVer=`echo $ver | sed 's/-.*//'`
    [[ `echo "${pureVer} >= $2" | bc -l` -eq 1 ]] && echo 0 || echo 1
  fi
}

if [[ $(NeedToInstall libc6 '2.28') -eq 1 ]]; then
	echo -e "> Install libc6"
	echo "deb http://cz.archive.ubuntu.com/ubuntu jammy main" >> /etc/apt/sources.list
	apt update
	apt install libc6 -yqq --no-install-recommends
else
	echo "${GREEN}> libc6 already installed${NOCOLOR}"
fi

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

NODE_MAJOR=20
nvm install $NODE_MAJOR
nvm use $NODE_MAJOR

if [[ $(NeedToInstall git) -eq 1 ]]; then
	echo "> Install git"
	apt install -yqq git
else
	echo "${GREEN}> git already installed${NOCOLOR}"
fi

dir=/hive/miners/custom/gpu-miner/miner
if [[ ! -d $dir/.git ]]; then
	echo "> git dir does not exist, cloning"
	git clone $GIT_REPO.git $dir

	cd $dir
	npm i
else
	echo "${GREEN}> git dir exist, just pull${NOCOLOR}"
	cd $dir
	git pull
	npm i
fi

cd ..

# if we have modified files, than change them
filesToChange=("send_multigpu.js" "givers.js" "pow-miner-cuda")
for (( i = 0; i < ${#filesToChange[@]}; i++ )); do
    fileToChange=${filesToChange[$i]}
    if [[ ! -f $fileToChange ]]; then
      echo -e "${RED}> File ${CYAN}$fileToChange${RED} is in in replacement list, but not found, ignore${WHITE}"
      continue
    fi

    echo -e "${GREEN}> Replace ${CYAN}$fileToChange${WHITE}"
    cp $fileToChange $dir/$fileToChange
done

echo "${GREEN}> install script complete${NOCOLOR}"

