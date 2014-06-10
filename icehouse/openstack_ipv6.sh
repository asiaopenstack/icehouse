#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear

# source the setup file
. ./setuprc

# variables based on rig type
if [[ -z $SG_SERVICE_CONTROLLER ]]; then
  rignic=$SG_SERVICE_COMPUTE_NIC
else
  rignic=$SG_SERVICE_CONTROLLER_NIC
fi

# install netaddr and radvd
apt-get install -y python-netaddr
apt-get install -y radvd

# hack up the nova.conf file
sed -e "
/^use_ipv6=.*$/s/^.*$/enable_ipv6=True/
" -i /etc/nova/nova.conf

# set the routing flags correctly
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding # default value is 1
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra # default value is 2
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra

# build a file for reboot + janky patch for OpenStack networking foobaring things
cat > /etc/init.d/ipv6-setup <<EOF
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra
EOF

# set to execute and run on boot
chmod 755 /etc/init.d/ipv6-setup
ln -s /etc/init.d/ipv6-setup /etc/rc2.d/S10ipv6-setup

# start radvd
service radvd restart
 
# restart nova services
for svc in api cert compute conductor network scheduler; do
  service nova-$svc restart
done

echo;
echo "##########################################################################################"
echo;
echo "IPv6 configuration complete.  Be sure to add a proper network using 'nova-manage'"
echo;
echo "If you install a compute node, you will need to run this command on it as well."
echo;
echo "##########################################################################################"
echo;