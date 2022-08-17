#!/bin/bash

# prepare a bare {} to populate.
# add timestamp of current time in secs since epoch to {}
# accept data in the form: [item_id,type_id,score:]...
# for each [item_id,type_id,score]:
# - check from whitelists: valid item_id and type_id
#    - need to generate whitelists at start of script
# - check valid score
#    - need to check if score is valid from querying items.json
# - update {} with all {id,type,score} entries.
# calculate final score
# - need a ruleset
# - then process updated {} to calculate final score
# finally, update data.json with populated {}.

# we add to DATA_OBJ then add DATA_OBJ to data.json at the end.

DATE="$1"
DATA="$2"

[[ -z "$DATA" || -z "$DATE" ]] && echo empty DATE or DATA! >&2 && exit 1

# we start with DATA in form [item_id,type_id,score:]...
#DATA="6,2,P:0,2,-:20,2,+:21,2,+:0,0,-"
# test: DATA   PASS!
#DATA="6,2,P:0,2,-:20,2,+:21,2,+:7,2,-:5,0,+:19,1,+:12,1,-"

# TODO: test regex against DATA and DATE.

# search for duplicate entry then quit if found
echo "$DATA" | tr ':' '\n' | cut -d, -f1 | sort | uniq -c | egrep -qv '^ *1' && echo duplicate entry! >&2 && exit 1

# prepare bare object.
DATA_OBJ=$(cat <<END
{
   "since_epoch": -1,
   "scores": [],
   "final_score": 0
}
END
)

# test output: bare object DATA_OBJ.     PASS!
#echo "$DATA_OBJ"

# options: now or specific date.
add_timestamp () {
    local now=$(date +%s)
    local date_str=$1
    local date_epoch=
    
    # now
    if [[ -z $1 ]]; then
	DATA_OBJ=$(jq --argjson n "$now" '.since_epoch|=$n' <<<"$DATA_OBJ")
    else # specific date
	date_epoch=$(date -d "$date_str" +%s)
	DATA_OBJ=$(jq --argjson d "$date_epoch" '.since_epoch|=$d' <<<"$DATA_OBJ")
    fi
}

add_timestamp "$DATE"

# test: add_timestamp     PASS!
#add_timestamp
#echo "$DATA_OBJ"
#add_timestamp "13 aug 2022"
#echo "$DATA_OBJ"

# generate white lists
# form: [number,]...
WHITE_I=$(jq -c '.score_items[].id' items.json | tr '\n' ',' | sed -E 's/-1,//;s/,$//')
WHITE_T=$(jq -c '.activity_types[].id' items.json | tr '\n' ',' | sed -E 's/,$//')

# test: output white lists          PASS!
#echo "items whitelist: $WHITE_I"   
#echo "types whitelist: $WHITE_T"

# if WHITE_T is 1,10,100 and type to validate is 1
#$ type=1
#$ test=$(echo "$WHITE_T" | tr ',' ' ' | egrep -o "\b$type\b")
# now compare this $test to $type
#$ [[ "$test" == "$type" ]]; echo $?
#0
validate_from_whitelist () {
    local w_l=$1     # either WHITE_I or WHITE_T
    local look_up=$2
    local test=$(echo "$w_l" | tr ',' ' ' | egrep -o "\b$look_up\b")
    [[ "$test" == "$look_up" ]]; echo $?
}

# test: validate_from_whitelist    PASS!
#echo querying from types in items.json...
#lkup1=0
#lkup2=5
#[[ $(validate_from_whitelist $WHITE_T $lkup1) -eq 0 ]] && echo $lkup1 is valid || echo $lkup1 is invalid 
#[[ $(validate_from_whitelist $WHITE_T $lkup2) -eq 0 ]] && echo $lkup2 is valid || echo $lkup2 is invalid
#echo querying from items in items.json...
#lkup1=20
#lkup2=30
#[[ $(validate_from_whitelist $WHITE_I $lkup1) -eq 0 ]] && echo $lkup1 is valid || echo $lkup1 is invalid
#[[ $(validate_from_whitelist $WHITE_I $lkup2) -eq 0 ]] && echo $lkup2 is valid || echo $lkup2 is invalid 

# example:
#$ jq -ce '.' items.json 
#{"fruits":["apple","pear","pineapple","banana","orange"]}
#$ jq -ce '.fruits|any(.=="orange")' items.json; echo $?
#true
#0
#$ jq -ce '.fruits|any(.=="orange1")' items.json; echo $?
#false
#1
validate_score () {
    local item_id=$1
    local score_chk=$2   # figure out how to do this in jq.
    # query items.json: item id: from allowed
    jq --argjson i $item_id --arg s $score_chk  -ce '.score_items[]|select(.id==$i)|.allowed|any(.==$s)' items.json > /dev/null; echo $?
}

# test: validate_score     PASS!
#id=6;chk="F"
#[[ $(validate_score $id $chk) -eq 0 ]] && echo $id: $chk is valid || echo $id: $chk is invalid
#id=6;chk="P"
#[[ $(validate_score $id $chk) -eq 0 ]] && echo $id: $chk is valid || echo $id: $chk is invalid
#id=6;chk="G"
#[[ $(validate_score $id $chk) -eq 0 ]] && echo $id: $chk is valid || echo $id: $chk is invalid
#id=20;chk="+"
#[[ $(validate_score $id $chk) -eq 0 ]] && echo $id: $chk is valid || echo $id: $chk is invalid
#id=20;chk="-"
#[[ $(validate_score $id $chk) -eq 0 ]] && echo $id: $chk is valid || echo $id: $chk is invalid 

