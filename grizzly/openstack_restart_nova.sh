#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# restart nova
cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
