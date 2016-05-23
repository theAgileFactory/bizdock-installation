#!/bin/sh

HELP=$'Available options: \n\t-a - BizDock instance name (default is default)\n\t-x - interactive mode (default is true)\n\t-h - help' 

INSTANCE_NAME='default'
INTERACTIVE_MODE=true
DB_CONTAINER_DETECTED=false;

if [ $? != 0 ] # There was an error parsing the options
then
  echo "Unkown option $1"
  echo "$HELP"
  exit 1 
fi

# Process the arguments
while getopts ":P:u:k:a:v:s:u:p:r:H:c:m:b:dhxi" option
do
  case $option in
    a)
      INSTANCE_NAME="$OPTARG"
      ;;
    h)
      echo "$HELP"
      exit 0
      ;;
    x)
      INTERACTIVE_MODE="$OPTARG"
      ;;
    :)
      echo "Option -$OPTARG needs an argument"
      exit 1
      ;;
    \?)
      echo "$OPTARG : invalid option"
      exit 1
      ;;
  esac
done

INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdockdb$")
if [ $? -eq 0 ]; then
  DB_CONTAINER_DETECTED=true
fi

#Here is the configuration to be used
echo "---- WARNING ----"
echo "The BizDock instance $INSTANCE_NAME will be stopped and the corresponding containers destroyed"
echo "The container ${INSTANCE_NAME}_bizdock will stopped and deleted"
if [ "$DB_CONTAINER_DETECTED" = "true" ]; then
  echo "The container ${INSTANCE_NAME}_bizdockdb will stopped and deleted"
fi

if [ "$INTERACTIVE_MODE" = "true" ]; then
  read -p "Continue (y/n)?" choice
  case "$choice" in 
    y|Y ) echo "OK launching installation...";;
    * ) exit 1;;
  esac
fi

echo ">>> Stopping the BizDock application container ${INSTANCE_NAME}_bizdock..."
docker stop ${INSTANCE_NAME}_bizdock
echo "... blocking until the container is stopped..."
docker wait ${INSTANCE_NAME}_bizdock
echo "... ${INSTANCE_NAME}_bizdock is stopped !"
echo ">>> Deleting the application container ${INSTANCE_NAME}_bizdock..."
docker rm ${INSTANCE_NAME}_bizdock
echo "... ${INSTANCE_NAME}_bizdock is deleted !"

if [ "$DB_CONTAINER_DETECTED" = "true" ]; then
  echo ">>> Stopping the BizDock database container ${INSTANCE_NAME}_bizdockdb..."
  docker stop ${INSTANCE_NAME}_bizdockdb
  echo "... blocking until the container is stopped..."
  docker wait ${INSTANCE_NAME}_bizdockdb
  echo "... ${INSTANCE_NAME}_bizdockdb is stopped !"
  echo ">>> Deleting the database container ${INSTANCE_NAME}_bizdockdb..."
  docker rm ${INSTANCE_NAME}_bizdockdb
  echo "... ${INSTANCE_NAME}_bizdockdb is deleted !"
fi





