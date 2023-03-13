# **Welcome to the Advanced Services Sitespeed Portal**

The Sitespeed monitoring system consists of the following three machine types:

+ Sitespeed
+ Graphite
+ Grafana

Sitespeed and Graphite run in Docker containers and Grafana runs natively. Currently there are 10 Sitespeed machines, one in each of the Linode datacenters, with the exception of Atlanta, GA. Graphite and Grafana operate on the same machine, which is located in the Newark, NJ. All VMs run on CentOS 7. The Sitespeed machines are configured with 16GB memory and 8 CPUs on a dedicated VM. Graphite and Grafana are configured with 32GB of memory and 16 CPUs on a dedicated VM. The Graphite database writes data to an external 1TB volume. The goal is to save data for a period of 13 months. The following screenshot are the details from the Linode console manager with all of the configuration details of each machine.

### <img src="https://as.akamai.com/user/gwolf-2e566b8711afa134d752619ea2dc7f2eb90c29602e8f91c8/Linode.jpg" width="75%" height="75%" >

There are two use cases for ongoing Sitespeed testing:

+ Single domain
+ Competitive analysis

A single domain tests multiple pages on the same domain, and the competitive analysis runs a single page (typically the across multiple domains. The remainder of this document covers installation, test configuration, and administration.

## Installation
Scripts have been developed to streamline the installation process. All scripts referenced in this document can be found in this Github repository. The installation process can be done anywhere on the system. However, for purposes of this README, everything has been installed in `/home/greg`.

The first step on every machine is to install Docker, which can be done by executing the following command:
```
sudo ./install-docker.sh
```
Although not integral to the execution of Sitespeed, the following package should be installed on each machine since the program is referenced by a number of scripts and quite frankly is very handy:
```
sudo yum -y install tree
```

## **Sitespeed**

#### Step 1 - Create folder structure
Folder structure is very important. Regardless of the location, the following folders are required:

+ tld
+ comp
+ portal
+ logs

The `./tld` and `./comp` folders are for single domain and competitive analysis tests respectively. Each folder contains the Sitespeed `config.json`, test seed files, and the result of each Sitespeed test, `sitespeed-result`.

The `./portal` folder is the root folder that is served by the `nginx` web server. It also contains the key images that were collected by Sitespeed during each test. These images are overwritten with the latest images at the end of each Sitespeed test.

The `./logs` folder contains the `stdout` and `stderr` associated with each Sitespeed test. Logs are maintained on an individual test basis.

The root of the folder structure will contain the following scripts which are copied `push.sh`:

+ master.sh - Primary script that drives Sitespeed tests
+ nginx.sh - Automates the setting of folder permissions for web access
+ reset.sh - Erases all Sitespeed related test results. Does not touch Graphite database
+ syschk.sh - Displays the current state of key folders

#### Step 2 - Install `nginx`
```
sudo yum -y install nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

#### Step 3 - Configure `/etc/nginx/nginx.conf`
```
    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /home/greg/portal;
        # root         /usr/share/nginx/html;
```

#### Step 4 - Modify firewall rules
The following commands MUST be executed on a new installation
```
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --zone=public --add-port=80/tcp 
sudo firewall-cmd --permanent --list-all
```
Need to repeat for every required port

Run the following after the sitespeed-results have been created
```
sudo setfacl -m 'u:nginx:--x' /home/greg
```

#### Step 5 - Install `nc`
`nc` is used to write data directly to Graphite
```
sudo yum -y install nc
```

#### Step 6 - Setup SSH
SSH is used between each Sitespeed machine and Graphite during every run to log statistics.

Execute the following on each Sitespeed machine:
```
ssh-keygen -t rsa -b 2048 -f ~/.ssh/graphite-`date +%Y-%m-%d`
cp ~/.ssh/graphite-2022-01-05 id_rsa
eval `ssh-agent -s`
ssh-add
```

Do not to enter a passphrase during the `ssh-keygen` process. The `ssh-agent` and `ssh-add` will have to be restarted upon reboot.

Execute the following on Graphite:
```
cp "contents of graphite-2022-01-05.pub" into ~/.ssh/authorized_keys
sudo systemctl restart sshd
```

#### Step 7 - Install SSL certificate
Make sure `nginx` web server is up and running on port 80 BEFORE installing certificate.

Execute the following to install an SSL certificate:
```
sudo yum -y install dnf
sudo dnf -y install epel-release
sudo dnf -y upgrade
sudo yum -y install snapd
sudo systemctl enable --now snapd.socket
```

Log out and reboot the machine in order to activate the new device. Continue the process by executing the following:
```
sudo snap install core
sudo snap refresh core
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

Make sure everything above was successful before running final step
```
sudo certbot --nginx
```

When everything has successfully completed perfrom the following steps:
```
sudo systemctl restart nginx
sudo firewall-cmd --zone=public --add-port=443/tcp
```

Certificates can be renewed within 30 days of expiration. When it comes time to renew the SSL certificate use the following commands.

Test renewal
```
sudo certbot renew --dry-run
```

Check certificate
```
sudo certbot certificates
```

Renew certificates
```
sudo certbot renew
```

#### Step 8 - Install Linux packages to support Throttle
Sitespeed is configured to do emulated mobile testing, which throttles the CPU slower in order to emulate a slower mobile device.

Execute the following:
```
sudo yum -y install iproute-tc
sudo yum -y install kernel-modules-extra
```

Reboot to make active
```
sudo modprobe sch_netem
```

Confirm the module is loaded
```
lsmod | grep netem
```

## **Graphite**
The Graphite web interface is accessible on TCP port 8888. Carbon is name of the process that receives incoming data and is accessible on port TCP 2003.

Once a Linode external volume has been created, use the following steps to gain access to the storage.
To get started with a new Linode volume, create a filesystem:
```
mkfs.ext4 "/dev/disk/by-id/scsi-0Linode_Volume_data"
mkdir "/mnt/data"
mount "/dev/disk/by-id/scsi-0Linode_Volume_data" "/mnt/data"
mount "/dev/disk/by-id/scsi-0Linode_Volume_data" "/mnt/data"
```

To mount the volume every time the Linode boots, add the following line to `/etc/fstab file`:
```
/dev/disk/by-id/scsi-0Linode_Volume_data /mnt/data ext4 defaults,noatime,nofail 0 2
```

Execute the following script to start the Graphite container:
```
docker exec -it graphite /bin/sh
```

When the Graphite container comes up, the following structure will be created:

```
lrwxrwxrwx. 1 greg greg  24 Apr 29 05:57 graphite-conf -> /mnt/data/graphite-conf/
lrwxrwxrwx. 1 greg greg  27 Apr 29 05:56 graphite-storage -> /mnt/data/graphite-storage/
lrwxrwxrwx. 1 greg greg  26 Apr 29 05:58 graphite-webapp -> /mnt/data/graphite-webapp/
lrwxrwxrwx. 1 greg greg  14 Apr 29 05:58 log -> /mnt/data/log/
lrwxrwxrwx. 1 greg greg  16 Apr 29 05:59 nginx -> /mnt/data/nginx/
lrwxrwxrwx. 1 greg greg  24 Apr 29 05:59 statsd-config -> /mnt/data/statsd-config/
```

Modify the following configuration files in `./graphite-conf`:

+ carbon.conf
+ storage-aggregation.conf
+ storage-schemas.conf

Use the `*.conf` files provides in this repository, which provide optimized settings. Once they are put in place, restart the Graphite container.

Note - To display the entry point of a Docker container:
```
docker exec -it graphite ps -elf
```

## **Grafana**
Grafana uses an embedded Apache web server, which accessible on TCP port 3000.

Before installing Grafana add a new file to YUM repository so `yum` can be used to install and update Grafana. 

#### Step 1 - Create `grafana.repo`:
```
sudo vim /etc/yum.repos.d/grafana.repo
```

#### Step 2 - Add the following lines:
```
[grafana]
name=grafana-enterprise
baseurl=https://packages.grafana.com/enterprise/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
```

#### Step 3 - Install Grafana
```
sudo yum -y install grafana-enterprise
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl daemon-reload
sudo systemctl status grafana-server
```

#### Step 4  - Redirect inbound Grafana traffic
All of the Sitespeed servers go through Akamai. When Grafana gets installed, it listens on TCP port 3000 by default. Since Akamai does not support the forwading of port 3000, it is necessary to either change the Grafana listening port (e.g., 80) or redirect inbound port 80 traffic to the listening port of 3000. After a lot of testing it has been determined that the easiest solution is to use the redirection approach. Use the following command to redirect TCP port 80 to TCP port 3000:
```
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3000
```

#### Update Grafana
```
sudo yum -y update grafana-enterprise
```

Note - The default Grafana credentials are `admin/admin`

## Test Configuration

#### Step 1 - Create seed file
All tests require a seed file that contains the URLs of interest. The name of seed file is the name of a test and requires a file extension of `txt`. The following is an example of a test for ATT:
```
https://www.att.com/ Home ATT
https://www.att.com/deals/ Deals ATT
https://www.att.com/wireless/ Wireless ATT
https://www.att.com/buy/phones/ PLP ATT
https://www.att.com/buy/phones/apple-iphone-13-128gb-blue.html PDP ATT
```

There are three required fields:

+ Field 1: URL to be tested, which can include paths and query parameters
+ Field 2: URL alias name (cannot include spaces)
+ Field 3: Domain alias (cannot include spaces)

Depending on the type of test, the administrative script (`push.sh`) will place the seed file in either the `./tld` or `./comp` folder.

#### Step 2 - Create `crontab` entry
The file `mycron` is template that contains `crontab` entries that will be pushed to all Sitespeed Linodes. The following is an example:
```
45 * * * * ~/master.sh tld ATT XXX &>> ~/logs/YYY.ZZZ.msg.log
```

Description:
+ master.sh - script used to drive all tests
+ tld - name of test type
+ ATT - name of test
+ XXX - placeholder that gets updated during deployment, e.g., US-East, London
+ YYY.ZZZ - log file that contains all `stdout` and `stderr` for each test

When `push.sh cron update` gets run, XXX, YYY, ZZZ will be replaced with the correct settings.

## Administration
A script called `push.sh` automates the process of deploying key files and performing maintenance functions on each of the Sitespeed Linodes. The script has been developed to run from a local machine that uses the following folder structure:

```
├── Backups
├── Docker
├── Grafana
├── Graphite
├── Info
├── Portal
│   └── images
├── Seeds
└── Sitespeed
```

The entire folder structure and associated files will be created when the repository is cloned to a local disk.

The `push.sh` script requires one or more arguments depending on the function:
```
USAGE push arg1 [arg2 arg3]

DESCRIPTION Automates the distribution and/or execution of key scripts across all Linodes.
Intended to run from a local machine. If running from a Linode, be sure to modify the 
source path of the scripts.

The following options for arg1 are available:

	all	Copies Sitespeed scripts across all Linodes

	config	Copies config.json to ~/tld and ~/comp across all Linodes

	cron	Modifies crontab across all Linodes. Requires:

		arg2 = list|update|delete

	docker	Executes docker commands across all Linodes. Requires:

		arg2 = Version of Sitespeed (xx.y.z)

	index	Copies index.html to the main Sitespeed portal

	log	Checks for errors across all Linodes. Requires:

		arg2 = check|delete

	master	Copies master.sh across all Linodes

	nginx	Sets Web permissions across all Linodes

	reset	Deletes key data across all Linodes

	seed	Copies test URL seed file to all Linodes. Requires:

		arg2 = tld|comp
		arg3 = Name of URL seed file

	update	Updates YUM packages across all Linodes
```

The following is the workflow for updating the Sitespeed tests that are scheduled using `cron`. The flow is to display the current `crontab`, change the `mycron` template file, and then deploy the new `crontab`.

#### Step 1 - View the existing `crontab`
```
./push.sh cron list
5 * * * * /home/greg/master.sh tld ATT US-East &>> /home/greg/logs/tld.ATT.msg.log
35 * * * * /home/greg/master.sh comp Tapestry US-East &>> /home/greg/logs/comp.Tapestry.msg.log
```

Objective is to replace ATT with a new test called Abercrombie

#### Step 2 - Update `mycron` with new entry
```
5 * * * * ~/master.sh comp Abercrombie XXX &>> ~/logs/YYY.ZZZ.msg.log
35 * * * * ~/master.sh comp Tapestry XXX &>> ~/logs/YYY.ZZZ.msg.log

```

Make sure that the Abercrombie seed file exists! Also be sure that a c/r follows the last line in the file. 

#### Step 3 - Deploy the new `crontab`
```
./push.sh cron update
Starting US-East ... success
Starting US-Central ... success
Starting US-West ... success
Starting Toronto ... success
Starting London ... success
Starting Frankfurt ... success
Starting Singapore ... success
Starting Tokyo ... success
Starting Mumbai ... success
Starting Sydney ... success
10 Linodes updated
```

#### Step 4 - Confirm the new `crontab` looks good
```
./push.sh cron list
5 * * * * /home/greg/master.sh comp Abercrombie US-East &>> /home/greg/logs/comp.Abercrombie.msg.log
35 * * * * /home/greg/master.sh comp Tapestry US-East &>> /home/greg/logs/comp.Tapestry.msg.log
```

#### Step 5 - Deploy the new `Abercrombie` seed file
```
./push.sh seed comp Abercrombie
Starting US-East ... success
Starting US-Central ... success
Starting US-West ... success
Starting Toronto ... success
Starting London ... success
Starting Frankfurt ... success
Starting Singapore ... success
Starting Tokyo ... success
Starting Mumbai ... success
Starting Sydney ... success
10 Linodes updated
```
