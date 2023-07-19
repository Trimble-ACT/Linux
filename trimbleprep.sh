#! /usr/bin/env bash

# change keyboard & locales

sudo dpkg-reconfigure keyboard-configuration && sudo dpkg-reconfigure locales && sudo dpkg-reconfigure tzdata

# intro if you are doing it for a desktop you might want to rip out all vpn related things as chances are you will not use them

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

# Install FortiNet client

sudo dpkg -i /opt/forticlient_7.0.7.0246_amd64.deb
sudo apt install -f

# Install Intune
# Install dependencies
sudo apt update
sudo apt install -y apt-transport-https curl gpg

# Download and install the signing key
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/

# Add the Intune repository
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee -a /etc/apt/sources.list.d/microsoft-edge.list

sudo rm microsoft.gpg

# Update package list
sudo apt update

# Install Intune management extension agent
sudo apt install -y mdatp intune-portal microsoft-edge-stable

# FortiCliet old way with issues

#wget -O - https://repo.fortinet.com/repo/7.0/ubuntu/DEB-GPG-KEY | sudo tee /etc/apt/trusted.gpg.d/fortinet.asc
#echo "deb [arch=amd64] https://repo.fortinet.com/repo/7.0/ubuntu/ /bionic multiverse" | sudo tee -a /etc/apt/sources.list
#sudo apt-get update && sudo apt install forticlient

# FortiCliet new way wuth other issues

#wget -O - https://repo.fortinet.com/repo/forticlient/7.2/debian/DEB-GPG-KEY | gpg --dearmor | sudo tee /usr/share/keyrings/repo.fortinet.com.gpg
#echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/7.2/debian/ stable non-free" | sudo tee /etc/apt/sources.list.d/repo.fortinet.com.list
#sudo apt-get update
#sudo apt install forticlient

# configure forticlient

#/opt/forticlient/epctrl -r usdayt-ems01.trimble.com -p 8013

# Trimblefy prep

Sudo apt update && sudo apt upgrade -y
sudo mv /opt/trimbleify-linux-workstation.sh /tmp/trimbleify-linux-workstation.sh

read -s -n 1 -p "The Trimbleify script was downloaded to your /tmp folder. Press any key to close this script. Browse to your /tmp folder open a terminal and run the command (sudo bash trimbleify-linux-workstation.sh"
echo -e $'\e[1;34m' "\Connect to VPN if you are not in a Trimble Office for the next part!!!"$'\e[0m'

read -s -n 1 -p "Thanks!"
