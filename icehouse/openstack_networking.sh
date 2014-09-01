#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# bridge stuff
apt-get install vlan qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils -y

# install time server
apt-get install ntp -y
service ntp restart

# modify timeserver configuration
sed -e "
/^server ntp.ubuntu.com/i server 127.127.1.0
/^server ntp.ubuntu.com/i fudge 127.127.1.0 stratum 10
/^server ntp.ubuntu.com/s/^.*$/server ntp.ubutu.com iburst/;
" -i /etc/ntp.conf

# turn on forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl net.ipv4.ip_forward=1

echo;
echo "##############################################################################################################

Go and edit your /etc/network/interfaces file to look something like this:

# loopback
auto lo
iface lo inet loopback
iface lo inet6 loopback

# primary interface
auto eth0
iface eth0 inet static
  address 10.0.1.100
  netmask 255.255.255.0
  gateway 10.0.1.1
  dns-nameservers 8.8.8.8

# ipv6 configuration
iface eth0 inet6 auto

Now edit your /etc/hosts file to look like this:

127.0.0.1	localhost
10.0.1.100	hanoman
10.0.1.101	ravana

Be sure to put each machine in the cluster's IP then name in the /etc/hosts file.

After you are done, do a 'ifdown --exclude=lo -a && sudo ifup --exclude=lo -a'.

To start the virtualization test, run './openstack_server_test.sh'

###############################################################################################################"

exit
