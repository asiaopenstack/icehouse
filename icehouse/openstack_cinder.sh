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
apt-get install -y lvm2
apt-get install -y python-cinderclient python-mysqldb
apt-get install -y cinder-api cinder-scheduler cinder-volume 

# edit keystone conf file to use templates and mysql
if [ -f /etc/cinder/cinder.conf.orig ]; then
  echo "Original backup of cinder config files exist. Your current configs will be modified by this script."
  cp /etc/cinder/cinder.conf.orig /etc/cinder/cinder.conf
else
  cp /etc/cinder/cinder.conf /etc/cinder/cinder.conf.orig
fi

echo "
rpc_backend = cinder.openstack.common.rpc.impl_kombu
rabbit_host = localhost
rabbit_port = 5672
rabbit_userid = guest
rabbit_password = guest

[database]
connection = mysql://cinder:$password@$managementip/cinder

[keystone_authtoken]
auth_uri = http://$managementip:5000
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = cinder
admin_password = $password
" >> /etc/cinder/cinder.conf

# restart and sync
cinder-manage db sync

# restart cinder services
service cinder-scheduler restart
service cinder-api restart
service cinder-volume restart
service tgt restart

echo;
echo "#################################################################################################

Run ./openstack_loop.sh to setup the cinder-volumes loopback device.

#################################################################################################"
echo;

exit
