#!/bin/bash

# download the net installer
ISO="centos_netinstall.iso"
if [ -f $ISO ]
then
  echo "ISO downloaded already!" 
else
  curl http://mirror.stanford.edu/yum/pub/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso > $ISO
  echo "ISO downloaded!" 
fi

# build the VM in VirtualBox
VM="BlueCentOS"
VBoxManage createvm --name $VM --ostype "RedHat_64" --register
VBoxManage createhd --filename ~/VirtualBox\ VMs/$VM/$VM.qcow --size 8192

# add a qcow storage device
VBoxManage storagectl $VM --name "SATA Controller" --add sata --controller IntelAHCI
VBoxManage storageattach $VM --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/$VM/$VM.qcow

# add the dvd install
VBoxManage storagectl $VM --name "IDE Controller" --add ide
VBoxManage storageattach $VM --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $PWD/$ISO

# do a few important things
VBoxManage modifyvm $VM --ioapic on
VBoxManage modifyvm $VM --boot1 dvd --boot2 disk --boot3 none --boot4 none
VBoxManage modifyvm $VM --memory 1024 --vram 128

# set port forwarding
VBoxManage modifyvm $VM --natpf1 "ssh,tcp,,2222,,22"



