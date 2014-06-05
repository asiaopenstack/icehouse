#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

apt-get update -y
apt-get install curl -y
apt-get install python-pip -y

echo "#################################################################################################

System updated.  Now run './openstack_setup.sh' to run the system setup.

#################################################################################################
"

exit
