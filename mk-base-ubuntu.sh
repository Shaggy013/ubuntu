#!/bin/bash -e

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36m please input the os type,armhf or arm64...... \033[0m"
fi

VERSION="debug"
TARGET_ROOTFS_DIR="binary"

if [ -e lubuntu-$RELEASE-base-*.tar.gz ]; then
	rm lubuntu-$RELEASE-base-*.tar.gz
fi

if [ ! -d $TARGET_ROOTFS_DIR ] ; then
    sudo mkdir -p $TARGET_ROOTFS_DIR

    if [ ! -e ubuntu-base-20.04.1-base-$ARCH.tar.gz ]; then
        echo "\033[36m wget ubuntu-base-20.04-base-x.tar.gz \033[0m"
        wget -c http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.3-base-$ARCH.tar.gz
    fi
    sudo chmod 0666 ubuntu-base-20.04.3-base-$ARCH.tar.gz
    sudo tar -xzvf ubuntu-base-20.04.3-base-$ARCH.tar.gz -C $TARGET_ROOTFS_DIR/
    sudo cp -b /etc/resolv.conf $TARGET_ROOTFS_DIR/etc/resolv.conf
    if [ "$ARCH" == "armhf" ]; then
	    sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
    elif [ "$ARCH" == "arm64"  ]; then
	    sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
    fi
    sudo cp -b sources.list $TARGET_ROOTFS_DIR/etc/apt/sources.list

fi

finish() {
    ./ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo -e "error exit"
    exit -1
}
trap finish ERR

echo "\033[36m Change root.....................\033[0m"

./ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR/

apt-get -y update
apt-get -f -y upgrade

# install useful tools anf lubuntu
apt-get -f -y install apt-utils inetutils-ping vim git net-tools ubuntu-advantage-tools glmark2-es2
apt-get install -f -y lubuntu-default-settings lubuntu-desktop ssh ufw htop screen bluez blueman

# remove gnome by default
apt-get -y -f remove --purge gnome-*
apt-get -y -f remove --purge gnome
apt-get -y -f autoremove

HOST=ubuntu

# Create User
useradd -G sudo -m -s /bin/bash ubuntu
passwd ubuntu <<IEOF
ubuntu
ubuntu
IEOF
gpasswd -a ubuntu video
gpasswd -a ubuntu audio
passwd root <<IEOF
root
root
IEOF

sync

EOF

./ch-mount.sh -u $TARGET_ROOTFS_DIR

sudo tar zcvf lubuntu-$RELEASE-base-$ARCH.tar.gz $TARGET_ROOTFS_DIR

echo -e "normal exit"
