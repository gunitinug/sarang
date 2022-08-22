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


VER="0.1"

# menu(main menu)
# - add entry
# - show report
# - delete entry
# - quit

# add entry:
# inputbox(take entry date: now or specific)
#    -> keep showing inputbox until correct date ->
#    -> loop: radiolist(done, show activity types, show processed items, cancel, list of all items)
#       -> selected item -> inputbox(type id) -> if invalid type id show inputbox again ->
#                                             -> radiolist: processed item removed from list(to_process_l)
#                                                   processed item added for "show processed items"
#       -> show activity types -> textbox showing all activity types -> radiolist
#       -> show processed items -> textbox showing all processed items -> radiolist
#       -> cancel -> main menu
#       -> done -> msgbox(error processing items) -> main menu
#               -> textbox(show report) -> main menu

# here DATE and DATA are ONLY for writing an entry to data.json.
DATE=""
DATA=""

# keep track of items to process yet
to_process_l="$(jq -r '.score_items[]|select(.id!=-1)|(.id|tostring)+":"+.allowed[]+" "+.desc' items.json | sed -E 's/$/ OFF/')"
# test: to_process_l   PASS!
#whiptail --title "content of to_process_l" --msgbox "$to_process_l" 8 78

# keep track of processed items
spool_l=""

validate_date () {
    local d=$1
    local n=0
    
    # validate d
    n=$(date -d "$d" &>/dev/null; echo $?)
    [[ $n -gt 0 ]] && echo 1 || echo 0
}

# test: validate_date   PASS!
#echo not valid: $(validate_date "20 augg 2023")
#echo valid: $(validate_date "20 aug 2023")

validate_type () {
    local type=$1
    local test=$(jq '.activity_types[]|.id' items.json | tr '\n' ' ' | egrep -o "\b$type\b")
    [[ $type == $test ]] && echo 0 || echo 1
}

# test: validate_type   PASS!
#echo valid: $(validate_type 1)
#echo invalid: $(validate_type 10)

select_item () {
    local parse="$1"
    local item=$(echo "$parse" | cut -d: -f1)
    local score=$(echo "$parse" | cut -d: -f2)
    local desc=$(jq -r --argjson i $item '.score_items[]|select(.id==$i)|.desc' items.json)
    
    while :; do
	local chk=1
	local type=$(whiptail --inputbox "Provide type id" 8 39 --title "Type" 3>&1 1>&2 2>&3)
	[[ -n "$type"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_type "$type") -eq 0 ]] && chk=0
	[[ "$chk" -eq 0 ]] && break
    done

    local desc2=$(jq -r --argjson t $type '.activity_types[]|select(.id==$t)|.desc' items.json)

    DATA+="$item,$type,$score:"
    
    # exclude processed item for viewing in radiolist (to_process_l).
    # also update spool_l (list of processed items) here.
    if [[ $score == "P" || $score == "F" ]]; then
	to_process_l=$(echo "$to_process_l" | awk -v i="$item:P" -v j="$item:F" '$1!=i && $1!=j')   # PASS!
	spool_l+="$item|$desc|$score|$type|$desc2\n"
    else
	to_process_l=$(echo "$to_process_l" | awk -v i="$item:$score" '$1!=i')     # PASS!
	spool_l+="$item|$desc|$score|$type|$desc2\n"
    fi
}

# test: select_item
#select_item "6:F"    # PASS!
# select_item 1:-   # PASS!
#echo "to_process_l:"
#echo "$to_process_l"

show_act_types () {
    ACT_TYPES=$(jq -r '.activity_types[]|(.id|tostring)+"|"+.desc' items.json)
    whiptail --title "Here are list of all activity types you can use" --msgbox "$ACT_TYPES" 20 78
}

show_procd_items () {
    whiptail --title "Here are list of scored items so far" --msgbox "$spool_l" 30 78
}

