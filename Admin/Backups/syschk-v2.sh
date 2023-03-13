#!/bin/bash

############################################
#                                          #
#                syschk.sh                 #
#                  v 2                     #
#                                          #
############################################

# Simple way to check system health

ls -l --color /home/greg/logs 
ls -l --color /home/greg/portal
ls -l --color /home/greg/tld
ls -l --color /home/greg/comp

tree -d -L 3 /home/greg/tld
tree -d -L 3 /home/greg/comp
tree /home/greg/portal

ssh grafana tree graphite-storage/whisper/sitespeed_usage
ssh grafana tree -d -L 3 graphite-storage/whisper/sitespeed_io