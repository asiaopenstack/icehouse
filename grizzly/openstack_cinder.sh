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
read -p "Hit enter to start Cinder setup. " -n 1 -r

# install packages
apt-get install -y iscsitarget iscsitarget-source
apt-get install -y open-iscsi iscsitarget-dkms
apt-get install -y cinder-api cinder-scheduler cinder-volume 

# edit keystone conf file to use templates and mysql
if [ -f /etc/cinder/cinder.conf.orig ]; then
  echo "Original backup of cinder config files exist. Your current configs will be modified by this script."
  cp /etc/default/iscsitarget.orig /etc/default/iscsitarget
  cp /etc/cinder/api-paste.ini.orig /etc/cinder/api-paste.ini
  cp /etc/cinder/cinder.conf.orig /etc/cinder/cinder.conf
else
  cp /etc/default/iscsitarget /etc/default/iscsitarget.orig
  cp /etc/cinder/api-paste.ini /etc/cinder/api-paste.ini.orig
  cp /etc/cinder/cinder.conf /etc/cinder/cinder.conf.orig
fi

# toggle iscsitarget
sed -i 's/false/true/g' /etc/default/iscsitarget

# hack up the cinder paste file
sed -e "
/^service_host =.*$/s/^.*$/service_host = $MANAGEMENT_IP/
/^auth_host =.*$/s/^.*$/auth_host = $MANAGEMENT_IP/
" -i /etc/cinder/api-paste.ini

sed -e "
s,127.0.0.1,$MANAGEMENT_IP,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,cinder,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/cinder/api-paste.ini

 # hack up the cinder config file
echo "
iscsi_ip_address=$MANAGEMENT_IP
sql_connection = mysql://cinder:$password@$MANAGEMENT_IP/cinder
" >> /etc/cinder/cinder.conf

# restart and sync
service iscsitarget start
service open-iscsi start
sleep 5
cinder-manage db sync
 
echo "#################################################################################################

Instructions for Cinder volume configuration coming soon.

#################################################################################################"
echo;

if [[ -z $SG_CONTROLLER ]]; then
echo "#################################################################################################

When you are done with setting up your volumes, run './openstack_glance.sh'

#################################################################################################"
else
echo "#################################################################################################

When you are done with setting up your volumes, run './openstack_nova_compute.sh'

#################################################################################################"
fi

echo;
exit
"
