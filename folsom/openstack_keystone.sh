#!/bin/bash

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
#HOST_IP=10.0.10.100

echo;
echo "#############################################################################################################"
echo "The main IP address for this machine is probably $HOST_IP.  If that's wrong, ctrl-c and edit this script."
echo "#############################################################################################################"
echo;

read -p "Hit enter to start Keystone setup. " -n 1 -r

# get keystone
apt-get install keystone -y

# some vars from the SG setup file
password=$SG_SERVICE_PASSWORD
email=$SG_SERVICE_EMAIL
token=$SG_SERVICE_TOKEN
region=$SG_SERVICE_REGION

# set up env variables for various things - you'll need this later to run keystone and nova-manage commands 
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

exit

# edit keystone conf file to use templates and mysql
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig
sed -e "
/^admin_token = ADMIN/s/^.*$/admin_token = $token/
/^driver = keystone.catalog.backends.sql.Catalog/d
/^\[catalog\]/a driver = keystone.catalog.backends.templated.TemplatedCatalog 
/^\[catalog\]/a template_file = /etc/keystone/default_catalog.templates
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$password@127.0.0.1\/keystone/
" -i /etc/keystone/keystone.conf

# create db tables and restart
keystone-manage db_sync
service keystone restart

# sleep a bit before we whack on it
sleep 5

ADMIN_PASSWORD=$password
SERVICE_PASSWORD=$password


function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# Tenants
SERVICE_TENANT_NAME="service"
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)

# Users
ADMIN_USER=$(get_id keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=$email)
DEMO_USER=$(get_id keystone user-create --name=demo --pass="$ADMIN_PASSWORD" --email=$email)

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)

# Add Roles to Users in Tenants
keystone user-role-add --user $ADMIN_USER --role $ADMIN_ROLE --tenant_id $ADMIN_TENANT
keystone user-role-add --user $ADMIN_USER --role $KEYSTONEADMIN_ROLE --tenant_id $ADMIN_TENANT
keystone user-role-add --user $ADMIN_USER --role $KEYSTONESERVICE_ROLE --tenant_id $ADMIN_TENANT

# nova
NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant_id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE
keystone service-create --name nova --type compute --description 'OpenStack Compute Service'
keystone endpoint-create --region $KEYSTONE_REGION --service-id compute --publicurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s'

# glance
GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant_id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE
keystone service-create --name glance --type image --description 'OpenStack Image Service'
keystone endpoint-create --region $KEYSTONE_REGION --service-id glance --publicurl 'http://'"$HOST_IP"':9292/v2' --adminurl 'http://'"$HOST_IP"':9292/v2' --internalurl 'http://'"$HOST_IP"':9292/v2'

# quantum
if $SG_QUANTUM; then
	QUANTUM_USER=$(get_id keystone user-create --name=quantum --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=$email)
	keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $QUANTUM_USER --role-id $ADMIN_ROLE
	keystone service-create --name quantum --type network --description 'OpenStack Networking service'
	keystone endpoint-create --region $KEYSTONE_REGION --service-id quantum --publicurl 'http://'"$HOST_IP"':9696/' --adminurl 'http://'"$HOST_IP"':9696/' --internalurl 'http://'"$HOST_IP"':9696/'
fi

# cinder
CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=$email)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE
keystone service-create --name cinder --type volume --description 'OpenStack Volume Service'
keystone endpoint-create --region $KEYSTONE_REGION --service-id volume --publicurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s'

# keystone 
keystone service-create --name keystone --type identity --description 'OpenStack Identity'
keystone endpoint-create --region $KEYSTONE_REGION --service-id identity --publicurl 'http://'"$HOST_IP"':5000/v2.0' --adminurl 'http://'"$HOST_IP"':35357/v2.0' --internalurl 'http://'"$HOST_IP"':5000/v2.0'

# ec2 compatability
keystone service-create --name ec2 --type ec2 --description 'OpenStack EC2 service'
keystone endpoint-create --region $KEYSTONE_REGION --service-id ec2 --publicurl 'http://'"$HOST_IP"':8773/services/Cloud' --adminurl 'http://'"$HOST_IP"':8773/services/Admin' --internalurl 'http://'"$HOST_IP"':8773/services/Cloud'

# create ec2 creds and parse the secret and access key returned
RESULT=$(keystone ec2-credentials-create --tenant-id=$ADMIN_TENANT --user-id=$ADMIN_USER)
ADMIN_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
ADMIN_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`

# write the secret and access to ec2rc
cat > $EC2RC <<EOF
ADMIN_ACCESS=$ADMIN_ACCESS
ADMIN_SECRET=$ADMIN_SECRET
EOF

echo "######################################################################################"
echo "Time to test keystone.  Do a '. ./stackrc' then a 'keystone user-list'."
echo "Assuming you get a user list back, go on to install glance with './openstack_glance.sh'."
echo "######################################################################################"
