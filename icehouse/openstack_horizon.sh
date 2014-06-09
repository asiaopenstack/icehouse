#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# get horizon
apt-get install -y apache2 memcached libapache2-mod-wsgi openstack-dashboard

# remove the ubuntu theme - seriously this is fucking stupid it's still broken
apt-get remove -y --purge openstack-dashboard-ubuntu-theme

# restart apache
service apache2 restart; service memcached restart

# source the setup and stack files
. ./setuprc
managementip=$SG_SERVICE_CONTROLLER_IP
password=$SG_SERVICE_PASSWORD

# patch nova.conf files - TODO

echo "#######################################################################################"
echo;
echo "The horizon dashboard should be at http://$managementip/horizon.  Login with admin/$password"
echo;
echo "Now run the StackMonkey virtual appliance setup: ./openstack_stackmonkey_va.sh"
echo;
echo "#######################################################################################"

