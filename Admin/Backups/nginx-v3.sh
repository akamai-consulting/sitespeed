 #!/bin/bash

############################################
#                                          #
#                nginx.sh                  #
#                  v 3                     #
#                                          #
############################################

# Run this only after the sitespeed-result directory has been created or reset has been run

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]
  then 
    echo -e "\nRun as root\n"
    exit
fi

# Touch portal
chmod -R 755 $(pwd)/portal
chcon -vR system_u:object_r:httpd_sys_content_t:s0 $(pwd)/portal

# Touch tld only if it exists
if [ -d $(pwd)/tld/sitespeed-result ]
  then
    chmod -R 755 $(pwd)/tld/sitespeed-result
    chcon -vR system_u:object_r:httpd_sys_content_t:s0 $(pwd)/tld/sitespeed-result
fi

# Touch comp only if it exists
if [ -d $(pwd)/comp/sitespeed-result ]
  then
    chmod -R 755 $(pwd)/comp/sitespeed-result
    chcon -vR system_u:object_r:httpd_sys_content_t:s0 $(pwd)/comp/sitespeed-result
fi
