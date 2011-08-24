#!/bin/sh
###############################################################################
# This script is used to start an encrypted EBS-backed system for Amazon EC2. #
# It uses the EC2 API, and calls make_encrypted_ubuntu.sh to create a system. #
#                                                                             #
# This was tested with ami-3e02f257 (32-bit EBS us-east-1 - Ubuntu 10.04 LTS) #
# See https://help.ubuntu.com/community/UEC/Images for info on Ubuntu images. #
# Latest Lucid Lynx: http://uec-images.ubuntu.com/releases/lucid/release/     #
#                                                                             #
###############################################################################
#                                                                             #
# Copyright (c) 2011 Henrik Gulbrandsen <henrik@gulbra.net>                   #
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

exitValue=1
set -e

### Options ###################################################################

options=""
sgroup=""
system=""

while [ "${1#-}" != "$1" ]; do
    case $1 in
        --big-boot) options="$options --big-boot"; shift;;
        --group) sgroup="$2"; shift 2;;
        --group=*) sgroup="${1#--system=}"; shift;;
        --system) system="$2"; shift 2;;
        --system=*) system="${1#--system=}"; shift;;
        -*) echo "Invalid option: $1"; exit 1;;
        *) break;;
    esac
done

### Basic checks ##############################################################

SUDO="$(which sudo)"
domain=$1

if [ -z "$domain" ]; then
    echo "Usage: ${0##*/} [<options>] <domain>"
    echo " --big-boot   : full system on /dev/sda1, not just /boot"
    echo " --group <g>  : Security group for the started instance"
    echo " --system <s> : e.g. \"lucid-20101228\" or \"maverick/i386\""
    echo "   domain     : DNS domain for decryption password entry"
    exit 1
fi

if [ ! -e "$(dirname $0)/make_encrypted_ubuntu.sh" ]; then
    echo "Missing file: make_encrypted_ubuntu.sh - system creation script"
    exit 1
fi

$SUDO "$(dirname $0)/make_encrypted_ubuntu.sh" --validate

### Initialization ############################################################

dots() { perl -e 'print $ARGV[0], "."x(40-length($ARGV[0])), "... "' "$*"; }
print_separator() {
    printf "%s" "----------------------------------------"
    echo "---------------------------------------"
}

# Prepare things for EC2 operations
export EC2_API_VERSION="2010-11-15"
ORIGINAL_AWSAPI_FILE_DIR="$AWSAPI_FILE_DIR"
METADATA=http://169.254.169.254/latest/meta-data
PATH="$(dirname $0):$PATH"

# Describe the instance we're running on
workInstance=$(curl -s "$METADATA/instance-id")
$(awsapi ec2.DescribeInstances InstanceId.1=$workInstance \
    reservationSet.1.{ \
        group:groupSet.1.groupId, \
        instancesSet.1.{ \
            key:keyName, type:instanceType, \
            zone:placement.availabilityZone, \
            arch:architecture \
        } \
    } \
)

# Select a kernel suitable for this architecture and region
case $arch in
    i386)
        case $zone in
            us-east-1?) kernelId="aki-4c7d9525";;
            eu-west-1?) kernelId="aki-47eec433";;
            ap-southeast-1?) kernelId="aki-6fd5aa3d";;
            us-west-1?) kernelId="aki-9da0f1d8";;
            *) echo "Unknown zone: $zone"; exit 1;
        esac;;
    x86_64)
        case $zone in
            us-east-1?) kernelId="aki-4e7d9527";;
            eu-west-1?) kernelId="aki-41eec435";;
            ap-southeast-1?) kernelId="aki-6dd5aa3f";;
            us-west-1?) kernelId="aki-9fa0f1da";;
            *) echo "Unknown zone: $zone"; exit 1;
        esac;;
    *) echo "Unknown arch: $arch"; exit 1;
esac

### Cleanup Code ##############################################################

# Just in case...
unset imageId
unset instanceId
unset snapshotId
unset volumeId

