#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

. ./stackrc
password=$SERVICE_PASSWORD

clear

# grab our IP 
read -p "Enter the device name for the Internet NIC (eth0, etc.) : " internetnic
read -p "Enter the device name for the Management NIC (eth1, etc.) : " managementnic

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
read -p "Hit enter to start Glance setup. " -n 1 -r

# get glance
apt-get install glance -y

# edit glance api conf files 
if [ -f /etc/glance/glance-api.conf.orig ]
then
   echo "#################################################################################################"
   echo;
   echo "Notice: I'm not changing config files again.  If you want to edit, they are in /etc/glance/"
   echo; 
   echo "#################################################################################################"
else 
   # copy to backups before editing
   cp /etc/glance/glance-api-paste.ini /etc/glance/glance-api-paste.ini.orig
   cp /etc/glance/glance-registry-paste.ini /etc/glance/glance-registry-paste.ini.orig
   cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig
   cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig

# do not unindent!
# hack up glance-api-paste.ini file
echo "
auth_host = $MANAGEMENT_IP
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $password
" >> /etc/glance/glance-api-paste.ini

# hack up glance-registry-paste.ini file
echo "
auth_host = $MANAGEMENT_IP
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $password
" >> /etc/glance/glance-registry-paste.ini

# we sed out the mysql connection here, but then tack on the flavor info later on...
sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql:\/\/glance:$password@$MANAGEMENT_IP\/glance/
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/glance/glance-registry.conf
   
echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-registry.conf

sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql:\/\/glance:$password@$MANAGEMENT_IP\/glance/
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/glance/glance-api.conf

# do not unindent!
echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-api.conf

   echo "#################################################################################################"
   echo;
   echo "Backups of configs for glance are in /etc/glance/"
   echo; 
   echo "#################################################################################################"
fi

service glance-api restart; service glance-registry restart
sleep 4
glance-manage db_sync
sleep 4
service glance-api restart; service glance-registry restart

# add ubuntu image
mkdir images
if [ -f images/ubuntu-12.04-server-cloudimg-amd64-disk1.img ]
then
  glance image-create --name "Ubuntu 12.04 LTS" --is-public true --container-format ovf --disk-format qcow2 --file images/ubuntu-12.04-server-cloudimg-amd64-disk1.img 
else
  wget http://stackgeek.s3.amazonaws.com/ubuntu-12.04-server-cloudimg-amd64-disk1.img
  mv ubuntu-12.04-server-cloudimg-amd64-disk1.img images
  glance image-create --name "Ubuntu 12.04 LTS" --is-public true --container-format ovf --disk-format qcow2 --file images/ubuntu-12.04-server-cloudimg-amd64-disk1.img 
fi

# add cirros image
glance image-create --name "Cirros 0.3.0"  --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

echo "#################################################################################################"
echo;
echo "Do a 'glance image-list' to see images.  You can now run './openstack_nova.sh' to set up Nova." 
echo;
echo "#################################################################################################"
echo;
