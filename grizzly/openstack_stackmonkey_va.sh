#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# warn we're going to track

echo "######################################################################################################

In 5 seconds, this script will call home to indicate your interest in setting up the StackMonkey VA.

If you don't want this machine to be tracked, hit ctrl-c to halt execution.

######################################################################################################
"
echo;
sleep 5

# fake the install and just do a tracking ping
curl -s "https://www.stackmonkey.com/api/v1/track?message=OpenStack%20installed%20via%20StackGeek%20scripts." > /dev/null

echo "######################################################################################################

This script just sent a tracking ping to https://www.stackmonkey.com/ to help measure possible
conversions resulting from users like yourself who are interested in participating in the 
xov.io distributed cloud project.  More information about the project is available on the site.

The public IP address of this box was recorded an no further action will be taken.  We're done! :)

If you'd like to test the script, edit it and remove the exit command following this comment section.

######################################################################################################
"
# remove this if you want to test - appreciate the fact you are here and alive
exit

# source the rc and setup files
. ./setuprc
. ./stackrc

# get_id function for loading variables from command runs
function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# create stackmonkey project, user and roles
STACKMONKEY_TENANT=$(get_id keystone tenant-create --name=StackMonkey)
STACKMONKEY_USER=$(get_id keystone user-create --name=stackmonkey --pass="$ADMIN_PASSWORD" --email=$SG_SERVICE_EMAIL)
STACKMONKEY_ROLE=$(get_id keystone role-create --name=Monkey)
keystone user-role-add --user-id $STACKMONKEY_USER --role-id $STACKMONKEY_ROLE --tenant-id $STACKMONKEY_TENANT

# switch tenant name and username for the remaining commands
export OS_TENANT_NAME=StackMonkey
export OS_USERNAME_NAME=stackmonkey

# create and add keypairs
ssh-keygen -f stackmonkey-id -N ""
nova keypair-add --pub_key stackmonkey-id.pub stackmonkey

# configure default security group to allow port 80 and 22, plus pings
nova secgroup-add-rule default tcp 80 80 0.0.0.0/0
nova secgroup-add-rule default tcp 22 80 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0./0

# start the appliance instance
# key, post boot data, flavor, image, instance name
nova boot --key_name stackmonkey --user-data postcreation.sh --flavor 1 --image "Ubuntu Precise 12.04 LTS" "StackMonkey VA"

echo "#####################################################################################################

The StackMonkey appliance has been built and a private key called 'stackmonkey.pem' has been created.

The IP address of the appliance is x.x.x.x.  You can configure the VA at: http://x.x.x.x/

#####################################################################################################
"

# switch tenant name and username back, just in case user runs stuff
export OS_TENANT_NAME=admin
export OS_USERNAME_NAME=admin

exit