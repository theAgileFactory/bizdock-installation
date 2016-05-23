# BizDock - Command line

The BizDock command line consists in a shell script : ```create.sh```.
This script is to be used to create a BizDock application instance which consists in one or two containers (depending on the selected options).


* [Pre-requisites](#pre-requisites)
* [BizDock containers](#bizdock-containers)
* [Create a BizDock instance](#create-a-new-bizdock-instance)
* [Start and stop a previously created BizDock instance](#start-and-stop-a-previously-created-bizdock-instance)
* [Upgrade a BizDock instance](#upgrade-a-bizdock-instance)
* [Backup a BizDock instance](#backup-a-bizdock-instance)
* [Database](#database)
* [Configuration files](#configuration-files)
* [Logs](#logs)

## Pre-requisites

BizDock requires a Docker engine version > 1.10 on a Linux host.

> Other systems have not been tested yet but may also work.

> The installation script ```create.sh``` has been tested on CentOS 7 but should run on any bash compatible Linux distribution


## BizDock containers

The BizDock installation consists into:
* at least one container named ```<<instance name>>_bizdock``` which is running the BizDock application
* optionally (if you do not specify a distant database to the ```create.sh``` script) a MariaDB database container named ```<<instance name>>_bizdockdb```

> ```<<instance name>>``` is the name of the BizDock instance you are creating.

> By default the ```create.sh``` script will attempt to create an instance named ```default```.


## Create a new BizDock instance

To create and run a BizDock, you need to use the ```create.sh``` script.
Use the ```-h``` flag to display the help.

By default this script will run two containers on the same host : one for the database and one for the application.
It is however possible to  use a database installed on a different host (please see the option ```-H``` of the ```create.sh``` script).

If the application container already exists, it will be stopped and the deleted.

If the database container already exists:
* if it is stopped it is deleted
* if it is started it is reused

The ```create.sh``` script creates two other scripts (the administration scripts):
* a ```start-<<instance name>>.sh``` script : to be used to start the BizDock instance
* a ```stop-<<instance name>>.sh``` script : to be used to stop the BizDock instance

*Please note* : 
* the ```create.sh``` script should be used only to create a new BizDock instance.
* the ```create.sh``` also creates a ```remove.sh``` script, both must not be deleted or moved to another folder

### Default

Running the ```create.sh``` without any option will:
* create a container ```default_bizdock``` (for the BizDock application container), this one will listen on the port ```8080```
* create a container ```default_bizdockdb``` with the default password for ```maf``` and ```root```
* create a docker network named ```default_bizdock_network```
* create a docker volume (for the database data) named ```default_bizdock_database```
* create a folder (in the folder where you run the script) named ```cfg``` containing the BizDock configuration files
* create a folder (in the folder where you run the script) named ```fs``` containing the BizDock file system (file attachments for instance)
* create a folder (in the folder where you run the script) named ```db``` containing the database dumps (backup) as well as the configuration script for the Cronjob managing the backup and the script used for the backup


### Interactive mode

By default the ```run.sh``` script run in interactive mode.

Before running the installation it will display the parameters for the installation and request a validation before proceeding.


### Options

You can give different arguments to the ```create.sh``` script :

* ```-a``` : BizDock instance name (default is "default"), required if you intend to run multiple instances on the same host
* ```-v``` : version of the BizDock image (default is "latest")
* ```-P``` : define the port on which you will access BizDock on your host
* ```-d``` : start a basic database container with default options (user: maf, password: maf)
* ```-s``` : define the database schema (name of the database)
* ```-u``` : define the user of the database (default: maf)
* ```-p``` : define the password for the database user (default: maf)
* ```-r``` : define the password for the database user root
* ```-H``` : define the database host and port (ex.: HOST:PORT) if you are using your own database (not the default BizDock database container)
* ```-b``` : define a mount point (on your host) where to store cron job for database dumps
* ```-c``` : define a mount point (on your host) where to store configuration files
* ```-m``` : define a mount point (on your host) where the BizDock file system is stored
* ```-i``` : reset and initialize the database (warning: this will erase the database)
* ```-w``` : BizDock binary additional parameters (to provide parameters to the play framework application)
* ```-z``` : additional parameters for the ```docker run``` command used to start the two containers
* ```-x``` : interactive mode (default is true) - will request the validation of the user before running the installation
* ```-h``` : print help


## Start and stop a previously created BizDock instance

Once your instance is created, you can control it using the two administration scripts generated during the installation:
* a ```start-<<instance name>>.sh``` script : to be used to start the BizDock instance
* a ```stop-<<instance name>>.sh``` script : to be used to stop the BizDock instance

These two scripts holds all the parameters you defined when creating your instance.

### Remark about the "stop" script

This script will stop and then delete the application and database containers (if this one exists).

IMPORTANT: the **volumes** and **network** are **NOT removed**.
You need to clean them manually.
Here are the name patterns for these objects:
* ```<<instance name>>_bizdock_database``` for the BizDock database volume (which is persisting the database data)
* ```<<instance name>>_bizbock_network``` for the BizDock bridge network which is dedicated to one instance


## Upgrade a BizDock instance

To upgrade a BizDock instance.
The old containers must be removed and the new version installed.
You must edit the ```start-<<instance name>>.sh``` script and change the value of the ```-v``` parameter.
You can then stop/start BizDock and the upgrade will be automatic.

> NB: by default the version is set to 'latest' which will always upgrade to the last recommended BizDock version

WARNING: do not execute ```run.sh``` with an older version (see parameter ```-v```) of BizDock than the one currently installed. This would break the installation and may corrupt your data.



## Backup a BizDock instance

Backing up a BizDock instance consists in:
* backing up the database (if you are using the default BizDock database container, see below)
* backing up the 3 mounted folders:
   * The database dump folder (see option ```-b``` of the ```create.sh``` script)
   * The configuration folder (see option ```-c``` of the ```create.sh``` script)
   * The BizDock file system folder (see option ```-m``` of the ```create.sh``` script)

## Database

[MariaDB](https://mariadb.org/) is the database used by BizDock.
In addition of the official Docker image of MariaDB, we add to our image a cron job to generete automatically some dumps of the database.

### Forcing the database backup

To force a database backup you should run the following command:

```docker exec <<instance name>>_bizdockdb /var/opt/db/cron/mysqldump_db.sh```

where ```<<instance name>>``` is the name of your BizDock instance.

This will create a database dump in your "dump" folder (see ```-b``` parameter of the installation script).

### Changing the database dump frequency

By default, the dump is done every day at 2 AM.
If you want to modify it, you simply need to modify the ```crontabFile``` in the database dump mount and restart the database container matching your instance (```docker restart <<instance name>>_bizdockdb```).
The file is located on the path you chose for parameter ```-b```.

### Using a remote database

You can use your own instance of MariaDB (version 10.1.12) instead of the default BizDock database container.
You can specify the database host and port using the ```-H``` parameter.

Do not forget to specify the:
* ```-s``` schema name
* ```-u``` user for accessing this schema

## Configuration files

You must set a folder on your host where to store the configuration files using the ```-c``` flag.
After running BizDock once, you will find in this folder the default configurations files.
You may the modify the BizDock configuration.
To enable the modifications, you simply need to stop and start the BizDock application.

### Default user

The installation creates a user:
* login : admin
* password : admin123

> WARNING: change it once your installation is started


## Logs

To get logs of containers, you can run ```docker logs <container-name>```.
You can find further informations on the [official documentation](https://docs.docker.com/engine/reference/commandline/logs/).

>NB: you can pass to the ```create.sh``` script some parameters for the ```docker run``` commands in order, for instance, to specify a specific log driver (example : ./create.sh -z "--log-driver=syslog")

