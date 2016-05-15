#!/bin/sh

HELP=$'Available options: \n\t-a - BizDock instance name (default is default)\n\t-v - BizDock version (default is latest)\n\t-P - main Bizdock port (default is 8080)\n\t-d - start a database docker container (default if no -H is provided)\n\t-H - database host and port in case the db is not set up as a docker container (ex. HOST:PORT)\n\t-s - database schema (default is maf)\n\t-u - database user (default is maf)\n\t-p - user database password (default is maf)\n\t-r - root database password (default is root)\n\t-u - public URL (default is localhost:<BIZDOCK_PORT>)\n\t-b - mount point of db backup (MANDATORY)\n\t-c - mount point for configuration files (MANDATORY)\n\t-m - mount point of the maf-file-system volume on the host (MANDATORY)\n\t-k - additional parameters to be added to BizDock binary\n\t-i - reset and initialize database with default data (default is false)\n\t-x - interactive mode (default is true)\n\t-h - help' 

INSTANCE_NAME='default'
DOCKER_VERSION='latest'
DB_NAME_DEFAULT='maf'
DB_USER_DEFAULT='maf'
DB_USER_PASSWD_DEFAULT='maf'
DB_ROOT_PASSWD_DEFAULT='root'
DB_NAME=""
DB_USER=""
DB_USER_PASSWD=""
DB_ROOT_PASSWD=""
DB_HOST=""
CONFIG_VOLUME=""
DB_DUMPS=""
MAF_FS=""
BIZDOCK_PORT=8080
BIZDOCK_PORT_DEFAULT=8080
BIZDOCK_PUBLIC_URL=""
BIZDOCK_BIN_PARAMETERS=""
DISTANT_DB=false
CONFIGURE_DB=false
INTERACTIVE_MODE=true

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
    v)
      DOCKER_VERSION="$OPTARG"
      ;;
    P)
      BIZDOCK_PORT="$OPTARG"
      ;;
    d)
      DB_USER="$DB_USER_DEFAULT"
      DB_USER_PASSWD="$DB_USER_PASSWD_DEFAULT"
      ;;
    s)
      if [ -z "$DB_NAME" ]; then
        DB_NAME="$OPTARG"
      fi
      ;;
    b)
      DB_DUMPS="$OPTARG"
      if [ ! -d "$DB_DUMPS" ]; then
        echo ">> $DB_DUMPS does not exist. Please create it."
        exit 1
      fi
      ;;
    u)
      if [ -z "$DB_USER" ]; then
        DB_USER="$OPTARG"
      else
        DB_USER=$DB_USER_DEFAULT
      fi
      ;;
    p)
      if [ -z "$DB_USER_PASSWD" ]; then
        DB_USER_PASSWD="$OPTARG"
      else
        DB_USER_PASSWD=$DB_USER_PASSWD_DEFAULT
      fi
      ;;
    r)
      if [ -z "$DB_ROOT_PASSWD" ]; then
        DB_ROOT_PASSWD="$OPTARG"
      else
        DB_ROOT_PASSWD=$DB_ROOT_PASSWD_DEFAULT
      fi
      ;;
    H)
      if [ -z "$DB_HOST" ]; then
        DB_HOST="$OPTARG"
        TEMP_HOST=$(echo "$DB_HOST" | egrep -e '[a-zA-Z]+[a-zA-Z0-9]+:[0-9]+')
        if [ "$TEMP_HOST" != "$DB_HOST" ]; then
          echo "The host must have the format HOST:PORT"
          exit 1;
        fi
        DB_HOST="-p $DB_HOST"
        DISTANT_DB=true
      else
        DISTANT_DB=false
        DB_HOST=""
      fi
      ;;
    m)
      MAF_FS="$OPTARG"
      if [ ! -d "$MAF_FS" ]; then
        echo ">> $MAF_FS does not exist. Please create it."
        exit 1
      fi
      ;;
    c)
      CONFIG_VOLUME="$OPTARG"
      if [ ! -d "$CONFIG_VOLUME" ]; then
        echo ">> $CONFIG_VOLUME does not exist. Please create it."
        exit 1
      fi
      ;;
    u)
      BIZDOCK_PUBLIC_URL="$OPTARG"
      ;;
    k)
      BIZDOCK_BIN_PARAMETERS="$OPTARG"
      ;;
    h)
      echo "$HELP"
      exit 0
      ;;
    i)
      CONFIGURE_DB=true
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

#Check mandatory attributes
if [ ! -d "$MAF_FS" ]; then
  echo ">> Invalid maf filesystem folder path (see -m command line parameter)."
  exit 1
fi
if [ ! -d "$CONFIG_VOLUME" ]; then
  echo ">> Invalid configuration folder path (see -c command line parameter)."
  exit 1
fi
if [ ! -d "$DB_DUMPS" ]; then
  echo ">> Invalid database dump folder path (see -b command line parameter)."
  exit 1
fi

#Set defaults if needed
if [ -z "$DB_NAME" ]; then
  DB_NAME=$DB_NAME_DEFAULT
fi
if [ -z "$DB_USER" ]; then
  DB_USER=$DB_USER_DEFAULT
fi
if [ -z "$DB_USER_PASSWD" ]; then
  DB_USER_PASSWD=$DB_USER_PASSWD_DEFAULT
fi
if [ -z "$DB_ROOT_PASSWD" ]; then
  DB_ROOT_PASSWD=$DB_ROOT_PASSWD_DEFAULT
fi
if [ "$DISTANT_DB" = "false" ]; then
  DB_HOST="${INSTANCE_NAME}_bizdockdb:3306"
