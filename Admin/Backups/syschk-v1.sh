#/bin/bash

# Simple way to check system health

ls -l --color /home/greg/logs /home/greg/portal /home/greg/tld /home/greg/comp
tree -d -L 3 /home/greg/tld /home/greg/comp
tree /home/greg/portal
ssh grafana tree graphite-storage/whisper/sitespeed_usage
ssh grafana tree -d -L 2 graphite-storage/whisper/sitespeed_io

