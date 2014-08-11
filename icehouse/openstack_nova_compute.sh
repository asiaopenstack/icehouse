#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# tracking ping - run openstack_disable_tracking.sh to disable
if [ ! -f ./trackrc ]; then
	curl -s "https://www.stackmonkey.com/api/v1/track?message=OpenStack%20nova%20compute%20script%20run." > /dev/null
fi

# source the setup file
. ./setuprc

clear

# grab our IP 
read -p "Enter the device name for this rig's NIC (eth0, etc.) : " rignic
rigip=$(/sbin/ifconfig $rignic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD    
managementip=$SG_SERVICE_CONTROLLER_IP
computeip=$SG_SERVICE_COMPUTE_IP
computenic=$SG_SERVICE_COMPUTE_NIC

# install packages
apt-get install -y nova-compute

# hack up the nova paste file
sed -e "
s,127.0.0.1,$managementip,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,nova,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/nova/api-paste.ini
 
 # create the dnsmasq-nova.conf file
echo "
cache-size=0
" > /etc/nova/dnsmasq-nova.conf

# write out a new nova file
echo "
[DEFAULT]

# LOGS
verbose=True
debug=False
logdir=/var/log/nova

# STATE
auth_strategy=keystone
state_path=/var/lib/nova
lock_path=/run/lock/nova
rootwrap_config=/etc/nova/rootwrap.conf

# PASTE FILE
api_paste_config=/etc/nova/api-paste.ini

# RABBIT
rabbit_host=$managementip
rabbit_port=5672
rpc_backend = nova.openstack.common.rpc.impl_kombu
rabbit_userid=guest
rabbit_password=guest

# SCHEDULER
compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# NETWORK
# network_manager=nova.network.manager.FlatDHCPManager
# force_dhcp_release=True
# dhcpbridge_flagfile=/etc/nova/nova.conf
# dhcpbridge=/usr/bin/nova-dhcpbridge
# firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
# my_ip=$computeip
# public_interface=br100
# vlan_interface=$computenic
# flat_network_bridge=br100
# flat_interface=$computenic
# dnsmasq_config_file=/etc/nova/dnsmasq-nova.conf
# enable_ipv6=False

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$managementip:9292
glance_host=$managementip

# CINDER
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
snapshot_image_format=qcow2
iscsi_helper=tgtadm

# COMPUTE
network_api_class = nova.network.api.API
security_group_api = nova
compute_manager=nova.compute.manager.ComputeManager
connection_type=libvirt
compute_driver=libvirt.LibvirtDriver
libvirt_type=kvm
libvirt_inject_key=false
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
remove_unused_base_images=true
remove_unused_resized_minimum_age_seconds=3600
remove_unused_original_minimum_age_seconds=3600
checksum_base_images=false
start_guests_on_host_boot=true
resume_guests_state_on_host_boot=true
volumes_path=/var/lib/nova/volumes

# QUOTAS
quota_security_groups=50
quota_fixed_ips=40
quota_instances=20
force_config_drive=false
cpu_allocation_ratio=16.0
ram_allocation_ratio=1.5

# KEYSTONE
keystone_ec2_url=http://$managementip:5000/v2.0/ec2tokens

# VNC CONFIG
my_ip=$computeip
novnc_enabled=true
novncproxy_base_url=http://$managementip:6080/vnc_auto.html
xvpvncproxy_base_url=http://$managementip:6081/console
novncproxy_host=$computeip
novncproxy_port=6080
vncserver_listen=$computeip
vncserver_proxyclient_address=$computeip

# OTHER
osapi_max_limit=1000

# APIs
enabled_apis=ec2,osapi_compute,metadata
osapi_compute_extension = nova.api.openstack.compute.contrib.standard_extensions
ec2_workers=4
osapi_compute_workers=4
metadata_workers=4
osapi_volume_workers=4
osapi_compute_listen=$computeip
osapi_compute_listen_port=8774
ec2_listen=$computeip
ec2_listen_port=8773
ec2_host=$computeip
ec2_private_dns_show_ip=True

[database]
connection = mysql://nova:$password@$managementip/nova

[keystone_authtoken]
auth_uri = http://$managementip:5000
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = $password
" > /etc/nova/nova.conf

# restart
service nova-network restart
service nova-compute restart
service nova-novncproxy restart

echo "###################################################################################################"
echo;
echo "Install complete.  Log into the controller and run a 'nova-manage service list' to check."
echo;
echo "###################################################################################################"
echo;