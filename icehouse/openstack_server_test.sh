#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# tracking ping - run openstack_disable_tracking.sh to disable
if [ ! -f ./trackrc ]; then
	curl -s "https://www.stackmonkey.com/api/v1/track?message=OpenStack%20server%20test%20script%20run." > /dev/null
fi

# install and run kvm-ok to see if we have virt capabilities
apt-get install cpu-checker -y
if /usr/sbin/kvm-ok
then echo;
echo "#################################################################################################

Your CPU seems to support KVM extensions.  If you are installing OpenStack on a virtual machine,
you will need to add 'virt_type=qemu' to your nova.conf file in /etc/nova/ and then restart all
nova services once you've finished running through the installation.  You DO NOT need to do this 
on a bare metal box.

Run './openstack_system_update.sh' to continue setup.

#################################################################################################
"
else echo;
echo "#################################################################################################

Your system isn't configured to run KVM properly.  Investigate this before continuing.

You can still modify /etc/nova/nova.conf (once nova is installed) to emulate acceleration:

[libvirt]
virt_type = qemu

#################################################################################################
"
fi


