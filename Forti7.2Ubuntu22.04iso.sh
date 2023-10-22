#! /usr/bin/env bash

# FortiCliet new way with other issues

wget -O - https://repo.fortinet.com/repo/forticlient/7.2/debian/DEB-GPG-KEY | gpg --dearmor | sudo tee /usr/share/keyrings/repo.fortinet.com.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/7.2/debian/ stable non-free" | sudo tee /etc/apt/sources.list.d/repo.fortinet.com.list
sudo apt-get update
sudo apt install forticlient

# configure forticlient
/opt/forticlient/epctrl -r usdayt-ems01.trimble.com -p 8013

end
