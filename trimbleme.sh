#! /usr/bin/env bash
#!/bin/bash

# Getting Trimble Scripts

wget https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/vpnscript.sh -o /opt/vpnscript.sh && wget https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/trimbleify-linux-workstation.sh -o /opt/trimbleify-linux-workstation.sh && wget https://raw.githubusercontent.com/Trimble-Technologies-Team/Linux/main/trimbleprep.sh -o /opt/trimbleprep.sh

sh /opt/trimbleprep.sh
#sh /opt/vpnscript.sh