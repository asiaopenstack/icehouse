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
apt-get install -y nova-compute nova-network

# hack up the nova paste file
sed -e "
s,127.0.0.1,$managementip,g;
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
rabbit_host=$managementip
nova_url=http://$managementip:8774/v1.1/
sql_connection=mysql://nova:$password@$managementip/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
ec2_private_dns_show_ip=True
volumes_path=/var/lib/nova/volumes
enabled_apis=ec2,osapi_compute,metadata

# AUTH
use_deprecated_auth=false
auth_strategy=keystone

# IMAGING SERVICE
glance_api_servers=$managementip:9292
image_service=nova.image.glance.GlanceImageService

# VNC CONFIG
novnc_enabled=true
novncproxy_base_url=http://$managementip:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=$managementip
vncserver_listen=0.0.0.0

# NETWORK
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
flat_interface=$managementip
public_interface=$managementip

# COMPUTE
compute_driver=libvirt.LibvirtDriver

# CINDER
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
echo;
echo "Install complete.  Do './openstack_horizon.sh' next."
echo;
echo "###################################################################################################"
echo;