#!/bin/sh

HELP=$'Available options: \n\t-a - BizDock instance name (default is default)\n\t-v - BizDock version (default is latest)\n\t-P - main Bizdock port (default is 8080)\n\t-d - start a database docker container (default if no -H is provided)\n\t-H - database host and port in case the db is not set up as a docker container (ex. HOST:PORT)\n\t-s - database schema (default is maf)\n\t-u - database user (default is maf)\n\t-p - user database password (default is maf)\n\t-r - root database password (default is root)\n\t-j - public URL (default is localhost:<BIZDOCK_PORT>)\n\t-b - mount point of db backup (MANDATORY)\n\t-c - mount point for configuration files (MANDATORY)\n\t-m - mount point of the BizDock file-system volume on the host (MANDATORY)\n\t-i - reset and initialize database with default data (default is false)\n\t-w - BizDock binary additional parameters\n\t-z - docker run additional parameters\n\t-x - interactive mode (default is true)\n\t-t - test data (default is false)\n\t-h - help' 

CLI_VERSION="1.0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIZDOCK_USERNAME=$(whoami)
BIZDOCK_USERNAME_DEFAULT='maf'
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
TEST_DATA=false
DOCKER_RUN_PARAMETERS=""
BIZDOCK_BIN_PARAMETERS=""

if [ $? != 0 ] # There was an error parsing the options
then
  echo "Unkown option $1"
  echo "$HELP"
  exit 1 
fi

# Process the arguments
while getopts ":P:u:k:a:v:s:j:p:r:H:c:m:b:x:w:z:t:dhi" option
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
    t)
      TEST_DATA="$OPTARG"
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
if ! [[ "$BIZDOCK_USERNAME" =~ "[a-z_][a-z0-9_]{0,30}" ]]; then
  #If the user is not a valid user name, use the default
  echo ">> The user name $BIZDOCK_USERNAME is not valid, using the default one instead : $BIZDOCK_USERNAME_DEFAULT"
  BIZDOCK_USERNAME=$BIZDOCK_USERNAME_DEFAULT
fi

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
echo "Name of the BizDock instance          = $INSTANCE_NAME"
echo "Version of BizDock application image  = $DOCKER_VERSION"
echo "Name of the database schema           = $DB_NAME"
echo "Name of the database user             = $DB_USER"
echo "Host mount for BizDock configuration  = $CONFIG_VOLUME"
echo "Host mount for database dumps         = $DB_DUMPS"
echo "Host mount for BizDock file system    = $MAF_FS"
echo "Port on which BizDock will listen     = $BIZDOCK_PORT"
echo "True if a distant database is used    = $DISTANT_DB"
echo "Host of the distant database          = $DB_HOST"
echo "Reset the database ?                  = $CONFIGURE_DB"
echo "BizDock public URL                    = $BIZDOCK_PUBLIC_URL"
echo "BizDock binary special parameters     = $BIZDOCK_BIN_PARAMETERS"
echo "Docker run commands parameters        = $DOCKER_RUN_PARAMETERS"
echo "Reset the database and load test data = $TEST_DATA"

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
      -e MYSQL_USER="$DB_USER" \
      -e MYSQL_PASSWORD="$DB_USER_PASSWD" \
      -e MYSQL_DATABASE="$DB_NAME" \
      bizdock/bizdock_mariadb:10.1.12 --useruid $(id -u $(whoami)) --username $BIZDOCK_USERNAME
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
docker run $DOCKER_RUN_PARAMETERS --name=${INSTANCE_NAME}_bizdock -d --net=${INSTANCE_NAME}_bizdock_network -p $BIZDOCK_PORT:8080 \
  -v ${CONFIG_VOLUME}:/opt/start-config/ \
  -v ${MAF_FS}:/opt/artifacts/maf-file-system/ \
  -e CONFIGURE_DB_INIT=$CONFIGURE_DB \
  -e MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWD \
  -e MYSQL_HOSTNAME=$MYSQL_HOSTNAME \
  -e MYSQL_PORT=$MYSQL_PORT \
  -e MYSQL_DATABASE=$DB_NAME \
  -e MYSQL_USER=$DB_USER \
  -e MYSQL_PASSWORD=$DB_USER_PASSWD \
  -e TEST_DATA="$TEST_DATA" \
  -e BIZDOCK_PORT=$BIZDOCK_PORT \
  -e BIZDOCK_PUBLIC_URL=$BIZDOCK_PUBLIC_URL \
  -e BIZDOCK_BIN_PARAMETERS=$BIZDOCK_BIN_PARAMETERS \
  -e CLI_VERSION=$CLI_VERSION \
  bizdock/bizdock:${DOCKER_VERSION} --useruid $(id -u $(whoami)) --username $BIZDOCK_USERNAME
echo "... start command completed"

echo ">>> Creating the administration scripts..."

