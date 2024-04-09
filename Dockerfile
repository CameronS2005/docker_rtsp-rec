# docker build -t rtsp_rec .
# Use a base image with necessary dependencies (e.g., Debian-based image)
FROM debian:buster-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y curl screen ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Copy your script & config, and set permissions
COPY rtsp_rec.sh /usr/local/bin/rtsp_rec
RUN chmod +x /usr/local/bin/rtsp_rec

# Set up directories and configuration
RUN mkdir -p /etc/rtsp_rec/logs /etc/rtsp_rec/captures /etc/rtsp_rec/config

# Set the working directory
WORKDIR /etc/rtsp_rec

# Command to run the script
CMD ["/usr/local/bin/rtsp_rec"]

