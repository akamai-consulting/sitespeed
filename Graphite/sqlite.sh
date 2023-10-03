#!/bin/bash

############################################
#                                          #
#              sqlite.sh                   #
#                  v 3                     #
#                                          #
############################################

# The purpose of this script is to reduce the size of the graphite.db by removing old tags
# This script is triggered remotely but executed directly on the Graphite Linode

# This version uses a root of /mnt/data/ for Graphite, which in turn points to an external volume
# The existing Stackscript installs Graphite using a root path of /usr/local/graphite/
# If an external volume is used, be sure to create the volume and then update the script to use the correct root

sqlite3 /mnt/data/graphite-storage/graphite.db < /usr/local/graphite/deleteoldevents.sql && sqlite3 /mnt/data/graphite-storage/graphite.db 'VACUUM;'
