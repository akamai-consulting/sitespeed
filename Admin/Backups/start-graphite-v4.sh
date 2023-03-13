#!/bin/bash

############################################
#                                          #
#           start-graphite.sh              #
#                  v 4                     #
#                                          #
############################################

# Make sure /usr/local/graphite/nginx exists
if [ ! -d /usr/local/graphite/nginx ]
    then
        sudo mkdir /usr/local/graphite/nginx
fi

# Make sure /usr/local/graphite/graphite-webapp exists
if [ ! -d /usr/local/graphite/graphite-webapp ]
    then
        sudo mkdir /usr/local/graphite/graphite-webapp
fi

# Uncomment and move the following two lines to the docker section
# --mount type=volume,dst=/etc/nginx,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/usr/local/graphite/nginx \
# --mount type=volume,dst=/opt/graphite/webapp/graphite,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/usr/local/graphite/graphite-webapp \

docker run -d \
--name graphite \
--restart=always \
-v /usr/local/graphite/graphite-conf:/opt/graphite/conf \
-v /usr/local/graphite/graphite-storage:/opt/graphite/storage \
-v /usr/local/graphite/statsd-config:/opt/statsd/config \
-v /usr/local/graphite/log:/var/log \
-p 8888:80 \
-p 2003-2004:2003-2004 \
graphiteapp/graphite-statsd:1.1.8-8

