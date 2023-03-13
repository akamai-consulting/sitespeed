#!/bin/bash

############################################
#                                          #
#                reset.sh                  #
#                  v 4                     #
#                                          #
############################################

# Wipes out all of the key files

if [ $(ls $(pwd)/logs | wc -l) -ne 0 ]
  then
  	rm $(pwd)/logs/*
fi

if [ $(ls tld/*.txt | wc -l) -ne 0 ]
  then
  	rm $(pwd)/tld/*.txt
fi

if [ $(ls comp/*.txt | wc -l) -ne 0 ]
  then
  	rm $(pwd)/comp/*.txt
fi

if [ $(ls portal/tld* | wc -l) -ne 0 ]
  then
  	rm $(pwd)/portal/tld*
fi

if [ $(ls portal/comp* | wc -l) -ne 0 ]
  then
  	rm $(pwd)/portal/comp*
fi

if [ -d $(pwd)/tld/sitespeed-result ]
  then
  	rm -Rf $(pwd)/tld/sitespeed-result
fi

if [ -d $(pwd)/comp/sitespeed-result ]
  then
  	rm -Rf $(pwd)/comp/sitespeed-result
fi

if [ -d $(pwd)/portal/images/ ]
  then
    rm -Rf $(pwd)/portal/images/
fi
