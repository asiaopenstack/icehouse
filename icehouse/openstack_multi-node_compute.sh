#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

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
  address 192.168.1.101
  netmask 255.255.255.0
  gateway 192.168.1.1
  dns-nameservers 8.8.8.8

# ipv6 configuration
iface eth0 inet6 auto

# The external network interface
auto eth1
iface eth1 inet manual
        up ip link set dev $IFACE up
        down ip link set dev $IFACE down

Now edit your /etc/hosts file to look like this:

127.0.0.1	    localhost
# 127.0.1.1    compute1
192.168.1.100	controller
192.168.1.101	compute1

Be sure to put each machine in the cluster's IP then name in the /etc/hosts file.

Make sure you check that the 127.0.1.1 number is commented out of your /etc/hosts file.

After you are done, do a 'ifdown --exclude=lo -a && sudo ifup --exclude=lo -a'.

###############################################################################################################"

read -p "Make sure you have your rig name and networking configured properly before pressng ENTER to continue: "

# making a unique token for this install
	token=`cat /dev/urandom | head -c2048 | md5sum | cut -d' ' -f1`

# grab our IP 
read -p "Enter the device name for this rig's NIC (eth0, etc.) : " rignic
rigip=$(/sbin/ifconfig $rignic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

# Grab our controller's name
read -p "Enter the name for this rig (controller, controller-01, etc.) : " ctrl_name

# Grab our compute's name
read -p "Enter the name for this rig (compute1, compute-01, etc.) : " cmpt_name

# Give your password
read -p "Please enter a password for MySQL : " password

# Admin email
read -p "Please enter an administrative email address : " email

# Upgrade your rig
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y

# Install Time Server
apt-get install -y ntp

# Install MySQL
apt-get install python-mysqldb

# Install nova
apt-get install nova-compute-kvm

# Edit the /etc/nova/nova.conf:
echo "
[DEFAULT]
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
iscsi_helper=tgtadm
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
volumes_path=/var/lib/nova/volumes
enabled_apis=ec2,osapi_compute,metadata

[database]
connection = mysql://nova:$password@$ctrl_name/nova

[keystone_authtoken]
auth_uri = http://$ctrl_name:5000
auth_host = $ctrl_name
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = $password
" > /etc/nova/nova.conf
