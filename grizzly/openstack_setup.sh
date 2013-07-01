#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear 

if [ -f ./setuprc ]
then
	echo "########################################################################################################################"
	echo;
	echo "Setup has already been run.  Edit or delete the ./setuprc file in this directory to reconfigure setup."
	echo;
	echo "You can reset the installation by running './openstack_cleanup.sh' or continue by running './openstack_server_test.sh'."
	echo;
	echo "########################################################################################################################"
	echo;
	exit
fi

echo;
echo "#############################################################################################################"
echo "Please refer to http://stackgeek.com/guides/osi10min.html before continuing the setup."
echo "#############################################################################################################"

# single or multi?
echo;
read -p "Is this a multi node install? " -n 2 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
	SG_MULTI_NODE=1
else
	SG_MULTI_NODE=0
fi
echo;

# swift
read -p "Do you want to install Swift? " -n 2 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
	SG_INSTALL_SWIFT=1
else
	SG_INSTALL_SWIFT=0
fi
echo;


# prompt for a few things we'll need for mysql
read -p "Enter a password to be used for the OpenStack services to talk to MySQL (users nova, glance, keystone, quantum): " password
echo;
read -p "Enter the email address for service accounts (nova, glance, keystone, quantum, etc.): " email
echo;
read -p "Enter a short name to use for your default region: " region
echo;

# making a unique token for this install
token=`cat /dev/urandom | head -c2048 | md5sum | cut -d' ' -f1`

cat > setuprc <<EOF
export SG_INSTALL_SWIFT=$SG_INSTALL_SWIFT
export SG_MULTI_NODE=$SG_MULTI_NODE
export SG_SERVICE_EMAIL=$email
export SG_SERVICE_PASSWORD=$password
export SG_SERVICE_TOKEN=$token
export SG_SERVICE_REGION=$region
EOF

echo "Using the following for determining your setup type.  Edit 'setuprc' if you don't like what you see. "
echo
cat setuprc
echo

echo "#############################################################################################################"
echo;
echo "Setup configuration complete.  Continue the setup by doing a './openstack_server_test.sh'."
echo;
echo "#############################################################################################################"
echo;
