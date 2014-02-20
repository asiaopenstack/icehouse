#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear 

if [ -f ./setuprc ]
then
	echo "######################################################################################################"
	echo;
	echo "Setup has already been run.  Edit or delete the ./setuprc file in this directory to reconfigure setup."
	echo;
	echo "You can reset the installation by running './openstack_cleanup.sh'"
	echo;
	echo "#######################################################################################################"
	echo;
	exit
fi

echo;
echo "################################################################################################"
echo;
echo "Please refer to https://github.com/StackGeek/openstackgeek/blob/master/readme.md for setup help."
echo;
echo "################################################################################################"
echo;

# grab our IP 
read -p "Enter the device name for the controller's NIC (eth0, etc.) : " managementnic

MANAGEMENT_IP=$(/sbin/ifconfig $managementnic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo;
echo "#################################################################################################################"
echo;
echo "The IP address on the controller's NIC is probably $MANAGEMENT_IP.  If that's wrong, ctrl-c and edit this script."
echo;
echo "#################################################################################################################"
echo;
#MANAGEMENT_IP=x.x.x.x

# controller install?
echo;
read -p "Is this the controller node? " -n 2 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
	# prompt for a few things we'll need for mysql
	echo;
	read -p "Enter a password to be used for the OpenStack services to talk to MySQL: " password
	echo;
	read -p "Enter the email address for service accounts: " email
	echo;
	read -p "Enter a short name to use for your default region: " region
	echo;

	# making a unique token for this install
	token=`cat /dev/urandom | head -c2048 | md5sum | cut -d' ' -f1`

# do not unindent this section!
cat > setuprc <<EOF
# set up env variables for testing
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://$MANAGEMENT_IP:5000/v2.0/" 
export SG_SERVICE_CONTROLLER_IP=$MANAGEMENT_IP
export SG_SERVICE_TENANT_NAME=service
export SG_SERVICE_EMAIL=$email
export SG_SERVICE_PASSWORD=$password
export SG_SERVICE_TOKEN=$token
export SG_SERVICE_REGION=$region
EOF

	# single or multi?
	read -p "Is this a multi node install? " -n 2 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		echo;
		echo "The following URL will be used for configuring the other rigs in this cluster.  Copy it."
		echo;
		cat setuprc | curl -F 'geek=<-' https://sgsprunge.appspot.com 
	fi

else
	echo;
	read -p "Enter the URL given to you from the controller setup: " sprungeurl
	curl $sprungeurl > setuprc

	echo;
	echo "##########################################################################################"
	echo;
	echo "Setup configuration complete.  Continue the setup by doing a './openstack_cinder.sh'."
	echo;
	echo "##########################################################################################"
	echo;
	exit
fi

# tack on an indicator we're the controller
cat >> setuprc <<EOF
export SG_SERVICE_CONTROLLER=1
EOF

echo;
echo "##########################################################################################"
echo;
echo "Setup configuration complete.  Continue the setup by doing a './openstack_mysql.sh'."
echo;
echo "##########################################################################################"
echo;
