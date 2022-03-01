#!/bin/sh


case "$1" in
	test)
		multivideoplayer /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4 /rockchip_test/video/SampleVideo_1280x720_5mb.mp4
		;;
	$1)
		multivideoplayer $1 $1 $1 $1 $1 $1 $1 $1 $1
		;;
esac
shift
