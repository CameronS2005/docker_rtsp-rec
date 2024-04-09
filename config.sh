#!/bin/bash

############## WE NEED TO SANITIZE THIS INPUT!!!! 

### RTSP STREAM CONFIG
rtsp_auth="USER:PASS" # user:pass
rtsp_relay="rtsp://$rtsp_auth@192.168.68.124:8554" # rtsp://USERNAME:PASSWORD@RTSPIP:RTSPPORT
all_streams=("driveway" "backyard" "garage") # must coincide with wyze camera name minus the -cam for example these are driveway-cam
enable_audio=true # currently either all or none doesnt support individual cams (IS ENABLED IT MUST ALSO BE ENABLED ON RTSP RELAY FOR EXAMPLE WYZE BRIDGE)
#enable_debug=false ## NOT IMPLEMENTED ### INTENDED FOR FFMPEG DEBUG

segment_length_minutes="360" # currently 6 hour segments

### Notification Config (Ntfy)
api="https://ntfy.sh/"
#CURRENT_TEMP=$(vcgencmd measure_temp | cut -d'=' -f2 | sed 's/[^0-9.]//g')

### Directories
log_dir_root="/etc/rtsp_rec/logs"
main_log_file="$log_dir_root/rtsp_rec_host.log"
capture_dir_root="/etc/rtsp_rec/captures"


### FFMPEG Config
ffmpeg_args_audio="-c:v copy -c:a aac -strict experimental"
ffmpeg_args_no_audio="-c:v copy"

ffmpeg_args_debug="" ## THIS NEEDS ADDED!!