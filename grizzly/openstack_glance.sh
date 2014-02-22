#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear

# source the setup file and set variables
. ./setuprc
password=$SG_SERVICE_PASSWORD
managementip=$SG_SERVICE_CONTROLLER_IP

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
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $password
" >> /etc/glance/glance-api-paste.ini

# hack up glance-registry-paste.ini file
echo "
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $password
" >> /etc/glance/glance-registry-paste.ini

# we sed out the mysql connection here, but then tack on the flavor info later on...
sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql:\/\/glance:$password@$managementip\/glance/
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/glance/glance-registry.conf
   
echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-registry.conf

sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql:\/\/glance:$password@$managementip\/glance/
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

# source the setuprc file
. ./setuprc

# add cirros image
glance image-create --name "Cirros 0.3.0"  --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

echo;
echo "#################################################################################################"
echo;
echo "Do a 'glance image-list' to see images.  You can now run './openstack_cinder.sh' to set up Nova." 
echo;
echo "#################################################################################################"
echo;
