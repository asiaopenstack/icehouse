#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

echo;
echo "##############################################################################################################

Go and edit your /etc/network/interfaces file to look something like this:

# loopback
auto lo
iface lo inet loopback
iface lo inet6 loopback

# The management network interface
auto eth0
iface eth0 inet static
  address 10.0.0.11
  netmask 255.255.255.0
  
# The external network interface  
auto eth1
iface eth1 inet manual
address 192.168.1.100
  netmask 255.255.255.0
  gateway 192.168.1.1
  dns-nameservers 8.8.8.8

# ipv6 configuration
iface eth0 inet6 auto

#########################################################################

Now edit your /etc/hosts file to look like this:

127.0.0.1   localhost
# 127.0.1.1 compute1
10.0.0.11   controller
10.0.0.31   compute1
10.0.0.32   compute2

Be sure to put each machine in the cluster's IP then name in the /etc/hosts file.

Make sure you check that the 127.0.1.1 number is commented out of your /etc/hosts file.

After you are done, do a 'ifdown --exclude=lo -a && sudo ifup --exclude=lo -a'.

###############################################################################################################"

# making a unique token for this install
	token=`cat /dev/urandom | head -c2048 | md5sum | cut -d' ' -f1`

# grab our IP 
read -p "Enter the device name for this rig's management NIC (eth0, etc.) : " rignic
rigip=$(/sbin/ifconfig $rignic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

# Grab our controller's name
read -p "Enter the name for this rig (controller, controller-01, etc.) : " ctrl_name

# Give your password
read -p "Please enter a password for MySQL : " password

# Admin email
read -p "Please enter an administrative email address : " email

# Upgrade your rig
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y

# Install Time Server
apt-get install -y ntp

# Install MySQL
echo mysql-server-5.5 mysql-server/root_password password $password | debconf-set-selections
echo mysql-server-5.5 mysql-server/root_password_again password $password | debconf-set-selections
apt-get install -y mysql-server python-mysqldb

# make mysql listen on 0.0.0.0
sed -i "/^bind-address.*$/s/^.*$/bind-address = $rigip/" /etc/mysql/my.cnf

# setup mysql to support utf8 and innodb
sed -i "/\[mysqld\]/a default-storage-engine = innodb\\
innodb_file_per_table\\
collation-server = utf8_general_ci\\
init-connect = 'SET NAMES utf8'\\
character-set-server = utf8\\
" /etc/mysql/my.cnf


# Restart the MySQL service:
service mysql restart

# wait for restart
sleep 4 

# Delete the anonymous users that are created when the database is first started:
aptitude -y install expect
 
SECURE_MYSQL=$(expect -c "
 
set timeout 10
spawn mysql_secure_installation
 
expect \"Enter current password for root (enter for none):\"
send \"$password\r\"
 
expect \"Change the root password?\"
send \"n\r\"
 
expect \"Remove anonymous users?\"
send \"y\r\"
 
expect \"Disallow root login remotely?\"
send \"y\r\"
 
expect \"Remove test database and access to it?\"
send \"y\r\"
 
expect \"Reload privilege tables now?\"
send \"y\r\"
 
expect eof
")
 
echo "$SECURE_MYSQL"
 
aptitude -y purge expect

# Install RabbitMQ (Message Queue):
apt-get install -y rabbitmq-server

#Replace RABBIT_PASS with a suitable password.
rabbitmqctl change_password guest $password


################################################################################
##                                    KEYSTONE                                ##
################################################################################


# Install keystone packages:
apt-get install -y keystone

# edit keystone conf file to use templates and mysql
if [ -f /etc/keystone/keystone.conf.orig ]; then
  echo "Original backup of keystone.conf file exists. Your current config will be modified by this script."
  cp /etc/keystone/keystone.conf.orig /etc/keystone/keystone.conf
else
  cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig
fi

sed -e "
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$password@$ctrl_name\/keystone/
" -i /etc/keystone/keystone.conf

# Remove Keystone SQLite database:
rm /var/lib/keystone/keystone.db

# Create a MySQL database for keystone:
mysql -u root -p"$password"<<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$password';
EOF

keystone-manage db_sync
sleep 5

sed -e "
/^#admin_token=.*$/s/^.*$/admin_token = $token/
/\[DEFAULT\]/a log_dir=/var/log/keystone/
" -i /etc/keystone/keystone.conf

# Restart the identity service then synchronize the database:
service keystone restart
sleep 5

# Define users, tenants, and roles:
export OS_SERVICE_TOKEN=$token
export OS_SERVICE_ENDPOINT=http://$ctrl_name:35357/v2.0

# Create an administrative user
keystone user-create --name=admin --pass=$password --email=$email
keystone role-create --name=admin
keystone tenant-create --name=admin --description="Admin Tenant"
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin

# Create a normal user
keystone user-create --name=demo --pass=$password --email=$email
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo

# Create a service tenant
keystone tenant-create --name=service --description="Service Tenant"

# Define services and API endpoints:
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://$ctrl_name:5000/v2.0 \
--internalurl=http://$ctrl_name:5000/v2.0 \
--adminurl=http://$ctrl_name:35357/v2.0

# Test Keystone
#clear the values in the OS_SERVICE_TOKEN and OS_SERVICE_ENDPOINT environment variables
 unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

#Request a authentication token
keystone --os-username=admin --os-password=$password --os-auth-url=http://$ctrl_name:35357/v2.0 token-get

keystone --os-username=admin --os-password=$password \
  --os-tenant-name=admin --os-auth-url=http://$ctrl_name:35357/v2.0 \
  token-get

# Create a simple credential file:
cat > /root/admin-openrc.sh <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$ctrl_name:35357/v2.0
EOF

# Source this file to read in the environment variables:
source /root/admin-openrc.sh

# Verify that your admin-openrc.sh file is configured correctly. 
# Run the same command without the --os-* arguments:
keystone token-get

# Verify that your admin account has authorization to perform administrative commands:
keystone user-list
keystone user-role-list --user admin --tenant admin

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone

################################################################################
##                                    GLANCE                                  ##
################################################################################

# Install Glance packages:
apt-get install -y glance python-glanceclient



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

# Edit /etc/glance/glance-api.conf and /etc/glance/glance-registry.conf 
# and edit the [database] section of each file:
sed -e "
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$ctrl_name\/glance/
" -i /etc/glance/glance-api.conf

sed -e "
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$ctrl_name\/glance/
" -i /etc/glance/glance-registry.conf

# Delete the glance.sqlite file created in the /var/lib/glance/ 
# directory so that it does not get used by mistake:
rm /var/lib/glance/glance.sqlite

#Use the password you created to log in as root and create a glance database user:
mysql -u root -p"$password" <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$password';
EOF

# Synchronize the glance database:
glance-manage db_sync

# Configure service user and role:
keystone user-create --name=glance --pass=$password --email=$email
keystone user-role-add --user=glance --tenant=service --role=admin

# Edit the /etc/glance/glance-api.conf and /etc/glance/glance-registry.conf files. 
sed -e "
/keystone_authtoken/a auth_uri = http://$ctrl_name:5000
/^auth_host =.*$/s/^.*$/auth_host = $ctrl_name/
/^auth_port =.*$/s/^.*$/auth_port = 35357/
/^auth_protocol =.*$/s/^.*$/auth_protocol = http/
/^admin_tenant_name =.*$/s/^.*$/admin_tenant_name = service/
/^admin_user =.*$/s/^.*$/admin_user = glance/
/^admin_password =.*$/s/^.*$/admin_password = $password/
/\[paste_deploy\]/a flavor = keystone
" -i /etc/glance/glance-registry.conf

sed -e "
/^rabbit_host =.*$/s/^.*$/rabbit_host = $ctrl_name/
/rabbit_use_ssl = false/a rpc_backend = rabbit
/keystone_authtoken/a auth_uri = http://$ctrl_name:5000
/^auth_host =.*$/s/^.*$/auth_host = $ctrl_name/
/^auth_port =.*$/s/^.*$/auth_port = 35357/
/^auth_protocol =.*$/s/^.*$/auth_protocol = http/
/^admin_tenant_name =.*$/s/^.*$/admin_tenant_name = service/
/^admin_user =.*$/s/^.*$/admin_user = glance/
/^admin_password =.*$/s/^.*$/admin_password = $password/
/\[paste_deploy\]/a flavor = keystone
" -i /etc/glance/glance-api.conf
fi

# Register the service and create the endpoint:
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://$ctrl_name:9292 \
--internalurl=http://$ctrl_name:9292 \
--adminurl=http://$ctrl_name:9292

# Restart the glance-api and glance-registry services:
service glance-api restart 
sleep 5
service glance-registry restart
sleep 5

# Test Glance, upload the cirros cloud image:
source /root/admin-openrc.sh
glance image-create --name "cirros-0.3.2-x86_64" --is-public true \
--container-format bare --disk-format qcow2 \
--location http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img

glance image-create --name "Trusty 14.04" --is-public true \
--container-format bare --disk-format qcow2 \
--location https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img

# List Images:
glance image-list


################################################################################
##                                    NOVA                                    ##
################################################################################

# Install nova packages:
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth \
nova-novncproxy nova-scheduler python-novaclient

# Edit the /etc/nova/nova.conf:
echo "
[DEFAULT]
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
iscsi_helper=tgtadm
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
volumes_path=/var/lib/nova/volumes
enabled_apis=ec2,osapi_compute,metadata

#RABBIT
rpc_backend = rabbit
rabbit_host = $ctrl_name
rabbit_password = $password

#VNC
my_ip = $rigip
vncserver_listen = $rigip
vncserver_proxyclient_address = $rigip
auth_strategy = keystone

#NETWORKING
network_api_class = nova.network.api.API
security_group_api = nova

[database]
connection = mysql://nova:$password@$ctrl_name/nova

[keystone_authtoken]
auth_uri = http://$ctrl_name:5000
auth_host = $ctrl_name
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = $password
" > /etc/nova/nova.conf

# Remove Nova SQLite database:
rm /var/lib/nova/nova.sqlite

# Create a Mysql database for Nova:
mysql -u root -p"$password" <<EOF

CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$password';
EOF

# Synchronize your database:
nova-manage db sync

# Configure service user and role:
keystone user-create --name=nova --pass=$password --email=$email
keystone user-role-add --user=nova --tenant=service --role=admin

# Register the service and create the endpoint:
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://$ctrl_name:8774/v2/%\(tenant_id\)s \
--internalurl=http://$ctrl_name:8774/v2/%\(tenant_id\)s \
--adminurl=http://$ctrl_name:8774/v2/%\(tenant_id\)s

# Restart nova-* services:
service nova-api restart
service nova-cert restart
service nova-conductor restart
service nova-consoleauth restart
service nova-novncproxy restart
service nova-scheduler restart

# Check Nova is running. The :-) icons indicate that everything is ok !:
nova-manage service list

# To verify your configuration, list available images:
source /root/admin-openrc.sh
nova image-list


################################################################################
##                                    HORIZON                                 ##
################################################################################


# Install the required packages:
apt-get install -y apache2 memcached libapache2-mod-wsgi openstack-dashboard
sleep 5
apt-get remove -y --purge openstack-dashboard-ubuntu-theme
sleep 5

# Edit /etc/openstack-dashboard/local_settings.py:
sed -e "
/^ALLOWED_HOSTS =.*$/s/^.*$/ALLOWED_HOSTS = '*'/
" -i /etc/openstack-dashboard/local_settings.py

sed -e '
/^OPENSTACK_HOST =.*$/s/^.*$/OPENSTACK_HOST = "'$ctrl_name'"/
' -i /etc/openstack-dashboard/local_settings.py


# Reload Apache and memcached:
service apache2 restart
service memcached restart
