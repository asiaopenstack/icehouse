#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi

# warn we're going to disable tracking
echo "######################################################################################################

In 5 seconds, this script will disable tracking for the remaining OpenStack install scripts.

If you are OK with this compute rig being tracked, hit ctrl-c to halt execution.

######################################################################################################
"
echo;

# take a nap
sleep 5

# set to not track
cat >> trackrc <<EOF
export SG_SERVICE_TRACK_DIABLE=true
EOF

echo "######################################################################################################

Tracking of the scripts has been disabled.  Thank you for installing OpenStack using these scripts!

######################################################################################################
"
echo;