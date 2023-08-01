#!/bin/bash
# This script finds all mounted USB devices, then
# - unmount and ejects it 
# - make two short-beeps
# - wait 60 seconds
# - reconnect USB device (if it still connected)
# - make one short-beeps

# checked on DSM 6.x



[[ $(id -u) -ne 0 ]] && echo "Must be run as root! Aborted." &&  exit 1

usblist=""

# We need to get this: "sdq\nsdr\n" from "mount" output:
# /dev/sdq1 on /volumeUSB1/usbshare1-1 type vfat (rw,relatime,uid=1024,gid=100,fmask=0000,dmask=0000,allow_utime=0022,codepage=default,iocharset=default,shortname=mixed,quiet,utf8,flush,errors=remount-ro)
# /dev/sdq2 on /volumeUSB1/usbshare1-2 type fuseblk.ntfs (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
# So we just cut chars 6-8
devs=$(mount | grep USB | cut -b6-8 | uniq)
echo $devs


for dev in $(mount | grep USB | cut -b6-8 | uniq); do
    echo "Found dev: $dev"

    echo Unmounting: 
    ls /dev/$dev*

    umount /dev/$dev* &>/dev/null
    # Because mount return exit code 3 if device "not mount" we can't use return code as result. So we have to check result with "mount" 
    mount | grep /dev/$dev &>/dev/null && echo "Unmount error. Aborted!" && exit 1
    
    sync

    # Next, we have output of lsusb like this:
    # |__usb4          1d6b:0003:0302 09  3.00 5000MBit/s   0mA 1IF  (Linux 3.2.40 etxhci_hcd-161118 Etron xHCI Host Controller 0000:01:00.0) hub
    #   |__4-1         1058:25a2:1021 00  3.10 5000MBit/s 224mA 1IF  (Western Digital Elements 25A2 575833314141384B31345A58)
    #   4-1:1.0         (IF) 08:06:50 2EPs () usb-storage host14 (sdq) 
    # And we need to extract this line:
    #   4-1:1.0         (IF) 08:06:50 2EPs () usb-storage host14 (sdq)
    # and just take first charster of it

    idfull=$(lsusb -iu | grep "($dev)")

    echo Found device "$dev" on the node: "$idfull"
    id=$(echo $idfull | cut -b 1)

    echo USB device numder: $id. Disconnecting [/sys/bus/usb/devices/usb$id/authorized]...

    # I don't know what is better to operate with, for example:  "/sys/bus/usb/devices/4-1" or "/sys/bus/usb/devices/usb4"
    echo 0 >/sys/bus/usb/devices/usb$id/authorized
    #echo 0 >/sys/bus/usb/devices/$id-1/authorized

    ls /dev/$dev* &>/dev/null && echo "Device $dev failed to unmount/eject" || echo "Device $dev unmounted and ejected successfully"

    # store ejected device id - we will reconnect it later
    usblist="$usblist usb$id"
done

# Make short beeps
echo 2 >/dev/ttyS1
sleep 0.3
echo 2 >/dev/ttyS1


echo Waiting 60 seconds before USB ports [$usblist] will be reactivated...
sleep 60
for usb in $usblist; do
    echo Activating port /sys/bus/usb/devices/$usb/authorized...
    echo 1 >/sys/bus/usb/devices/$usb/authorized
done
echo 2 >/dev/ttyS1
echo Done