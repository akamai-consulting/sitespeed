#!/bin/bash

############################################
#                                          #
#              sqlite.sh                   #
#                  v 4                     #
#                                          #
############################################

# The purpose of this script is to reduce the size of the graphite.db by removing old tags
# This script is triggered remotely but executed directly on the Graphite Linode

sqlite3 /usr/local/graphite/graphite-storage/graphite.db < /usr/local/graphite/deleteoldevents.sql && sqlite3 /usr/local/graphite/graphite-storage/graphite.db 'VACUUM;'
