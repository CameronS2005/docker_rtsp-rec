#!/bin/bash
docker buildx build --platform linux/arm,linux/amd64 -t registry.localwmx.duckdns.org/rtsp_rec:dev --push .
#docker build -t registry.localwmx.duckdns.org/rtsp_rec:dev --push .
#docker build -t rtsp_rec:dev .
