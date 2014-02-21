## Script Flow
The scripts in this directory use a flag for determining install flow.  If the user is installing the OpenStack controller, the flow goes like this:

    ./openstack_networking.sh
    ./openstack_server_test.sh
    ./openstack_system_update.sh
    ./openstack_setup.sh
    ./openstack_mysql.sh
    ./openstack_keystone.sh
    ./openstack_glance.sh
    ./openstack_cinder.sh
    ./openstack_loop.sh
    ./openstack_nova.sh
    ./openstack_horizon.sh

If the user is installing a compute node, the flow goes like this:

    ./openstack_networking.sh
    ./openstack_server_test.sh
    ./openstack_system_update.sh
    ./openstack_setup.sh
    ./openstack_cinder.sh
    ./openstack_loop.sh
    ./openstack_nova_compute.sh

