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
managementip=$SG_SERVICE_CONTROLLER_IP

# install packages
apt-get install -y nova-novncproxy novnc nova-api nova-ajax-console-proxy nova-cert nova-conductor nova-consoleauth nova-doc nova-scheduler nova-network nova-compute

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
verbose=true
debug=false
logdir=/var/log/nova

# STATE
auth_strategy=keystone
use_deprecated_auth=false
state_path=/var/lib/nova
lock_path=/run/lock/nova

# PASTE FILE
api_paste_config=/etc/nova/api-paste.ini

# RABBIT
rabbit_host=$managementip
rabbit_port=5672

# SCHEDULER
compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
scheduler_available_filters=nova.scheduler.filters.standard_filters
scheduler_max_attempts=3
scheduler_default_filters=AvailabilityZoneFilter,RamFilter,ComputeFilter,CoreFilter,SameHostFilter,DifferentHostFilter,RetryFilter
least_cost_functions=nova.scheduler.least_cost.compute_fill_first_cost_fn
default_availability_zone=nova
default_schedule_zone=nova

# NETWORK
network_manager=nova.network.manager.FlatDHCPManager
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
multi_host=True
public_interface=br100
fixed_range=10.0.47.0/24
dmz_cidr=10.128.0.0/24
force_dhcp_release=true
dns_server=8.8.8.8
send_arp_for_ha=true
auto_assign_floating_ip=false
#dhcp_domain=geekceo.com
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
libvirt_use_virtio_for_bridges=true
dnsmasq_config_file=/etc/nova/dnsmasq-nova.conf
use_ipv6=true

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$managementip:9292

# CINDER
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
snapshot_image_format=qcow2
iscsi_helper=tgtadm

# COMPUTE
compute_manager=nova.compute.manager.ComputeManager
sql_connection=mysql://nova:$password@$managementip/nova
connection_type=libvirt
compute_driver=libvirt.LibvirtDriver
libvirt_type=kvm
libvirt_inject_key=false
rootwrap_config=/etc/nova/rootwrap.conf
remove_unused_base_images=true
remove_unused_resized_minimum_age_seconds=3600
remove_unused_original_minimum_age_seconds=3600
checksum_base_images=false
start_guests_on_host_boot=true
resume_guests_state_on_host_boot=true

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
novnc_enabled=true
novncproxy_base_url=http://$managementip:6080/vnc_auto.html
xvpvncproxy_base_url=http://$managementip:6081/console
novncproxy_host=$managementip
novncproxy_port=6080
vncserver_listen=$managementip
vncserver_proxyclient_address=$managementip

# OTHER
osapi_max_limit=1000

# APIs
ec2_workers=4
osapi_compute_workers=4
metadata_workers=4
osapi_volume_workers=4
osapi_compute_listen=$managementip
osapi_compute_listen_port=8774
ec2_listen=$managementip
ec2_listen_port=8773
ec2_host=$managmentip

" > /etc/nova/nova.conf

# restart
cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
sleep 4

# sync db
nova-manage db sync
sleep 4

# restart nova
cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done

# create cinder volume type
cinder type-create Storage

echo;
echo "###################################################################################################"
echo;
echo "Do a 'nova-manage service list' and a 'nova image-list' to test.  Do './openstack_horizon.sh' next."
echo;
echo "###################################################################################################"
echo;