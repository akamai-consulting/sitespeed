#!/bin/bash

############################################
#                                          #
#                reset.sh                  #
#                  v 7                     #
#                                          #
############################################

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]
  then 
    echo -e "\nRun as root\n"
    exit
fi

# Delete all of the logs
rm /usr/local/sitespeed/logs/* &> /dev/null

# Delete all of the seed files
rm /usr/local/sitespeed/tld/*.txt &> /dev/null
rm /usr/local/sitespeed/comp/*.txt &> /dev/null

# Delete all of the symbolic links
rm /usr/local/sitespeed/portal/tld* &> /dev/null
rm /usr/local/sitespeed/portal/comp* &> /dev/null

# Delete all of the sitespeed results
rm -Rf /usr/local/sitespeed/tld/sitespeed-result &> /dev/null
rm -Rf /usr/local/sitespeed/comp/sitespeed-result &> /dev/null

# Delete all of the sitespeed images
rm -Rf /usr/local/sitespeed/portal/images/ &> /dev/null