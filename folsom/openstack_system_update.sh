#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# stuff canonical's repo in sources and update the system (for 12.04.1 only)
if grep -q STACKGEEK /etc/apt/sources.list
then
  echo "Folsom repo already added to /etc/apt/sources.list.  We're ready to rock."
else
  echo '# STACKGEEK ADDED THIS' >> /etc/apt/sources.list
  echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main' >> /etc/apt/sources.list
fi

apt-get install ubuntu-cloud-keyring -y
aptitude update -y
aptitude upgrade -y
aptitude dist-upgrade -y

echo "#################################################################################################

System updated.  Now run './openstack_networking.sh' to get instructions for network setup.

#################################################################################################
"

exit
