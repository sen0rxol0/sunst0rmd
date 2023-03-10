#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
  echo "Only macOS is supported."
  exit
fi

if [ ! -x requirements.sh ]; then
  chmod +x requirements.sh
fi

./requirements.sh

if [ -a .requirements_done ]; then
  clear
else
  echo "Run \$ ./requirements.sh"
  exit
fi

arg2="<ipsw path>"

_usage()
{
    cat <<EOF
================================================================================
Usage:
    Restoring: sunst0rm.sh [-yB] restore $arg2
    Booting: sunst0rm.sh boot
    Options:
      -y No prompt
      -B Skip Baseband
================================================================================
EOF
}

agreed=0
baseband=1
while getopts "yB" option
do
    case $option in
    y)  agreed=1;;
    B)  baseband=0;;
    esac
done

if [ $baseband == 0 ]; then
    echo "Option -B specified"
fi
# Move argument pointer to next.
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
  echo "No argument provided."
  _usage
  exit
fi

_eexit()
{
  echo "[EXITING] $1"
  exit
}

_dfuWait()
{
  clear
  echo "================================================================================"
  echo "Make sure to reboot device into DFU Mode."
  read -p "Press ENTER when device is ready to continue <-"
  echo "Searching for device in DFU Mode..."
  device_dfu=0
  until [[ $device_dfu == 1 ]]; do
    device_dfu=$(irecovery -m | grep -c "DFU")
  done
}

_dfuWait
require_dfu=0

# @TODO: ensure correct irecovery version is installed
_deviceInfo()
{
  echo $(irecovery -q | grep "$1" | sed "s/$1: //")
}
cpid=`_deviceInfo "CPID"`
device=`_deviceInfo "PRODUCT"`
ecid=`_deviceInfo "ECID"`
model=`_deviceInfo "MODEL"`
echo "Found device: |$device|$cpid|$model|$ecid|"

A10_plus=0
if [[ $cpid == *"0x801"* ]]; then
  A10_plus=1
fi

_pwnDevice()
{
  echo "Starting exploit, device should be in pwnd DFU Mode after this."
  ./bin/gaster pwn
}

if [ "$1" == "boot" ]; then
  if [ ! -d boot ]; then
    _eexit "Run 'sunst0rm.sh restore $arg2' command first."
  fi
  
  _pwnDevice
  cd boot

  if [ -e ibss.img4 ]; then
    echo "Booting untrusted images..."
    echo "**sunst0rm tethered downgrade**" > reset.txt
    irecovery -f reset.txt
    rm reset.txt
    irecovery -f ibss.img4
    irecovery -f ibec.img4
    sleep 1
    if [ $A10_plus == 1 ]; then
    irecovery -c "go"
    sleep 5
    fi
    irecovery -c "bootx"
    irecovery -c "bgcolor 255 223 0"
    irecovery -f devicetree.img4
    irecovery -c "devicetree"
    irecovery -f trustcache.img4
    irecovery -c "firmware"
    
    # if [ -e aop.img4 ]; then
    #   irecovery -f aop.img4
    #   irecovery -c "firmware"
    # fi
    #
    # if [ -e homer.img4 ]; then
    #   irecovery -f homer.img4
    #   irecovery -c "firmware"
    # fi

    irecovery -f kernelcache.img4
    irecovery -c "bootx"
    echo "Device should be booting now."
    sleep 5
  fi

  echo "Done booting device!"
  exit
fi

if [ "$1" != "restore" ]; then
  echo "Use either 'sunst0rm.sh restore' or 'sunst0rm.sh boot' command."
  _usage
  exit
fi

