####################################################################################
###
### gpool-miner
###
####################################################################################

#!/usr/bin/env bash
[[ -e /hive/miners/custom ]] && . /hive/miners/custom/gpool-miner/h-manifest.conf

conf=""
conf+=" --pubkey $CUSTOM_TEMPLATE"

[[ ! -z $CUSTOM_USER_CONFIG ]] && conf+=" $CUSTOM_USER_CONFIG"

echo "$conf"
echo "$conf" > $CUSTOM_CONFIG_FILENAME

