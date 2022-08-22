#!/bin/bash

# SARANG v0.1
#
# A way to measure Sarang's progress.
#
# Written by Logan Won-Ki Lee
# August 2022
#
# Sarang's story:
# Sarang is a 14 year old fox terrier. He is my dog. He injured his neck on
# an accident and he got paralyzed on all his limbs. Me and my family cared
# for Sarang for two months; he made a remarkable recovery. Now he is able
# to stand and walk, albeit wobbly at times.
#
# SARANG is a program to measure Sarang's progress when Sarang does his daily
# morning exercise on our backyward lawn. So I can track his progress (esp.
# how he walks) and hopefully move him out of the room (he is confined to mum's
# room except when he is out for his exercise). Fingers crossed.
#


# generate report:
# - reference by day-month-year
# - prooduce output:
#      - day-month-year
#      - item desc, type desc, score for each item
#      - final score

# A note on data.json:
#   - each item is either a non-empty string or an empty string.
#   - all scores are tallied unless if they are empty.
#   - final score is not calculated by this file.

# ref by day-month-year
# - retrieving from data.json is done in range of secs from epoch
#    - to do this: wanted date range in day-month-year format -> convert to range of secs from epoch
#    - -> retrieve range from data.json

# converting from human readable format to secs since epoch:
# $ date -d '9 aug 2022' +"%s"
# 1659967200
# $ date -d @1659967200
# Tue 09 Aug 2022 00:00:00 AEST

# example:
# if date to retrieve from data.json is 9 aug 2022:
# - human-readable range should be: 9 aug 2022 00:00:00 to 9 aug 2022 23:59:59
#
# if date to retrieve is 8 aug 2022 to 10 aug 2022:
# - 8 aug 2022 00:00:00 to 10 aug 2022 23:59:59

# there are two cases: retrieve a single date or a range of dates.
# - if single date: date: 00:00:00 to 23:99:99
# - if range: date1 00:00:00 to date2 23:99:99
#
# args: date1, date2 where dates are given as day-month-year.
# date2 may be optional.

ARG1="$1"   # first date in range
ARG2="$2"   # second date in range

[[ -z "$ARG1" || -z "$ARG2" ]] && echo "args not provided" >&2 && exit 1

# set up: A_EPOCH_RANGE
A_EPOCH_RANGE=()
generate_range_in_epoch () {
    #if [[ -z $2 ]]; then
	#A_EPOCH_RANGE+=($(date -d "$1 00:00:00" +"%s"))
	#A_EPOCH_RANGE+=($(date -d "$1 23:59:59" +"%s"))
    #else
	#A_EPOCH_RANGE+=($(date -d "$1 00:00:00" +"%s"))
	#A_EPOCH_RANGE+=($(date -d "$2 23:59:59" +"%s"))
    #fi

    A_EPOCH_RANGE+=($(date -d "$1" +"%s"))
    A_EPOCH_RANGE+=($(date -d "$2" +"%s"))
}

# test   PASS!
#generate_range_in_epoch "8 aug 2022"
#generate_range_in_epoch "8 aug 2022" "11 aug 2022"
#for s in "${A_EPOCH_RANGE[@]}"; do
#    date -d @"$s"
#done

# ref from data.json to return matching {}
# use A_EPOCH_RANGE to query from data.json.
# S_QUERY may contain multiple entries as single string.
# args: none
# depends: on calling generate_range_in_epoch
S_QUERY=
ref_by_range_in_epoch () {
    local r1=${A_EPOCH_RANGE[0]}
    local r2=${A_EPOCH_RANGE[1]}

    S_QUERY=$(jq --argjson r1 "$r1" --argjson r2 "$r2" '.data[]|select(.since_epoch>=$r1 and .since_epoch<=$r2)' data.json)

    # exit if S_QUERY is empty
    [[ -z "$S_QUERY" ]] && echo no match! >&2 && exit 1
}

# test: generate range in epoch, ref by range in epoch
#generate_range_in_epoch "11 aug 2022"   #PASS!
#generate_range_in_epoch "8 aug 2022" "15 aug 2022"   #PASS!
#generate_range_in_epoch "9 aug 2022" "11 aug 2022"   #PASS!
#generate_range_in_epoch "8 aug 2022" "10 aug 2022"   #PASS!
#ref_by_range_in_epoch
#echo "$S_QUERY"

# following two ref_* functions query from items.json.

# args: item id
I_DESC=
ref_item_desc_by_id () {
    id=$1; I_DESC="$(jq -r --argjson id $id '.score_items[]|select(.id==$id)|.desc' items.json)"
}

# test
#ref_item_desc_by_id 0  # PASS!
#echo "$I_DESC"

# args: type id
T_DESC=
ref_type_desc_by_id () {
    id=$1; T_DESC="$(jq -r --argjson id $id '.activity_types[]|select(.id==$id)|.desc' items.json)"
}

# test
#ref_type_desc_by_id 0   # PASS!
#echo "$T_DESC"

#echo block

# report: read from S_QUERY: for each entry {}:
#      - day-month-year                                                                                                                                                                                          
#      - item desc, type desc, score for each item                                                                                                                                                               
#      - final score
# for this we need: f's: ref_item_desc_by_id, ref_type_desc_by_id.
# specifying type is optional.
generate_report () {
    # get max/min/average of final scores from S_QUERY
    local max=$(jq '.final_score' <<< "$S_QUERY" | jq -s 'max')  
    local min=$(jq '.final_score' <<< "$S_QUERY" | jq -s 'min')
    local avg=$(jq '.final_score' <<< "$S_QUERY" | jq -s 'add/length')
    
    local lines="$(jq -r '.since_epoch as $t|.final_score as $f | .scores[]|($t|tostring)+"|"+($f|tostring)+"|"+(.id|tostring)+"|"+(.type|tostring)+"|"+(.score|tostring)' <<< "$S_QUERY")"
    # print inside this loop
    printf "%-30s %-11s %-50s %-50s %-11s\n" "time" "final_score" "score_item" "type" "score"
    while IFS= read -r line ; do
	local secs_epoch=$(echo $line | cut -d '|' -f 1)
	local final_score=$(echo $line | cut -d '|' -f 2)
	local item_id=$(echo $line | cut -d '|' -f 3)
	local type_id=$(echo $line | cut -d '|' -f 4)
	local score=$(echo $line | cut -d '|' -f 5)

	# convert secs since epoch to human-readable form
	local time_h=$(date -d @"$secs_epoch" | tr ' ' '_')
	
	# ref for desc's
	#echo "item id" $item_id
	ref_item_desc_by_id $item_id
	ref_type_desc_by_id $type_id
	i_desc=$(echo "$I_DESC" | cut -c -50)
	t_desc=$(echo "$T_DESC" | cut -c -50)
	
	# test
	#echo -n "secs since epoch: $secs_epoch   "
	#echo -n "final score: $final_score   "
	#echo -n "item id: $item_id   "
	#echo -n "type_id: $type_id   "
	#echo -n "score: $score   "
	#echo

	printf "%-30s %-11s %-50s %-50s %-11s\n" $time_h $final_score $i_desc $t_desc $score
    done <<< "$lines"

    echo
    echo "final score stats (from $ARG1 to $ARG2):"
    printf "%-10s %-10s %-10s\n" "min" "max" "avg"
    printf "%-10s %-10s %-10s\n" $min $max $avg

}

# run
if [[ "$ARG1" == "all" ]]; then
    S_QUERY=$(jq '.data[]' data.json)
else
    generate_range_in_epoch "$ARG1" "$ARG2"
    ref_by_range_in_epoch
fi
generate_report

