#!/bin/bash

# add the EPEL repo and update
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y update

# install cloud-init
yum -y install cloud-init
yum -y install rsync

# add the ec2-user (default for cloud-init)
adduser ec2-user
mkdir /home/ec2-user/.ssh/
chown -R ec2-user.ec2-user /home/ec2-user/.ssh

# patch up groups
sed -i '/^wheel:/ s/$/ec2-user/' /etc/group

# fix up sudoers
sed -i '/Defaults    requiretty/d' /etc/sudoers
sed -i '/## Same thing without a password/{n;d}' /etc/sudoers
sed -i '/# Same thing without a password/a \
%wheel	 ALL=(ALL)	 NOPASSWD: ALL' /etc/sudoers

# hack up sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

# clean up the network interface stuff
rm /etc/udev/rules.d/70-persistent-net.rules
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0

# graft up grub
sed -i 's/timeout=5/timeout=1/g' /boot/grub/menu.lst
sed -i '/hiddenmenu/a \
serial –unit=0 –speed=115200 \
terminal –timeout=10 console serial' /boot/grub/menu.lst
sed -i '/^\skernel/ s/$/ console=tty0 console=ttyS0,115200n8/' /boot/grub/menu.lst

# wipe the passwords
passwd -l root
passwd -l ec2-user

# say something cute in /etc/motd
echo "CentOS image built using BlueChipTek's OpenStack guide." >> /etc/motd
echo "" >> /etc/motd
echo "More guides on OpenStack are at http://openstack.bluechiptek.com/" >> /etc/motd
echo "" >> /etc/motd
echo "@StackGeek" >> /etc/motd

# notify we're halting
echo "Halting instance in 5 seconds!"
sleep 5

# halt the instance
halt
