#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear 

# source the setup file
. ./setuprc

# ask how big and create loopback file
read -p "Enter the integer amount in gigabytes (min 1G) to use as a loopback file for Cinder: " gigabytes
echo;
echo "Creating loopback file of size $gigabytes GB at /cinder-volumes..."
gigabytesly=$gigabytes"G"
dd if=/dev/zero of=/cinder-volumes bs=1 count=0 seek=$gigabytesly
echo;

# loop the file up
losetup /dev/loop2 /cinder-volumes

# create a rebootable remount of the file
echo "losetup /dev/loop2 /cinder-volumes; exit 0;" > /etc/init.d/cinder-setup-backing-file
chmod 755 /etc/init.d/cinder-setup-backing-file
ln -s /etc/init.d/cinder-setup-backing-file /etc/rc2.d/S10cinder-setup-backing-file

# create the physical volume and volume group
sudo pvcreate /dev/loop2
sudo vgcreate cinder-volumes /dev/loop2

# create storage type
sleep 2
cinder type-create Storage

# restart cinder services
service cinder-scheduler restart
service cinder-api restart
service cinder-volume restart
service tgt restart

if [[ -z $SG_SERVICE_CONTROLLER ]]; then
echo "#################################################################################################

When you are done with setting up your volumes, run './openstack_nova_compute.sh'

#################################################################################################"
else
echo "#################################################################################################

When you are done with setting up your volumes, run './openstack_nova.sh'

#################################################################################################"
fi

exit
