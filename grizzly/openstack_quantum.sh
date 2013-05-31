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
read -p "Enter the device name for the Management NIC (eth0, em1, etc.) : " managementnic
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

# install packages 
apt-get install -y quantum-server

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
   cp /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini.orig

# section not indented on purpose (see fi below)
# hack up the quantum paste file
sed -e "
s,127.0.0.1,$MANAGEMENT_IP,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,admin,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/quantum/quantum.conf

 # hack up the ovs plugin file
echo "
[DATABASE]
sql_connection = mysql://quantum:$password@$MANAGEMENT_IP/quantum

[OVS]
tenant_network_type = gre
tunnel_id_ranges = 1:1000
enable_tunneling = True

[SECURITYGROUP]
firewall_driver = quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
" >> /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini    
  
   echo "#################################################################################################"
   echo;
   echo "Backups of configs for quantum are in /etc/quantum/ and /etc/quantum/plugins/openvswitch/"
   echo; 
   echo "#################################################################################################"
fi

# restart 
service quantum-server restart 

echo "
#################################################################################################

When you are done with one of the above, run './openstack_keystone.sh'

#################################################################################################
"
exit
