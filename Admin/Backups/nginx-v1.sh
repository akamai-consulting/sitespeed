 #!/bin/bash

# Run this only once after the initial sitespeed-result directory is created

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]
  then 
    echo -e "\nRun as root\n"
    exit
fi

case $1 in

    tld|comp )  chmod -R 755 /home/greg/$1/sitespeed-result
                chcon -vR system_u:object_r:httpd_sys_content_t:s0 /home/greg/$1/sitespeed-result
                ;;

    portal )    chmod -R 755 /home/greg/$1
                chcon -vR system_u:object_r:httpd_sys_content_t:s0 /home/greg/$1
                ;;

    *  )        echo -e "\nMissing or incorrect argument"
                echo -e "Usage: nginx tld|comp|portal\n"
                ;;
  esac