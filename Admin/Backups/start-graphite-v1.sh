#!/bin/bash

# Make sure /home/greg/nginx exists
if [ ! -d /home/greg/nginx ]
    then
        sudo mkdir /home/greg/nginx
fi

# Make sure /home/greg/graphite-webapp exists
if [ ! -d /home/greg/graphite-webapp ]
    then
        sudo mkdir /home/greg/graphite-webapp
fi

docker run -d \
--name graphite \
--restart=always \
--mount type=volume,dst=/etc/nginx,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/home/greg/nginx \
--mount type=volume,dst=/opt/graphite/webapp/graphite,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=/home/greg/graphite-webapp \
-v /home/greg/graphite-conf:/opt/graphite/conf \
-v /home/greg/graphite-storage:/opt/graphite/storage \
-v /home/greg/statsd-config:/opt/statsd/config \
-v /home/greg/log:/var/log \
-p 8888:80 \
-p 2003-2004:2003-2004 \
graphiteapp/graphite-statsd:1.1.8-8
