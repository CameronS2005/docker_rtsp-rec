#!/bin/bash

##### THIS SCRIPT IS IN DEVELOPMENT!!!!

############## MODIFY CHECK PID FUNCTION TO SEARCH FOR THE FOLLOWING ERROR;
####### STREAM ERRORS IN SEGMENT LOGS
####### WYZE BRIDGE CONNECTION ERROR & INDIVIDUAL RTSP STREAMS
####### TEMPERATURE ISSUES
####### STORAGE ISSUES
####### WIFI ISSUES

source /etc/rtsp_rec/config/config.sh # source variables from config file

declare -A restarts # associative array

# -------------------------------------------------------------------------------------------------- #

notify() { # Function To Handle Ntfy API (For Notifications)
	notification_title="$1"
	notification_message="$2"

	curl \
		-d "$notification_message" \
		-H "Title: $notification_title" \
		-H "Tags: notification" \
		-H "Priority: high" \
		$api >/dev/null 2>&1 # or try silent curl?
}

run_first() { # Function To Handle The Starting of The Script
	notify "$(hostname) (ALERT)" "RECORD SCRIPT FIRST RUN DETECTED! || $(date)"
	start_record "all"

	handle_log ""--------------------------------------------------------------""
	handle_log "Date: $(date)"
	handle_log ""--------------------------------------------------------------""
}

start_record() { 
    # Function To Start New Segment
    handle_log "Recording Started!"
    start=$(date +%s)

    if [[ $1 == "all" ]]; then
        streams=("${all_streams[@]}")
    else
        streams=("$1")
        var="restart"
        if [[ ${restarts["$cam-restarts"]} == "" ]]; then
        	restarts["${cam}-restarts"]="0"
        fi
    fi

    old_date=$(date +"%Y-%m-%d")

    for cam in "${streams[@]}"; do
    	capture_dir="$capture_dir_root/${cam}-captures/$(date +"%Y-%m-%d")/" # Set capture directory including camera name & current date
    	log_dir="$log_dir_root/${cam}-logs/$(date +"%Y-%m-%d")/" # Set log directory including camera name & current date

    	## Check If Segment Directory Exists, If Not They're Created
    	if [[ ! -d "$log_dir" ]]; then
    		mkdir -p "$log_dir"
		fi; if [[ ! -d "$capture_dir" ]]; then
			mkdir -p "$capture_dir"
		fi

        if [[ $enable_audio == "true" ]]; then
        	if [[ $var != "restart" ]]; then
            	screen -dmS "${cam}-record" bash -c "ffmpeg -i $rtsp_relay/${cam}-cam $ffmpeg_args_audio $capture_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-aac.mp4 > $log_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-aac.log 2>&1"
        	else
            	# Restart
        	screen -dmS "${cam}-record" bash -c "ffmpeg -i $rtsp_relay/${cam}-cam $ffmpeg_args_audio $capture_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-aac-RESTART_${restarts["$cam-restarts"]}.mp4 > $log_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-aac-RESTART_${restarts["$cam-restarts"]}.log 2>&1"
        	fi
    	else
    		if [[ $var != "restart" ]]; then
                screen -dmS "${cam}-record" bash -c "ffmpeg -i $rtsp_relay/${cam}-cam $ffmpeg_args_no_audio $capture_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed.mp4 > $log_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed.log 2>&1"
                # Restart
            else
                screen -dmS "${cam}-record" bash -c "ffmpeg -i $rtsp_relay/${cam}-cam $ffmpeg_args_no_audio $capture_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-RESTART_${restarts["$cam-restarts"]}.mp4 > $log_dir/${cam}_$(date +"%Y-%m-%d")_$segment_seed-RESTART_${restarts["$cam-restarts"]}.log 2>&1"
    	fi; fi
    done

    if [[ $var == "restart" ]]; then
        var=""
        streams=("${all_streams[@]}")
        # Increment restart count for the current camera
        ((restarts["$1-restarts"]++))
		#eval 'echo "$1 Restarts: ${restarts["$1-restarts"]}"'
    fi

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
    		notify "$(hostname) ERROR" "${cam}-cam PID IS DEAD!!! || $(date)"
    		start_record "${cam}" # test to restart specific cams recording when detected as dead
		fi

		# Check if restarts are greater than a certain threshold ## CHANGE THIS TO A CHECK IF RESTART THRESHOLD IS REACH WITHIN X THRESHOLD LIMIT
end_record() { # Function To Stop Running Segment
	for cam in "${streams[@]}"; do
    	screen -S "${cam}-record" -X stuff $'\003' # interrupt the screen instead of killing it or ffmpeg wont finish to moov atom and the video file is unusable
	done

	screen -wipe >/dev/null 2>&1 # wipe all dead screen sessions
}

new_segment() {
	new_date=$(date +"%Y-%m-%d")

	if [ "$old_date" \< "$new_date" ]; then ### THIS CODE HASNT BEEN TESTED (REQUIRES OVERNIGHT TESTING)
		handle_log "Segment Is In New Day, Resetting Segment Count!!"
		segment_seed=0
	else
		segment_seed=$((segment_seed+1))
	fi

	end_record
	sleep 2
	start_record "all"
    handle_log "SEGMENT SPLIT RECORDING RESTARTED!"
}

handle_log() { # Function To Log Event To $main_log_file
	log_message="$1"

	echo "$1" | tee -a "$main_log_file" # echo & append $log_message to $main_log_file
}

cleanup() { # Function To Handling Resource Cleanup
	handle_log "Detact Detected! Cleaning Up!"
	notify "$(hostname) (ALERT)" "DETACH DETECTED!! RECORDING WAS INTERRUPTED! || $(date)"

	end_record
	exit 0
}

trap 'cleanup' SIGINT # trap interruption signal for cleanup function

### START OF SCRIPT (*LOGIC)
segment_seed=0 # should this be 1 or 0?

run_first

while true; do # logic loop
	# Check Elapsed Time At Each Loop Start
    current=$(date +%s)
    elapsed=$((current - start))
    minutes=$((elapsed / 60))

    # If elapsed greater than segment threshold then its time for segment split!
    if [[ $minutes -ge "$segment_length_minutes" ]]; then # 4 Hour segments
    	handle_log "SEGMENT TIME LIMIT HIT ($segment_length_minutes), TIME FOR A NEW SEGMENT! Segment: ($segment_seed) || $(date)"

    	new_segment # split segment
    else
    	check_cam_pids # check status of screen pids
    	sleep 3
    fi
done

### END OF SCRIPT