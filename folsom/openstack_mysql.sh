#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

. ./setuprc

# throw in a few other services we need installed
apt-get install rabbitmq-server memcached python-memcache -y

# now let's install MySQL
echo;
echo "##############################################################################################"
echo;
echo "Setting up MySQL now.  You will be prompted to set a MySQL root password by the setup process."
echo;
echo "##############################################################################################"
echo;

# mysql
apt-get install -y mysql-server python-mysqldb

# make mysql listen on 0.0.0.0
sudo sed -i '/^bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf

# restart
service mysql restart

# wait for restart
sleep 4 

echo;
echo "##############################################################################################"
echo;
echo "Creating OpenStack databases and users.  Use the same password you gave the MySQL setup."
echo;
echo "##############################################################################################"
echo;

# load service pass from config env
service_pass=$SG_SERVICE_PASSWORD

# we create a quantum db irregardless of whether the user wants to install quantum
mysql -u root -p <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$service_pass';
CREATE DATABASE quantum;
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'localhost' IDENTIFIED BY '$service_pass';
EOF

echo;
echo "#######################################################################################"
echo;
echo "Run './openstack_keystone.sh' now."
echo;
echo "#######################################################################################"
echo;