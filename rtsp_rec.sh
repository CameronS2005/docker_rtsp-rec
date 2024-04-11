#!/bin/bash

######## CREATE STANDALONE SANITY CHECK DOCKER IMAGE!! << temp check etc..

################### KNOWN ISSUES;
#### check_cam_pids NEEDS REVAMPED ASAP (currently spams errors & attempts too many restarts too fast << Needs counter...)
#### ^^^^ STILL AN ERROR. UNKNOWN CAUSE. POSSIBLE RTSP STREAM OR FFMPEG CORRUPTION
#### ^^^ WE NEED BETTER FFMPEG ERROR HANDLING...
####
####
####
####

VERSION="1.0.1 DEV Build"

############ THIS CODE NEEDS CLEANED UP!!

##### THIS SCRIPT IS IN DEVELOPMENT!!!!

### MORE LEIGHTWEIGHT SOLUTION THEN SCREEN? SUCH AS & or nohup

config_file="/opt/rtsp_rec/config/config.sh"

if [[ -f "$config_file" ]]; then
	source /opt/rtsp_rec/config/config.sh # source variables from config file
else
	echo "ERROR! CONFIG FILE NOT FOUND!! ($config_file)"
	exit 0
fi

#declare -A restarts
declare -A last_capture_file
declare -A last_log_file
#declare -A capture_start_time
#declare -A notify_runs ## not implemented << this is to be used to count notifications runs and prevent spams

# -------------------------------------------------------------------------------------------------- #

sanity_check() { ###### THIS FUNCTION NEEDS FINISHED ASAP
	disk_space=$(df -h "$disk" | grep -E '/$' | awk '{print $4}' | sed 's/G//')
	#if [[ $is_pi == "true" ]]; then
	#pi_temp=$(vcgencmd measure_temp | cut -d'=' -f2 | sed 's/[^0-9.]//g' | bc)
	#	if [[ "$pi_temp" -ge "$critical_temp" ]]; then # || "$pi_temp" -lt "20" ]]; then
	#		handle_log "Temperature Sanity Check Failed!! ($pi_temp)"
	#		notify "$(hostname) (ALERT)" "Temperature Sanity Check Failed! ($pi_temp)"
	#	fi
	#fi
	#if [ -n $(ping -c 1 -W 2 1.1.1.1 2>&1) ]; then # well this obviously wont fucking work...
	#	true
	#else
	#    handle_log "Wi-Fi Sanity Check Failed!"
	#    notify "$(hostname) (ALERT)" "Wi-Fi Sanity Check Failed!"
	#fi

	#if telnet "$rtsp_ip" "$rtsp_port" >/dev/null 2>&1; then
    #	true
	#else
    #	handle_log "RTSP Sanity Check Failed!"
	#    notify "$(hostname) (ALERT)" "RTSP Sanity Check Failed!"
	#fi

	if [[ "$disk_space" -le "$critical_disk_left" ]]; then
		handle_log "Disk Space Sanity Check Failed! ($disk_space Left!)"
		notify "$(hostname) (ALERT)" "Disk Space Sanity Check Failed! ($disk_space Left!)"
	fi
}

notify() { # Function To Handle Ntfy API (For Notifications) ## (DISABLED WHILE TESTING SOME SHIT!!)
	notification_title="$1"
	notification_message="$2"

	if [[ ! -f "/opt/rtsp_rec/config/.sleeping" ]]; then # temporary way to disable notifications while sleeping (as sometimes its a loop of like 100...)
	curl \
		-d "$notification_message" \
		-H "Title: $notification_title" \
		-H "Tags: notification" \
		-H "Priority: high" \
		-k $api >/dev/null 2>&1 # currently forced insecure because of a docker ssl error ## << THIS SHOULD BE OK.. currently no creds or secrets are supplied
	fi
}

run_first() { # Function To Handle The Starting of The Script
	sanity_check

	handle_log ""--------------------------------------------------------------""
	handle_log "Date: $(date) (Version: $VERSION)"
	handle_log ""--------------------------------------------------------------""

	notify "$(hostname) (ALERT)" "RECORD SCRIPT FIRST RUN DETECTED! || $(date)"
	start_record "all"
}

