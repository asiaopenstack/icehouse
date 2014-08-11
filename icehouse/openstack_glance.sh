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
apt-get install python-glanceclient -y
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
   cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig
   cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig

# do not unindent!

# TODO - need to delete the backend = sqlalchemy lines

# we sed out the mysql connection here, but then tack on the flavor info later on...
sed -e "
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$managementip\/glance/
/^backend = sqlalchemy/d
/\[paste_deploy\]/a flavor = keystone
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/glance/glance-registry.conf

echo "
[paste_deploy]
flavor = keystone
" >> /etc/glance/glance-registry.conf

sed -e "
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$managementip\/glance/
/^rabbit_host =.*$/s/^.*$/rabbit_host = $managementip/
/rabbit_use_ssl = false/a rpc_backend = rabbit
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/glance/glance-api.conf
sed -e "/^backend = sqlalchemy/d" -i /etc/glance/glance-api.conf

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
sleep 3
glance-manage db_sync
sleep 3
service glance-api restart; service glance-registry restart
sleep 3

# source the setuprc file
. ./setuprc

# add cirros image
glance image-create --name="Cirros 0.3.0"  --is-public=true --container-format=bare --disk-format=qcow2 --location=http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img

# add ubuntu image
glance image-create --name="Ubuntu Precise 12.04 LTS" --is-public=true --container-format=bare --disk-format=qcow2 --location=http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img

echo;
echo "##################################################################################################"
echo;
echo "Do a 'glance image-list' to see images.  You can now run './openstack_cinder.sh' to set up Cinder." 
echo;
echo "##################################################################################################"
echo;
