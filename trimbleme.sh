#!/bin/bash

# Getting Trimble Scripts

wget -O vpnscript.sh https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/vpnscript.sh && wget -O trimbleify-linux-workstation.sh https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/trimbleify-linux-workstation.sh && wget -O trimbleprep.sh https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/trimbleprep.sh

sh /opt/trimbleprep.sh
#sh /opt/vpnscript.sh