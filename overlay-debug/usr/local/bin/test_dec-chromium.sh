#!/bin/sh

export DISPLAY=:0.0 
#export GST_DEBUG=*:5
#export GST_DEBUG_FILE=/tmp/2.txt

su ubuntu -c "chromium --no-sandbox file:///usr/local/test.mp4"