cleanup() {
    echo; print_separator;
    printf "Cleaning for start_encrypted_instance\n\n"

    # Terminate the instance
    if [ -n "$instanceId" ]; then
        dots "Terminating instance $instanceId"
        $(awsapi ec2.TerminateInstances InstanceId.1=$instanceId)
        $(awsapi ec2.DescribeInstances InstanceId.1=$instanceId \
            reservationSet.1.instancesSet.1.instanceState.name \
                := shutting-down/terminated)
        echo "done"; unset instanceId
    fi

    # Deregister the image
    if [ -n "$imageId" ]; then
        dots "Deregistering image $imageId"
        $(awsapi ec2.DeregisterImage ImageId=$imageId return := true)
        echo "done"; unset imageId
    fi

    # Delete the snapshot
    if [ -n "$snapshotId" ]; then
        dots "Deleting snapshot $snapshotId"
        $(awsapi ec2.DeleteSnapshot SnapshotId=$snapshotId return := true)
        echo "done"; unset snapshotId
    fi

    if [ -n "$volumeId" ]; then

        $(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId volumeSet.1.status)

        # Detach the volume
        if [ "$status" = "in-use" ]; then
            dots "Detaching volume $volumeId"
            $(awsapi ec2.DetachVolume VolumeId=$volumeId)
            $(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId \
                volumeSet.1.status := in-use/available)
            echo "done"
        fi

        # Delete the volume
        dots "Deleting volume $volumeId"
        $(awsapi ec2.DeleteVolume VolumeId=$volumeId return := true)
        echo "done"; unset volumeId
    fi

    # We must handle this, since we're overriding the awsapi cleanup
    if [ "$AWSAPI_FILE_DIR" != "$ORIGINAL_AWSAPI_FILE_DIR" ]; then
        rm -rf "$AWSAPI_FILE_DIR"
    fi

    echo; exit $exitValue
}

trap cleanup INT EXIT

### Prepare an empty volume ###################################################

attach_volume() {
    local second

    # Attempt to attach the volume
    $(awsapi ec2.AttachVolume VolumeId=$volumeId \
        InstanceId=$workInstance Device=$dev)
    $(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId \
        volumeSet.1.status := available/in-use)

    # Print the device name
    printf "$dev"

    # Give it ten seconds to show up
    for second in 0 1 2 3 4 5 6 7 8 9; do
        if [ -e $dev ]; then return 0; fi
        sleep 1
    done

    # If it wasn't attached: detach to clean up
    if [ ! -e $dev ]; then
        $(awsapi ec2.DetachVolume VolumeId=$volumeId)
        $(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId \
            volumeSet.1.status := in-use/available)
        while [ -n "$dev" ]; do dev="${dev%?}"; printf "\010"; done
        return 1
    fi

    return 0
}

# Create an empty volume and wait for it to become available
dots "Creating volume in $zone"
$(awsapi ec2.CreateVolume AvailabilityZone=$zone Size=8 volumeId)
$(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId \
    volumeSet.1.status := creating/available)
    echo "$volumeId"

# Find a suitable device and attach the volume
dots "Selecting device node"
for x in f g h i j k l m n o p; do
    dev=${device:-/dev/sd$x};
    if [ ! -e $dev ] && attach_volume; then
        echo; break;
    fi;
    if [ $x = p ]; then
        echo "No device available"
        exit 1
    fi
done

# A blank line before the next step
echo

### Create the encrypted filesystem ###########################################

# Put an encrypted filesystem on the volume
args="--trust-me$options $dev $domain $system"
$SUDO "$(dirname $0)/make_encrypted_ubuntu.sh" $args
print_separator;

# Detach the volume
dots "Detaching volume from instance"
$(awsapi ec2.DetachVolume VolumeId=$volumeId)
$(awsapi ec2.DescribeVolumes VolumeId.1=$volumeId \
    volumeSet.1.status := in-use/available)
    echo "done"

# Create a snapshot from the volume
dots "Creating snapshot"
text=$(date "+Linux_%F_%H.%M.%S")
$(awsapi ec2.CreateSnapshot VolumeId=$volumeId Description="$text" snapshotId)
echo "$snapshotId"; progress="0%"; unset oldProgress

