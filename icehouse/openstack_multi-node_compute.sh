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

# grab our IP 
read -p "Enter the device name for this rig's NIC (eth0, em1, etc.) : " rignic
rigip=$(/sbin/ifconfig $rignic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

# Grab our controller's name
read -p "Enter the device name for the rig's exernal NIC (ETH1, p2p1, etc.) : " extnic

# Grab our controller's name
read -p "Enter of the controller rig (controller, controller-01, etc.) : " ctrl_name

# Give your password
read -p "Please enter the password for MySQL on the controller rig : " password

# Grab our compute's name
read -p "Enter the name for this compute rig (compute1, compute-01, etc.) : " cmpt_name

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

#RABBIT
rpc_backend = rabbit
rabbit_host = $ctrl_name
rabbit_password = $password

#VNC
my_ip = $rigip
vnc_enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $rigip
novncproxy_base_url = http://$ctrl_name:6080/vnc_auto.html

#GLANCE
glance_host = $ctrl_name

#NETWORKING
network_api_class = nova.network.api.API
security_group_api = nova
firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver
network_manager = nova.network.manager.FlatDHCPManager
network_size = 254
allow_same_net_traffic = False
multi_host = True
send_arp_for_ha = True
share_dhcp_address = True
force_dhcp_release = True
flat_network_bridge = br100
flat_interface = $extnic
public_interface = $extnic

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

# Remove Nova SQLite database:
rm /var/lib/nova/nova.sqlite

# Restart the Compute service:
service nova-compute restart
sleep 4
service nova-network restart
sleep 4
service nova-api-metadata restart
sleep 4
