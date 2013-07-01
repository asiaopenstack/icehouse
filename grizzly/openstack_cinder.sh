#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

clear 

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD    

# grab our IP 
read -p "Enter the device name for the Internet NIC (eth0, etc.) : " internetnic
read -p "Enter the device name for the Management NIC (eth1, etc.) : " managementnic

INTERNET_IP=$(/sbin/ifconfig $internetnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
MANAGEMENT_IP=$(/sbin/ifconfig $managementnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo;
echo "#############################################################################################################"
echo;
echo "The IP address on the Internet NIC is probably $INTERNET_IP.  If that's wrong, ctrl-c and edit this script."
echo "The IP address on the Management NIC is probably $MANAGEMENT_IP If that's wrong, ctrl-c and edit this script."
echo;
echo "#############################################################################################################"
echo;
#INTERNET_IP=x.x.x.x
#MANAGEMENT_IP=x.x.x.x
read -p "Hit enter to start Cinder setup. " -n 1 -r

# install packages and toggle iscitarget
apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms

sed -i 's/false/true/g' /etc/default/iscsitarget

# hack up the cinder paste file
sed -e "
s,127.0.0.1,$INTERNET_IP,g;
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,cinder,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i /etc/cinder/api-paste.ini

 # hack up the cinder config file
echo "
iscsi_ip_address=$MANAGEMENT_IP
sql_connection = mysql://cinder:$password@$MANAGEMENT_IP/cinder
" >> /etc/cinder/cinder.conf

# restart and sync
service iscsitarget start
service open-iscsi start
sleep 5
cinder-manage db sync
 
echo "#################################################################################################

You need to manually create a LVM for the 'cinder-volumes' group.  This process requires you have
either a a dedicated partition to use for the volume group, usually located on an extra drive, or
room in your existing physical volume to allow cinder to create new logical volumes.

Using a Dedicated Partition
---------------------------
We're going to assume you have an empty disk spinning at /dev/sdb.  Begin by starting 'fdisk':

 fdisk /dev/sdb

Create a new partition by hitting 'n' then 'p'.  Use the defaults.  Type 't' then '8e' to set the 
partition to the LVM type.  Hit 'w' to write and exit.

Next, from the command line, enter the follow commands:

  pvcreate -ff /dev/sdb1
  vgcreate cinder-volumes /dev/sdb1

You should get back something like this:

  root@nero:/home/kord# vgcreate cinder-volumes /dev/sdb1
  Volume group "cinder-volumes" successfully created

NOTE: You should use whatever device handle your system has for the second drive.  Do be careful!

Now verify 'cinder-volumes' exists by doing:

  vgdisplay cinder-volumes

Using an Existing Volume Group
------------------------------
NOTE: Don't do this part if you are using a dedicated partition. 

You need to find the physical volume name and use it to edit your cinder.conf file.  Begin by 
running 'pvdisplay' and finding the 'VG Name':

  root@ace:/home/kord/# pvdisplay 
    --- Physical volume ---
    PV Name               /dev/sda3
    VG Name               ace-vg  <----- THIS IS WHAT YOU WANT
    PV Size               7.28 TiB / not usable 0   
    Allocatable           yes 
    PE Size               4.00 MiB
    Total PE              1907138
    Free PE               1156720
    Allocated PE          750418

Now use the 'VG Name' to edit the cinder.conf file to use the volume group name:

  volume_group = ace-vg

#################################################################################################

When you are done with one of the above, run './openstack_quantum.sh'

#################################################################################################
"
echo;
exit
