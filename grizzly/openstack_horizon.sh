#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# get horizon
apt-get install -y openstack-dashboard memcached

# remove the ubuntu theme - seriously this is fucking stupid it's still broken
apt-get remove -y --purge openstack-dashboard-ubuntu-theme

# restart apache
service apache2 restart; service memcached restart

# source the setup and stack files
. ./setuprc
managementip=$SG_SERVICE_CONTROLLER_IP
password=$SERVICE_PASSWORD

echo "#######################################################################################"
echo;
echo "The horizon dashboard should be at http://$managementip/horizon.  Login with admin/$password"
echo;
echo "#######################################################################################"