cat > $SCRIPT_DIR/remove.tmp <<- EOM
IyEvYmluL3NoCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBUaGlzIHNjcmlwdCBtdXN0IGJl
IGJhc2U2NCBlbmNvZGVkIGFuZCBpbnNlcnRlZCBpbnRvIHRoZSBjcmVhdGUuc2ggc2NyaXB0Ogoj
IGNhdCBkZWxldGUuc2ggfCBiYXNlNjQgPiBlbWJlZGRlZC50eHQKIyAtLS0tLS0tLS0tLS0tLS0t
LS0tLS0tCgpIRUxQPSQnQXZhaWxhYmxlIG9wdGlvbnM6IFxuXHQtYSAtIEJpekRvY2sgaW5zdGFu
Y2UgbmFtZSAoZGVmYXVsdCBpcyBkZWZhdWx0KVxuXHQtZCAtIFN0b3AgdGhlIGRhdGFiYXNlIGNv
bnRhaW5lciAoZGVmYXVsdCBpcyB0cnVlKVxuXHQteCAtIGludGVyYWN0aXZlIG1vZGUgKGRlZmF1
bHQgaXMgdHJ1ZSlcblx0LWggLSBoZWxwJyAKCklOU1RBTkNFX05BTUU9J2RlZmF1bHQnCklOVEVS
QUNUSVZFX01PREU9dHJ1ZQpTVE9QX0RBVEFCQVNFPXRydWUKREJfQ09OVEFJTkVSX0RFVEVDVEVE
PWZhbHNlOwoKaWYgWyAkPyAhPSAwIF0gIyBUaGVyZSB3YXMgYW4gZXJyb3IgcGFyc2luZyB0aGUg
b3B0aW9ucwp0aGVuCiAgZWNobyAiVW5rb3duIG9wdGlvbiAkMSIKICBlY2hvICIkSEVMUCIKICBl
eGl0IDEgCmZpCgojIFByb2Nlc3MgdGhlIGFyZ3VtZW50cwp3aGlsZSBnZXRvcHRzICI6UDp1Oms6
YTp2OnM6dTpwOnI6SDpjOm06YjpkaHhpIiBvcHRpb24KZG8KICBjYXNlICRvcHRpb24gaW4KICAg
IGEpCiAgICAgIElOU1RBTkNFX05BTUU9IiRPUFRBUkciCiAgICAgIDs7CiAgICBkKQogICAgICBT
VE9QX0RBVEFCQVNFPSIkT1BUQVJHIgogICAgICA7OwogICAgaCkKICAgICAgZWNobyAiJEhFTFAi
CiAgICAgIGV4aXQgMAogICAgICA7OwogICAgeCkKICAgICAgSU5URVJBQ1RJVkVfTU9ERT0iJE9Q
VEFSRyIKICAgICAgOzsKICAgIDopCiAgICAgIGVjaG8gIk9wdGlvbiAtJE9QVEFSRyBuZWVkcyBh
biBhcmd1bWVudCIKICAgICAgZXhpdCAxCiAgICAgIDs7CiAgICBcPykKICAgICAgZWNobyAiJE9Q
VEFSRyA6IGludmFsaWQgb3B0aW9uIgogICAgICBleGl0IDEKICAgICAgOzsKICBlc2FjCmRvbmUK
CklOU1RBTkNFX1RFU1Q9JChkb2NrZXIgcHMgLWEgfCBncmVwIC1lICIke0lOU1RBTkNFX05BTUV9
X2JpemRvY2tkYiQiKQppZiBbICQ/IC1lcSAwIF07IHRoZW4KICBEQl9DT05UQUlORVJfREVURUNU
RUQ9dHJ1ZQpmaQoKI0hlcmUgaXMgdGhlIGNvbmZpZ3VyYXRpb24gdG8gYmUgdXNlZAplY2hvICIt
LS0tIFdBUk5JTkcgLS0tLSIKZWNobyAiVGhlIEJpekRvY2sgaW5zdGFuY2UgJElOU1RBTkNFX05B
TUUgd2lsbCBiZSBzdG9wcGVkIGFuZCB0aGUgY29ycmVzcG9uZGluZyBjb250YWluZXJzIGRlc3Ry
b3llZCIKZWNobyAiVGhlIGNvbnRhaW5lciAke0lOU1RBTkNFX05BTUV9X2JpemRvY2sgd2lsbCBz
dG9wcGVkIGFuZCBkZWxldGVkIgppZiBbICIkREJfQ09OVEFJTkVSX0RFVEVDVEVEIiA9ICJ0cnVl
IiBdOyB0aGVuCiAgaWYgWyAiJFNUT1BfREFUQUJBU0UiID0gInRydWUiIF07IHRoZW4KICAgIGVj
aG8gIlRoZSBjb250YWluZXIgJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrZGIgd2lsbCBzdG9wcGVk
IGFuZCBkZWxldGVkIgogIGVsc2UKICAgIGVjaG8gIlRoZSBjb250YWluZXIgJHtJTlNUQU5DRV9O
QU1FfV9iaXpkb2NrZGIgd2lsbCBOT1QgYmUgc3RvcHBlZCIKICBmaQpmaQoKaWYgWyAiJElOVEVS
QUNUSVZFX01PREUiID0gInRydWUiIF07IHRoZW4KICByZWFkIC1wICJDb250aW51ZSAoeS9uKT8i
IGNob2ljZQogIGNhc2UgIiRjaG9pY2UiIGluIAogICAgeXxZICkgZWNobyAiT0sgbGF1bmNoaW5n
IGluc3RhbGxhdGlvbi4uLiI7OwogICAgKiApIGV4aXQgMTs7CiAgZXNhYwpmaQoKZWNobyAiPj4+
IFN0b3BwaW5nIHRoZSBCaXpEb2NrIGFwcGxpY2F0aW9uIGNvbnRhaW5lciAke0lOU1RBTkNFX05B
TUV9X2JpemRvY2suLi4iCmRvY2tlciBzdG9wICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9jawplY2hv
ICIuLi4gYmxvY2tpbmcgdW50aWwgdGhlIGNvbnRhaW5lciBpcyBzdG9wcGVkLi4uIgpkb2NrZXIg
d2FpdCAke0lOU1RBTkNFX05BTUV9X2JpemRvY2sKZWNobyAiLi4uICR7SU5TVEFOQ0VfTkFNRX1f
Yml6ZG9jayBpcyBzdG9wcGVkICEiCmVjaG8gIj4+PiBEZWxldGluZyB0aGUgYXBwbGljYXRpb24g
Y29udGFpbmVyICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9jay4uLiIKZG9ja2VyIHJtICR7SU5TVEFO
Q0VfTkFNRX1fYml6ZG9jawplY2hvICIuLi4gJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrIGlzIGRl
bGV0ZWQgISIKCmlmIFsgIiREQl9DT05UQUlORVJfREVURUNURUQiID0gInRydWUiIF07IHRoZW4K
ICBpZiBbICIkU1RPUF9EQVRBQkFTRSIgPSAidHJ1ZSIgXTsgdGhlbgogICAgZWNobyAiPj4+IFN0
b3BwaW5nIHRoZSBCaXpEb2NrIGRhdGFiYXNlIGNvbnRhaW5lciAke0lOU1RBTkNFX05BTUV9X2Jp
emRvY2tkYi4uLiIKICAgIGRvY2tlciBzdG9wICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9ja2RiCiAg
ICBlY2hvICIuLi4gYmxvY2tpbmcgdW50aWwgdGhlIGNvbnRhaW5lciBpcyBzdG9wcGVkLi4uIgog
ICAgZG9ja2VyIHdhaXQgJHtJTlNUQU5DRV9OQU1FfV9iaXpkb2NrZGIKICAgIGVjaG8gIi4uLiAk
e0lOU1RBTkNFX05BTUV9X2JpemRvY2tkYiBpcyBzdG9wcGVkICEiCiAgICBlY2hvICI+Pj4gRGVs
ZXRpbmcgdGhlIGRhdGFiYXNlIGNvbnRhaW5lciAke0lOU1RBTkNFX05BTUV9X2JpemRvY2tkYi4u
LiIKICAgIGRvY2tlciBybSAke0lOU1RBTkNFX05BTUV9X2JpemRvY2tkYgogICAgZWNobyAiLi4u
ICR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9ja2RiIGlzIGRlbGV0ZWQgISIKICBmaQpmaQoKZWNobyAt
ZSAiXG5XQVJOSU5HOiBUaGUgbmV0d29yayB1c2VkIGJ5IHRoaXMgaW5zdGFuY2UgKCR7SU5TVEFO
Q0VfTkFNRX1fYml6ZG9ja19uZXR3b3JrKSBhcyB3ZWxsIGFzIHRoZSBuYW1lZCB2b2x1bWUgdXNl
ZCBieSB0aGUgZGF0YWJhc2UgKCR7SU5TVEFOQ0VfTkFNRX1fYml6ZG9ja19kYXRhYmFzZSkgYXJl
IE5PVCBkZWxldGVkIGJ5IHRoaXMgc2NyaXB0XG4iCmVjaG8gLWUgIklmIHlvdSBuZWVkIHRvIHJl
bW92ZSB0aGVtLCB5b3UgbXVzdCBwcm9jZWVkIG1hbnVhbGx5LiIKCgoKCgo=
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
#Stopping application only script
echo '#!/bin/sh' > $SCRIPT_DIR/stop-application-$INSTANCE_NAME.sh
echo -e "$SCRIPT_DIR/remove.sh -a $INSTANCE_NAME" -d false >> $SCRIPT_DIR/stop-application-$INSTANCE_NAME.sh
chmod u+x $SCRIPT_DIR/stop-application-$INSTANCE_NAME.sh
echo "... scripts created"

echo -e "\n**** BizDock is starting, please wait 30 seconds before calling $BIZDOCK_PUBLIC_URL BizDock may need a bit of time to start ****"
