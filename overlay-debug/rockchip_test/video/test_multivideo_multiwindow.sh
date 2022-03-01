#!/bin/bash

case "$1" in
	test)
		./videowidget file:///rockchip_test/video/SampleVideo_1280x720_5mb.mp4&
		sleep 1
		./videowidget file:///rockchip_test/video/SampleVideo_1280x720_5mb.mp4&
		sleep 1
		./videowidget file:///rockchip_test/video/SampleVideo_1280x720_5mb.mp4&
		sleep 1
		./videowidget file:///rockchip_test/video/SampleVideo_1280x720_5mb.mp4&
		;;
	$1)
		./videowidget file:///$1&
		sleep 1
		./videowidget file:///$1&
		sleep 1
		./videowidget file:///$1&
		sleep 1
		./videowidget file:///$1&
		;;
esac
shift
