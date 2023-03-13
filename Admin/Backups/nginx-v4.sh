 #!/bin/bash

############################################
#                                          #
#                nginx.sh                  #
#                  v 4                     #
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
chmod -R 755 /usr/local/sitespeed/portal
chcon -vR system_u:object_r:httpd_sys_content_t:s0 /usr/local/sitespeed/portal

# Touch tld only if it exists
if [ -d /usr/local/sitespeed/tld/sitespeed-result ]
  then
    chmod -R 755 /usr/local/sitespeed/tld/sitespeed-result
    chcon -vR system_u:object_r:httpd_sys_content_t:s0 /usr/local/sitespeed/tld/sitespeed-result
fi

# Touch comp only if it exists
if [ -d /usr/local/sitespeed/comp/sitespeed-result ]
  then
    chmod -R 755 /usr/local/sitespeed/comp/sitespeed-result
    chcon -vR system_u:object_r:httpd_sys_content_t:s0 /usr/local/sitespeed/comp/sitespeed-result
fi