# chop up each entry in DATA into lines
# turn [item_id,type_id,score:]... into
# [item_id,type_id,score\n]... like this. 
#
# you can do something like:
#$ echo -e "abc:def:ghi" | tr ':' '\n'
#abc
#def
#ghi
LINES=$(echo "$DATA" | tr ':' '\n')

# process lines
# - validate each entry then:
#    - if score is F then quit because final score can't be calculated if F is scored.
#    - if pass then update DATA_OBJ and proceed to next line
#    - if fail then discard DATA_OBJ and quit with error message.
# - if all pass then we end up with {} to add to data.json (after adding final score).
process_lines () {
    while IFS= read -r line; do
	local id="$(echo $line | cut -d, -f1)"
	local type="$(echo $line | cut -d, -f2)"
	local score="$(echo $line | cut -d, -f3)"

	# validate id,type,score here.
	[[ $(validate_from_whitelist $WHITE_I $id) -gt 0 ]] && echo bad item id >&2 && DATA_OBJ= && exit 1
	[[ $(validate_from_whitelist $WHITE_T $type) -gt 0 ]] && echo bad activity type >&2 && DATA_OBJ= && exit 1
	[[ $(validate_score $id $score) -gt 0 ]] && echo bad score >&2 && DATA_OBJ= && exit 1

	# check for F score.
	[[ "$score" == "F" ]] && echo there is F score >&2 && DATA_OBJ= && exit 1
	
	# if line is valid then add to DATA_OBJ.
	DATA_OBJ=$(jq --argjson i $id --argjson t $type --arg s $score '.scores+=[{"id":$i,"type":$t,"score":$s}]' <<<"$DATA_OBJ")
    done <<< "$LINES"

}

process_lines

# test: process lines   PASS!
#process_lines
#echo "$DATA_OBJ"

# calculate final score.
# ruleset encoded in form: [STR,OP:]...
FINAL_SCORE=0
RULES="+,*1:-,*-1:P,true:F,exit"

# maybe extract (with delmiter :)
#$ jq -r '.data[1].scores[].score' data.json | tr '\n' ':' | sed -E 's/:$/\n/'
# -:-:-:-:+:+:F:-:+:+:-:+:-:-:-:+:+:+:+:+:+:+
# then count OP's occurrence
#$ echo -:-:-:-:+:+:F:-:+:+:-:+:-:-:-:+:+:+:+:+:+:+ | grep -o "-" | wc -l
#9
# then OP it:
#$ OP=$(echo "+,*1:-,*-1:P,true:F,exit" | cut -d':' -f2 | cut -d',' -f2); echo $((9$OP))
#-9
# do this for every OP then sum them.


OP_STR=$(jq -r '.scores[].score' <<<"$DATA_OBJ" | tr '\n' ':' | sed -E 's/:$//')   # [OP:]... string above in the comments.
# test: OP_STR   PASS!
#echo OP_STR: "$OP_STR"

# count occurence of OP in OP_STR
count_OP () {
    echo "$OP_STR" | grep -o "$1" | wc -l
}

# test: count_OP   PASS!
#echo + $(count_OP "+")
#echo - $(count_OP "-")
#echo P $(count_OP "P")
#echo F $(count_OP "F")

SUM_A=()
sum () {
    # there are +,-,P,F to process (although F should not be there at this point).
    local n=0
    local op=
    
    # process +
    n=$(count_OP "+")
    #echo +:n: $n
    op=$(echo "$RULES" | cut -d: -f1 | cut -d, -f2)
    #echo +:op: $op
    SUM_A+=($(($n$op)))

    # process -
    n=$(count_OP "-")
    #echo -:n: $n
    op=$(echo "$RULES" | cut -d: -f2 | cut -d, -f2)
    #echo -:op: $op
    SUM_A+=($(($n$op)))

    # it seems when inputting item score: P or F, if not P then maybe it should record F.
    # this should be dealt with when inputting inside user interface (like dialog).
    # OR don't let entries with empty score to pass the UI stage (when constructing DATA).
    
    # here, we should look for any F present.
    # this is strictly not needed because F is processed inside process_lines
    # but it's here for redundancy.
    n=$(count_OP "F")
    [[ $n -gt 0 ]] && echo "final score can't be calculated due to premature F score." >&2 && SUM_A=() && exit 1 
}

# test: sum
sum

# test: SUM_A
#echo SUM_A: ${SUM_A[@]}

calculate_and_add_final_score () {
    f=0   # final score
    for s in "${SUM_A[@]}"; do
	let f+=$s
    done

    # update DATA_OBJ
    DATA_OBJ=$(jq --argjson f "$f" '.final_score|=$f' <<<"$DATA_OBJ")
}

# test: calculate and add final score   PASS!
calculate_and_add_final_score
#echo "$DATA_OBJ"

# write to data.json
update () {
    jq --argjson o "$DATA_OBJ" '.data+=[$o]' data.json > /tmp/sarang-tmp.json
    cp /tmp/sarang-tmp.json ./data.json
    rm /tmp/sarang-tmp.json
}

# test: update   PASS!
update
