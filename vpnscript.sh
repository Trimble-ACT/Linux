#! /usr/bin/env bash

# make directories for Cisco AnyConnect

mkdir -p ~/.cisco/certificates/ca/ && mkdir -p ~/.cisco/certificates/client && mkdir -p ~/.cisco/certificates/client/private

# extract .pem from .pfx

openssl pkcs12 -legacy -in ~/Downloads/*.pfx -nocerts -out ~/.cisco/certificates/ca/CAs.pem -nodes && openssl pkcs12 -legacy -in ~/Downloads/*.pfx -clcerts -nokeys -out ~/.cisco/certificates/client/CL.pem -nodes && openssl rsa -in ~/.cisco/certificates/ca/CAs.pem -out ~/.cisco/certificates/client/private/CL.key && openssl pkcs12 -legacy -in ~/Downloads/*.pfx -cacerts -nokeys -chain -out ~/.cisco/certificates/ca/CA.pem

echo Thanks!

# Install FortiNet client

sudo dpkg -i /opt/forticlient_7.0.7.0246_amd64.deb
sudo apt install -f

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

/opt/forticlient/epctrl -r usdayt-ems01.trimble.com -p 8013
# end