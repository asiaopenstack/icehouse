### Building a CentOS Image for OpenStack in 10 Minutes

There are [several pre-built images for OpenStack](http://docs.openstack.org/image-guide/content/ch_obtaining_images.html), including Ubuntu, Red Hat and Fedora.  Images for CentOS and a few other Linux distros are not readily available, but they can be built from their respective installers using VirtualBox.

This guide provides a step-by-step method for building and deploying a CentOS image for OpenStack.

### Prerequisites for Building a CentOS Image
The scripts for assisting in the build can be checked out from [BlueChip's Github account](https://github.com/bluechiptek/):
    
    mkdir ~/bluechip; cd ~/bluechip
    git clone https://github.com/bluechiptek/openstackguides.git
    cd openstackguides/centos

*Note: While the scripts are not necessary to complete the build, the steps below assume the above directory structure exists.*

You'll also need to install VirtualBox on your computer before proceeding.

* Install VirtualBox 4.2.16 for [Windows](http://download.virtualbox.org/virtualbox/4.2.16/VirtualBox-4.2.16-86992-Win.exe) or [OSX](http://download.virtualbox.org/virtualbox/4.2.16/VirtualBox-4.2.16-86992-OSX.dmg) 

Double click the package to run through the installation on your local machine and then continue by watching the video guide.

### Video Guide
It is recommended you familiarize yourself with the build process by watching the screencast below before proceeding.

[![ScreenShot](https://raw.github.com/bluechiptek/openstackguides/master/centos/video.png)](http://vimeo.com/77826518)

### Installing CentOS on VirtualBox
The process for installing CentOS requires downloading the net install ISO, mounting it to a new VM in VirtualBox, and then running through the install using the graphical interface console in VirtualBox.

#### Option #1: Build the VM from the Scripts
Several bash scripts have been written to speed up the install process.  The manual instructions are located below for completeness.
    
Start the automated setup of a CentOS install in VirtualBox by doing the following:

    cd ~/bluechip/openstackguides/centos
    ./install_centos.sh

Proceed with the install by skipping over the 'Option #2' section and going straight into 'Start the Install' section below.

#### Option #2: Build the VM Manually from the Command Line
The following contains detailed commands for building a new VirtualBox instance and populating it with the CentOS 6.4 net installer.  If you want to install via another ISO or version, please refer to the [list of CentOS mirrors](http://www.centos.org/modules/tinycontent/index.php?id=30).

##### Download the Net Installer
Start by downloading the network based installer from the Stanford mirror:

    cd ~/bluechip/openstackguides/centos
    curl http://mirror.stanford.edu/yum/pub/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso > centos_netinstall.iso

##### Create the VM Using VBoxManage
VBoxManage is the command line interface for VirtualBox.  Start by creating the VM and its disk:

    VBoxManage createvm --name "BlueCentOS" --ostype "RedHat_64" --register
    VBoxManage createhd --filename ~/VirtualBox\ VMs/BlueCentOS/BlueCentOS.qcow --size 8192
    
*Note: This assumes VirtualBox is creating instances in the default 'VirtualBox VMs' directory in your home directory.*

Now create and attach the disk:

    VBoxManage storagectl "BlueCentOS" --name "SATA Controller" --add sata --controller IntelAHCI
    VBoxManage storageattach "BlueCentOS" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/BlueCentOS/BlueCentOS.qcow

Next, attach the install file as a DVD:
    
    VBoxManage storagectl BlueCentOS --name "IDE Controller" --add ide
    VBoxManage storageattach BlueCentOS --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium centos_netinstall.iso
    
Finally, add a few key settings, including port forwarding for ssh:

    VBoxManage modifyvm BlueCentOS --ioapic on
    VBoxManage modifyvm BlueCentOS --boot1 dvd --boot2 disk --boot3 none --boot4 none
    VBoxManage modifyvm BlueCentOS --memory 1024 --vram 128
    VBoxManage modifyvm BlueCentOS --natpf1 "ssh,tcp,,2222,,22"
    
#### Start the Install
To start the install, open VirtualBox and click on the 'BlueCentOS' instance and click on the start button at the top.  Proceed through the install using the following steps:

 * Select 'Install or upgrade an existing system' (hit enter).
 * Hit 'tab' to select 'Skip' and hit enter on the 'testing media' dialog.
 * Select 'English' for language and 'us' keyboard (hit enter twice).
 * Under the 'installation method' dialog, select 'URL' and hit enter.
 * Under TCP/IP configuration, hit 'tab' (7) times to select 'OK' and hit enter.
 * Wait for the network configuration to take place.

You'll be prompted for a URL to use for the install.  Here's a screenshot:

![ScreenShot](https://raw.github.com/bluechiptek/openstackguides/master/centos/url.png) 

Under the URL for the CentOS installation, enter the following (sorry, no cut/paste with the VirtualBox console):

    http://mirror.stanford.edu/centos/6/os/x86_64

Hit 'tab' twice and hit enter on 'OK'.

Finally, run through the following steps to configure the rest of the CentOS install.  CentOS will shift to a GUI install, so you can use your mouse.

 * Click the 'next' button on the welcome screen.
 * Click the 'next' button on the device selection screen.
 * Click 'discard any data' on the warning screen.
 * Click 'next' on the name this computer screen. This will be handled by cloud-init later.
 * Select your timezone and click 'next' to proceed to setting root's password.
 * Enter 'f00bar' for your root password.  Ignore the short password warning - we'll wipe it later.
 * Leave 'replace system' checked and click 'next' on install type screen.
 * Click 'write changes to disk' and then click 'next'.
 * Click 'next' on the 'select software to install' screen.
 
The install process should commence and complete in about 5 minutes.  When the button saying 'reboot' appears, close the VM's window and select 'power off' from the close options.

#### Remove the DVD and Start the Instance
To boot into the new system, the DVD drive needs to be unmounted.  Enter the following to unmount the drive:

    VBoxManage storageattach "BlueCentOS" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium none

The instance is now ready to boot for the first time.  

Go into VirtualBox and click on the new instance and click start at the top of the VirtualBox Manager window.

#### Install a Few Key Packages
The instance should be running and booted in a minute or so.  A forwarding rule has been built to allow you to ssh into the instance:

    ssh root@localhost -p 2222
    
Remember, your password for root is 'f00bar'.  Once you are logged in, install *git*:

    yum -y install git

*Note: This installs an older version of git.  Follow the instructions [here](https://gist.github.com/matthewriley/4694850) to update to a newer version of git.*

Checkout the *openstackguides* repository again:

    mkdir ~/bluechip; cd ~/bluechip
    git clone https://github.com/bluechiptek/openstackguides.git
    cd openstackguides/centos

Now run the *build_cloud.sh* script:

    ./build_cloud.sh

### Upload the Image to OpenStack
You will need to upload the disk image to your OpenStack cluster.  Start a simple web server by entering the following:

    cd ~/VirtualBox\ VMs/BlueCentOS/
    ./serve

Select the line with the *BlueCentOS.qcow* file in the URL and copy it into your paste buffer.  

To upload the image to OpenStack, do the following:

 * login to your OpenStack cluster with a user with admin privileges
 * click on the 'Admin' tab in the left pane
 * click on the 'Images' link on the left under 'System Panel'
 * click on the 'Create Image' button at the top right

Here's a screenshot of the modal that should pop up:

![ScreenShot](https://raw.github.com/bluechiptek/openstackguides/master/centos/upload.png)

Fill out the form:

 * enter 'CentOS 6.4' for the name of the image 
 * paste in the URL you copied earlier into the image location
 * select the *QCOW2* format
 * make the image public, if you like
 * click 'create image'
 
The image will take a little while to upload and add to the cluster as it's about 1.3GB in size.

Start up a new test instance to try out your CentOS image!









