# BizDock - Command line

The BizDock command line consists in a shell script : ```run.sh```.
This script is to be used to run the BizDock application which consists in one or two containers (depending on the selected options).

## Pre-requisites

BizDock requires a Docker engine version > 1.10 on a Linux host.

> Other systems have not been tested yet but may also work.


## BizDock containers

The BizDock installation consists into:
* at least one container named ```<<instance name>>_bizdock``` which is running the BizDock application
* optionally (if you do not specify a distant database to the ```run.sh``` script) a MariaDB database container named ```<<instance name>>_bizdockdb```

```<<instance name>>``` is the name of the BizDock instance you are creating.
By default the ```run.sh``` script will attempt to create an instance named ```default```.


## Run a BizDock instance

To run BizDock, you need to use the ```run.sh``` script.
Use the ```-h``` flag to display the help.

By default this script will run two containers on the same host : one for the database and one for the application.
It is however possible to  use a database installed on a different host.
If the application container already exists, it will be stopped and the deleted.
If the database container already exists:
* if it is stopped it is deleted
* if it is started it is reused

### Usage

You can give different arguments to the ```run.sh``` script :

* ```-a``` : BizDock instance name (default is "default"), required if you intend to run multiple instances on the same host
* ```-v``` : version of the BizDock image (default is "latest")
* ```-P``` : define the port on which you will access BizDock on your host
* ```-d``` : start a basic database container with default options (user: maf, password: maf)
* ```-s``` : define the database schema (name of the database)
* ```-u``` : define the user of the database (default: maf)
* ```-p``` : define the password for the database user (default: maf)
* ```-r``` : define the password for the database user root
* ```-H``` : define the database host and port (ex.: HOST:PORT)
* ```-b``` : define a mount point (on your host) where to store cron job for database dumps
* ```-c``` : define a mount point (on your host) where to store configuration files
* ```-m``` : define a mount point (on your host) where the BizDock file system is stored
* ```-i``` : reset and initialize the database (warning: this will erase the database)
* ```-k``` : interactive mode (default is true) - will request the valitation of the user before running the installation
* ```-h``` : print help

IMPORTANT : you can modify the ```run.sh``` script for specific situations where you need to:
* provide some specific parameters to the BizDock application GUI (example: for proxy configuration)
* provide some specific parameters to the Docker containers run commands (example: changing the log driver)


## Upgrade a BizDock instance

To upgrade a BizDock instance, simply run ```run.sh``` script again.
The old containers will be removed and the new version installed.

WARNING: do not execute ```run.sh``` with an older version of BizDock than the one currently installed.
This would break the installation and may corrupt your data.


## Backup a BizDock instance

Backing up a BizDock instance consists in:
* backing up the database (if you are using the default BizDock database container, see below)
* backing up the 3 mounted folders:
   * The database dump folder (see option ```-b``` of the ```run.sh``` script)
   * The configuration folder (see option ```-c``` of the ```run.sh``` script)
   * The BizDock file system folder (see option ```-m``` of the ```run.sh``` script)


## Stop a BizDock instance

To stop a BizDock instance, you need to use the ```stop.sh``` script.
This one will stop and then delete the application and database containers (if this one exists).

IMPORTANT: the volumes and network are NOT removed.
You need to clean them manually.
Here are the name patterns for these objects:
* ```<<instance name>>_bizdock_database``` for the BizDock database volume (which is persisting the database data)
* ```<<instance name>>_bizbock_network``` for the BizDock bridge network which is dedicated to one instance


## Database

[MariaDB](https://mariadb.org/) is the database used by BizDock.
In addition of the official Docker image of MariaDB, we add to our image a cron job to make dumps of the database.

### Forcing the database backup

To force a database backup you should run the following command:

```docker exec <<instance name>>_bizdockdb /var/opt/db/cron/mysqldump_db.sh```

where ```<<instance name>>``` is the name of your BizDock instance.

This will create a database dump in your "dump" folder (see ```run.sh``` parameters).

### Changing the database dump frequency

By default, the dump is done every day at 2 AM.
If you want to modify it, you simply need to modify the ```crontabFile``` in the database dump mount and restart the database container matching your instance (```docker restart <<instance name>>_bizdockdb```).
The file is located on the path you chose for parameter ```-b```.

## Configuration files

You must set a folder on your host where to store the configuration files using the ```-c``` flag.
After running BizDock once, you will find in this folder the default configurations files.
You may the modify the BizDock configuration.
To enable the modifications, you simply need to restart the container using the ```run.sh``` script.

### Default user

The installation creates a user:
* login : admin
* password : admin123

> WARNING: change it once your installation is started

### Note

This is also important to keep consistency between arguments you give to the ```run.sh``` script and the configuration files (ports, user of the database,...).


## Logs

To get logs of containers, you can run ```docker logs <container-name>```.
You can find further informations on the [official documentation](https://docs.docker.com/engine/reference/commandline/logs/).

