#!/bin/sh
###############################################################################
# This script is used to boot an EBS image from a minimal AMI in Amazon EC2.  #
# It should be installed as a replacement for /sbin/init on the boot AMI.     #
#                                                                             #
# More detailed instructions are found in a separate README.txt file.         #
#                                                                             #
# See this thread for some background information:                            #
#   http://developer.amazonwebservices.com/connect/thread.jspa?threadID=24091 #
#                                                                             #
###############################################################################
#                                                                             #
# Copyright (c) 2009, 2011 Henrik Gulbrandsen <henrik@gulbra.net>             #
#                                                                             #
# This software is provided 'as-is', without any express or implied warranty. #
# In no event will the authors be held liable for any damages arising from    #
# the use of this software.                                                   #
#                                                                             #
# Permission is granted to anyone to use this software for any purpose,       #
# including commercial applications, and to alter it and redistribute it      #
# freely, subject to the following restrictions:                              #
#                                                                             #
# 1. The origin of this software must not be misrepresented; you must not     #
#    claim that you wrote the original software. If you use this software     #
#    in a product, an acknowledgment in the product documentation would be    #
#    appreciated but is not required.                                         #
#                                                                             #
# 2. Altered source versions must be plainly marked as such, and must not be  #
#    misrepresented as being the original software.                           #
#                                                                             #
# 3. This notice may not be removed or altered from any source distribution,  #
#    except that more "Copyright (c)" lines may be added to already existing  #
#    "Copyright (c)" lines if you have modified the software and wish to make #
#    your changes available under the same license as the original software.  #
#                                                                             #
###############################################################################

### Important variables #######################################################

# num is 16 * drive_number + partition (sda is SCSI disk 0; sdf is disk 5)
dev="/dev/sda2"
num="2"

# This external script can be used to perform various extra tasks, such as
# automatically attaching EBS volumes or fetching passwords from the net.
pre_init="/etc/ec2/pre_init.sh"

# The passphrase for an encrypted volume is fetched from EC2 user-data, but if
# one-time passwords are used, it will no longer be valid after a warm reboot.
# This file can be used to carry the new passphrase across reboots. It will be
# deleted by shred(1) as soon as this script has read it, for what it's worth.
key_file="/var/ec2/key_file.txt"

# These make things easier
new_root="/vol" # Location of the EBS drive when mounted in the AMI drive
old_root="/mnt" # Location of the AMI drive when mounted in the EBS drive
cleanup=""      # Shell commands run after chroot; must end with a semicolon

### Help functions ############################################################

# Some state
networking=false

# Starts networking if necessary
start_net() {
    if ! $networking; then
        mkdir -p /var/run/network
        ifup -a
        networking=true
    fi
}

# Stops networking if necessary
stop_net() {
    if $networking; then
        ifdown -a
        networking=false;
    fi
}

# These may be implemented by the $pre_init script
fetch_password()  { return false; }
accept_password() { return false; }
reject_password() { return false; }

### Fix the bootstrap environment #############################################

# These are needed on some systems
PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
unset SHLVL

# Make writable just in case files are missing...
echo "Remounting writable."
mount -o remount,rw /
mkdir -p $new_root

# These are needed for decryption
modprobe dm-crypt
modprobe sha256

# Include the optional $pre_init script
if [ -e $pre_init ]; then
    . $pre_init
fi

### Waiting for the root device ###############################################

# The udevd is not started at this point (unless $pre_init started it)
if [ -e $dev ]; then
    echo "Found existing device node: $dev"
else
    echo "Creating device node: $dev"
    mknod -m 660 $dev b 8 $num
fi

# It may take a while for the root device to show up
while ! blockdev --getsize $dev > /dev/null 2>&1; do
    echo "Waiting for the root device."
    sleep 10
done

echo "Detected root device."
cryptCount=0

### Optional decryption #######################################################

# Handle encrypted file systems
while cryptsetup isLuks $dev; do

    echo "Encrypted disk; looking for the password."
    cryptCount=$((cryptCount+1))

    # Try this function from $pre_init first
    if [ -z "$password" ]; then
        fetch_password;
    fi

    # The password may have been saved during a warm reboot
    if [ -z "$password" ] && [ -e $key_file.txt ]; then
        password=$(cat $key_file)
        shred -zu $key_file
    fi

    # Otherwise, it should be given as user data...
    if [ -z "$password" ]; then
        data_url="http://169.254.169.254/2009-04-04/user-data"
        curl="curl --retry 3 --silent --show-error --fail"
        start_net; password=$($curl $data_url | head -1 | sed 's/.*Key: //')
    fi

    echo "Starting decryption."
    name="luks$cryptCount"

    # This should always work if the password is correct
    if ! printf "$password" | cryptsetup --key-file=- luksOpen $dev $name; then

        echo "Decryption failed."

        # First see if $pre_init can handle it
        if reject_password; then
            cryptCount=$((cryptCount-1))
            password=""
            continue
        fi

        # otherwise, just hang forever...
        while true; do
            sleep 60
        done;
    fi

    echo "Decryption worked."

    # Use the decrypted file system
    dev="/dev/mapper/$name"
    if [ ! -e $dev ]; then
        mknod -m 660 $dev b 253 $((cryptCount-1))
    fi
done

# Cleanup from $pre_init
accept_password;

### Pivot to the new root #####################################################

# Tear down the network if necessary
stop_net;

# This will hopefully work...
echo "Mounting $dev as new root."
mount -o ro $dev $new_root

# Pivot to the new root
cd $new_root; pivot_root . ${old_root#/}

# Move mounted file systems to the new root
for dir in /dev /proc /sys; do
    mount --move ${old_root}${dir} ${dir}
done

# Get rid of $old_root; it can be mounted from /dev/sda1 later
cleanup="${cleanup}umount ${old_root}; "

# Start the real init with redirects so the old /dev can be released
exec chroot . /bin/sh -c "${cleanup}exec /sbin/init $*" \
    < /dev/console > /dev/console 2>&1

###############################################################################

