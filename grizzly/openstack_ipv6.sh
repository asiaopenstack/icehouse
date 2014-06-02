#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear

# source the setup file
. ./setuprc

# install netaddr and radvd
apt-get install -y python-netaddr
apt-get install -y radvd

# variables
if [[ -z $SG_SERVICE_CONTROLLER ]]; then
	rignic=$SG_SERVICE_COMPUTE_NIC
else
	rignic=$SG_SERVICE_CONTROLLER_NIC
fi

# set the routing flags correctly
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra

# build a file for reboot
cat > /etc/init.d/ipv6-setup <<EOF
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra
EOF

# set to execute and run on boot
chmod 755 /etc/init.d/ipv6-setup
ln -s /etc/init.d/ipv6-setup /etc/rc2.d/S10ipv6-setup

echo;
echo "##########################################################################################"
echo;
echo "IPv6 configuration complete.  Be sure to add a proper network using 'nova-manage'"
echo;
echo "##########################################################################################"
echo;