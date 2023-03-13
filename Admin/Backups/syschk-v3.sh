#!/bin/bash

############################################
#                                          #
#                syschk.sh                 #
#                  v 3                     #
#                                          #
############################################

# Simple way to check system health

echo -e "\nDisplaying /logs..."
ls --color /home/greg/logs 

echo -e "\nDisplaying /portal..."
ls --color /home/greg/portal

echo -e "\nDisplaying /portal tree..."
tree -d /home/greg/portal

echo -e "\nDisplaying /tld..."
ls --color /home/greg/tld

echo -e "\nDisplaying /tld tree..."
tree -d -L 3 /home/greg/tld

echo -e "\nDisplaying /comp..."
ls --color /home/greg/comp

echo -e "\nDisplaying /comp tree..."
tree -d -L 3 /home/greg/comp