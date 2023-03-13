#!/bin/bash

############################################
#                                          #
#                reset.sh                  #
#                  v 5                     #
#                                          #
############################################

# Wipes out all of the key files
rm $(pwd)/logs/* &> /dev/null
rm $(pwd)/tld/*.txt &> /dev/null
rm $(pwd)/comp/*.txt &> /dev/null
rm $(pwd)/portal/tld* &> /dev/null
rm $(pwd)/portal/comp* &> /dev/null
rm -Rf $(pwd)/tld/sitespeed-result &> /dev/null
rm -Rf $(pwd)/comp/sitespeed-result &> /dev/null
rm -Rf $(pwd)/portal/images/ &> /dev/null