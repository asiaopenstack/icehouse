## Installing OpenStack Grizzly on Ubuntu 12.04 LTS
Infrastructure is meant to be [open, trustworthy and secure](http://www.stackgeek.com/blog/kordless/post/a-code-of-trust). The best way to ensure these goals is to use Open Source software and [hardware](http://en.wikipedia.org/wiki/Open_Compute_Project) exclusively at the infrastruture level.  As such, this guides and the software it references are released under the MIT and Apache Open Source licenses.

OpenStack's technology stack consists of a series of interrelated projects which controls a given deployment of hardware providing processing, storage, and networking.  Deployments are managed using a simple UI and a flexible API which can be used by third party software.

This guide is dedicated to helping individuals deploy OpenStack for use with the [xov.io](https://github.com/stackmonkey/xovio-pool) decentralized cloud project.  Xov.io impliments highly a highly distributed cloud backed by a simple cryptocurrency payment system.  Partcipitation in a xov.io enabled compute pool provides resource and revenue sharing among participants.

Anyone is welcome to use these scripts to install OpenStack for evaluation or production use.

### A Brief Rant on the OpenStack Scene
OpenStack was released as [Open Source software by Rackspace](http://en.wikipedia.org/wiki/OpenStack#History).  While portions of the project carried an Open Source license from the beginning, [Rackspace](http2://rackspace.com/) is ultimately credited for the release of OpenStack's codebase by way of the aquisition of Anso Labs.  Anso Labs was contracted by NASA to build an early version of OpenStack called Nova, but they (NASA) had little to nothing to do with the decision to put an open license on the codebase.  Any claims to the contrary are simply rationalizations which detract from Anso Lab's and Rackspace's contributions to the efforts to create open and trustworthy infrastructure.

The [OpenStack project](http://openstack.org/) is managed by the [OpenStack Foundation](http://openstack.org/foundation/).  The foundation is controlled by a governance board which is comprised of individuals who work for very large corporations with very large corporate interests, including Rackspace.  The effect on the OpenStack ecosystem has been mixed.  In this author's opinion, corporate interests have been detrimental to the innovative process inside OpenStack's ecosystem.

At the very least, this effect has caused the OpenStack scene to lose marketing traction.  Evidence of that fact is seen in the complete lack of a decent install methodologies and infighting between foundation members on [stupid matters including EC2 API support](http://www.cloudscaling.com/blog/cloud-computing/openstack-aws/).  This project aims to fix that.

Corporations who create infrastructure components and the sotware they run, including compute, storage and networking gear, and who do so using combinations that include closed source code, are a direct threat by way of centralized pools of control.  There are complex reasons why this is a **'very bad thing'** for the ecosystem and I encourage you to do independent research around this concept to form your own opinions on the topic.  You should start by researching [cryptocurrency technologies](http://en.wikipedia.org/wiki/Cryptocurrency).  BTW, there is a distiction between pools of power and pools of knowledge.  The latter is acceptable by way of proof of work concepts.

Again, infrastructure is meant to be open, trustworthy and secure.  We will not relent on this topic.  Humanitiy's future lies in the balance.

### Getting Started
StackGeek provides [these scripts](https://github.com/StackGeek/openstackgeek) and this guide to enable you to get a working installation of OpenStack Grizzly going in about 10 minutes. This author is the source of the **'10 Minute OpenStack Install'** craze and is also responsible for coining the term **'cloud'** back in 1999 while working on the [Grub project]().  Sorry about that.

Before you start your OpenStack setup, please read the following requirements carefully:

#### Requirements
1. You need a **minimum** of one rig with at least 8GB of RAM, 4 cores, (1) SSD drive, and one ethernet card.
2. You need a clean [install of Ubuntu 12.04 LTS](http://www.ubuntu.com/download/desktop) 64-bit Linux on your box.  You can also install this on the server version of 12.04.x.
3. You'll need a router which supports IPv6. Ideally, your router is also configured for a small group of publicly routable IPv4 addresses.
3. Optionally, you should have an account on a xov.io pool. If you aren't a member of a pool, you may join [StackMonkey's](http://stackmonkey.com/) pool for free. *Please note, the pool software is not complete at this time.*
4. Optionally, you can install [Veo's sgminer](https://github.com/veox/sgminer) to mine alt currencies with your rig's GPUs without impacting instance performance.
5. Optionally, fire up a [good music track](https://soundcloud.com/skeewiff/sets/skeewiff-greatest-wiffs) to listen to while you watch the bytes scroll by.

***Note: Each OpenStack cluster needs a single controller which is in charge of managing the cluster.  Certain steps below are labeled to indicate they need to be run only on the controller.  All other steps which are not labeled will need to be completed for each and every node in the cluster - including the controller.*** 

#### Video Guide
A video guide is forthcoming.  Hold tight.

#### Forum Discussion
There is a [forum based discussion area on Google Groups](https://groups.google.com/forum/#!category-topic/stackgeek/openstack/zVVS4DgiJnI) for posting technical questions regarding the guide.

Support is only provided for **xov.io** participants.  If you are installing OpenStack without participating in a compute pool you will be required to donate a Bitcoin to **1PKyowDf4VTMDhju2tEmWK3Gw51LHJeov** before receiving support.

#### IRC Channel
The IRC channel for the project is located in the [#stackgeek channel on Mibbit](http://client00.chat.mibbit.com/#stackmonkey&server=irc.mibbit.net).

Support is only provided for **xov.io** participants.

#### Install Bugs?
If you encounter bug with the installation code, you may [open a ticket](https://github.com/StackGeek/openstackgeek/issues).

### Installation
Assuming a fresh install of Ubuntu Desktop, you'll need to locally login to each rig and install the *openssh-server* to allow remote *ssh* access:

    sudo apt-get install openssh-server
    
You may now login remotely to your rig via *ssh* and install *git* with *aptitude*:

    sudo su
    apt-get -y install git

Checkout the StackGeek OpenStack setup scripts from Github:

    git clone git://github.com/StackGeek/openstackgeek.git
    cd openstackgeek/grizzly

#### Network Interfaces
You need to manually configure your ethernet interface to support a non-routable static IPv4 address and an autoconfigured IPv6 address.  Externally routed IPv4 addresses will be added in a later section. To start, run the following script:

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

#### Test and Update
After editing the network, you'll need to test your rig for virtualization support:

    ./openstack_server_test.sh
    
If your rig doesn't support virtualization, you will need to check your virtualization settings in bios or upgrade your hardware.  If it does support virtualization, you'll be prompted to update your Ubuntu install:

    ./openstack_system_update.sh
    
The update takes a while, so just kick back and enjoy the music!

#### Setup
*Note: Be sure to take a look at the scripts before you run them.  Keep in mind the setup scripts will periodically prompt you for input, either for confirming installation of a package, or asking you for information for configuration.*

Start the installation by running the setup script:

    ./openstack_setup.sh
    
You will be asked whether or not this rig is to be configured as a controller.  If you answer yes, the result of the setup will be a **setuprc** file in the install directory.  The setup script will also output a URL which is used to copy the existing setup to a compute rig.  Here's an example URL:

    https://sgsprunge.appspot.com/I2DIkNZxJyPhhIJc

If you indicated the rig is not a controller node, you will be prompted for the URL spit out by the controller installation as mentioned above.  Paste this URL in and hit enter to start the compute rig install.

***Note: If you are installing a compute rig, you may skip to the *Cinder Setup* section below.***

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
The Glance service provides operating system images used for booting instances.  The xov.io software provides methods for installing system recommended images for instance starts.  You'll add more images once you install the xov.io appliance.  Start the Glance install by typing:

    ./openstack_glance.sh
    
Once Glance is installed, you can get a list of images installed on the cluster:

    glance image-list
    
The output should look something like this:

#### Cinder Setup
Cinder is used to provide additional volume attachments to running instances and snapshot space.  Start the install of Cinder by typing:

    ./openstack_cinder.sh
    
Once the install of Cinder is complete, determine your space requirements and run the loopback volume creation script:

    ./openstack_loop.sh

Keep in mind you have to create a loopback file that is at least 1GB in size.  You should be able to query a storage type now:

    cinder type-list
    
You may then create a new volume to test:

    cinder create --volume-type Storage --display-name test 1

***Note: If you are installing a compute rig, you may skip to the *Nova Compute Setup* section below.***

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
    | 29ac82cc-f3ac-4530-922d-672dfa743bc0 | Ubuntu 12.04 LTS | qcow2       | ovf              | 226426880 | active |
    +--------------------------------------+------------------+-------------+------------------+-----------+--------+

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
    
#### Flat Networking Setup
This guide completely ignores the disaster ridden [Neutron/Quantum project](https://wiki.openstack.org/wiki/Neutron).  If you are interested in Neutron, this is not the place to seek help.

Begin by creating an IPv4 private network range which blocks out the **10.0.47.0** network:

    nova-manage network create private --fixed_range_v4=10.0.47.0/24 --num_networks=1 --bridge=br100 --bridge_interface=eth0 --network_size=255

You'll need to add a route in your router to point to the new network managed by the controller (psuedo command here):

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

#### OpenStack Cheat Sheet
An OpenStack Command Line Cheat Sheet is available on [Anystacker's site](http://anystacker.com/2014/02/openstack-command-line-cheat-sheet/).  Commands can be run once the **setuprc** file has been sourced:

    . ./setuprc

#### Delete the Paste File
The URL created for a multi-rig install is stored on an AppEngine application based on [Rupa's sprunge project](http://github.com/rupa/sprunge).  You should delete the paste after you are done with your setup for security's sake:

    curl -X DELETE https://sgsprunge.appspot.com/I2DIkNZxJyPhhIJc

If you have any questions, issues or concerns, please feel free to join IRC, post on the forum, or create a ticket!