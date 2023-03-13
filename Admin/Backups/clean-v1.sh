#!/bin/bash

############################################
#                                          #
#                clean.sh                  #
#                  v 1                     #
#                                          #
############################################

# Delete sitespeed-result runs older than 7 days (60 * 24 * 7)
find $(pwd)/comp/sitespeed-result/*/ -maxdepth 1 -mmin +10080 | xargs rm -Rf
find $(pwd)/tld/sitespeed-result/*/ -maxdepth 1 -mmin +10080 | xargs rm -Rf
