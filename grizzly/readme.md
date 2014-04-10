## Installing OpenStack Grizzly on Ubuntu 12.04 LTS
Before beginning this guide, be sure you read the introduction README in the [directory above this one](https://github.com/stackgeek/openstackgeek/).  Information on the project, goals, support channels and other versions is available there.

#### Video Guide
The video for this guide is [located on Vimeo](https://vimeo.com/87528023).

[![OpenStack Video](https://raw.github.com/StackGeek/openstackgeek/master/grizzly/openstack_grizzly.png)](https://vimeo.com/87528023)

### Installation
Assuming a fresh install of Ubuntu Desktop, you'll need to locally login to each rig and install the *openssh-server* to allow remote *ssh* access:

    sudo apt-get install openssh-server
    
You may now login remotely to your rig via *ssh* and do an upgrade:
    
    echo '# STACKGEEK ADDED THIS' >> /etc/apt/sources.list
  	echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main' >> /etc/apt/sources.list
	apt-get install ubuntu-cloud-keyring -y
	apt-get update -y
	apt-get upgrade -y
	
The upgrade will take a while.  When it is done, install *git* with *aptitude*:

    sudo su
    apt-get -y install git

Checkout the StackGeek OpenStack setup scripts from Github:

    git clone git://github.com/StackGeek/openstackgeek.git
    cd openstackgeek/grizzly

#### Network Interfaces
You need to manually configure your ethernet interface to support a non-routable static IPv4 address and an auto configured IPv6 address.  Externally routed IPv4 addresses will be added in a later section. To start, run the following script:

    ./openstack_networking.sh
    
The script will output a short configuration block which should be placed manually in **/etc/network/interfaces**.  **Be sure to edit the IP adddress before you save the file!**  I suggest you use an ordered set of IPs like .100, .101, .102, etc. for your rigs.

    # loopback
    auto lo
    iface lo inet loopback

    # primary interface
    auto eth0
    iface eth0 inet static
      address 10.0.1.100
      netmask 255.255.255.0
      gateway 10.0.1.1
      dns-nameservers 8.8.8.8

    # ipv6 configuration
    iface eth0 inet6 auto

Reboot the rig after saving the file.

#### Test and Update
After editing the network, you'll need to test your rig for virtualization support:

    ./openstack_server_test.sh
    
If your rig doesn't support virtualization, you will need to check your virtualization settings in bios or upgrade your hardware.  If it does support virtualization, you'll be prompted to update your Ubuntu install:

    ./openstack_system_update.sh
    
The update should come back pretty quick as you've already updated the system. 

#### Setup
*Note: Be sure to take a look at the scripts before you run them.  Keep in mind the setup scripts will periodically prompt you for input, either for confirming installation of a package, or asking you for information for configuration.*

Start the installation by running the setup script:

    ./openstack_setup.sh
    
You will be asked whether or not this rig is to be configured as a controller.  If you answer yes, the result of the setup will be a **setuprc** file in the install directory.  The setup script will also output a URL which is used to copy the existing setup to a compute rig.  Here's an example URL:

    https://sgsprunge.appspot.com/I2DIkNZxJyPhhIJc

If you indicated the rig is not a controller node, you will be prompted for the URL spit out by the controller installation as mentioned above.  Paste this URL in and hit enter to start the compute rig install.

***Note: If you are installing a compute rig, you may skip to the Cinder Setup section below.***

#### Database Setup (Controller Only)
The next part of the setup installs MySQL and RabbitMQ.  **This is only required for the controller rig. Skip this step if you are setting up a compute rig for your cluster.** Start the install on the controller rig by typing:

    ./openstack_mysql.sh
    
The install script will install Rabbit and MySQL.  During the MySQL install you will be prompted for the MySQL password you entered earlier to set a password for the MySQL root user.  You'll be prompted again toward the end of the script when it creates the databases.

#### Keystone Setup (Controller Only)
Keystone is used by OpenStack to provide central authentication across all installed services.  Start the install of Keystone by typing the following:

    ./openstack_keystone.sh
    
When the install is done, test Keystone by setting the environment variables using the newly created **stackrc** file.  ***Note: This file can be sourced any time you need to manage the OpenStack cluster from the command line.***

    . ./stackrc
    keystone user-list
    
Keystone should output the current user list to the console:

    +----------------------------------+---------+---------+--------------------+
    |                id                |   name  | enabled |       email        |
    +----------------------------------+---------+---------+--------------------+
    | 5474c43e65c840b5b371d695af72cba4 |  admin  |   True  | xxxxxxxx@gmail.com |
    | dec9e0adf6af4066810b922035f24edf |  cinder |   True  | xxxxxxxx@gmail.com |
    | 936e0e930553423b957d1983d0a29a62 |   demo  |   True  | xxxxxxxx@gmail.com |
    | 665bc14a5da44e86bd5856c6a22866fb |  glance |   True  | xxxxxxxx@gmail.com |
    | bf435eb480f643058e27520ee3737685 |   nova  |   True  | xxxxxxxx@gmail.com |
    | 7fa480363a364d539278613aa7e32875 | quantum |   True  | xxxxxxxx@gmail.com |
    +----------------------------------+---------+---------+--------------------+

#### Glance Setup (Controller Only)
Glance provides image services for OpenStack.  Images are comprised of prebuilt operating system images built to run on OpenStack.  There is a [list of available images](http://docs.openstack.org/image-guide/content/ch_obtaining_images.html) on the OpenStack site.

Start the Glance install by typing:

    ./openstack_glance.sh
    
Once the Glance install completes, you should be able to query the system for the available images:

    glance image-list

The output should be something like this:

    +--------------------------------------+------------------+-------------+------------------+-----------+--------+
    | ID                                   | Name             | Disk Format | Container Format | Size      | Status |
    +--------------------------------------+------------------+-------------+------------------+-----------+--------+
    | df53bace-b5a0-49ba-9b7f-4d43f249e3f3 | Cirros 0.3.0     | qcow2       | bare             | 9761280   | active |
    +--------------------------------------+------------------+-------------+------------------+-----------+--------+

#### Cinder Setup
Cinder is used to provide additional volume attachments to running instances and snapshot space.  Start the install of Cinder by typing:

    ./openstack_cinder.sh
    
Once the install of Cinder is complete, determine your space requirements and run the loopback volume creation script:

    ./openstack_loop.sh

Keep in mind you have to create a loopback file that is at least 1GB in size.  After you complete the Nova setup for the controller below, you should be able to query installed storage types:

    cinder type-list
    
You may then create a new volume to test (again, this requires running the Nova setup for the controller below):

    cinder create --volume-type Storage --display-name test 1

***Note: If you are installing a compute rig, you may skip to the *Nova Compute Setup* section below.***

#### Nova Setup (Controller Only)
Nova provides multiple services to OpenStack for controlling networking, imaging and starting and stopping instances.  If you are installing a compute rig, please skip to the following section to install the base *nova-compute* methods needed for running a compute rig.

Start the controller's nova install by typing the following:

    ./openstack_nova.sh
    
When the install is complete, you may query the running services by doing the following:

    nova service-list
    
You should see output that looks similar to this:
    
    +------------------+--------+----------+---------+-------+----------------------------+
    | Binary           | Host   | Zone     | Status  | State | Updated_at                 |
    +------------------+--------+----------+---------+-------+----------------------------+
    | nova-cert        | tester | internal | enabled | up    | 2014-02-20T10:37:25.000000 |
    | nova-conductor   | tester | internal | enabled | up    | 2014-02-20T10:37:17.000000 |
    | nova-consoleauth | tester | internal | enabled | up    | 2014-02-20T10:37:25.000000 |
    | nova-network     | tester | internal | enabled | up    | 2014-02-20T10:37:25.000000 |
    | nova-scheduler   | tester | internal | enabled | up    | 2014-02-20T10:37:24.000000 |
    +------------------+--------+----------+---------+-------+----------------------------+

#### Nova Compute Setup (Compute Rigs Only)
If you are installing a controller, this step has already been completed using the **Nova Setup** section above.  You may skip this if you are installing a controller rig.

You may run this on any number of compute rigs.  Start the Nova Compute setup on a given compute rig by typing the following:

    ./openstack_nova_compute.sh
    
Once the compute rig has been configured, you may log back into the **controller rig** and run the nova service list command again:

    nova service-list
    
You should see new entries for the newly added compute rig:

    EXAMPLE HERE


#### Flat Networking Setup (Controller Only)
This guide completely ignores the disaster ridden [Neutron/Quantum project](https://wiki.openstack.org/wiki/Neutron).  If you are interested in Neutron, this is not the place to seek help.

Begin by creating an IPv4 private network range which blocks out the **10.0.47.0** network:

    nova-manage network create private --fixed_range_v4=10.0.47.0/24 --num_networks=1 --bridge=br100 --bridge_interface=eth0 --network_size=255

You'll need to add a route in your router to point to the new network managed by the controller (pseudo command here):

    route add 10.0.47.0 255.255.255.0 gw 10.0.1.200

Now enter a set of publicly available IPv4 based addresses:

    nova-mange floating create 208.128.7.128/25
    
This example would allow a floating IP address to be assigned to instance from the range of **208.128.7.129 to 208.128.7.254**.

You can view the private network by querying nova:

    nova network-list

Output should look like this:

    +--------------------------------------+---------+---------------+
    | ID                                   | Label   | CIDR          |
    +--------------------------------------+---------+---------------+
    | 22aca431-14b3-43e0-a762-b02914770e6d | private | 10.0.1.224/28 |
    +--------------------------------------+---------+---------------+

View the available floating pool addresses by querying nova again:

    nova floating-ip-bulk-list
    
Output should look like this (truncated for space):

    +------------+---------------+---------------+------+-----------+
    | project_id | address       | instance_uuid | pool | interface |
    +------------+---------------+---------------+------+-----------+
    | None       | 208.128.7.129 | None          | nova | 10.0.2.15 |
    | None       | 208.128.7.130 | None          | nova | 10.0.2.15 |
    +------------+---------------+---------------+------+-----------+

There will be additional guides posted on best practices for IPv6 allocation and IPv4 mapping and isolation.  Hold tight.

#### Horizon Setup (Controller Only)
Horizon provides OpenStack's managment interface.  Install Horizon by typing:

    ./openstack_horizon.sh
    
Now reboot the controller rig:

    reboot
    
Once the rig comes back up, you should be able to log into your OpenStack cluster with the following URL format (changing the IP of course):

    http://10.0.1.100/horizon

Your user/pass combination will be *'admin'* and whatever you entered for a password earlier.  If you accidentally run this command before adding the network above, you may see errors in the UI.    

***Note: If you log into the dashboard and get errors regarding quotas, log out of the UI by clicking on 'sign out' at the top right and then reboot the rig.  The errors should go away when you log back in.***

#### Install the StackMonkey Virtual Appliance
StackMonkey is a pool instance of the xov.io highly distributed cloud framework.  If you elect to install the appliance, this OpenStack node will provide a small portion of its compute power to help build a highly distributed cloud.  You will earn Bitcoin doing this.

The virtual appliance setup can be run by typing the following command:

    ./openstack_stackmonkey_va.sh

More information about the project can be viewed on the [StackMonkey pool's site](https://www.stackmonkey.com).
#### OpenStack Cheat Sheet
An OpenStack Command Line Cheat Sheet is available on [Anystacker's site](http://anystacker.com/2014/02/openstack-command-line-cheat-sheet/).  Commands can be run once the **setuprc** file has been sourced:

    . ./setuprc

#### Delete the Paste File
The URL created for a multi-rig install is stored on an AppEngine application based on [Rupa's sprunge project](http://github.com/rupa/sprunge).  You should delete the paste after you are done with your setup for security's sake:

    curl -X DELETE https://sgsprunge.appspot.com/I2DIkNZxJyPhhIJc

If you have any questions, issues or concerns, please feel free to join IRC, post on the forum, or create a ticket!