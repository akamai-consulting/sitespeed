#!/bin/bash

#########################################
#                                       #
#           ssh-key-gen.sh              #
#                  v 1                  #
#                                       #
#########################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'

# Key pair 1 user <--> jump WITH passcode
echo -e "\n${Green}Generating the key pair for User and Jump communication"
echo -e "Be sure to enter a PASSCODE when prompted${NoColor}\n"
ssh-keygen -t rsa -b 2048 -C "jump-`date +%Y-%m-%d`" -f jump-`date +%Y-%m-%d`

# Key pair 2 jump <--> all servers WITHOUT passcode
echo -e "\n${Green}Generating the key pair for Jump and Sitespeed communication"
echo -e "Do not creat a PASSCODE when prompted${NoColor}\n"
ssh-keygen -t rsa -b 2048 -C "sitespeed" -f sitespeed

exit 0