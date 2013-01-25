#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# stuff canonical's repo in sources and update the system (for 12.04.1 only)
echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main' >> /etc/apt/sources.list
apt-get install ubuntu-cloud-keyring -y
aptitude update -y
aptitude upgrade -y
aptitude dist-upgrade -y

echo "#################################################################################################

System updated.  Now run './openstack_server_test.sh' to see if your box supports KVM.

#################################################################################################
"

exit
