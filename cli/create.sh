#!/bin/sh

HELP=$'Available options: \n\t-a - BizDock instance name (default is default)\n\t-v - BizDock version (default is latest)\n\t-P - main Bizdock port (default is 8080)\n\t-d - start a database docker container (default if no -H is provided)\n\t-H - database host and port in case the db is not set up as a docker container (ex. HOST:PORT)\n\t-s - database schema (default is maf)\n\t-u - database user (default is maf)\n\t-p - user database password (default is maf)\n\t-r - root database password (default is root)\n\t-j - public URL (default is localhost:<BIZDOCK_PORT>)\n\t-b - mount point of db backup (MANDATORY)\n\t-c - mount point for configuration files (MANDATORY)\n\t-m - mount point of the BizDock file-system volume on the host (MANDATORY)\n\t-i - reset and initialize database with default data (default is false)\n\t-w - BizDock binary additional parameters\n\t-z - docker run additional parameters\n\t-x - interactive mode (default is true)\n\t-h - help' 

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
DISTANT_DB=false
CONFIGURE_DB=false
INTERACTIVE_MODE=true
DOCKER_RUN_PARAMETERS=""
BIZDOCK_BIN_PARAMETERS=""

if [ $? != 0 ] # There was an error parsing the options
then
  echo "Unkown option $1"
  echo "$HELP"
  exit 1 
fi

# Process the arguments
while getopts ":P:u:k:a:v:s:j:p:r:H:c:m:b:x:w:z:dhi" option
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
    j)
      BIZDOCK_PUBLIC_URL="$OPTARG"
      ;;
    h)
      echo "$HELP"
      exit 0
      ;;
    w)
      BIZDOCK_BIN_PARAMETERS="$OPTARG"
      ;;
    z)
      DOCKER_RUN_PARAMETERS="$OPTARG"
      ;;
    x)
      INTERACTIVE_MODE="$OPTARG"
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

#Set defaults if needed
echo -e "\n\n---- COMPUTING CONFIGURATION ----\n"
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
if [ ! -d "$MAF_FS" ]; then
  echo -e ">> WARNING : No valid filesystem folder path (see -m command line parameter).\nA default folder will be created (if it does not exists) : $PWD/fs\n"
  MAF_FS="$PWD/fs"
fi
if [ ! -d "$CONFIG_VOLUME" ]; then
  echo -e ">> WARNING : No valid configuration folder path (see -c command line parameter).\nA default folder will be created (if it does not exists) : $PWD/cfg\n"
  CONFIG_VOLUME="$PWD/cfg"
fi
if [ ! -d "$DB_DUMPS" ]; then
  echo -e ">> WARNING : No valid database dump folder path (see -b command line parameter).\nA default folder will be created (if it does not exists) : $PWD/db\n"
  DB_DUMPS="$PWD/db"
fi

#Check if the instance name already exists
INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdock$")
if [ $? -eq 0 ]; then
  echo ">> WARNING : the instance name $INSTANCE_NAME is already in use and will be deleted !"
fi

#Here is the configuration to be used
echo -e "\n\n---- PROPOSED CONFIGURATION ----\n"
echo "Name of the BizDock instance         = $INSTANCE_NAME"
echo "Version of BizDock application image = $DOCKER_VERSION"
echo "Name of the database schema          = $DB_NAME"
echo "Name of the database user            = $DB_USER"
echo "Host mount for BizDock configuration = $CONFIG_VOLUME"
echo "Host mount for database dumps        = $DB_DUMPS"
echo "Host mount for BizDock file system   = $MAF_FS"
echo "Port on which BizDock will listen    = $BIZDOCK_PORT"
echo "True if a distant database is used   = $DISTANT_DB"
echo "Host of the distant database         = $DB_HOST"
echo "Reset the database ?                 = $CONFIGURE_DB"
echo "BizDock public URL                   = $BIZDOCK_PUBLIC_URL"
echo "BizDock binary special parameters    = $BIZDOCK_BIN_PARAMETERS"
echo "Docker run commands parameters       = $DOCKER_RUN_PARAMETERS"

if [ "$INTERACTIVE_MODE" = "true" ]; then
  read -p "Continue (y/n)?" choice
  case "$choice" in 
    y|Y ) echo "OK launching installation...";;
    * ) exit 1;;
  esac
fi

