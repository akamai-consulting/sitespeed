#!/bin/bash

############################################
#                                          #
#                reset.sh                  #
#                  v 6                     #
#                                          #
############################################

# Wipes out all of the key files
rm $(pwd)/logs/* &> /dev/null
rm $(pwd)/tld/*.txt $(pwd)/tld/*.js &> /dev/null
rm $(pwd)/comp/*.txt $(pwd)/comp/*.js &> /dev/null
rm $(pwd)/portal/tld* &> /dev/null
rm $(pwd)/portal/comp* &> /dev/null
rm -Rf $(pwd)/tld/sitespeed-result &> /dev/null
rm -Rf $(pwd)/comp/sitespeed-result &> /dev/null
rm -Rf $(pwd)/portal/images/ &> /dev/null