#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# restart nova
service nova-api restart
service nova-api-metadata restart
service nova-cert restart
service nova-conductor restart
service nova-consoleauth restart
service nova-network restart
service nova-compute restart
service nova-novncproxy restart
service nova-scheduler restart