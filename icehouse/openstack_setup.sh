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

# tracking ping - run openstack_disable_tracking.sh to disable
if [ ! -f ./trackrc ]; then
	curl -s "https://www.stackmonkey.com/api/v1/track?message=OpenStack%20setup%20script%20run." > /dev/null
fi

echo;
echo "################################################################################################"
echo;
echo "Please refer to https://github.com/StackGeek/openstackgeek/blob/master/readme.md for setup help."
echo;
echo "################################################################################################"
echo;

# grab our IP 
read -p "Enter the device name for this rig's NIC (eth0, etc.) : " rignic

rigip=$(/sbin/ifconfig $rignic| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo;
echo "#################################################################################################################"
echo;
echo "The IP address on this rig's NIC is probably $rigip.  If that's wrong, ctrl-c and edit this script."
echo;
echo "#################################################################################################################"
echo;
#rigip=x.x.x.x

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
# some of these envrionment variables are set again in stackrc later
cat > setuprc <<EOF
# set up env variables for install
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://$rigip:5000/v2.0/"
export OS_REGION_NAME=$region
export SG_SERVICE_CONTROLLER_IP=$rigip
export SG_SERVICE_CONTROLLER_NIC=$rignic
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
	
# again, don't unindent!
# tack on an indicator we're the controller
cat >> setuprc <<EOF
export SG_SERVICE_CONTROLLER=1
EOF

else
	echo;
	read -p "Enter the URL given to you from the controller setup: " sprungeurl
	curl $sprungeurl > setuprc

# don't unindent!
# tack on the IP address for the compute rig
cat >> setuprc <<EOF
export SG_SERVICE_COMPUTE_IP=$rigip
export SG_SERVICE_COMPUTE_NIC=$rignic
EOF

	echo;
	echo "##########################################################################################"
	echo;
	echo "Setup configuration complete.  Continue the setup by doing a './openstack_cinder.sh'."
	echo;
	echo "##########################################################################################"
	echo;
	exit
fi

echo;
echo "##########################################################################################"
echo;
echo "Setup configuration complete.  Continue the setup by doing a './openstack_mysql.sh'."
echo;
echo "If you would like to install Splunk, do a './openstack_splunk.sh' before continuing."
echo;
echo "##########################################################################################"
echo;
