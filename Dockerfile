# Use a base image with necessary dependencies (e.g., Debian-based image)
FROM debian:buster-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y curl screen ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN groupadd -g 1000 appuser && \
    useradd -r -u 1000 -g appuser appuser

# Copy your script & config, and set permissions
COPY rtsp_rec.sh /usr/local/bin/rtsp_rec.sh
RUN chmod +x /usr/local/bin/rtsp_rec.sh

# Set up directories and configuration
RUN mkdir -p /opt/rtsp_rec/logs /opt/rtsp_rec/captures /opt/rtsp_rec/config

# Set the ownership of directories to the non-root user
RUN chown -R 1000:1000 /opt/rtsp_rec

# Switch to the non-root user
USER appuser

# Set the working directory
WORKDIR /opt/rtsp_rec

# Command to run the script
CMD ["/usr/local/bin/rtsp_rec.sh"]
