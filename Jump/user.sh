#!/bin/bash

############################################
#                                          #
#               user.sh                    #
#                  v3                      #
#                                          #
############################################

# Make sure the script runs as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nNeed to run script as root\n"
  exit 1
fi

# Set variables
Host=[HOST]
Domain=[DOMAIN]
Google=[GOOGLE]
Graphite=[GRAPHITE]
Key=/home/$(logname)/.ssh/sitespeed

# Create new user
function adduser {
   User=""   
   until [ "$taken" == "false"  ]
     do
       read -p "Username: " User
       grep -i -q $User /etc/passwd
       if [ "$?" == "0" ]; then
          echo "Name already exists"
          taken=true
         else
          taken=false
       fi
     done
}

# Delete existing user
function deluser {
   User=""
   until [ "$valid" == "true"  ]
     do
       read -p "Username: " User
       if [ "$User" == "$(logname)" ]; then
          echo "Cannot delete yourself"
        else
          grep -i -q $User /etc/passwd
          if [ "$?" == "1" ]; then
             echo "$User does not exist"
             valid=false
            else
             valid=true
          fi
       fi   
     done
}

# Read servers and set Servers variable
Servers=""
end=$(cat /usr/local/sitespeed/servers | wc -l)
exec 3</usr/local/sitespeed/servers
read data <&3
for (( index=1; index <= $end; index+=1 ))
  do
    Servers="$Servers$data "
    read data <&3
  done

# Process each option
All="$Google $Graphite $Servers"
case $1 in
    add ) adduser
          # Create user on Jump server
          echo "Creating $User on $Host ..."
          useradd $User
          usermod -aG wheel $User
          usermod -aG sitespeed $User
          mkdir /home/$User/.ssh
          tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz jump.pub sitespeed
          mv /home/$User/.ssh/jump.pub /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh
          chgrp $User /home/$User/.ssh
          chmod 600 /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh/authorized_keys
          chgrp $User /home/$User/.ssh/authorized_keys
          chmod 600 /home/$User/.ssh/sitespeed
          chown $User /home/$User/.ssh/sitespeed
          chgrp $User /home/$User/.ssh/sitespeed
          sudo -u $User ln -s /usr/local/sitespeed/admin.sh /home/$User/admin.sh
          sudo -u $User ln -s /usr/local/sitespeed/cron/ /home/$User/cron
          sudo -u $User ln -s /usr/local/sitespeed/seeds/ /home/$User/seeds
          echo -e "function jump() {\n  ssh -i /home/$User/.ssh/sitespeed \$1.$Domain\n}\nexport PS1='[$Host \u@\h \W]\$ '" >> /home/$User/.bash_profile
          echo         
          for region in $All
            do
              # Create users on remote servers
              echo "Creating $User on $region ..."
              ssh -i $Key $(logname)@"$region".$Domain sudo useradd $User
              ssh -i $Key $(logname)@"$region".$Domain sudo usermod -aG wheel $User
              ssh -i $Key $(logname)@"$region".$Domain sudo usermod -aG sitespeed $User
              ssh -i $Key $(logname)@"$region".$Domain sudo mkdir /home/$User/.ssh
              ssh -i $Key $(logname)@"$region".$Domain sudo tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz sitespeed.pub
              ssh -i $Key $(logname)@"$region".$Domain sudo mv /home/$User/.ssh/sitespeed.pub /home/$User/.ssh/authorized_keys
              ssh -i $Key $(logname)@"$region".$Domain sudo chown -R $User /home/$User/.ssh
              ssh -i $Key $(logname)@"$region".$Domain sudo chgrp -R $User /home/$User/.ssh            
              ssh -i $Key $(logname)@"$region".$Domain sudo chmod 600 /home/$User/.ssh/authorized_keys
              echo
            done
            exit 0
          ;;
          
 delete ) deluser
          # Delete user on Jump server
          echo "Deleting $User on $Host ..."
          echo
          userdel -r $User
          # Delete user on remote servers
          for region in $All
            do
              echo "Deleting $User on $region ..."
              ssh -i $Key $(logname)@"$region".$Domain sudo userdel -r $User
              echo
            done  
          exit 0
          ;;
esac
