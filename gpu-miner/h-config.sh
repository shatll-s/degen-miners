#!/usr/bin/env bash

####################################################################################
###
### gpu miner based on gram-miner
### Hive integration: shatll
###
####################################################################################

[[ -e /hive/custom ]] && . /hive/custom/gpu-miner/h-manifest.conf
[[ -e /hive/miners/custom ]] && . /hive/miners/custom/gpu-miner/h-manifest.conf

/hive/miners/custom/gpu-miner/install.sh

conf=""
conf2="SEED=$CUSTOM_TEMPLATE"

[[ ! -z $CUSTOM_USER_CONFIG ]] && conf+=" $CUSTOM_USER_CONFIG"

echo "$conf"
if [[ "$conf" == *"--target-address"* ]]; then
  target_address=`echo $conf | sed -e 's/.*--target-address //; s/ .*//'`
  [[ $target_address ]] && conf2+="\nTARGET_ADDRESS=$target_address"
  conf=`echo "$conf" | sed -e "s/--target-address $target_address//"`
fi

echo -e "$conf" > $CUSTOM_CONFIG_FILENAME

[[ $CUSTOM_PASS ]] && conf2+="\nTONAPI_TOKEN=$CUSTOM_PASS"
echo -e "$conf2" > $CUSTOM_CONFIG_FILENAME2
