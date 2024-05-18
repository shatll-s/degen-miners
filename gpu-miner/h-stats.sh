#!/usr/bin/env bash

################################
###
### gpu miner based on gram-miner
### Hive integration: shatll
###
################################

. /hive/miners/custom/gpu-miner/h-manifest.conf
stats_raw=`cat $CUSTOM_LOG_BASENAME.log | grep -w "mined" | tail -n 1 `

#Calculate miner log freshness
maxDelay=120
time_now=`date +%s`
datetime_rep=`echo $stats_raw | awk '{print $1 $2}' | sed -e 's/:$//; s/,/ /'`

time_rep=`date -d "$datetime_rep" +%s`
diffTime=`echo $((time_now-time_rep)) | tr -d '-'`

if [ "$diffTime" -lt "$maxDelay" ]; then
	gpuCount=`gpu-detect NVIDIA`

	busid_json='[]'
	fan_json='[]'
	temp_json='[]'

	declare -a hr_data=( )

	for (( i=0; i < gpuCount; i++ )); do
		hr_data+=(0)
	done

	gpu_stats=$(< $GPU_STATS_JSON)

    readarray -t gpu_stats < <( jq --slurp -r -c '.[] | .brand, .temp, .fan, .busids | join(" ")' $GPU_STATS_JSON 2>/dev/null)
    brands=(${gpu_stats[0]})
    temps=(${gpu_stats[1]})
    fans=(${gpu_stats[2]})
    busids=(${gpu_stats[3]})
    gpuCountFromStatsJson=${#brands[@]}

    fan_arr=()
    temp_arr=()

	for (( i=0; i < $gpuCountFromStatsJson; i++ )); do
		brand=${brands[$i]}

		if [[ ${brands[$i]} != 'cpu' ]]; then
			fan_arr+=(${fans[i]})
			temp_arr+=(${temps[i]})
		fi
	done

	[[ ${brands[0]} == 'cpu' ]] && internalCpuShift=1 || internalCpuShift=0

	readarray -t speed_lines < <(tail -n 170 "$CUSTOM_LOG_BASENAME.log" | grep "instant speed" | tail -n "$gpuCount")
	busidRawJson='[]'
	for (( i=0; i < $gpuCount; i++ )); do
		y=`echo "$i + $internalCpuShift" | bc`
		busid=${busids[$y]}
		b=`echo $busid | awk -F ':' '{print $1}'`
		busidRawJson=$(jq ". += [\"$b\"]" <<< "$busidRawJson")
		fan_json=$(jq ". += [\"${fans[$y]}\"]" <<< "$fan_json")
		temp_json=$(jq ". += [\"${temps[$y]}\"]" <<< "$temp_json")
		if [[ -n "${speed_lines[$i]}" ]]; then
		    instant_speed=$(echo "${speed_lines[$i]}" | grep -oP 'instant speed: \K[0-9.]+(?= Mhash/s)')
		    if (( $(echo "$instant_speed > 0" | bc) )); then
		        hr_data[$i]=$instant_speed
		    fi
		fi
	done

	for (( i=0; i < `echo $busidRawJson | jq 'length'`; i++ )); do
		busidHex=`echo $busidRawJson | jq -r ".[$i]"  | tr '[:lower:]' '[:upper:]'`
		[[ ${busidHex:0:1} == 0 ]] && busidHex=${busidHex:1:2}

		busidDecimal=`echo "ibase=16; $busidHex" | bc`

		busid_json=`jq ". + [\"$busidDecimal\"]" <<< "$busid_json"`
	done


	hr_json=$(printf '%s\n' "${hr_data[@]}" | jq -R . | jq -s .)

	totalHr=0
	for hr in "${hr_data[@]}"; do
		totalHr=$(echo "$totalHr + $hr" | bc)
	done
	totalKhs=`echo "scale=0; $totalHr * 1000 / 1" | bc -l`

	lastLine=$(tail -n 1 "$CUSTOM_LOG_BASENAME.log" | sed 's/\x1b\[[0-9; ]*m//g')
	total_share=$(echo "$lastLine" | awk '{print $7}')

	uptime=$(( `date +%s` - `stat -c %Y $CUSTOM_CONFIG_FILENAME` ))
    #Compile stats/khs
    stats=$(jq -nc \
		--arg algo "sha256" \
		--arg ver "$CUSTOM_VERSION" \
		--arg uptime "$uptime" \
		--argjson hs "$hr_json" \
		--arg hs_units "mhs" \
		--arg ths $totalKhs \
		--argjson bus_numbers "$busid_json" \
		--argjson fan "$fan_json" \
		--argjson temp "$temp_json" \
        '{ $hs, $ths, $hs_units, $algo, $ver, $uptime, $bus_numbers, $fan, $temp}')
    khs=$totalHr
else
  khs=0
  stats="null"
fi

#echo Debug info:
echo Log file : $CUSTOM_LOG_BASENAME.log
echo Time since last log entry : $diffTime
#echo Raw stats : $stats_raw
echo KHS : $khs
echo Output : $stats

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
