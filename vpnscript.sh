#! /usr/bin/env bash

# change keyboard & locales

sudo dpkg-reconfigure keyboard-configuration && sudo dpkg-reconfigure locales && sudo dpkg-reconfigure tzdata

# intro

echo Trimble VPN Certificate script ; echo Make sure up have downloaded the Certificate file from your email to the ~/Downloads folder
read -s -n 1 -p "If ready, press any key to continue..."

Red=$'\e[1;31m'
Green=$'\e[1;32m'
Blue=$'\e[1;34m'

echo $'\e[1;34m' " Closeing FireFox if you have it opened ! "$'\e[0m'

sudo pkill -f firefox
sudo apt-get purge transmission-gtk

# remove snap & change prio 

echo
sudo snap remove firefox && sudo add-apt-repository ppa:mozillateam/ppa
echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox
echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

# install deb FFox

sudo apt install firefox

# make directories for Cisco AnyConnect

mkdir -p ~/.cisco/certificates/ca/ && mkdir -p ~/.cisco/certificates/client && mkdir -p ~/.cisco/certificates/client/private

# extract .pem from .pfx

openssl pkcs12 -legacy -in ~/Downloads/*.pfx -nocerts -out ~/.cisco/certificates/ca/CAs.pem -nodes && openssl pkcs12 -legacy -in ~/Downloads/*.pfx -clcerts -nokeys -out ~/.cisco/certificates/client/CL.pem -nodes && openssl rsa -in ~/.cisco/certificates/ca/CAs.pem -out ~/.cisco/certificates/client/private/CL.key && openssl pkcs12 -legacy -in ~/Downloads/*.pfx -cacerts -nokeys -chain -out ~/.cisco/certificates/ca/CA.pem

echo Thanks!

# Trimblefy prep 

cd /opt && sudo mv /opt/trimbleify-linux-workstation.sh /tmp/trimbleify-linux-workstation.sh && sudo cd /tmp

read -s -n 1 -p "The Trimbleify script was downloaded to your /tmp folder. Press any key to close this script. Browse to your /tmp folder open a terminal and run the command (sudo bash trimbleify-linux-workstation.sh"
echo $'\e[1;34m' "Connect to VPN if you are not in a Trimble Office for the next part!!!"$'\e[0m'

read -s -n 1 -p "Thanks!"
