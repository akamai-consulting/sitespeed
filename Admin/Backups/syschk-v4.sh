#!/bin/bash

############################################
#                                          #
#                syschk.sh                 #
#                  v 4                     #
#                                          #
############################################

# Simple way to check Sitespeed files and folders

echo -e "\nDisplaying /logs..."
ls --color $(pwd)/logs 

echo -e "\nDisplaying /portal..."
ls --color $(pwd)/portal

echo -e "\nDisplaying /portal tree..."
tree -d $(pwd)/portal

echo -e "\nDisplaying /tld..."
ls --color $(pwd)/tld

echo -e "\nDisplaying /tld tree..."
tree -d -L 3 $(pwd)/tld

echo -e "\nDisplaying /comp..."
ls --color $(pwd)/comp

echo -e "\nDisplaying /comp tree..."
tree -d -L 3 $(pwd)/comp