#Starting the installation
echo -e "\n\n---- INSTALLATION ----\n"

#Create the volume folders if they do not exists
mkdir -p $MAF_FS
mkdir -p $CONFIG_VOLUME
mkdir -p $DB_DUMPS

#Create network
NETWORK_TEST=$(docker network ls | grep -e "${INSTANCE_NAME}_bizdock_network")
if [ $? -eq 1 ]; then
  echo "---- NETWORK CREATION ----"
  docker network create ${INSTANCE_NAME}_bizdock_network
fi

#Run Bizdock Database Container if requested
if [ "$DISTANT_DB" = "false" ]; then
  echo "---- DATABASE VOLUME CREATION (if it does not exists) ----"
  docker volume create --name=${INSTANCE_NAME}_bizdock_database

  INSTANCE_TEST=$(docker ps | grep -e "${INSTANCE_NAME}_bizdockdb$")
  if [ $? -eq 1 ]; then
    INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdockdb$")
    if [ $? -eq 0 ]; then
      echo ">>> Deleting the stopped database container ${INSTANCE_NAME}_bizdockdb..."
      docker rm ${INSTANCE_NAME}_bizdockdb
      echo "... ${INSTANCE_NAME}_bizdockdb is deleted !"
    fi
    echo "---- RUNNING DATABASE CONTAINER ----"
    echo ">> Starting the database container ${INSTANCE_NAME}_bizdockdb ..."
    docker run $DOCKER_RUN_PARAMETERS --name=${INSTANCE_NAME}_bizdockdb -d --net=${INSTANCE_NAME}_bizdock_network \
      -v ${INSTANCE_NAME}_bizdock_database:/var/lib/mysql/ \
      -v ${DB_DUMPS}:/var/opt/db/dumps/ \
      -v ${DB_DUMPS}:/var/opt/db/cron/ \
      -e MYSQL_ROOT_PASSWORD="$DB_ROOT_PASSWD" \
      -e MYSQL_DATABASE="$DB_NAME" \
      -e MYSQL_USER="$DB_USER" \
      -e MYSQL_PASSWORD="$DB_USER_PASSWD" \
      -e MYSQL_DATABASE="$DB_NAME" \
      bizdock/bizdock_mariadb:10.1.12 --useruid $(id -u $(whoami)) --username $(whoami)
    echo "... start command completed"

    #wait 15 seconds to give time to DB to start correctly before bizdock
    echo ">> Wait 15 seconds to ensure that the database container is started"
    sleep 15

    #test if db container is up
    if [ -z "$(docker ps | grep ${INSTANCE_NAME}_bizdockdb$)" ]; then
      echo "/!\\ Database container is not up. BizDock will not start /!\\"
      exit 1
    fi
  else
    echo -e ">> A database container is already running, it will be reused.\n If are not willing this, please stop it using the docker command line :'docker stop ${INSTANCE_NAME}_bizdockdb'"
  fi

  IS_TABLE=$(docker exec -it ${INSTANCE_NAME}_bizdockdb mysql -h localhost -P 3306 -u "$DB_USER" -p"$DB_USER_PASSWD" -D "$DB_NAME" -e 'show tables;')
  if [ -z "$IS_TABLE" ]; then
    CONFIGURE_DB=true
  fi
fi

#Running Bizdock application container
echo "---- RUNNING BIZDOCK ----"
INSTANCE_TEST=$(docker ps | grep -e "${INSTANCE_NAME}_bizdock$")
if [ $? -eq 0 ]; then
  echo ">>> Stopping the existing BizDock application container ${INSTANCE_NAME}_bizdock..."
  docker stop ${INSTANCE_NAME}_bizdock
  echo "... blocking until the container is stopped..."
  docker wait ${INSTANCE_NAME}_bizdock
  echo "... ${INSTANCE_NAME}_bizdock is stopped !"
fi
INSTANCE_TEST=$(docker ps -a | grep -e "${INSTANCE_NAME}_bizdock$")
if [ $? -eq 0 ]; then
  echo ">>> Deleting the existing application container ${INSTANCE_NAME}_bizdock..."
  docker rm ${INSTANCE_NAME}_bizdock
  echo "... ${INSTANCE_NAME}_bizdock is deleted !"
fi

