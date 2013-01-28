#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# get glance
apt-get install glance -y

. ./stackrc
password=$SERVICE_PASSWORD

# edit glance api conf files 
if [ -f /etc/glance/glance-api-paste.ini.orig ]
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
   cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig

   # we sed out the mysql connection here, but then tack on the flavor info later on...
   sed -e "
   /^sql_connection =.*$/s/^.*$/sql_connection = mysql:\/\/glance:$password@127.0.0.1\/glance/
   s,%SERVICE_TENANT_NAME%,admin,g;
   s,%SERVICE_USER%,admin,g;
   s,%SERVICE_PASSWORD%,$password,g;
   " -i /etc/glance/glance-registry.conf
   
   sed -e "
   s,%SERVICE_TENANT_NAME%,admin,g;
   s,%SERVICE_USER%,admin,g;
   s,%SERVICE_PASSWORD%,$password,g;
   " -i /etc/glance/glance-registry-paste.ini
   
   sed -e "
   s,%SERVICE_TENANT_NAME%,admin,g;
   s,%SERVICE_USER%,admin,g;
   s,%SERVICE_PASSWORD%,$password,g;
   " -i /etc/glance/glance-api-paste.ini
   
# do not unindent!
echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-api.conf
   
# do not unindent!
echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-registry.conf

   echo "#################################################################################################"
   echo;
   echo "Backups of configs for glance are in /etc/glance/"
   echo; 
   echo "#################################################################################################"
fi

# prevent version control, create db tables, and restart
glance-manage version_control 0
glance-manage db_sync
sleep 4
service glance-api restart
service glance-registry restart
sleep 4

# add ubuntu image
if [ -f images/ubuntu-12.04-server-cloudimg-amd64-disk1.img ]
then
  glance add name="Ubuntu 12.04 LTS" disk_format=qcow2 container_format=ovf < images/ubuntu-12.04-server-cloudimg-amd64-disk1.img
else
  wget http://stackgeek.s3.amazonaws.com/ubuntu-12.04-server-cloudimg-amd64-disk1.img
  mv ubuntu-12.04-server-cloudimg-amd64-disk1.img images
  glance add name="Ubuntu 12.04 LTS" disk_format=qcow2 container_format=ovf < images/ubuntu-12.04-server-cloudimg-amd64-disk1.img
fi

sleep 4
glance index

echo "#################################################################################################"
echo;
echo "You can now run './openstack_nova.sh' to set up Nova." 
echo;
echo "#################################################################################################"