# process scoring items
done_add_entry () {
    [[ -z "$DATA" || -z "$DATE" ]] && return 1

    # check regex against DATA. Should be [id,type,score:]...
    
    DATA=$(echo "$DATA" | sed 's/:$//')
    
    local err=$(./write.sh "$DATE" "$DATA" 3>&1 1>&2 2>&3)
    [[ -n "$err" ]] && whiptail --msgbox "$err" 20 78 --title "Error" && DATA="" && DATE="" && to_process_l="$(jq -r '.score_items[]|select(.id!=-1)|(.id|tostring)+":"+.allowed[]+" "+.desc' items.json | sed -E 's/$/ OFF/')" && spool_l="" && return 1   # clean up when there is write error.

    local report=$(./report.sh "$DATE" "$DATE" 2>/dev/null)
    whiptail --msgbox "$report" 16 200 --title "Report" --scrolltext     
}

add_entry () {
    # inputbox: get date
    # implement "now" as date.
    while :; do
	local chk=1
	date_ae=$(whiptail --inputbox "Provide date(eg. 20 aug 2023 12:00 or 'now')" 8 39 --title "Date" 3>&1 1>&2 2>&3)
	local cancel="$?"

	# if selected 'cancel' then return to main menu.
	[[ "$cancel" -gt 0 ]] && return 1
	
	[[ "$date_ae" == "now" ]] && date_ae=$(date +'%e %b %G %H:%M') && break
	
	local pattern="^[0-9]{1,2} [A-Za-z]{3,9} [0-9]{4} [0-9]{1,2}:[0-9]{1,2}$"
	[[ -n "$date_ae"  ]] && [[ "$cancel" -eq 0 ]] && [[ $(validate_date "$date_ae") -eq 0 ]] && [[ "$date_ae" =~ $pattern ]] && chk=0
	[[ "$chk" -eq 0 ]] && break	
    done

    DATE="$date_ae"
    
    # radiolist loop
    while :; do
	# display radiolist
	sel_ae=$(whiptail --title "Add entry" --radiolist \
			     "Choose an item to score next.\ndate: $DATE" 30 78 20 \
			     "DONE" "Process your scores" ON \
			     "ACTIVITY_TYPES" "Show available activity types" OFF \
			     "PROCESSED_ITEMS" "Show scored items" OFF \
			     "CANCEL" "Cancel and back to main menu" OFF $to_process_l 3>&1 1>&2 2>&3)

	# if selected 'cancel' then return to main menu.
	local cancel2="$?"
	[[ "$cancel2" -gt 0 ]] && return 1
	
	# choices
	case "$sel_ae" in
	    "DONE")
	        # pass DATE and DATA to write.sh (this writes entry to data.json).
		# trailing : from DATA should be removed beforehand.
	        # if either DATE or DATA is empty then it shouldn't be processed this way.
		# after writing, show report by retrieving latest entry by DATE from report.sh.
		done_add_entry
		return 0
	        ;;
	    "ACTIVITY_TYPES")
		show_act_types
		;;
	    "PROCESSED_ITEMS")
		show_procd_items
		;;
	    "CANCEL")
		# should really clear DATE= and DATA= here.
		DATE=""
		DATA=""
		to_process_l="$(jq -r '.score_items[]|select(.id!=-1)|(.id|tostring)+":"+.allowed[]+" "+.desc' items.json | sed -E 's/$/ OFF/')" 
		spool_l=""
		return 1
		;;
	    *)
		select_item $sel_ae 
		;;
        esac

    done
}

# test: add_entry
#add_entry

# test: DATE
#echo date: "$DATE"

# test: DATA
#echo data: "$DATA"

#
# show report: whiptail textbox to show output from report.sh
# - filter by date range.
#   - use two series of inputboxes for each date in range.
#   - if it is "now" then only one inputbox is shown.
#   - convert to secs since epoch appropriately (not needed).
# - if errorneous dates then no pass (loop it until get it right).
# - then display all matched entries in msgbox.

