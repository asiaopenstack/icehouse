#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

clear

# install netaddr and radvd
apt-get install -y python-netaddr
apt-get install -y radvd

# set the routing flags correctly
echo 0 > /proc/sys/net/ipv6/conf/eth0/forwarding
echo 1 > /proc/sys/net/ipv6/conf/eth0/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra

echo;
echo "##########################################################################################"
echo;
echo "IPv6 configuration complete.  Be sure to add a proper network using 'nova-manage'"
echo;
echo "##########################################################################################"
echo;