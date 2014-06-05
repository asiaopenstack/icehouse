#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

clear

# source the setup file
. ./setuprc

# install netaddr and radvd
apt-get install -y python-netaddr
apt-get install -y radvd

# variables
if [[ -z $SG_SERVICE_CONTROLLER ]]; then
	rignic=$SG_SERVICE_COMPUTE_NIC
else
	rignic=$SG_SERVICE_CONTROLLER_NIC
fi

# get current IPv6 info
echo;
echo "##########################################################################################"
echo;
echo "These are your current IPv6 addresses: "
echo;
ip -f inet6 addr
echo;
echo "You'll want to copy the first 4 blocks of hex numbers from one address."
echo;
echo "An example would be: 2601:9:1380:960"
echo;
echo "##########################################################################################"
echo;

# grab our IPv6 prefix
read -p "Enter a (global) IPv6 prefix for $rignic: " prefix
read -p "Enter the router's IPv6 address to be used as a gateway: " routeripv6

# create radvd conf file
cat <<EOF > /etc/radvd.conf
interface $INTERFACE
{
    AdvSendAdvert             on;
 
    prefix $PREFIX::/64
    {
        AdvOnLink             on;
        AdvAutonomous         on;
    };
};
EOF

# hack network interfaces
cat <<EOF >> /etc/networking/interfaces
auto br100
iface br100 inet6 static
  address $prefix::1
  netmask 64
  up ip -6 route add default dev br100
EOF

# set the routing flags correctly
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra

# default route + replace the bad ipv6 address on br100
route -A inet6 add 2000::/3 gw $routeripv6
ifconfig br100 inet6 del $prefix::/64
ifconfig br100 inet6 add $prefix::1/64

# build a file for reboot + janky patch for OpenStack networking foobaring things
cat > /etc/init.d/ipv6-setup <<EOF
echo 0 > /proc/sys/net/ipv6/conf/$rignic/forwarding
echo 1 > /proc/sys/net/ipv6/conf/$rignic/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra
echo 0 > /proc/sys/net/ipv6/conf/br100/forwarding
echo 1 > /proc/sys/net/ipv6/conf/br100/accept_ra
route -A inet6 add 2000::/3 gw $routeripv6
ifconfig br100 inet6 del $prefix::/64
ifconfig br100 inet6 add $prefix::1/64
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