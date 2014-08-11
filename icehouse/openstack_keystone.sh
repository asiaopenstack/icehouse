#!/bin/bash
# The end of this script is somewhat cobbled together from all sorts of places.  Thanks to those people, whoever you are.

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

clear 

# get keystone
apt-get install keystone -y

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD
email=$SG_SERVICE_EMAIL
token=$SG_SERVICE_TOKEN
region=$SG_SERVICE_REGION
managementip=$SG_SERVICE_CONTROLLER_IP

# set up env variables for various things - you'll need this later to run keystone and nova-manage commands 
# some of these variables are used by this script, so don't get confused if you seem them listed below again
cat > stackrc <<EOF
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://$managementip:5000/v2.0/"
export OS_REGION_NAM=$region
export ADMIN_PASSWORD=$password
export SERVICE_PASSWORD=$password
export SERVICE_TOKEN=$token
export SERVICE_ENDPOINT="http://$managementip:35357/v2.0"
export SERVICE_TENANT_NAME=service
export KEYSTONE_REGION=$region
EOF

# source the stackrc file we just created
. ./stackrc

# edit keystone conf file to use templates and mysql
if [ -f /etc/keystone/keystone.conf.orig ]; then
  echo "Original backup of keystone.conf file exists. Your current config will be modified by this script."
  cp /etc/keystone/keystone.conf.orig /etc/keystone/keystone.conf
else
  cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig
fi

sed -e "
/^#admin_token=.*$/s/^.*$/admin_token = $token/
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$password@$managementip\/keystone/
" -i /etc/keystone/keystone.conf

# create db tables and restart
keystone-manage db_sync
service keystone restart

# sleep a bit before we whack on it
sleep 5

# The following portions of this script were inspired by works by Hastexo and the OpenStack wiki scripts.
# Where possible, I've clarified or cleaned up logic flow to 'group' linear commands to each other.

function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# the following commands use an interesting pattern due to keystone's asinine way of doing asset association.
# we run a keystone command through the get_id function (defined above) and then use the resulting md5 hash  
# to set a variable which we then use on the next command, effectively tying the two resources together inside
# keystone.  later on we do this twice for each role.  why on earth keystone itself doesn't do this is anyone's 
# guess. consider me disgruntled. Kord 

# Users
keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=$email
keystone user-create --name=demo --pass="$ADMIN_PASSWORD" --email=$email

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=service)
DEMO_TENANT=$(get_id keystone tenant-create --name=demo)

# Add Roles to Users in Tenants
keystone user-role-add --user=admin --role=admin --tenant=admin
keystone user-role-add --user=demo --role=_member_ --tenant=demo

# keystone 
KEYSTONE=$(get_id keystone service-create --name=keystone --type=identity --description=Identity )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$KEYSTONE --publicurl='http://'"$managementip"':5000/v2.0' --adminurl='http://'"$managementip"':35357/v2.0' --internalurl='http://'"$managementip"':5000/v2.0'

# glance
keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --user=glance --tenant=service --role=admin
GLANCE=$(get_id keystone service-create --name=glance --type=image --description=Image)
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$GLANCE --publicurl='http://'"$managementip"':9292' --adminurl='http://'"$managementip"':9292' --internalurl='http://'"$managementip"':9292'

# cinder
keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=cinder --role=admin
CINDER=$(get_id keystone service-create --name=cinder --type=volume --description=Volume )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$CINDER --publicurl='http://'"$managementip"':8776/v1/$(tenant_id)s' --adminurl='http://'"$managementip"':8776/v1/$(tenant_id)s' --internalurl='http://'"$managementip"':8776/v1/$(tenant_id)s'
CINDER2=$(get_id keystone service-create --name=cinder --type=volumev2 --description=Volume2 )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$CINDER2 --publicurl='http://'"$managementip"':8776/v2/$(tenant_id)s' --adminurl='http://'"$managementip"':8776/v2/$(tenant_id)s' --internalurl='http://'"$managementip"':8776/v2/$(tenant_id)s'

# nova
keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=nova --role=admin
NOVA=$(get_id keystone service-create --name=nova --type=compute --description=Compute )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$NOVA --publicurl='http://'"$managementip"':8774/v2/$(tenant_id)s' --adminurl='http://'"$managementip"':8774/v2/$(tenant_id)s' --internalurl='http://'"$managementip"':8774/v2/$(tenant_id)s'

# ec2 compatability
EC2=$(get_id keystone service-create --name=ec2 --type=ec2 --description=EC2 )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$EC2 --publicurl='http://'"$managementip"':8773/services/Cloud' --adminurl='http://'"$managementip"':8773/services/Admin' --internalurl='http://'"$managementip"':8773/services/Cloud'

echo "########################################################################################"
echo;
echo "Time to test keystone.  Do a '. ./stackrc' then a 'keystone user-list'."
echo "Assuming you get a user list back, go on to install glance with './openstack_glance.sh'."
echo;
echo "########################################################################################"
