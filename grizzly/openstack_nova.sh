#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

clear

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD    

# grab our IP 
read -p "Enter the device name for the controller's NIC (eth0, etc.) : " managementnic

MANAGEMENT_IP=$(/sbin/ifconfig $managementnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo;
echo "#################################################################################################################"
echo;
echo "The IP address on the controller's NIC is probably $MANAGEMENT_IP.  If that's wrong, ctrl-c and edit this script."
echo;
echo "#################################################################################################################"
echo;
#MANAGEMENT_IP=x.x.x.x
read -p "Hit enter to start Nova setup. " -n 1 -r

# install packages
apt-get install -y nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor nova-compute-kvm

# hack up the nova paste file
sed -e "
s,127.0.0.1,$MANAGEMENT_IP,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,nova,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/nova/api-paste.ini
 
# write out a new nova file
echo "
[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/run/lock/nova
verbose=True
api_paste_config=/etc/nova/api-paste.ini
compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
rabbit_host=$MANAGEMENT_IP
nova_url=http://$MANAGEMENT_IP:8774/v1.1/
sql_connection=mysql://nova:$password@$MANAGEMENT_IP/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
ec2_private_dns_show_ip=True
volumes_path=/var/lib/nova/volumes
enabled_apis=ec2,osapi_compute,metadata

# Auth
use_deprecated_auth=false
auth_strategy=keystone

# Imaging service
glance_api_servers=$MANAGEMENT_IP:9292
image_service=nova.image.glance.GlanceImageService

# Vnc configuration
novnc_enabled=true
novncproxy_base_url=http://$MANAGEMENT_IP:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=$MANAGEMENT_IP
vncserver_listen=0.0.0.0

# Network
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
force_dhcp_release=True
network_manager=nova.network.manager.FlatDHCPManager
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
network_size=254
allow_same_net_traffic=False
multi_host=True
send_arp_for_ha=True
share_dhcp_address=True
force_dhcp_release=True
flat_network_bridge=br100
flat_interface=$MANAGEMENT_IP
public_interface=$MANAGEMENT_IP

# Compute #
compute_driver=libvirt.LibvirtDriver

# Cinder #
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
" > /etc/nova/nova.conf

# add to nova-compute.conf

echo "
libvirt_vif_type=ethernet
libvirt_vif_driver=nova.virt.libvirt.vif.QuantumLinuxBridgeVIFDriver
" >> /etc/nova/nova-compute.conf

# restart
cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
sleep 4

# sync db
nova-manage db sync
sleep 4

# restart nova
cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done

echo "###################################################################################################"
echo "Do a 'nova-manage service list' and a 'nova image-list' to test.  Do './openstack_horizon.sh' next."
echo "###################################################################################################"
echo;

