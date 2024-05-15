#!/bin/bash

# Getting Trimble Scripts

wget -O trimbleify-linux-workstation.sh https://raw.githubusercontent.com/Trimble-ACT/Linux/main/trimbleify-linux-workstation.sh && wget -O trimbleprep.sh https://raw.githubusercontent.com/Trimble-ACT/Linux/main/trimbleprep.sh

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
