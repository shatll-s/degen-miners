#!/usr/bin/env bash

####################################################################################
###
### gpool-miner
### Hive integration: shatll
###
####################################################################################

#######################
# MAIN script body
#######################

. /hive/miners/custom/gpool-miner/h-manifest.conf

#Calculate miner log freshness
maxDelay=120

time_now=`date +%s`
info_line=`tail -n 40 $CUSTOM_LOG_BASENAME.log | grep -w "info" | tail -n 1`
datetime_rep=`echo $info_line | awk '{print $1" "$2}'`
time_rep=`date -d "$datetime_rep" +%s`
diffTime=`echo $((time_now-time_rep)) | tr -d '-'`

if [ "$diffTime" -lt "$maxDelay" ]; then
  linesToSearch=200
  total_hr=0

  #remove all unread symbols
  logPart=`tail -n $linesToSearch $CUSTOM_LOG_BASENAME.log | tr '\n' '@' | tr -dc '[[:print:]]' | tr '@' '\n' | sed 's/\[00m//g' | tr '\|' @ | sed '/^@/!d'`

  #GPU Status
  gpu_stats=$(< $GPU_STATS_JSON)

  readarray -t gpu_stats < <( jq --slurp -r -c '.[] | .busids, .brand, .temp, .fan | join(" ")' $GPU_STATS_JSON 2>/dev/null)
  busids=(${gpu_stats[0]})
  brands=(${gpu_stats[1]})
#  echo "Debug: brands[0] ${brands[0]}"
  [[ ${brands[0]} == 'cpu' ]] && cpuFirst=1 || cpuFirst=0
  temps=(${gpu_stats[2]})
  fans=(${gpu_stats[3]})
  gpu_count=${#busids[@]}

  hash_arr=()
  busid_arr=()
  fan_arr=()
  temp_arr=()

  for(( i=0; i < gpu_count; i++ )); do
    [[ "${busids[i]}" =~ ^([A-Fa-f0-9]+): ]]
    busid_arr+=($((16#${BASH_REMATCH[1]})))
    temp_arr+=(${temps[i]})
    fan_arr+=(${fans[i]})
#    echo "Debug: $i $((16#${BASH_REMATCH[1]})) ${temps[i]} ${fans[i]}"

    if [[ $cpuFirst -eq 1 && i -eq 0 ]]; then
      hr=0
    else
      [[ $cpuFirst -eq 1 ]] && shift=-1 || shift=0
      y=`echo "$i + $shift" | bc`

      hrStr=`echo "$logPart" | grep -E "^@[[:space:]]$y[[:space:]]"`
      rawHr=`echo $hrStr | sed "s#.*@[[:space:]]\([.0-9]*\).*H/s.*#\1#"`

      if [[ $rawHr =~ ^[.0-9]+$ ]]; then
        hr=`echo "scale=2; $rawHr / 1000" | bc -l`

        total_hr=$(echo "$total_hr + $hr" | bc)
      else
        hr=0
      fi
    fi

    hash_arr+=($hr)
  done

  hash_json=`printf '%s\n' "${hash_arr[@]}" | jq -cs '.'`
  bus_numbers=`printf '%s\n' "${busid_arr[@]}"  | jq -cs '.'`
  fan_json=`printf '%s\n' "${fan_arr[@]}"  | jq -cs '.'`
  temp_json=`printf '%s\n' "${temp_arr[@]}"  | jq -cs '.'`

  uptime=$(( `date +%s` - `stat -c %Y $CUSTOM_CONFIG_FILENAME` ))
  ver=`echo $info_line | awk '{print $3}' | tr -d '()v'`

  oreBalance=`tail -n 200 $CUSTOM_LOG_BASENAME.log | grep -w "Current ORE balance" | tail -n 1 | awk '{print $10}'`
  if [[ ! $oreBalance ]]; then
    oreBalance=`echo "scale=4; $oreBalance /1" | bc`
    [[ ${oreBalance:0:1} == "." ]] && oreBalance="0$oreBalance"
    ver="$ver | $oreBalance ORE"
  fi

  coalBalance=`tail -n 200 $CUSTOM_LOG_BASENAME.log | grep -w "Current COAL balance" | tail -n 1 | awk '{print $10}'`
  if [[ $coalBalance ]]; then
    coalBalance=`echo "scale=4; $coalBalance /1" | bc`
    [[ ${coalBalance:0:1} == "." ]] && coalBalance="0$coalBalance"
    ver="$ver | $coalBalance COAL"
  fi

  ver="$ver | $oreBalance ORE | $coalBalance COAL"


  #Compile stats/khs
  stats=$(jq -nc \
          --argjson hs "$hash_json"\
          --arg ver "$ver" \
          --arg ths "$total_hr" \
          --argjson bus_numbers "$bus_numbers" \
          --argjson fan "$fan_json" \
          --argjson temp "$temp_json" \
          --arg uptime "$uptime" \
          '{ hs: $hs, $ths, hs_units: "khs", algo : "ore", ver:$ver , $uptime, $bus_numbers, $temp, $fan}')
  khs=$total_hr
else
  khs=0
  stats="null"
fi

echo Debug info:
echo Log file : $CUSTOM_LOG_BASENAME.log
echo Time since last log entry : $diffTime
echo Raw stats : $stats_raw
echo KHS : $khs
echo Output : $stats

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
