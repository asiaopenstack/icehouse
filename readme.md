## Installing OpenStack Grizzly on Ubuntu 12.04.4 LTS
OpenStack is an Infrastructure as a Service (IaaS) cloud computing project released under the terms of the Apache License.  Infrastructure is meant to be open, trustworthy and secure. The best way to ensure these goals is to use Open Source software exclusively at the infrastruture level.

OpenStack's technology stack consists of a series of interrelated projects which can control pools of processing, storage, and networking resources.  These resources can be managed through a simple web based dashboard and accessed via APIs by other projects which empower their users to provision resources in a secure way.

This guide is now dedicated to helping individuals deploy OpenStack for use with the [xov.io](https://github.com/stackmonkey/xovio-pool) project, which provides cryptocurrency backed payments via a centralized pool controller.  Support is only provided for **xov.io** participants.  If you are installing OpenStack without participating in a compute pool you will be required to donate a Bitcoin to **1PKyowDf4VTMDhju2tEmWK3Gw51LHJeov** before receiving support.

Anyone is welcome to use these scripts to install OpenStack for evaluation or production use.

### Getting Started
StackGeek provides [these scripts](https://github.com/StackGeek/openstackgeek) and this guide to enable you to get a working installation of OpenStack Grizzly going in about 10 minutes. Before you start your OpenStack setup, please read the following requirements carefully:

#### Requirements
1. You need a **minimum** of one rig with at least 8GB of RAM, 4 cores, (1) SSD drive, and one ethernet card, preferably configured as **eth0**.
2. You need a clean [install of Ubuntu 12.04.2 LTS](http://www.ubuntu.com/download/desktop) 64-bit Linux on your box.  This guide will NOT work with other versions of Ubuntu, but it can be installed on the server version if you prefer.
3. You'll need a router which supports IPv6. Ideally, your router is also configured for a small group of staticallly 
3. Optionally, you **should** be an existing member of a xov.io pool organization.  If you aren't a member of a pool, you may join [StackMonkey's](http://stackmonkey.com/) pool for free.  *You will earn money by doing this.*
4. Optionally, you can install [Veo's sgminer](https://github.com/veox/sgminer) to mine alt currencies with your rig's GPUs without impacting performance. More money.
5. Optionally, fire up a [good music track](https://soundcloud.com/skeewiff/sets/skeewiff-greatest-wiffs) to listen to while you watch the bits scroll by.

***Note: Each OpenStack cluster needs a single controller which is in charge of managing the cluster.  The steps below are labeled to indicate they need to be run on the controller.  All other steps which are not labeled will need to be completed for each and every node in the cluster - including the controller.*** 

#### Video Guide
A video guide is forthcoming.  Hold tight.

#### Forum Discussion
There is a [forum based discussion area on Google Groups](https://groups.google.com/forum/#!category-topic/stackgeek/openstack/zVVS4DgiJnI) for posting technical questions regarding the guide.

#### IRC Channel
The IRC channel for the project is located in the [#stackgeek channel on Mibbit](http://client00.chat.mibbit.com/#stackmonkey&server=irc.mibbit.net).

#### Install Issues?
If you encounter problems with the installation, you may [open a ticket](https://github.com/StackGeek/openstackgeek/issues).  Please put your mining provider's name in the ticket so we can verify you are a member of a compute pool.  If you want support without being a pool member, you'll be required to pay 1 Bitcoin first.

### Installation
Assuming a fresh install of Ubuntu Desktop, you'll need to locally login to each rig and install the *openssh-server* to allow remote *ssh* access:

    sudo apt-get install openssh-server
    
You may not login remotely to your rig via *ssh* and install *git* with *aptitude*. After logging in, we'll become root and install *git*:

	sudo su
    apt-get install git

Checkout the StackGeek OpenStack setup scripts from Github:

    git clone git://github.com/StackGeek/openstackgeek.git
    cd openstackgeek/grizzly

#### Network Interfaces
This part of the networking setup is fairly straighforward.  You need to manually configure your ethernet interface to support a non-routable static IPv4 address and an autoconfigured IPv6 address.  To start, run the following script:

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
    
#### Setup, Test and Update
*Note: Be sure to take a look at the scripts before you run them.  Keep in mind the setup scripts will periodically prompt you for input, either for confirming installation of a package, or asking you for information for configuration.*

Start the installation by running the setup script:

    ./openstack_setup.sh
    
If you indicated the rig is a controller node, the result of the setup will be a **setuprc** file containing something like the following:

    export SG_MULTI_NODE=1
    export SG_SERVICE_EMAIL=kordless@example.com
    export SG_SERVICE_PASSWORD=f00bar
    export SG_SERVICE_TOKEN=83a412be8036d1e6e516598051cf6826
    export SG_SERVICE_REGION=nodeprime

After running setup, you'll be prompted to test for virtualization support:

    ./openstack_server_test.sh
    
If your rig doesn't support virtualization, you will need to upgrade your hardware.  If it does, you'll be prompted to update your Ubuntu install:

    ./openstack_system_update.sh
    
That last one takes a while, so just kick back and enjoy the music!


#### Database Setup (Controller Only)
The next part of the setup installs MySQL and RabbitMQ.  **This is only required for the controller rig. Skip this step if you are setting up a compute rig for your cluster.** Start the install on the controller rig by typing:

    ./openstack_mysql.sh
    
The install script will install Rabbit and MySQL.  During the MySQL install you will be prompted for a MySQL password used to for the root password for MySQL.  Write this password down, as you'll use toward the end of the script to allow for the creation of the databases and later to administer the database.

#### Cinder Setup
Cinder is used to provide additional volume attachments to running instances.  Start the install of Cinder by typing:

    ./openstack_cinder.sh
    
The xov.io software does not currently utilize Cinder, so you may skip this step if you don't need additional storage for your instances.

#### Glance Setup (Controller Only)
The Glance service provides operating system images used for booting instances.  The xov.io software provides methods for installing system recommended images for instance starts.  You'll add more images once you install the xov.io appliance.  Start the Glance install by typing:

    ./openstack_glance.sh
    
Once Glance is installed, you can get a list of images installed on the cluster:

    glance image-list
    
The output should look something like this:

    