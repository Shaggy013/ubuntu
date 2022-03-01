#!/bin/bash

media-ctl -d /dev/media0 --set-v4l2 '"m00_b_tc35874x 1-000f":0[fmt:UYVY8_2X8/1920x1080]'
media-ctl -d /dev/media0 --set-v4l2 '"rkisp1-isp-subdev":0[fmt:UYVY8_2X8/1920x1080]'
media-ctl -d /dev/media0 --set-v4l2 '"rkisp1-isp-subdev":0[crop:(0,0)/1920x1080]'
media-ctl -d /dev/media0 --set-v4l2 '"rkisp1-isp-subdev":2[fmt:UYVY8_2X8/1920x1080]'
media-ctl -d /dev/media0 --set-v4l2 '"rkisp1-isp-subdev":2[crop:(0,0)/1920x1080]'

v4l2-ctl -d /dev/video0 \
--set-selection=target=crop,top=0,left=0,width=1920,height=1080 \
--set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
--stream-mmap=3 --stream-count=1 --stream-poll
#--stream-to=/tmp/mp.out 
cheese
