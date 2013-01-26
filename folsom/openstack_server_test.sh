#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# install and run kvm-ok to see if we have virt capabilities
apt-get install cpu-checker -y
if /usr/sbin/kvm-ok
then echo "#################################################################################################

Your CPU seems to support KVM extensions.  Run './openstack_system_update.sh' to continue setup. 

#################################################################################################
"
else echo "#################################################################################################

Your system isn't configured to run KVM properly.  Investigate this before continuing.

#################################################################################################
"
fi