echo ">> Starting the container ${INSTANCE_NAME}_bizdock ..."
docker run $DOCKER_RUN_PARAMETERS --name=${INSTANCE_NAME}_bizdock -d --net=${INSTANCE_NAME}_bizdock_network -p $BIZDOCK_PORT:$BIZDOCK_PORT_DEFAULT \
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
  bizdock/bizdock:${DOCKER_VERSION} --useruid $(id -u $(whoami)) --username $(whoami)
echo "... start command completed"

echo ">>> Creating the administration scripts..."

cat > $SCRIPT_DIR/remove.tmp <<- EOM
IyEvYmluL3NoCgpIRUxQPSQnQXZhaWxhYmxlIG9wdGlvbnM6IFxuXHQtYSAtIEJpekRvY2sgaW5z
dGFuY2UgbmFtZSAoZGVmYXVsdCBpcyBkZWZhdWx0KVxuXHQteCAtIGludGVyYWN0aXZlIG1vZGUg
KGRlZmF1bHQgaXMgdHJ1ZSlcblx0LWggLSBoZWxwJyAKCklOU1RBTkNFX05BTUU9J2RlZmF1bHQn
CklOVEVSQUNUSVZFX01PREU9dHJ1ZQpEQl9DT05UQUlORVJfREVURUNURUQ9ZmFsc2U7CgppZiBb
ICQ/ICE9IDAgXSAjIFRoZXJlIHdhcyBhbiBlcnJvciBwYXJzaW5nIHRoZSBvcHRpb25zCnRoZW4K
ICBlY2hvICJVbmtvd24gb3B0aW9uICQxIgogIGVjaG8gIiRIRUxQIgogIGV4aXQgMSAKZmkKCiMg
UHJvY2VzcyB0aGUgYXJndW1lbnRzCndoaWxlIGdldG9wdHMgIjpQOnU6azphOnY6czp1OnA6cjpI
OmM6bTpiOmRoeGkiIG9wdGlvbgpkbwogIGNhc2UgJG9wdGlvbiBpbgogICAgYSkKICAgICAgSU5T
VEFOQ0VfTkFNRT0iJE9QVEFSRyIKICAgICAgOzsKICAgIGgpCiAgICAgIGVjaG8gIiRIRUxQIgog
ICAgICBleGl0IDAKICAgICAgOzsKICAgIHgpCiAgICAgIElOVEVSQUNUSVZFX01PREU9IiRPUFRB
UkciCiAgICAgIDs7CiAgICA6KQogICAgICBlY2hvICJPcHRpb24gLSRPUFRBUkcgbmVlZHMgYW4g
YXJndW1lbnQiCiAgICAgIGV4aXQgMQogICAgICA7OwogICAgXD8pCiAgICAgIGVjaG8gIiRPUFRB
UkcgOiBpbnZhbGlkIG9wdGlvbiIKICAgICAgZXhpdCAxCiAgICAgIDs7CiAgZXNhYwpkb25lCgpJ
TlNUQU5DRV9URVNUPSQoZG9ja2VyIHBzIC1hIHwgZ3JlcCAtZSAiJHtJTlNUQU5DRV9OQU1FfV9i
aXpkb2NrZGIkIikKaWYgWyAkPyAtZXEgMCBdOyB0aGVuCiAgREJfQ09OVEFJTkVSX0RFVEVDVEVE
PXRydWUKZmkKCiNIZXJlIGlzIHRoZSBjb25maWd1cmF0aW9uIHRvIGJlIHVzZWQKZWNobyAiLS0t
LSBXQVJOSU5HIC0tLS0iCmVjaG8gIlRoZSBCaXpEb2NrIGluc3RhbmNlICRJTlNUQU5DRV9OQU1F
IHdpbGwgYmUgc3RvcHBlZCBhbmQgdGhlIGNvcnJlc3BvbmRpbmcgY29udGFpbmVycyBkZXN0cm95
ZWQiCmVjaG8gIlRoZSBjb250YWluZXIgJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrIHdpbGwgc3Rv
cHBlZCBhbmQgZGVsZXRlZCIKaWYgWyAiJERCX0NPTlRBSU5FUl9ERVRFQ1RFRCIgPSAidHJ1ZSIg
XTsgdGhlbgogIGVjaG8gIlRoZSBjb250YWluZXIgJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrZGIg
d2lsbCBzdG9wcGVkIGFuZCBkZWxldGVkIgpmaQoKaWYgWyAiJElOVEVSQUNUSVZFX01PREUiID0g
InRydWUiIF07IHRoZW4KICByZWFkIC1wICJDb250aW51ZSAoeS9uKT8iIGNob2ljZQogIGNhc2Ug
IiRjaG9pY2UiIGluIAogICAgeXxZICkgZWNobyAiT0sgbGF1bmNoaW5nIGluc3RhbGxhdGlvbi4u
LiI7OwogICAgKiApIGV4aXQgMTs7CiAgZXNhYwpmaQoKZWNobyAiPj4+IFN0b3BwaW5nIHRoZSBC
aXpEb2NrIGFwcGxpY2F0aW9uIGNvbnRhaW5lciAke0lOU1RBTkNFX05BTUV9X2JpemRvY2suLi4i
CmRvY2tlciBzdG9wICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9jawplY2hvICIuLi4gYmxvY2tpbmcg
dW50aWwgdGhlIGNvbnRhaW5lciBpcyBzdG9wcGVkLi4uIgpkb2NrZXIgd2FpdCAke0lOU1RBTkNF
X05BTUV9X2JpemRvY2sKZWNobyAiLi4uICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9jayBpcyBzdG9w
cGVkICEiCmVjaG8gIj4+PiBEZWxldGluZyB0aGUgYXBwbGljYXRpb24gY29udGFpbmVyICR7SU5T
VEFOQ0VfTkFNRX1fYml6ZG9jay4uLiIKZG9ja2VyIHJtICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9j
awplY2hvICIuLi4gJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrIGlzIGRlbGV0ZWQgISIKCmlmIFsg
IiREQl9DT05UQUlORVJfREVURUNURUQiID0gInRydWUiIF07IHRoZW4KICBlY2hvICI+Pj4gU3Rv
cHBpbmcgdGhlIEJpekRvY2sgZGF0YWJhc2UgY29udGFpbmVyICR7SU5TVEFOQ0VfTkFNRX1fYml6
ZG9ja2RiLi4uIgogIGRvY2tlciBzdG9wICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9ja2RiCiAgZWNo
byAiLi4uIGJsb2NraW5nIHVudGlsIHRoZSBjb250YWluZXIgaXMgc3RvcHBlZC4uLiIKICBkb2Nr
ZXIgd2FpdCAke0lOU1RBTkNFX05BTUV9X2JpemRvY2tkYgogIGVjaG8gIi4uLiAke0lOU1RBTkNF
X05BTUV9X2JpemRvY2tkYiBpcyBzdG9wcGVkICEiCiAgZWNobyAiPj4+IERlbGV0aW5nIHRoZSBk
YXRhYmFzZSBjb250YWluZXIgJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrZGIuLi4iCiAgZG9ja2Vy
IHJtICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9ja2RiCiAgZWNobyAiLi4uICR7SU5TVEFOQ0VfTkFN
RX1fYml6ZG9ja2RiIGlzIGRlbGV0ZWQgISIKZmkKCgoKCgo=
EOM

