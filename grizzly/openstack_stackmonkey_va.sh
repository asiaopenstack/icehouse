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

  echo 'delete from role where name=\"Monkey\";' | mysql -u root -p nova

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

# create stackmonkey project, user and roles
STACKMONKEY_TENANT=$(get_id keystone tenant-create --name=StackMonkey)
STACKMONKEY_USER=$(get_id keystone user-create --name=stackmonkey --pass="$ADMIN_PASSWORD" --email=$SG_SERVICE_EMAIL)
STACKMONKEY_ROLE=$(get_id keystone role-create --name=Monkey)
keystone user-role-add --user-id $STACKMONKEY_USER --role-id $STACKMONKEY_ROLE --tenant-id $STACKMONKEY_TENANT

# source rc file as the new user
. ./stackmonkeyrc

# create and add keypairs
ssh-keygen -f stackmonkey-id -N ""
nova keypair-add --pub_key stackmonkey-id.pub stackmonkey

# configure default security group to allow port 80 and 22, plus pings
nova secgroup-add-rule default tcp 80 80 0.0.0.0/0
nova secgroup-add-rule default tcp 22 80 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 

# start the appliance instance
# key, post boot data, flavor, image, instance name
nova boot --poll --key_name stackmonkey --user-data postcreation.sh --flavor 1 --image "Ubuntu Precise 12.04 LTS" "StackMonkey VA"

# grab the IP address for display to the user
APPLIANCE_IP=`nova list | grep "private*=[^=]" | cut -d= -f2 | cut -d, -f1`

echo "#####################################################################################################

The StackMonkey appliance is in progress and a private key called 'stackmonkey.pem' has been created.

The username/password for the OpenStack Horizon account is $OS_USERNAME/$OS_PASSWORD.

You may now configure the appliance at: http://$APPLIANCE_IP/

#####################################################################################################
"

# switch tenant name and username back, just in case user runs stuff
export OS_TENANT_NAME=admin
export OS_USERNAME=admin

exit