# Wait for snapshot completion
dots "Waiting for snapshot"
while true; do

    # Print the progress
    printf "%s" "${progress}"
    if [ "$progress" = "100%" ]; then
        break
    fi

    # Wait before checking the progress
    sleep 10; oldProgress="$progress"
    $(awsapi ec2.DescribeSnapshots SnapshotId.1=$snapshotId \
        snapshotSet.1.progress or "0%")

    # Erase any old progress
    while [ -n "$oldProgress" ]; do
        oldProgress="${oldProgress%?}";
        printf "\010";
    done

done

# This should be completed, but let's make sure...
$(awsapi ec2.DescribeSnapshots SnapshotId.1=$snapshotId \
    snapshotSet.1.status := pending/completed)

echo

# Delete the volume; we will work with the snapshot from now on
dots "Deleting volume"
$(awsapi ec2.DeleteVolume VolumeId=$volumeId return := true)
echo "done"; unset volumeId

### Launch the instance #######################################################

# Register the image
dots "Registering image"
$(awsapi ec2.RegisterImage \
    BlockDeviceMapping.1.{ DeviceName=/dev/sda, Ebs.SnapshotId=$snapshotId } \
    Name="$text" KernelId=$kernelId RootDeviceName=/dev/sda1 \
    Architecture=$arch imageId)
    echo "$imageId"

# Wait for the image to become available
$(awsapi ec2.DescribeImages \
    Filter.1.{ Name="image-id", Value.1="$imageId" } \
    imagesSet.1.imageState := -/available)

# Launch a new instance
dots "Launching instance"
$(awsapi ec2.RunInstances ImageId=$imageId MinCount=1 MaxCount=1 \
    SecurityGroup.1="${sgroup:-$group}" KeyName="$key" InstanceType="$type" \
    Placement.AvailabilityZone="$zone" instancesSet.1.instanceId)

# Wait for the instance to boot
$(awsapi ec2.DescribeInstances \
    Filter.1.{ Name="instance-id", Value.1="$instanceId" } \
    reservationSet.1.instancesSet.1.instanceState.name \
        := -/pending/running)

echo "$instanceId"

# Deregister the image
dots "Deregistering image"
$(awsapi ec2.DeregisterImage ImageId=$imageId return := true)
echo "done"; unset imageId

# Delete the snapshot
dots "Deleting snapshot"
$(awsapi ec2.DeleteSnapshot SnapshotId=$snapshotId return := true)
echo "done"; unset snapshotId

## Configure the instance #####################################################

# Set a name tag
$(awsapi ec2.CreateTags ResourceId.1=$instanceId \
    Tag.1.{ Key=Name, Value="$text" })

# Try to get an IP address for the domain
ipAddress=$(dig +short $domain | tail -1)

# If it worked:
if [ -n "$ipAddress" ]; then
    dots "Setting IP address ($ipAddress)"

    # Check what the initial address is
    $(awsapi --table ec2.DescribeInstances InstanceId.1=$instanceId \
        oldIpAddress:reservationSet.1.instancesSet.1.ipAddress)

    # Associate the new address
    $(awsapi ec2.AssociateAddress PublicIp=$ipAddress InstanceId=$instanceId)

    # Wait for the new address to replace the old one
    $(awsapi ec2.DescribeInstances InstanceId.1=$instanceId \
        reservationSet.1.instancesSet.1.ipAddress \
            := $oldIpAddress/$ipAddress)

    echo "done"
fi

### Display the result ########################################################

echo; print_separator;
echo "This is your new instance:"
echo

# Grab the "Name" tags for all "instance" resources
$(awsapi ec2.DescribeTags tag@resourceId+tagSet.n.{ \
    resourceId, resourceType eq instance, key eq Name, name:value \
})

# Describe the instance as a table, just to show off
$(awsapi --table ec2.DescribeInstances InstanceId.1=$instanceId \
    instance+reservationSet.1.instancesSet.1.{ \
        instanceId, state:instanceState.name, \
        zone:placement.availabilityZone, \
        ~tag.name@instanceId, ipAddress \
    } | sed 's/\\/\\\\/')


# This is a good idea
echo "Unlock at https://$domain/ before logging in."

# Don't terminate the instance
unset instanceId

exitValue=0

###############################################################################