show_report () {
    # "now" is removed. "today" added.
    # if date1==date2 then pass to report.sh just one of them.
    local date1=""
    local date2=""
    #local now=1
    local today=1

    # loop inputboxes until valid date1, date2 is retrieved
    # if "now" is entered then only show one inputbox then date2=$date1.
    # use validate_date

    # first, check date1,date2 to match regex ^[0-9]{1,2} [a-zA-Z]{3,9} [0-9]{4}$
    # if fail, keep displaying inputbox until valid value is provided.
    local pattern="^[0-9]{1,2} [A-Za-z]{3,9} [0-9]{4} [0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2}){0,1}$"
    local pattern2="^[0-9]+ (day|month|year)s{0,1} ago$"
    local usage="eg. 20 aug 2023 9:15 or 20 aug 2023 9:15:10 or 4 day ago or 3 month ago or 1 year ago"
    
    while :; do
	date1=$(whiptail --inputbox "Provide first date from range (just 'today' or $usage)" 10 49 --title "Date range" 3>&1 1>&2 2>&3)
	if [[ "$date1" == "today" ]]; then
		# assign to date1 and date2
		date1="$(date +'%e %b %G') 0:0" 
		date2="$(date +'%e %b %G') 23:59"
		today=0
		break
	else
		[[ -n "$date1"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date1") -eq 0 ]] && [[ "$date1" =~ $pattern || "$date1" =~ $pattern2  ]] && break
	fi
    done


    if [[ "$today" -eq 1 ]]; then
	while :; do
		date2=$(whiptail --inputbox "Provide second date from range ($usage)" 10 49 --title "Date range" 3>&1 1>&2 2>&3)
		[[ -n "$date2"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date2") -eq 0 ]] && [[ "$date2" =~ $pattern || "$date2" =~ $pattern2 ]] && break
	done
    fi    
    
    # get date1
    #while :; do
	#local chk1=1
	#date1=$(whiptail --inputbox "Provide start date(eg. 20 aug 2023 12:00)" 8 39 --title "Date" 3>&1 1>&2 2>&3)

	#[[ -n "$date1"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date1") -eq 0 ]] && [[ "$date1" =~ $pattern ]] && chk1=0
	#[[ "$chk1" -eq 0 ]] && break	
    #done

    # get date2
    #while :; do
	#local chk2=1
	#date2=$(whiptail --inputbox "Provide end date(eg. 20 aug 2023 12:00)" 8 39 --title "Date" 3>&1 1>&2 2>&3)

	#[[ -n "$date2"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date2") -eq 0 ]] && [[ "$date2" =~ $pattern ]] && chk2=0
	#[[ "$chk2" -eq 0 ]] && break	
    #done

    #####################

    #while :; do
	#date1=$(whiptail --inputbox "Provide first date from range (eg. 20 aug 2023 9:15)" 10 39 --title "Date range" 3>&1 1>&2 2>&3)
	#if [[ "$date1" == "now" ]]; then
	    # get current date string
	    # assign to date1 and date2
	    #date1=$(date +'%e %b %G %H:%M')
	    #date2="$date1"
	    #now=0
	    #break
	#else
	    #[[ -n "$date1"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date1") -eq 0 ]] && [[ "$date1" =~ $pattern  ]] && break
	#fi
    #done


    #if [[ "$now" -eq 1 ]]; then
	#while :; do
	    #date2=$(whiptail --inputbox "Provide second date from range (eg. 20 aug 2023 9:15)" 8 39 --title "Date range" 3>&1 1>&2 2>&3)
	    #[[ -n "$date2"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date2") -eq 0 ]] && [[ "$date2" =~ $pattern  ]] && break
        #done
    #fi


    # then, check date2>=date1.
    # if fail, do not generate report.
    local secs1=$(date -d "$date1" +%s)
    local secs2=$(date -d "$date2" +%s)
    
    # test: date1,date2
    #echo date1: "$date1"
    #echo date2: "$date2"
    
    # ask report.sh to generate report and display in msgbox.
    if [[ $secs2 -ge $secs1 ]]; then
	# test: secs2>=secs1
	#echo "yes, valid range"   # PASS!

	# generate report here
	local report=""
	report=$(./report.sh "$date1" "$date2" 2>/dev/null)
	whiptail --msgbox "$report" 16 200 --title "Report: from $date1 to $date2" --scrolltext
	# test: report   PASS!
	#echo "$report"
    else
	#date1=""
	#date2=""
	return 1
    fi
}

# test: show_report
#show_report




#
# delete entry:
# - two inputboxes for date range
#    - usual loop until valid dates are obtained.
# - list found entries for deletion
# - yesno box to confirm
delete_entry () {
    # get date1
    while :; do
	local chk1=1
	local date1=$(whiptail --inputbox "Provide start date(eg. 20 aug 2023 12:00)" 8 39 --title "Date" 3>&1 1>&2 2>&3)

	local pattern="^[0-9]{1,2} [A-Za-z]{3,9} [0-9]{4} [0-9]{1,2}:[0-9]{1,2}$"
	[[ -n "$date1"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date1") -eq 0 ]] && [[ "$date1" =~ $pattern ]] && chk1=0
	[[ "$chk1" -eq 0 ]] && break	
    done

    # get date2
    while :; do
	local chk2=1
	local date2=$(whiptail --inputbox "Provide end date(eg. 20 aug 2023 12:00)" 8 39 --title "Date" 3>&1 1>&2 2>&3)

	local pattern="^[0-9]{1,2} [A-Za-z]{3,9} [0-9]{4} [0-9]{1,2}:[0-9]{1,2}$"
	[[ -n "$date2"  ]] && [[ "$?" -eq 0 ]] && [[ $(validate_date "$date2") -eq 0 ]] && [[ "$date2" =~ $pattern ]] && chk2=0
	[[ "$chk2" -eq 0 ]] && break	
    done

    local secs1=$(date -d "$date1" +%s)
    local secs2=$(date -d "$date2" +%s)

    if [[ $secs2 -ge $secs1 ]]; then
	# matched entries' report
	local report=""
	report=$(./report.sh "$date1" "$date2" 2>/dev/null)
	[[ -z "$report" ]] && return 1
	
	whiptail --yesno "$report" 16 200 --title "Confirm matched entries to delete" --scrolltext
	local sel=$?
	
	# test: sel
	# echo yesno sel: $sel   PASS!
	
	# if yes, delete entries: between secs1 and secs2.
	[[ $sel -eq 0 ]] && jq --argjson s1 $secs1 --argjson s2 $secs2 'del(.data[]|select(.since_epoch>=$s1 and .since_epoch<=$s2))' data.json > /tmp/sarang-del-tmp.json
	[[ $sel -eq 0 ]] && cp /tmp/sarang-del-tmp.json ./data.json
	[[ $sel -eq 0 ]] && rm /tmp/sarang-del-tmp.json
    else
	#date1=""
	#date2=""
	return 1
    fi
}


# main menu
while :; do
    sel=$(whiptail --title "Menu" --menu "Sarang $VER\n'To assist Sarang to walk again'" 25 78 16 \
       "ADD_ENTRY" "Add scoring entry" \
       "SHOW_REPORT" "Search entries by date range" \
       "DELETE_ENTRY" "Delete entry by date" \
       "QUIT" "Quit" 3>&1 1>&2 2>&3)


    case "$sel" in
	"ADD_ENTRY")
	    add_entry
	    ;;
	"SHOW_REPORT")
	    show_report
	    ;;
	"DELETE_ENTRY")
	    delete_entry
	    ;;
	"QUIT")
	    break
	    ;;
	*)
	    ;;
    esac
done
