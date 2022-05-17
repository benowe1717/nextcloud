# ABOUT
I Run a NextCloud instance for having fun with sharing and accessing files from outside of my network when I'm on the go, mostly for me but open for family and friends as well.

As any good server administrator should know, your deployment is only as good as your backups! This repository here serves as that backup script.

# USAGE
To use this script you are going to need a few things:
- Linux (I wrote and tested on Ubuntu 20.04 LTS, this should work for other Linux flavors and distributions)
- NextCloud ( https://nextcloud.com/ )
- N-Able Backup ( https://www.n-able.com/products/backup )

Either download and unpack the zip file, or git clone the repo, and run the main script like: ```sudo ./nextcloud_backup.sh```

# CONFIGURATION
In the nextcloud_backup.sh script, you will want to review lines 20 and 21 to ensure that it matches your NextCloud install and data directories.

Example:
```
APP_DIR=/var/www/nextcloud
DATA_DIR=/nextcloud
```

Could be changed to
```
APP_DIR=/home/nextcloud
DATA_DIR=/var/lib/nextcloud
```

You will also want to review line 23 to ensure that the right user that is running your NextCloud instance is configured correctly.

Example:
```
USER="www-data"
```

Could be changed to
```
USER="pi"
```

Lastly, please make sure to review line 82 to ensure that the Database Host is configured correctly. In most cases this should be localhost, but if you are running the database for NextCloud on another host, you'll need to change that.

Example:
```
DBHOST="localhost"
```

Could be changed to
```
DBHOST="192.168.1.10"
```