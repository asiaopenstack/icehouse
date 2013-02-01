#!/bin/bash
# The end of this script is somewhat cobbled together from all sorts of places.  Thanks to those people, whoever you are.

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# source the setup file
. ./setuprc

# grab our IP 
# comment out the following line and uncomment the one after if you have a different IP in mind
HOST_IP=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
# HOST_IP=10.0.10.100

echo;
echo "#############################################################################################################"
echo;
echo "The main IP address for this machine is probably $HOST_IP.  If that's wrong, ctrl-c and edit this script."
echo;
echo "#############################################################################################################"
echo;

read -p "Hit enter to start Keystone setup. " -n 1 -r

# get keystone
apt-get install keystone -y

# some vars from the SG setup file getting locally reassigned 
password=$SG_SERVICE_PASSWORD
email=$SG_SERVICE_EMAIL
token=$SG_SERVICE_TOKEN
region=$SG_SERVICE_REGION

# set up env variables for various things - you'll need this later to run keystone and nova-manage commands 
# some of these variables are used by this script, so don't get confused if you seem them listed below again
cat > stackrc <<EOF
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://127.0.0.1:5000/v2.0/" 
export ADMIN_PASSWORD=$password
export SERVICE_PASSWORD=$password
export SERVICE_TOKEN=$token
export SERVICE_ENDPOINT="http://127.0.0.1:35357/v2.0"
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
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$password@127.0.0.1\/keystone/
/^# admin_token =.*$/s/^.*$/admin_token = $token/
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
# guess. consider me disgruntled.  Kord Campbell

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=service)
DEMO_TENANT=$(get_id keystone tenant-create --name=demo)
INVIS_TENANT=$(get_id keystone tenant-create --name=invisible_to_admin)

# Users
ADMIN_USER=$(get_id keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=$email)
DEMO_USER=$(get_id keystone user-create --name=demo --pass="$ADMIN_PASSWORD" --email=$email)

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)

# Add Roles to Users in Tenants
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONEADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONESERVICE_ROLE --tenant-id $ADMIN_TENANT

# The Member role is used by Horizon and Swift
MEMBER_ROLE=$(get_id keystone role-create --name=Member)
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $INVIS_TENANT

# nova
NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE
NOVA=$(get_id keystone service-create --name nova --type compute --description Compute )
keystone endpoint-create --region $KEYSTONE_REGION --service-id $NOVA --publicurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s'

# glance
GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant_id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE
GLANCE=$(get_id keystone service-create --name glance --type image --description Image)
keystone endpoint-create --region $KEYSTONE_REGION --service-id $GLANCE --publicurl 'http://'"$HOST_IP"':9292/v2' --adminurl 'http://'"$HOST_IP"':9292/v2' --internalurl 'http://'"$HOST_IP"':9292/v2'

# quantum
if [ "$SG_QUANTUM" != "0" ]; then
  QUANTUM_USER=$(get_id keystone user-create --name=quantum --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=$email)
  keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $QUANTUM_USER --role-id $ADMIN_ROLE
  QUANTUM=$(get_id keystone service-create --name quantum --type network --description Networking )
  keystone endpoint-create --region $KEYSTONE_REGION --service-id $QUANTUM --publicurl 'http://'"$HOST_IP"':9696/' --adminurl 'http://'"$HOST_IP"':9696/' --internalurl 'http://'"$HOST_IP"':9696/'
fi

# cinder
CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE
CINDER=$(get_id keystone service-create --name cinder --type volume --description Volume )
keystone endpoint-create --region $KEYSTONE_REGION --service-id $CINDER --publicurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s'

# keystone 
KEYSTONE=$(get_id keystone service-create --name keystone --type identity --description Identity )
keystone endpoint-create --region $KEYSTONE_REGION --service-id $KEYSTONE --publicurl 'http://'"$HOST_IP"':5000/v2.0' --adminurl 'http://'"$HOST_IP"':35357/v2.0' --internalurl 'http://'"$HOST_IP"':5000/v2.0'

# ec2 compatability
EC2=$(get_id keystone service-create --name ec2 --type ec2 --description EC2 )
keystone endpoint-create --region $KEYSTONE_REGION --service-id $EC2 --publicurl 'http://'"$HOST_IP"':8773/services/Cloud' --adminurl 'http://'"$HOST_IP"':8773/services/Admin' --internalurl 'http://'"$HOST_IP"':8773/services/Cloud'

# create ec2 creds and parse the secret and access key returned
RESULT=$(keystone ec2-credentials-create --tenant-id=$ADMIN_TENANT --user-id=$ADMIN_USER)
ADMIN_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
ADMIN_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`

# write the secret and access to ec2rc
cat > ec2rc <<EOF
ADMIN_ACCESS=$ADMIN_ACCESS
ADMIN_SECRET=$ADMIN_SECRET
EOF

echo "########################################################################################"
echo;
echo "Your EC2 credentials have been saved into ./ec2rc"
echo;
echo "Time to test keystone.  Do a '. ./stackrc' then a 'keystone user-list'."
echo "Assuming you get a user list back, go on to install glance with './openstack_glance.sh'."
echo;
echo "########################################################################################"