start_record() { 
    # Function To Start New Segment
    handle_log "Recording Started!"
    record_start=$(date +%s)

    if [[ $1 == "all" ]]; then
        streams=("${all_streams[@]}")
    else # if $1 != all then we assume its a single stream being restarted!
        #if [[ ${restarts["$cam-restarts"]} == "" ]]; then
        #	restarts["${cam}-restarts"]="0" # should this be 0 or 1?
        #fi

        streams=("$1")
        var="restart"
        #restart_tag="_RESTART${restarts["$cam-restarts"]}"
        #${restarts["$cam-restarts"]}
    fi

    old_date=$(date +"%Y-%m-%d")

	for cam in "${streams[@]}"; do
	    capture_dir="$capture_dir_root/${cam}-captures/$(date +"%Y-%m-%d")/" # Set capture directory including camera name & current date
	    log_dir="$log_dir_root/${cam}-logs/$(date +"%Y-%m-%d")/" # Set log directory including camera name & current date
	
	    #if [[ -f $capture_file || -f $log_file ]]; then ## IF $log_file or $capture_file exist we treat this as a restart
	    #    ((restarts["$1-restarts"]++))
	    #    var="restart"
	    #fi
	    if [[ $var == "restart" ]]; then ### SHOULD THIS BE ABOVE for cam in streams loop
	    	#restart_tag="_RESTART_${restarts["$cam-restarts"]}"
	    	restart_tag="_RESTART"
	    #else
	    #	segment_seed="${segment_seed}_"
	    fi
	    capture_start_time="$(date +"%H:%M")"

	    capture_file="$capture_dir/${cam}_${segment_seed}${restart_tag}_${capture_start_time}.mp4"
	    log_file="$log_dir/${cam}_${segment_seed}${restart_tag}_${capture_start_time}.log"

	    last_log_file["$cam"]="$log_file" ## while these are used outside this function, do these really need to be declared as global?
	    last_capture_file["$cam"]="$capture_file"
	    #capture_start_times["$cam"]=$(date +"%H:%M")
	
	    ## Check If Segment Directory Exists, If Not They're Created
	    if [[ ! -d "$log_dir" ]]; then
	        mkdir -p "$log_dir"
	    fi
	    if [[ ! -d "$capture_dir" ]]; then
	        mkdir -p "$capture_dir"
	    fi
	
	    echo "Starting ${cam}-stream!"
	
	    # Start ffmpeg command ## -rtsp_transport tcp
	    screen -dmS "${cam}-record" bash -c " \
	    ffmpeg -i $rtsp_relay/${cam}-cam \
	    $ffmpeg_args \
	    $capture_file \
	    > $log_file 2>&1"
	done


    ## Reset and set variables used for previous restart!
    if [[ $var == "restart" ]]; then
        var=""
        restart_tag=""
        streams=("${all_streams[@]}")
        # Increment restart count for the current camera
        #((restarts["$1-restarts"]++))
		#eval 'echo "$1 Restarts: ${restarts["$1-restarts"]}"'
    fi

    #sleep 5

    get_cam_pids
}

get_cam_pids() { # Function To Retrieve PID for each camera
	for cam in "${streams[@]}"; do
    	cam_pid="${cam}_pid" # dynamic variable names

    	eval "${cam}_pid=\$(screen -list | grep \"${cam}-record\" | cut -d'.' -f1 | awk '{print \$1}')"
    	handle_log "${cam}-cam's PID is: ${!cam_pid}"
	done
}

check_cam_pids() { # Function To Check If Screen PID Is Still Alive
	for cam in "${streams[@]}"; do
		if eval "kill -0 \"\${${cam}_pid}\" >/dev/null 2>&1"; then
    		#echo "(${cam}-cam) Process with PID $pid is still running."
    		true
		else
    		handle_log "(${cam}-cam) Process with PID $pid has finished or doesn't exist."
    		notify "$(hostname) ALERT" "${cam}-cam PID IS DEAD!!! || $(date)"
    		sleep 5 ## ATTEMPT TO FIX EMPTY LOGS & SEGMENTS CREATED BY RESTART LOOP
    		start_record "${cam}" # test to restart specific cams recording when detected as dead
		fi
		# Check if restarts are greater than a certain threshold
    	#if [[ ${restarts["$cam-restarts"]} -gt "1" ]]; then
        #	echo "Restart count for $cam is greater than 1"
        #	#notify "$(hostname) ALERT" "$cam HAS RESTARTED MORE THAN ONCE!!!"
    	#fi
	done
}

