#!/bin/bash -e
# Run this script without any arguments for a dry run
# Run the script with root and with exec arguments for removing old kernels and modules after checking
# the list printed in the dry run
# https://askubuntu.com/questions/1253347/how-to-easily-remove-old-kernels-in-ubuntu-20-04-lts

uname -a
IN_USE=$(uname -a | awk '{ print $3 }')
echo "Your in use kernel is $IN_USE"

OLD_KERNELS=$(
    dpkg --get-selections |
        grep -v "linux-headers-generic" |
        grep -v "linux-image-generic" |
        grep -v "linux-image-generic" |
        grep -v "${IN_USE%%-generic}" |
        grep -Ei 'linux-image|linux-headers|linux-modules' |
        awk '{ print $1 }'
)
echo "Old Kernels to be removed:"
echo "$OLD_KERNELS"

OLD_MODULES=$(
    ls /lib/modules |
    grep -v "${IN_USE%%-generic}" |
    grep -v "${IN_USE}"
)
echo "Old Modules to be removed:"
echo "$OLD_MODULES"

if [ "$1" == "exec" ]; then
  sudo apt-get purge $OLD_KERNELS
  for module in $OLD_MODULES ; do
    sudo rm -rf /lib/modules/$module/
  done
fi
