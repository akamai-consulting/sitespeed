#!/bin/bash

# Make sure /mnt/data/nginx exists
if [ ! -d /mnt/data/nginx ]
    then
        sudo mkdir /mnt/data/nginx
fi

# Make sure /mnt/data/graphite-webapp exists
if [ ! -d /mnt/data/graphite-webapp ]
    then
        sudo mkdir /mnt/data/graphite-webapp
fi

docker run -d \
--name graphite \
--restart=always \
--mount type=volume,dst=/etc/nginx,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/mnt/data/nginx \
--mount type=volume,dst=/opt/graphite/webapp/graphite,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/mnt/data/graphite-webapp \
-v /mnt/data/graphite-conf:/opt/graphite/conf \
-v /mnt/data/graphite-storage:/opt/graphite/storage \
-v /mnt/data/statsd-config:/opt/statsd/config \
-v /mnt/data/log:/var/log \
-p 8888:80 \
-p 2003-2004:2003-2004 \
graphiteapp/graphite-statsd:1.1.8-8
