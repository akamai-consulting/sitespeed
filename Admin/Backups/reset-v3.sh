#!/bin/bash

############################################
#                                          #
#                reset.sh                  #
#                  v 3                     #
#                                          #
############################################

# Wipes out all of the key files

rm $(pwd)/logs/*
rm $(pwd)/tld/*.txt
rm $(pwd)/comp/*.txt
rm $(pwd)/portal/tld*
rm $(pwd)/portal/comp*

rm -Rf $(pwd)/tld/sitespeed-result
rm -Rf $(pwd)/comp/sitespeed-result
rm -Rf $(pwd)/portal/images/