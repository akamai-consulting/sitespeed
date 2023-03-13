#!/bin/bash

############################################
#                                          #
#              sqlite.sh                   #
#                  v 1                     #
#                                          #
############################################

# The purpose of this script is to reduce the size of the graphite.db by removing old tags
# This script is triggered remotely but executed directly on the Graphite Linode

sqlite3 /home/greg/graphite-storage/graphite.db < /home/greg/deleteoldevents.sql && sqlite3 /home/greg/graphite-storage/graphite.db 'VACUUM;'