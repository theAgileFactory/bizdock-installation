# BizDock - Command line

The BizDock command line consists in a set of scripts run a BizDock instance.

BizDock is using Docker.

## Pre-requisites

BizDock requires a Docker engine version > 1.10 on a Linux host.

> Other systems have not been tested.

## Run the Docker container

To run BizDock, you need to use the ```run.sh``` script.
Use the ```-h``` flag to display the help.

By default this script will run two containers on the same host : one for the database and one for the application.
It is however possible to  use a database installed on a different host.

### Usage

You can give different arguments to the ```run.sh``` script :

* ```-a``` : BizDock instance name (default is "default"), required if you intend to run multiple instances on the same host
* ```-v``` : version of the BizDock image (default is "latest")
* ```-P``` : define the port on which you will access BizDock on your host (be careful to modify the configuration files as explained in the [development folder](https://github.com/theAgileFactory/bizdock-docker/blob/master/development-bizdock-image/README.md)
* ```-d``` : start a basic database container with default options (user: maf, password: maf)
* ```-s``` : define the database schema (name of the database)
* ```-u``` : define the user of the database (default: maf)
* ```-p``` : define the password for the database user (default: maf)
* ```-r``` : define the password for the database user root
* ```-b``` : define a mount point (on your host) where to store cron job for database dumps
* ```-H``` : define the database host and port (ex.: HOST:PORT)
* ```-c``` : define a mount point (on your host) where to store configuration files
* ```-m``` : define a mount point (on your host) where the maf-file-system is stored
* ```-k``` : additional parameters to be added to BizDock binary
* ```-i``` : reset and initialize the database (warning: this will erase the database)
* ```-k``` : interactive mode (default is true) - will request the valitation of the user before running the installation
* ```-h``` : print help

## Database

[MariaDB](https://mariadb.org/) is the database used by BizDock.
In addition of the official Docker image of MariaDB, we add to our image a cron job to make dumps of the database.

By default, the dump is done every day at 2 AM.
If you want to modify it, you simply need to modify the ```crontabFile``` on your host and restart the database container (```docker restart bizdockdb```).
The file is located on the path you chose for parameter ```-b```.

## Configuration files

You can set a folder on your host where to store the configuration files using the ```-c``` flag.
After running bizdock once, you will find in this folder the default configurations files.
Then, you can configure BizDock as you wish.
To enable the modifications, you simply need to restart the container using ```docker restart bizdock``` or using the ```run.sh``` script.

### Note

This is important to write paths with a ```/``` at the end of them to allow the folders creation for the ```maf-file-system```.

This is also important to keep consistency between arguments you give to the ```run.sh``` script and the configuration files (ports, user of the database,...).

## Logs

To get logs of containers, you can run ```docker logs <container-name>```.
You can find further informations on the [official documentation](https://docs.docker.com/engine/reference/commandline/logs/).

It is up to you to configure a tool to manage logs.
