#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# get horizon
apt-get install -y openstack-dashboard memcached

# restart apache
service apache2 restart; service memcached restart

. ./stackrc
password=$SERVICE_PASSWORD

# grab our IP 
read -p "Enter the device name for the Internet NIC (eth0, em1, etc.) : " internetnic

INTERNET_IP=$(/sbin/ifconfig $internetnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo "#######################################################################################"
echo "The horizon dashboard should be at http://$INTERNET_IP/horizon.  Login with admin/$password"
echo "#######################################################################################"

