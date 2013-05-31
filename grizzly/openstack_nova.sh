#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD    

# grab our IP 
read -p "Enter the device name for the Internet NIC (eth0, em1, etc.) : " internetnic
read -p "Enter the device name for the Management NIC (eth0, em1, etc.) : " managementnic

INTERNET_IP=$(/sbin/ifconfig $internetnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
MANAGEMENT_IP=$(/sbin/ifconfig $managementnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo;
echo "#############################################################################################################"
echo;
echo "The IP address on the Internet NIC is probably $INTERNET_IP.  If that's wrong, ctrl-c and edit this script."
echo "The IP address on the Management NIC is probably $MANAGEMENT_IP If that's wrong, ctrl-c and edit this script."
echo;
echo "#############################################################################################################"
echo;
#INTERNET_IP=x.x.x.x
#MANAGEMENT_IP=x.x.x.x
read -p "Hit enter to start Nova setup. " -n 1 -r

# install packages
apt-get install -y nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor

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

# Auth
use_deprecated_auth=false
auth_strategy=keystone

# Imaging service
glance_api_servers=$MANAGEMENT_IP:9292
image_service=nova.image.glance.GlanceImageService

# Vnc configuration
novnc_enabled=true
novncproxy_base_url=http://$INTERNET_IP:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=$MANAGEMENT_IP
vncserver_listen=0.0.0.0

# Network settings
network_api_class=nova.network.quantumv2.api.API
quantum_url=http://$MANAGEMENT_IP:9696
quantum_auth_strategy=keystone
quantum_admin_tenant_name=service
quantum_admin_username=quantum
quantum_admin_password=service_pass
quantum_admin_auth_url=http://$MANAGEMENT_IP:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
#If you want Quantum + Nova Security groups
firewall_driver=nova.virt.firewall.NoopFirewallDriver
security_group_api=quantum
#If you want Nova Security groups only, comment the two lines above and uncomment line -1-.
#-1-firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

#Metadata
service_quantum_metadata_proxy = True
quantum_metadata_proxy_shared_secret = helloOpenStack

# Compute #
compute_driver=libvirt.LibvirtDriver

# Cinder #
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
" > /etc/nova/nova.conf

# sync db
nova-manage db sync

# restart nova
./openstack_restart_nova.sh

echo "############################################################################################"
echo "Do a 'nova-manage list' and a 'nova image-list' to test.  Do './openstack_horizon.sh' next."
echo "############################################################################################"

