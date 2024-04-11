#!/bin/bash

##### ADD CONFIG SHIT FOR AUTO REMOVAL OF STORED FOOTAGE AFTER X days or minutes 
##### (For example on rpi we have ~20gb so we keep about 2 days of footage at a time, so every day we remove the day before last.)

############## THIS INPUT NEEDS SANITIZED POST SOURCE
### NOT ONLY SANITIZED BUT WE ALSO NEED TO CHECK IF THEY ARE VALID AFTERWARDS!!!!

### RTSP STREAM CONFIG
rtsp_auth="USERNAME:PASSWORD" # user:pass ## WILL ADD SUPPORT FOR MULTIPLE RELAYS
rtsp_ip="RTSPRELAYIP"
rtsp_port="8554"
rtsp_relay="rtsp://$rtsp_auth@$rtsp_ip:$rtsp_port" # rtsp://USERNAME:PASSWORD@RTSPIP:RTSPPORT
all_streams=("driveway" "backyard" "garage") # must coincide with wyze camera name minus the -cam for example these are driveway-cam
#enable_debug=false ## NOT IMPLEMENTED ### INTENDED FOR FFMPEG DEBUG #### THIS OPTION WILL FORCE ffmpeg_args_debug=true FOR ALL CAMS
#is_pi=true

segment_length_minutes="15" # currently half hour segments

### Sanity Check Variables
critical_disk_left="10" # left gb to consider critical
#critical_temp="60" # temp in f to consider critical

### Notification Config (Ntfy)
api="https://ntfy.sh/NTFY_TOPIC"
#CURRENT_TEMP=$(vcgencmd measure_temp | cut -d'=' -f2 | sed 's/[^0-9.]//g') ### THIS COMMAND IS RASPBERRY PI SPECIFIC

### Directories
disk="/" # used for checking space left.. for sanity checks...
log_dir_root="/opt/rtsp_rec/logs"
main_log_file="$log_dir_root/rtsp_rec_host.log"
capture_dir_root="/opt/rtsp_rec/captures"


### FFMPEG Config ### WILL ADD SUPPORT FOR HARDWARE ACCELERATION
ffmpeg_args="-c:v copy" # this is the variable thats used to record!!! FOR FFMPEG STREAMS!
#ffmpeg_args_audio="-c:v copy -c:a aac -strict experimental"
#ffmpeg_args_no_audio="-c:v copy"

#ffmpeg_args_debug="" ## THIS NEEDS ADDED!!
