#!/bin/bash

############################################
#                                          #
#            install-docker.sh             #
#                  v 2                     #
#                                          #
############################################

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nNeed to run script as root"
  exit 1
fi

# Update existing packages
echo -e "\nUpdating the system"
sleep 3
yum -y update

# Install Docker
echo -e "\nInstalling Docker"
sleep 3
curl -fsSL https://get.docker.com/ | sh

# Start Docker
echo -e "\nStart Docker as a system service"
sleep 3
systemctl enable docker
systemctl start docker
systemctl status docker | grep "active (running)" > /dev/null
if [ $? -eq 0 ] 
 then
    echo -e "\nDocker has been started successfully"
 else
 	echo -e "\nSomething went wrong and will have to be fixed"
fi

# Add user to Docker group
echo -e "\nAdding user to Docker group"
sleep 3

usermod -aG docker $SUDO_USER
echo -e "\nChange will take effect upon next login"
