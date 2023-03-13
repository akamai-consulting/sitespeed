#!/bin/bash

############################################
#                                          #
#                clean.sh                  #
#                  v 2                     #
#                                          #
############################################

# Identify sitespeed-result runs older than 7 days (60 * 24 * 7)
find $(pwd)/comp/sitespeed-result/*/ -maxdepth 1 -mmin +10080 > Folders
find $(pwd)/tld/sitespeed-result/*/ -maxdepth 1 -mmin +10080 >> Folders

# Open up Folders for processing
exec 3<Folders
read Folder <&3
status=$?

# Process Folder contents
while [ $status -eq 0 ]
   do
      rm -Rf $Folder
      read Folder <&3
      status=$?
   done

# Remove Folders
rm Folders

exit 0
