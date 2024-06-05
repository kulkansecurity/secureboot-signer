#!/bin/bash

if (( $EUID != 0 ))
then
	echo "Please run with sudo"
	exit 1
fi

echo "Installing dependencies"
# not 100% sure if gcc-12 is a requirement to build vmware modules, but just in case
apt-get install -y build-essential linux-headers-$(uname -r) gcc gcc-12 make shim-signed

# If the directory doesn't exist, create it.
mkdir -p /etc/kernel/header_postinst.d

echo "Moving the script to /etc/kernel/header_postinst.d so it runs after every kernel header update"
cp ./sign-vmware-modules /etc/kernel/header_postinst.d/
chmod +x /etc/kernel/header_postinst.d/sign-vmware-modules

MANUALLY_SIGNED_KEYS=
generate_secureboot_signing_keys_manually()
{
    echo "Creating the private key for vmware module signing"
    mkdir /root/signing && cd /root/signing
    openssl req -new -x509 -newkey rsa:2048 -keyout VMware.priv -outform DER -out VMware.der -nodes -days 36500 -subj "/CN=VMware/"


    echo "Importing the public key to MOK. You will be asked for a password. You'll need it after reboot"
    mokutil --import VMWare.der
    MANUALLY_SIGNED_KEYS=true    
}

###################
# Some parts of the following code were borrowed from the VirtualBox base platform packages 
# (VirtualBox 7, ref: https://www.virtualbox.org/browser/vbox/trunk/src/VBox/Installer/linux/vboxdrv.sh)

# Copyright (C) 2006-2023 Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, in version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses>.
#
# SPDX-License-Identifier: GPL-3.0-only)

# Ubuntu / Debian 10 and later public key pair.
DEB_PUB_KEY=/var/lib/shim-signed/mok/MOK.der
DEB_PRIV_KEY=/var/lib/shim-signed/mok/MOK.priv

# Check if update-secureboot-policy tool supports required commandline options.
update_secureboot_policy_supports()
{
    opt_name="$1"
    [ -n "$opt_name" ] || return

    [ -z "$(update-secureboot-policy --help 2>&1 | grep "$opt_name")" ] && return
    echo "1"
}

HAVE_UPDATE_SECUREBOOT_POLICY_TOOL=
if type update-secureboot-policy >/dev/null 2>&1; then
    [ "$(update_secureboot_policy_supports new-key)" = "1" -a "$(update_secureboot_policy_supports enroll-key)" = "1" ] && \
        HAVE_UPDATE_SECUREBOOT_POLICY_TOOL=true
fi

# Generate new signing key if needed. 
[ -n "$HAVE_UPDATE_SECUREBOOT_POLICY_TOOL" ] && update-secureboot-policy --new-key

enroll_key(){
     # Enroll signing key if needed.
    if test -n "$HAVE_UPDATE_SECUREBOOT_POLICY_TOOL"; then
        # update-secureboot-policy "expects" DKMS modules. As a workaround, we create a temporary directory. 
        mkdir -p /var/lib/dkms/kulkan-temp
        update-secureboot-policy --enroll-key 2>/dev/null ||
                echo "Failed to enroll secure boot key."
        rmdir -p /var/lib/dkms/kulkan-temp 2>/dev/null

        # Indicate that key has been enrolled and reboot is needed.
        HAVE_DEB_KEY=true
    fi
}

if test ! -f "$DEB_PUB_KEY" || ! test -f "$DEB_PRIV_KEY"; then
    # update-secureboot-policy tool present in the system, but keys were not generated.
    [ -n "$HAVE_UPDATE_SECUREBOOT_POLICY_TOOL" ] && "$(generate_secureboot_signing_keys_manually)" || "$(enroll_key)"
fi

###################

if [ -n "$MANUALLY_SIGNED_KEYS" ]; then echo "Please reboot and enroll the key to the MOK"; exit 0; fi

echo "Finished initial setup. Starting module signing"

/etc/kernel/header_postinst.d/sign-vmware-modules "$(uname -r)"
