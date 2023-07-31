#! /usr/bin/env bash

# NFS - i feel the need the need for speed :)
# Backup the original sources.list file
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# Fetch a list of mirrors and test their speed to find the fastest one
fastest_mirror=$(curl -sS -D - http://mirrors.ubuntu.com/mirrors.txt | grep -v "^#" | awk '{print $2}' | while read mirror; do echo "$(curl -o /dev/null -sS -w "%{speed_download}\n" $mirror/dists/$(lsb_release -cs)/InRelease -m 5) $mirror"; done | sort -rn | head -1 | awk '{print $2}')

# Update the sources.list file with the fastest mirror
echo "Updating sources.list with the fastest mirror: $fastest_mirror"
sudo sed -i "s@http://[^/]*/ubuntu/@$fastest_mirror/ubuntu/@g" /etc/apt/sources.list

# Update the package lists with the new mirror
sudo apt update

echo "Mirror update completed!"

# change keyboard & locales

sudo dpkg-reconfigure keyboard-configuration && sudo dpkg-reconfigure locales && sudo dpkg-reconfigure tzdata

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

# Install Intune
# Install dependencies
sudo apt update && sudo apt upgrade -y --allow-downgrades
sudo apt install -y apt-transport-https curl gpg

# Download and install the signing key
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/

# Add the Intune repository
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee -a /etc/apt/sources.list.d/microsoft-edge.list

sudo rm microsoft.gpg

# Update package list
sudo apt update && sudo apt upgrade -y --allow-downgrades

# Install Intune management extension agent
sudo apt install -y mdatp intune-portal microsoft-edge-stable

sudo mv /opt/trimbleify-linux-workstation.sh /tmp/trimbleify-linux-workstation.sh
# Function to delete the script file
delete_script() {
  script_path=$(readlink -f "$0")
  rm "$script_path"
  echo "Script deleted."
}

# Set a trap to call delete_script function upon normal exit or error
trap delete_script EXIT

# Your script's logic goes here
echo "Sleeping a bit"
sleep 5
echo "Script execution completed successfully."
