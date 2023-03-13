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
rm logs/* &> /dev/null

# Delete all of the seed files
rm tld/*.txt &> /dev/null
rm comp/*.txt &> /dev/null

# Delete all of the symbolic links
rm portal/tld* &> /dev/null
rm portal/comp* &> /dev/null

# Delete all of the sitespeed results
rm -Rf tld/sitespeed-result &> /dev/null
rm -Rf comp/sitespeed-result &> /dev/null

# Delete all of the sitespeed images
rm -Rf portal/images/ &> /dev/null