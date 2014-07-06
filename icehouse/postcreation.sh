#cloud-config
hostname: stackmonkey-va
manage_etc_hosts: true
runcmd:
 - [ wget, "http://goo.gl/KJH5Sa", -O, /tmp/install.sh ]
 - chmod 755 /tmp/install.sh
 - /tmp/install.sh