end_record() { # Function To Stop Running Segment
	for cam in "${streams[@]}"; do
    	screen -S "${cam}-record" -X stuff $'\003' >/dev/null 2>&1 # interrupt the screen instead of killing it or ffmpeg wont finish to moov atom and the video file is unusable
	done

	screen -wipe >/dev/null 2>&1 # wipe all dead screen sessions
}

finish_segment() {
    capture_stop_time="$(date +"%H:%M")"

	for cam in "${streams[@]}"; do
    	last_capture_file_noext="${last_capture_file[$cam]%.*}"  # Remove extension
    	last_log_file_noext="${last_log_file[$cam]%.*}"  # Remove extension

    	mv "${last_log_file[$cam]}" "${last_log_file_noext}_${capture_stop_time}-aac.log"
    	mv "${last_capture_file[$cam]}" "${last_capture_file_noext}_${capture_stop_time}-aac.mp4"

    	echo "Moved ${last_log_file[$cam]} To ${last_log_file_noext}_${capture_stop_time}-aac.log"
    	echo "Moved ${last_capture_file[$cam]} To ${last_capture_file_noext}_${capture_stop_time}-aac.mp4"
	done
	
}

new_segment() {
	new_date=$(date +"%Y-%m-%d")

	if [ "$old_date" \< "$new_date" ]; then
		handle_log "Segment Is In New Day, Resetting Segment Count!!"
		segment_seed=0
	else
		segment_seed=$((segment_seed+1))
	fi

	end_record
	finish_segment
	sleep 1
	start_record "all"
    handle_log "SEGMENT SPLIT RECORDING RESTARTED!"
}

handle_log() { # Function To Log Event To $main_log_file
	echo "$1" | tee -a "$main_log_file" # echo & append $1 to $main_log_file
}

cleanup() { # Function To Handling Resource Cleanup
	handle_log "Detact Detected! Cleaning Up!"
	notify "$(hostname) (ALERT)" "DETACH DETECTED!! RECORDING WAS INTERRUPTED! || $(date)"

	end_record
	exit 0
}

error_handler() {
	#err_command="$1"
	#err_message="$2"
	handle_log "ERROR HANDLER DETECTED SIGNAL || Command: ($1) || Message: ($2)"
	notify "$(hostname) (ALERT)" "ERROR HANDLER DETECTED SIGNAL || Command: ($1) || Message: ($2)"
}

trap 'cleanup' SIGINT SIGTERM ## trap interrupt and terminate signals for cleanup function
trap 'error_handler "$BASH_COMMAND" "$?"' ERR ## << MODIFY TO INCLUDE ERROR MESSAGE
#### ^^^ ADD ERROR TRAP


### START OF SCRIPT (*LOGIC)
segment_seed=0 # should this be 1 or 0?

run_first

while true; do # logic loop
	# Check Elapsed Time At Each Loop Start
    current=$(date +%s)
    record_elapsed=$((current - record_start)) # current time checked against start time (set in start_record function)
    record_minutes=$((record_elapsed / 60))

    #notify_current=$(date +%s)
    #notify_elapsed=$((current - notify_start)) # current time checked against out last notification (To Prevent Error Spams!)
    #notify_minutes=$((notify_elapsed / 60))

    # If elapsed greater than segment threshold then its time for segment split!
    if [[ $record_minutes -ge "$segment_length_minutes" ]]; then
    	handle_log "SEGMENT TIME LIMIT HIT ($segment_length_minutes), TIME FOR A NEW SEGMENT! Segment: ($segment_seed) || $(date)"
    	notify "$(hostname) (ALERT)" "SEGMENT TIME LIMIT HIT ($segment_length_minutes), TIME FOR A NEW SEGMENT! Segment: ($segment_seed) || $(date)"

    	new_segment # split segment
    elif [[ -f "/opt/rtsp_rec/config/.interrupt" ]]; then
    	rm "/opt/rtsp_rec/config/.interrupt"
    	handle_log "FORCED INTERRUPT DETECTED! ENDING SEGMENT!"
    	notify "$(hostname) (ALERT)" "FORCED INTERRUPT DETECTED! ENDING SEGMENT!"

    	new_segment
    else
    	sleep 3
    	sanity_check
    	check_cam_pids # check status of screen pids
    fi
done

### END OF SCRIPT
