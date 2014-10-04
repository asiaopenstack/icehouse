#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# have we run before?
if [ -f ./stackmonkeyrc ]; then
echo;
echo "####################################################################################################	

This script has already been run.  If you want to launch a new StackMonkey VA, enter the following 
on the command line:

  . ./stackmonkeyrc
  nova boot --poll --key_name stackmonkey --user-data postcreation.sh --flavor 1 --image 'Ubuntu Precise 12.04 LTS' 'StackMonkey VA'  
  nova list

####################################################################################################	
"
exit
fi

# grab a new password 
read -p "Enter a new password for the 'stackmonkey' user: " monkeypass

# source the stack and setup files
. ./setuprc
. ./stackrc

# indicate we've now run ourselves
cat >> stackmonkeyrc <<EOF
export SM_VA_LAUNCH=true
export OS_TENANT_NAME=StackMonkey
export OS_USERNAME=stackmonkey
export OS_PASSWORD=$monkeypass
export OS_AUTH_URL=$OS_AUTH_URL 
export KEYSTONE_REGION=$KEYSTONE_REGION
EOF

# tracking ping - run openstack_disable_tracking.sh to disable
if [ ! -f ./trackrc ]; then
	curl -s "https://www.stackmonkey.com/api/v1/track?message=StackMonkey%20VA%20install%20script%20run." > /dev/null
fi

echo "######################################################################################################

This script just sent a tracking ping to https://www.stackmonkey.com/ to help measure possible
conversions resulting from users like yourself who are interested in participating in a compute pool.

######################################################################################################
"

# get_id function for loading variables from command runs
function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# project, user, roles for stackmonkey
keystone tenant-create --name=stackmonkey
keystone user-create --name=stackmonkey --pass="$monkeypass" --email=$SG_SERVICE_EMAIL
keystone user-role-add --user=stackmonkey --role=admin --tenant=stackmonkey

# source configuration for the new user
. ./stackmonkeyrc

# create and add keypairs
ssh-keygen -f stackmonkey-id -N ""
nova keypair-add --pub_key stackmonkey-id.pub stackmonkey

# configure the appliance security group
nova secgroup-create appliance "Appliance security group."
nova secgroup-add-rule appliance tcp 80 80 0.0.0.0/0
nova secgroup-add-rule appliance tcp 22 22 0.0.0.0/0
nova secgroup-add-rule appliance icmp -1 -1 0.0.0.0/0 

# configure default security group to allow all tcp and udp ports to instances, plus pings
nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 

# create a new flavor for the va w/ 8GB drive space
nova flavor-create m512.v1.d20 m512.v1.d20 512 1 20

# create an image to use to boot the appliance (Ubuntu 14.04LTS)
glance image-create --name="Ubuntu Trusty 14.04 LTS" --is-public=true --container-format=bare --disk-format=qcow2 --location=https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img

# boot va with key, post boot data, flavor, image, instance name
nova boot --poll --key_name stackmonkey --user-data postcreation.sh --security-groups appliance --flavor m512.v1.d8 --image "Ubuntu Trusty 14.04 LTS" "StackMonkey VA"

# grab the IP address for display to the user
APPLIANCE_IP=`nova list | grep "private*=[^=]" | cut -d= -f2 | cut -d, -f1`

# instruction bonanza
echo "#####################################################################################################

The StackMonkey appliance will take about 10 minutes to build.  

A private key called 'stackmonkey.pem' has been created and placed in this directory.  You will be 
able to use this key to ssh into the appliance.  Copy it somwhere safe and then use it like this:

    ssh -i stackmonkey.pem ubuntu@$APPLIANCE_IP

A new OpenStack account has been created: $OS_USERNAME/$OS_PASSWORD.  Use this account to login and
download the API credentials file to your local machine.  You will need to upload this file to the
appliance once it is done building.

Use a web browser to see if the appliance is ready: http://$APPLIANCE_IP/

#####################################################################################################
"

# switch tenant name and username back, just in case user runs stuff
export OS_TENANT_NAME=admin
export OS_USERNAME=admin

exit
