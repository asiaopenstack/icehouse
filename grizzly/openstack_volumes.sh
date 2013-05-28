#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

echo "#################################################################################################

You need to manually create a LVM for the 'nova-volumes' group.  This process requires you have
a dedicated partition to use for the volume group, usually located on an extra drive.

We're going to assume you have an empty disk spinning at /dev/sdb.  Begin by starting 'fdisk':

 fdisk /dev/sdb

Create a new partition by hitting 'n' then 'p'.  Use the defaults.  Type 't' then '8e' to set the 
partition to the LVM type.  Hit 'w' to write and exit.

Next, from the command line, enter the follow commands:

  pvcreate -ff /dev/sdb1
  vgcreate nova-volumes /dev/sdb1

You should get back something like this:

  root@nero:/home/kord# vgcreate nova-volumes /dev/sdb1
  Volume group "nova-volumes" successfully created

Now verify 'nova-volumes' exists by doing:

  vgdisplay nova-volumes

NOTE: You should use whatever device handle your system has for the second drive.  Do be careful!

When you are done, run './openstack_mysql.sh'

#################################################################################################
"
exit