_runFuturerestore()
{
  sleep 5
  
  if [ $require_dfu == 1 ]; then
      _dfuWait
  fi
  
  _pwnDevice
  sleep 2
  echo "**sunst0rm tethered downgrade**" > reset.txt
  irecovery -f reset.txt
  rm reset.txt
  rm -rf /tmp/futurerestore/
  restore_ipsw=$(cat restore/ipsw)
  shsh=$(ls tickets/*.shsh2)
  futurerestore -t $shsh --use-pwndfu --skip-blob \
  --rdsk restore/rdsk.im4p --rkrn restore/rkrn.im4p \
  --latest-sep --latest-baseband $restore_ipsw;
  ret=$?
  clear
  
  if [ $ret == 0 ]; then
    echo "Done restoring device!!"
    exit 0
  else
    echo "Device could not be restored!"
    require_dfu=1
    _runFuturerestore
  fi
}

if [ -d restore ]; then

  if [ $agreed == 1 ]; then
    echo "Option -y specified"
    _runFuturerestore
  else
    echo "================================================================================"
    echo "Restore from previous run ? (y/n):"
    read yn

    if [ "$yn" == "y" ]; then
      echo "Continuing to futurerestore..."
      _runFuturerestore
    fi
  fi
  
  rm -rf restore/
fi

if [ -d work ]; then
  rm -rf work/
fi

if [ -d boot ]; then
  rm -rf boot/
fi

mkdir work
mkdir boot

ipsw=$2

if [ -z "$ipsw" ]; then
  _eexit "$arg2 is required to continue."
fi

if [ -a $ipsw ] || [ ${ipsw: -5} == ".ipsw" ]; then
  echo "Continuing..."
else
  _eexit "$arg2 is not a valid ipsw file."
fi

if [ ! -d tickets ]; then
  mkdir tickets
else
  rm -f tickets/*
fi

./bin/tsschecker -d $device -e $ecid --boardconfig $model -s -l --save-path tickets/
shsh=$(ls tickets/*.shsh2)
echo "SigningTicket: $shsh"

unzip -q $ipsw -x *.dmg -d work
firmware=$(plutil -extract 'ProductVersion' xml1 -o - work/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
echo "Firmware version: $firmware"

# @FIX: parse correct filename, BuildIdentities is of type array which makes finding device manifest complex to deal with
manifest_index=0
ret=0
until [[ $ret != 0 ]]; do
  manifest=$(plutil -extract "BuildIdentities.$manifest_index.Manifest" xml1 -o - work/BuildManifest.plist)
  ret=$?
  if [ $ret == 0 ]; then
    count_manifest=$(echo $manifest | grep -c "$model")
    if [ $count_manifest == 0 ]; then
      ((manifest_index++))
    else
      ret=1
    fi
  fi
done

if [ $ret != 1 ]; then
_eexit "Restore manifest not found."
fi

_extractFromManifest()
{
    echo $(plutil -extract "BuildIdentities.$manifest_index.Manifest.$1.Info.Path" xml1 -o - work/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
}

ibss=$(_extractFromManifest "iBSS")
ibec=$(_extractFromManifest "iBEC")
echo "iBSS: $ibss"
echo "iBEC: $ibec"
echo "Making boot files..."

if [ -a IM4M ]; then
  rm IM4M
fi

img4tool -e -s $shsh -m IM4M
./bin/gaster decrypt work/$ibss work/ibss.dec
./bin/gaster decrypt work/$ibec work/ibec.dec
./bin/iBoot64Patcher work/ibss.dec work/ibss.patched
./bin/iBoot64Patcher work/ibec.dec work/ibec.patched -b "-v"
img4 -i work/ibss.patched -o boot/ibss.img4 -M IM4M -A -T ibss
img4 -i work/ibec.patched -o boot/ibec.img4 -M IM4M -A -T ibec
devicetree=$(_extractFromManifest "DeviceTree")
echo "DeviceTree: $devicetree"
img4 -i work/$devicetree -o boot/devicetree.img4 -M IM4M -T rdtr
trustcache=$(_extractFromManifest "StaticTrustCache")
echo "StaticTrustCache: $trustcache"
img4 -i work/$trustcache -o boot/trustcache.img4 -M IM4M -T rtsc

# plutil -extract "BuildIdentities.$manifest_index.Manifest.AOP" xml1 -s work/BuildManifest.plist
# ret=$?
#
# if [ $ret == 0 ]; then
#   aop=$(_extractFromManifest "AOP")
#   echo "AOP: $aop"
#   img4 -i work/$aop -o boot/aop.img4 -M IM4M
# fi
#
# plutil -extract "BuildIdentities.$manifest_index.Manifest.Homer" xml1 -s work/BuildManifest.plist
# ret=$?
#
# if [ $ret == 0 ]; then
#   homer=$(_extractFromManifest "Homer")
#   echo "Homer: $homer"
#   img4 -i work/$homer -o boot/homer.img4 -M IM4M
# fi

kernelcache=$(_extractFromManifest "KernelCache")
echo "KernelCache: $kernelcache"

if [ $A10_plus == 1 ]; then
  img4 -i work/$kernelcache -o work/kcache.dec
else
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.dec --extra work/kpp.bin
fi

./bin/Kernel64Patcher work/kcache.dec work/kcache.patched -f -a

if [ $A10_plus == 1 ]; then
  pyimg4 im4p create -i work/kcache.patched -o work/kcache.im4p -f rkrn --lzss
else
  pyimg4 im4p create -i work/kcache.patched -o work/kcache.im4p -f rkrn --lzss --extra work/kpp.bin
  rm work/kpp.bin
fi

pyimg4 img4 create -p work/kcache.im4p -o boot/kernelcache.img4 -m IM4M
rm work/kcache.*
echo "Making restore files..."
ramdisk=$(_extractFromManifest "RestoreRamDisk")
echo "RestoreRamDisk: $ramdisk"
restore_kernelcache=$(_extractFromManifest "RestoreKernelCache")
echo "RestoreKernelCache: $restore_kernelcache"
mkdir restore
unzip -q $ipsw $ramdisk -d work
img4 -i work/$ramdisk -o work/ramdisk.dmg

if [ $A10_plus == 1 ]; then
  img4 -i work/$restore_kernelcache -o work/kcache.dec
else
  pyimg4 im4p extract -i work/$restore_kernelcache -o work/kcache.dec --extra work/kpp.bin
fi

mkdir work/ramdisk
hdiutil attach work/ramdisk.dmg -mountpoint work/ramdisk
sleep 5
./bin/asr64_patcher work/ramdisk/usr/sbin/asr work/patched_asr
./bin/ldid2 -e work/ramdisk/usr/sbin/asr > work/asr.plist
./bin/ldid2 -Swork/asr.plist work/patched_asr
cp work/ramdisk/usr/local/bin/restored_external work/restored_external
./bin/restored_external64_patcher work/restored_external work/patched_restored_external
./bin/ldid2 -e work/restored_external > work/restored_external.plist
./bin/ldid2 -Swork/restored_external.plist work/patched_restored_external
chmod 755 work/patched_restored_external
chmod 755 work/patched_asr
rm work/ramdisk/usr/sbin/asr
rm work/ramdisk/usr/local/bin/restored_external
mv work/patched_asr work/ramdisk/usr/sbin/asr
mv work/patched_restored_external work/ramdisk/usr/local/bin/restored_external
hdiutil detach -force work/ramdisk
sleep 5
./bin/Kernel64Patcher work/kcache.dec work/kcache.patched -f -a
pyimg4 im4p create -i work/ramdisk.dmg -o restore/rdsk.im4p -f rdsk

if [ $A10_plus == 1 ]; then
  pyimg4 im4p create -i work/kcache.patched -o restore/rkrn.im4p -f rkrn --lzss
else
  pyimg4 im4p create -i work/kcache.patched -o restore/rkrn.im4p -f rkrn --lzss --extra work/kpp.bin
fi

rm IM4M
rm -rf work/
echo $ipsw > restore/ipsw
echo "Continuing to futurerestore..."
require_dfu=1
_runFuturerestore
