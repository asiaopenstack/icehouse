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
region=$SG_SERVICE_REGION

# grab our IP 
read -p "Enter the device name for the Management NIC (eth1, etc.) : " managementnic
MANAGEMENT_IP=$(/sbin/ifconfig $managementnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
echo;
echo "#############################################################################################################"
echo;
echo "The IP address on the Management NIC is probably $MANAGEMENT_IP If that's wrong, ctrl-c and edit this script."
echo;
echo "#############################################################################################################"
echo;
#MANAGEMENT_IP=x.x.x.x
read -p "Hit enter to start Quantum setup. " -n 1 -r

# install packages for linux-bridge
apt-get install -y quantum-server quantum-plugin-linuxbridge quantum-plugin-linuxbridge-agent dnsmasq quantum-dhcp-agent quantum-l3-agent

# edit quantum files 
if [ -f /etc/quantum/quantum.conf.orig ]
then
   echo "#################################################################################################"
   echo;
   echo "Notice: I'm not changing config files again.  If you want to edit, they are in /etc/quantum/"
   echo; 
   echo "#################################################################################################"
else 
   # copy to backups before editing
   cp /etc/quantum/quantum.conf /etc/quantum/quantum.conf.orig
   cp /etc/quantum/api-paste.ini /etc/quantum/api-paste.ini.orig
   cp /etc/quantum/l3_agent.ini /etc/quantum/l3_agent.ini.orig
   cp /etc/quantum/dhcp_agent.ini /etc/quantum/dhcp_agent.ini.orig
   cp /etc/quantum/metadata_agent.ini /etc/quantum/metadata_agent.ini.orig
   cp /etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini /etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini.orig

# else section not indented on purpose (see fi below)
# hack up the quantum.conf file
sed -e "
s,core_plugin = quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPluginV2,core_plugin = quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2,g;
s,127.0.0.1,$MANAGEMENT_IP,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,quantum,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/quantum/quantum.conf

# hack up the api-paste.ini file
echo "
[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = $MANAGEMENT_IP
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = quantum
admin_password = $password
" >> /etc/quantum/api-paste.ini

# hack up the l3_agent.ini file
sed -e "
s,interface_driver = quantum.agent.linux.interface.OVSInterfaceDriver,interface_driver = quantum.agent.linux.interface.BridgeInterfaceDriver,g;
" -i /etc/quantum/l3_agent.ini

# hack up the dhcp_agent.ini file
sed -e "
s,interface_driver = quantum.agent.linux.interface.OVSInterfaceDriver,interface_driver = quantum.agent.linux.interface.BridgeInterfaceDriver,g;
" -i /etc/quantum/dhcp_agent.ini

# hack up the metadata_agent.ini file
sed -e "
s,localhost,$MANAGEMENT_IP,g;
s,RegionOne,$region,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,quantum,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/quantum/metadata_agent.ini

echo "
nova_metadata_ip = $MANAGEMENT_IP
nova_metadata_port = 8775
metadata_proxy_shared_secret = $password
" >> /etc/quantum/metadata_agent.ini

# hack up the linuxbridge file 
echo "
[DATABASE]
sql_connection = mysql://quantum:$password@$MANAGEMENT_IP/quantum

[LINUX_BRIDGE]
physical_interface_mappings = physnet1:eth0

[VLANS]
tenant_network_type = vlan
network_vlan_ranges = physnet1:1000:2999
" >> /etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini
  
   # end not indented on purpose section
   echo "#################################################################################################"
   echo;
   echo "Backups of configs for quantum are in /etc/quantum/ and /etc/quantum/plugins/openvswitch/"
   echo; 
   echo "#################################################################################################"
fi

# restart 
cd /etc/init.d/; for i in $( ls quantum-* ); do sudo service $i restart; done
service dnsmasq restart

echo "
#################################################################################################

Networking madness complete.  Run './openstack_keystone.sh' now.

#################################################################################################
"
echo;
exit
