#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# fake the install and do a tracking ping instead
curl -s "https://www.stackmonkey.com/api/v1/track?message=OpenStack%20installed%20via%20StackGeek%20scripts." > /dev/null

echo "######################################################################################################

This script just sent a tracking ping to https://www.stackmonkey.com/ to help measure possible
conversions resulting from users like yourself who are interested in participating in the 
xov.io distributed cloud project.  More information about the project is available on the site.

The public IP address of this box was recorded an no further action will be taken.

If you'd like to test the script, edit it and remove the exit command following this comment section.

######################################################################################################
"
# remove this if you want to test - appreciate the fact you are here and alive
exit

# source the rc and setup files
. ./setuprc
. ./stackrc

# create stackmonkey project, user and roles
STACKMONKEY_TENANT=$(get_id keystone tenant-create --name=StackMonkey)
STACKMONKEY_USER=$(get_id keystone user-create --name=stackmonkey --pass="$ADMIN_PASSWORD" --email=$SG_SERVICE_EMAIL)
STACKMONKEY_ROLE=$(get_id keystone role-create --name=Monkey)
keystone user-role-add --user-id $STACKMONKEY_USER --role-id $STACKMONKEY_ROLE --tenant-id $STACKMONKEY_TENANT

# create and add keypairs
ssh-keygen -f stackmonkey-id -N ""
nova keypair-add --tenant-id $STCKMONKEY_TENANT --pub_key stackmonkey-id.pub stackmonkey

# configure default security group

# start the appliance instance
nova boot --user-data postcreation.sh --flavor 1 --image "Ubuntu Precise 12.04" "StackMonkey VA"

echo "#####################################################################################################

The StackMonkey appliance has been built and a private key called 'stackmonkey.pem' has been created.

The IP address of the appliance is x.x.x.x.  You can configure the VA at: http://x.x.x.x/

#####################################################################################################
"

exit