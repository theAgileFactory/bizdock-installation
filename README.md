# BizDock installation

This project contains:
* the Dockerfiles for the two BizDock application containers
  * [bizdock](https://github.com/theAgileFactory/bizdock-installation/tree/master/bizdock) : the application container
  * [bizdockdb](https://github.com/theAgileFactory/bizdock-installation/tree/master/bizdockdb) : the database container which is extending the standard MariaDB one
  * [bizdockutils](https://github.com/theAgileFactory/bizdock-installation/tree/master/bizdockutils) : a container to embed various useful scripts required by the BizDock installation process
* the script (build_image.sh to create the images using the published BizDock software components)
* the default [properties](https://github.com/theAgileFactory/bizdock-installation/tree/master/default-configuration) used for creating the installation package
* [cli](https://github.com/theAgileFactory/bizdock-installation/tree/master/cli) : the command line interface to be used to run the containers
