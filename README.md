# Secure boot module signer.

## Features

Making VMware player work while having Secure Boot enabled can be a bit of a hassle, because the kernel modules require to be manually signed each time the kernel (or VMware Player) is updated. This script automates the signing and loading of the VMware modules when secure boot is enabled.
It installs the necessary dependencies and then copies the sign-vmware-modules script to /etc/kernel/header\_postinst.d.
The scripts inside that folder are ran every time a kernel header is installed.

More on our blog at:

- https://blog.kulkan.com/secure-boot-and-vmware-automating-kernel-module-signing-cbf01b0f62fe

![secureboot-signer](screencapture1.png?raw=true "secureboot-signer")

## Supported Software 

- VMware Workstation/Player.


## Installation

```
chmod +x ./install.sh
sudo ./install.sh
```

The installation should run automatically. If everything went well, you don't need to restart to run VMware. 

The following steps are only required if new keys are generated manually (in that case you'll be asked for a password, write it down): 

1) At boot, you'll get a blue screen that says "Enroll MOK". Then select "continue". 
2) You'll be asked for a password, it is the one that you input previously. Hit enter, then select "Reboot".

## How to update this script (if it was previously installed)

1) Download sign-vmware-modules from this repo
2) Run the following commands:

```
sudo mv sign-vmware-modules /etc/kernel/header_postinst.d/
sudo chmod +x /etc/kernel/header_postinst.d/sign-vmware-modules
```

## Additional notes

When upgrading VMware Workstation Player, the installation may finish correctly but if you check the logs, you'll see that the drivers couldn't be loaded.
In which case, just run `/etc/kernel/header_postinst.d/sign-vmware-modules` once.
