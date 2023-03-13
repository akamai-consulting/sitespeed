#!/bin/bash

#########################################
#                                       #
#             bundler.sh                #
#                  v 1                  #
#                                       #
#########################################

# Set Sitespeed root variable
root=/Users/gwolf/Documents/GitHub/Sitespeed

# Create and move tars
cd $root/Grafana && tar --exclude=.DS_Store -cf grafana.tgz * && mv -f $root/Grafana/grafana.tgz $root/Admin/Tars/
cd $root/Portal && tar --exclude=.DS_Store -cf portal.tgz * && mv -f $root/Portal/portal.tgz $root/Admin/Tars/

cd $root/Graphite && tar --exclude=.DS_Store -cf graphite.tgz *
cd $root/SSH-Keys && tar --exclude=.DS_Store -rf $root/Graphite/graphite.tgz *.pub && mv -f $root/Graphite/graphite.tgz $root/Admin/Tars/

cd $root/Google && tar --exclude=.DS_Store -cf google.tgz *
cd $root/SSH-Keys && tar --exclude=.DS_Store -rf $root/Google/google.tgz *.pub && mv -f $root/Google/google.tgz $root/Admin/Tars/

cd $root/Sitespeed && tar --exclude=.DS_Store -cf sitespeed.tgz *
cd $root/SSH-Keys && tar --exclude=.DS_Store -rf $root/Sitespeed/sitespeed.tgz *.pub && mv -f $root/Sitespeed/sitespeed.tgz $root/Admin/Tars/

cd $root/Jump && tar --exclude=.DS_Store -cf jump.tgz *
cd $root/SSH-Keys && tar --exclude=.DS_Store -rf $root/Jump/jump.tgz jump-*.pub sitespeed && mv -f $root/Jump/jump.tgz $root/Admin/Tars/

# Return to Sitespeed root
cd $root
exit 0
