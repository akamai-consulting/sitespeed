#!/bin/bash

# Wipes out all of the key files
# Good to use when testing to make clean up easy

rm $(pwd)/logs/*
rm -rf $(pwd)/tld/sitespeed-result
rm -rf $(pwd)/comp/sitespeed-result
rm -rf $(pwd)/portal/tld* $(pwd)/portal/comp*
rm -rf $(pwd)/portal/images/
ssh grafana sudo rm -rf graphite-storage/whisper/sitespeed_*