fi
MYSQL_HOSTNAME=$(echo $DB_HOST | cut -f1 -d:)
MYSQL_PORT=$(echo $DB_HOST | cut -f2 -d:)
if [ -z "$BIZDOCK_PUBLIC_URL" ]; then
  BIZDOCK_PUBLIC_URL="http://localhost:$BIZDOCK_PORT"
fi

#Here is the configuration to be used
echo "---- CONFIGURATION ----"
echo "INSTANCE_NAME = $INSTANCE_NAME"
echo "DOCKER_VERSION= $DOCKER_VERSION"
echo "DB_NAME = $DB_NAME"
echo "DB_USER = $DB_USER"
echo "CONFIG_VOLUME = $CONFIG_VOLUME"
echo "DB_DUMPS= $DB_DUMPS"
echo "MAF_FS= $MAF_FS"
echo "BIZDOCK_PORT = $BIZDOCK_PORT"
echo "DISTANT_DB = $DISTANT_DB"
echo "DB_HOST = $DB_HOST"
echo "CONFIGURE_DB = $CONFIGURE_DB"
echo "BIZDOCK_PUBLIC_URL = $BIZDOCK_PUBLIC_URL"
echo "BIZDOCK_BIN_PARAMETERS = $BIZDOCK_BIN_PARAMETERS"

if [ "$INTERACTIVE_MODE" = "true" ]; then
  read -p "Continue (y/n)?" choice
  case "$choice" in 
    y|Y ) echo "OK launching installation...";;
    * ) exit 1;;
  esac
fi

#Create network
NETWORK_TEST=$(docker network ls | grep ${INSTANCE_NAME}_bizdock_network)
if [ $? -eq 1 ]; then
  echo "---- NETWORK CREATION ----"
  docker network create ${INSTANCE_NAME}_bizdock_network
fi

#Run Bizdock Database
if [ "$DISTANT_DB" = "false" ]; then
  docker volume create --name=${INSTANCE_NAME}_bizdock_database

  INSTANCE_TEST=$(docker ps | grep -e "${INSTANCE_NAME}_bizdockdb$")
  if [ $? -eq 1 ]; then
    INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdockdb")
    if [ $? -eq 0 ]; then
      docker rm ${INSTANCE_NAME}_bizdockdb
    fi
    echo "---- RUNNING DATABASE CONTAINER ----"
    echo ">> By default, the database dump is done every day at 2 am."
    docker run --name=${INSTANCE_NAME}_bizdockdb -d --net=${INSTANCE_NAME}_bizdock_network \
      -v ${INSTANCE_NAME}_bizdock_database:/var/lib/mysql/ \
      -v ${DB_DUMPS}:/var/opt/db/dumps/ \
      -v ${DB_DUMPS}:/var/opt/db/cron/ \
      -e MYSQL_ROOT_PASSWORD="$DB_ROOT_PASSWD" \
      -e MYSQL_DATABASE="$DB_NAME" \
      -e MYSQL_USER="$DB_USER" \
      -e MYSQL_PASSWORD="$DB_USER_PASSWD" \
      -e MYSQL_DATABASE="$DB_NAME" \
      taf/bizdock_mariadb:10.1.12 --useruid $(id -u $(whoami)) --username $(whoami)

    #wait 15 seconds to give time to DB to start correctly before bizdock
    echo ">> Wait 15 seconds to ensure that the database container is started"
    sleep 15

    #test if db container is up
    if [ -z "$(docker ps | grep ${INSTANCE_NAME}_bizdockdb$)" ]; then
      echo "/!\\ Database container is not up. BizDock will not start /!\\"
      exit 1
    fi
  else
    echo ">> The database container is already running. If this is not the case, please remove it with the command 'docker rm ${INSTANCE_NAME}_bizdockdb'"
  fi

  IS_TABLE=$(docker exec -it ${INSTANCE_NAME}_bizdockdb mysql -h localhost -P 3306 -u "$DB_USER" -p"$DB_USER_PASSWD" -D "$DB_NAME" -e 'show tables;')
  if [ -z "$IS_TABLE" ]; then
    CONFIGURE_DB=true
  fi

else
  echo "/!\\ WARNING: you will have to modify the BizDock configuration to target the remove database and restart the container /!\\"
fi

#Run Bizdock
echo "---- RUNNING BIZDOCK ----"
INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdock$")
if [ $? -ne 1 ]; then
  docker stop ${INSTANCE_NAME}_bizdock
  docker rm ${INSTANCE_NAME}_bizdock
fi

docker run --name=${INSTANCE_NAME}_bizdock -d --net=${INSTANCE_NAME}_bizdock_network -p $BIZDOCK_PORT:$BIZDOCK_PORT_DEFAULT \
  -v ${CONFIG_VOLUME}:/opt/start-config/ \
  -v ${MAF_FS}:/opt/artifacts/maf-file-system/ \
  -e CONFIGURE_DB_INIT=$CONFIGURE_DB \
  -e MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWD \
  -e MYSQL_HOSTNAME=$MYSQL_HOSTNAME \
  -e MYSQL_PORT=$MYSQL_PORT \
  -e MYSQL_DATABASE=$DB_NAME \
  -e MYSQL_USER=$DB_USER \
  -e MYSQL_PASSWORD=$DB_USER_PASSWD \
  -e BIZDOCK_PORT=$BIZDOCK_PORT \
  -e BIZDOCK_PUBLIC_URL=$BIZDOCK_PUBLIC_URL \
  -e BIZDOCK_BIN_PARAMETERS=$BIZDOCK_BIN_PARAMETERS \
  taf/bizdock:${DOCKER_VERSION} --useruid $(id -u $(whoami)) --username $(whoami)


