#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36m please input is: armhf or arm64...... \033[0m"
fi

if [ ! $VERSION ]; then
    VERSION="debug"
fi

finish() {
    ./ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo "error exit"
    exit -1
}
trap finish ERR

echo -e "\033[36m Copy overlay to rootfs \033[0m"

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# overlay folder
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/

# version
echo -e "\033[36m Add version string to rootfs \033[0m"
echo "`date +%Y%m%d.%H%M%S`" > /tmp/firmware-release-version
sudo cp /tmp/firmware-release-version ./binary/etc/ubuntu-release

# overlay-firmware folder
sudo cp -rf overlay-firmware/* $TARGET_ROOTFS_DIR/

# overlay-debug folder
# adb, video, camera  test file
sudo cp -rf overlay-debug/* $TARGET_ROOTFS_DIR/

# adb
if [ "$ARCH" == "armhf" ] && [ "$VERSION" == "debug" ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-32 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-64 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
fi

# bt/wifi firmware
if [ "$ARCH" == "armhf" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_32 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_32 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
elif [ "$ARCH" == "arm64" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi
sudo mkdir -p $TARGET_ROOTFS_DIR/system/lib/modules/
sudo find ../kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | \
    xargs -n1 -i sudo cp {} $TARGET_ROOTFS_DIR/system/lib/modules/

echo -e "\033[36m Change root.....................\033[0m"

if [ "$ARCH" == "armhf" ]; then
	sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi

./ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR

apt-get update

chmod +x /etc/rc.local
export APT_INSTALL="apt-get install -fy --allow-downgrades"

#apt-get install -y git fakeroot devscripts cmake vim qemu-user-static binfmt-support dh-make dh-exec pkg-kde-tools device-tree-compiler bc cpio parted dosfstools mtools libssl-dev g++-arm-linux-gnueabihf

\${APT_INSTALL} libssl-dev hostapd ifupdown iperf isc-dhcp-client iw net-tools netbase netcat-openbsd openssh-client openssh-server

#---------------Rga--------------
dpkg -i /packages/rga/*.deb

echo -e "\033[36m Setup Video.................... \033[0m"
\${APT_INSTALL} gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-plugins-base-apps qtmultimedia5-examples

\${APT_INSTALL} /packages/mpp/*
\${APT_INSTALL} /packages/gst-rkmpp/*.deb
\${APT_INSTALL} /packages/gst-base/*.deb
#apt-mark hold gstreamer1.0-x

#---------Camera---------
echo -e "\033[36m Install camera.................... \033[0m"
\${APT_INSTALL} v4l-utils
\${APT_INSTALL} /packages/rkisp/*.deb
\${APT_INSTALL} /packages/rkaiq/*.deb
\${APT_INSTALL} /packages/libv4l/*.deb

#---------Xserver---------
#apt-get build-dep -y xorg-server-source

\${APT_INSTALL} /packages/xserver/*.deb
apt-mark hold xserver-common xserver-xorg-core xserver-xorg-legacy

#------------------ffmpeg------------
\${APT_INSTALL} ffmpeg
\${APT_INSTALL} /packages/ffmpeg/*.deb

#------------------mpv------------
\${APT_INSTALL} mpv
\${APT_INSTALL} /packages/mpv/*.deb

#---------update chromium-----
\${APT_INSTALL} chromium-browser
\${APT_INSTALL} /packages/chromium/*.deb

#------------------libdrm------------
\${APT_INSTALL} /packages/libdrm/*.deb

#------------------libdrm-cursor------------
echo -e "\033[36m Install libdrm-cursor.................... \033[0m"
\${APT_INSTALL} /packages/libdrm-cursor/*.deb

# Only preload libdrm-cursor for X
sed -i "/libdrm-cursor.so/d" /etc/ld.so.preload
sed -i "1aexport LD_PRELOAD=libdrm-cursor.so.1" /usr/bin/X

#------------------blueman------------
echo -e "\033[36m Install blueman.................... \033[0m"
\${APT_INSTALL} /packages/blueman/*.deb

#------------------rkwifibt------------
echo -e "\033[36m Install rkwifibt.................... \033[0m"
\${APT_INSTALL} /packages/rkwifibt/*.deb
ln -s /system/etc/firmware /vendor/etc/

# mark package to hold
# apt-mark hold libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev v4l-utils
#apt-mark hold librockchip-mpp1 librockchip-mpp-static librockchip-vpu0 rockchip-mpp-demos
#apt-mark hold xserver-common xserver-xorg-core xserver-xorg-legacy
#apt-mark hold libegl-mesa0 libgbm1 libgles1 alsa-utils
#apt-get install -f -y

#---------------Debug--------------
if [ "$VERSION" == "debug" ] || [ "$VERSION" == "jenkins" ] ; then
	apt-get install -y sshfs openssh-server bash-completion
fi

#---------------Custom Script--------------
systemctl enable rockchip.service
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

#---------------Clean--------------
rm -rf /var/lib/apt/lists/
#---------------Clean--------------
touch /var/cache/apt/archives/avoid-rm-error.deb
rm /var/cache/apt/archives/*.deb
sudo apt -y autoremove
EOF

./ch-mount.sh -u $TARGET_ROOTFS_DIR

echo "normal exit"

