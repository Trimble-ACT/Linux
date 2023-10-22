#! /usr/bin/env bash

# FortiCliet new way with other issues

wget -O - https://repo.fortinet.com/repo/forticlient/7.2/ubuntu/DEB-GPG-KEY | sudo apt-key add - | gpg --dearmor | sudo tee /usr/share/keyrings/repo.fortinet.com.gpg
echo "deb [arch=amd64] https://repo.fortinet.com/repo/forticlient/7.2/ubuntu/ /stable multiverse" | sudo tee /etc/apt/sources.list
sudo apt-get update
sudo apt install forticlient

# configure forticlient
/opt/forticlient/epctrl -r usdayt-ems01.trimble.com -p 8013

end