cat $SCRIPT_DIR/remove.tmp | base64 -d > $SCRIPT_DIR/remove.sh
rm $SCRIPT_DIR/remove.tmp
chmod u+x $SCRIPT_DIR/remove.sh


#Create the startup and stop scripts to be used later for starting and stopping bizdock
#Startup script
echo '#!/bin/sh' > $SCRIPT_DIR/start-$INSTANCE_NAME.sh
echo -e "$SCRIPT_DIR/create.sh -a '$INSTANCE_NAME' -v '$DOCKER_VERSION' -P '$BIZDOCK_PORT' -b '$DB_DUMPS' -c '$CONFIG_VOLUME' -m '$MAF_FS' -w '$BIZDOCK_BIN_PARAMETERS' -z '$DOCKER_RUN_PARAMETERS'" >> $SCRIPT_DIR/start-$INSTANCE_NAME.sh
chmod u+x $SCRIPT_DIR/start-$INSTANCE_NAME.sh
#Stopping script
echo '#!/bin/sh' > $SCRIPT_DIR/stop-$INSTANCE_NAME.sh
echo -e "$SCRIPT_DIR/remove.sh -a $INSTANCE_NAME" >> $SCRIPT_DIR/stop-$INSTANCE_NAME.sh
chmod u+x $SCRIPT_DIR/stop-$INSTANCE_NAME.sh

echo "... scripts created"
