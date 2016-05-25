#!/bin/bash

set -e

#Default entrypoint for the container
HELP="Possible arguments :
--help (-h)
--useruid (-g)   : the uid required for accessing the host files
--username (-u)  : the name of the user required for accessing the host files"

echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD"
echo "MYSQL_HOSTNAME=$MYSQL_HOSTNAME"
echo "MYSQL_PORT=$MYSQL_PORT"
echo "MYSQL_DATABASE=$MYSQL_DATABASE"
echo "MYSQL_USER=$MYSQL_USER"
echo "MYSQL_PASSWORD=$MYSQL_PASSWORD"

while [[ $# > 0 ]]
do
  key="$1"
  case $key in
    -h|--help)
      echo $HELP
      exit 0
      ;;
    -u|--username)
      userName=$2
      shift
      ;;
    -g|--useruid)
      userUid=$2
      shift
      ;;
    *)
      echo "Unknown parameter $1 exiting"
      exit 1
      ;;
  esac
  shift
done

#Create a user with the right UID to allow access to the files from the host
if [[ ! -z "$userUid" ]] && [[ ! -z "$userName" ]]  ; then
  user=$(id -u $userName > /dev/null 2>&1; echo $?)
  if [ $user -eq 1 ]; then
    useradd -u $userUid $userName
  fi

  /opt/scripts/update_bashrc.sh

  echo "---- PREPARING THE CONFIGURATION ----"
  START_CONFIG=$(find "/opt/start-config" -type f -exec echo Found file {} \;)
  if [ -z "$START_CONFIG" ]; then
    echo "---- UPDATING THE CONFIGURATION FILES WITH DB HOST AND PASSWORD (in case they have been change with CLI) ----"
    
    #Changing the environment.conf configuration
    sed "s/db\.default\.url=.*/db\.default\.url=\"jdbc:mysql:\/\/$MYSQL_HOSTNAME:$MYSQL_PORT\/$MYSQL_DATABASE\"/g" /opt/maf/maf-desktop/conf/environment.conf > tmp.cfg
    mv tmp.cfg /opt/maf/maf-desktop/conf/environment.conf
    sed "s/username=.*/username=\"$MYSQL_USER\"/g" /opt/maf/maf-desktop/conf/environment.conf > tmp.cfg
    mv tmp.cfg /opt/maf/maf-desktop/conf/environment.conf
    sed "s/password=.*/password=\"$MYSQL_PASSWORD\"/g" /opt/maf/maf-desktop/conf/environment.conf > tmp.cfg
    mv tmp.cfg /opt/maf/maf-desktop/conf/environment.conf

    #Changing the framework.conf configuration
    sed "s,maf\.public\.url=.*,maf\.public\.url=\"$BIZDOCK_PUBLIC_URL\",g" /opt/maf/maf-desktop/conf/framework.conf > tmp.cfg
    mv tmp.cfg /opt/maf/maf-desktop/conf/framework.conf
    sed "s,swagger\.api\.basepath=.*,swagger\.api\.basepath=\"$BIZDOCK_PUBLIC_URL\",g" /opt/maf/maf-desktop/conf/framework.conf > tmp.cfg
    mv tmp.cfg /opt/maf/maf-desktop/conf/framework.conf

    #Changing the dbmdl-framework configuration
    sed "s/url=.*/url=jdbc:mysql:\/\/$MYSQL_HOSTNAME:$MYSQL_PORT\/$MYSQL_DATABASE/g" /opt/maf/dbmdl-framework/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/dbmdl-framework/repo/environments/deploy.properties
    sed "s/username=.*/username=$MYSQL_USER/g" /opt/maf/dbmdl-framework/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/dbmdl-framework/repo/environments/deploy.properties
    sed "s/password=.*/password=$MYSQL_PASSWORD/g" /opt/maf/dbmdl-framework/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/dbmdl-framework/repo/environments/deploy.properties

    #Changing the maf-dbmdl configuration
    sed "s/url=.*/url=jdbc:mysql:\/\/$MYSQL_HOSTNAME:$MYSQL_PORT\/$MYSQL_DATABASE/g" /opt/maf/maf-dbmdl/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/maf-dbmdl/repo/environments/deploy.properties
    sed "s/username=.*/username=$MYSQL_USER/g" /opt/maf/maf-dbmdl/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/maf-dbmdl/repo/environments/deploy.properties
    sed "s/password=.*/password=$MYSQL_PASSWORD/g" /opt/maf/maf-dbmdl/repo/environments/deploy.properties > tmp.cfg
    mv tmp.cfg /opt/maf/maf-dbmdl/repo/environments/deploy.properties

    mkdir /opt/start-config/dbmdl-framework && cp /opt/maf/dbmdl-framework/repo/environments/deploy.properties /opt/start-config/dbmdl-framework
    mkdir /opt/start-config/maf-dbmdl && cp /opt/maf/maf-dbmdl/repo/environments/deploy.properties /opt/start-config/maf-dbmdl
    mkdir /opt/start-config/maf-desktop && cp /opt/maf/maf-desktop/conf/*.conf /opt/start-config/maf-desktop && cp /opt/maf/maf-desktop/conf/*.xml /opt/start-config/maf-desktop
    chown -R $userName.$userName /opt/start-config/
  else
    cp /opt/start-config/dbmdl-framework/deploy.properties /opt/maf/dbmdl-framework/repo/environments
    cp /opt/start-config/maf-dbmdl/deploy.properties /opt/maf/maf-dbmdl/repo/environments
    cp -Rf /opt/start-config/maf-desktop/* /opt/maf/maf-desktop/conf
    chown -R $userName.$userName /opt/maf/
  fi  

  echo "---- REFRESHING THE DATABASE ----"
  if [ "$CONFIGURE_DB_INIT" = true ]; then
    echo ">> Reseting the database schema"
mysql -h ${MYSQL_HOSTNAME} --port=${MYSQL_PORT} -u root --password=${MYSQL_ROOT_PASSWORD} <<EOF
DROP SCHEMA IF EXISTS ${MYSQL_DATABASE};
CREATE SCHEMA IF NOT EXISTS ${MYSQL_DATABASE} 
DEFAULT CHARACTER SET utf8;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_USER}';
GRANT ALL ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
EOF
  fi

  echo ">> Executing schema evolutions (framework)"
  /opt/maf/dbmdl-framework/scripts/run.sh
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    exit 1
  fi

  echo ">> Executing schema evolutions (desktop)"
  /opt/maf/maf-dbmdl/scripts/run.sh
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    exit 1
  fi

  if [ "$CONFIGURE_DB_INIT" = true ]; then
    echo ">> Inserting the default data"
    mysql -h ${MYSQL_HOSTNAME} --port=${MYSQL_PORT} -u ${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} < /opt/maf/maf-desktop/server/maf-desktop-app-dist/conf/sql/init_base.sql
  fi

  echo "---- CREATING THE MAF-FILE-SYSTEM ----"
  N=$(echo $(cat /opt/start-config/maf-desktop/framework.conf | grep saml.sso.config | cut -d '=' -f 2 | cut -d '"' -f 2 | grep -o "/" | wc -l)+1 | bc)
  SSO_FILE=$(cat /opt/start-config/maf-desktop/framework.conf | grep saml.sso.config | cut -d '=' -f 2 | cut -d '"' -f 2 | cut -d '/' -f $N)
  if [ ! -d /opt/artifacts/maf-file-system/$SSO_FILE ]; then
    touch /opt/artifacts/maf-file-system/$SSO_FILE
  fi

  N=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.personal.space.root | cut -d '=' -f 2 | cut -d '"' -f 2 | grep -o "/" | wc -l)
  PERSONAL_SPACE_FOLDER=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.personal.space.root | cut -d '=' -f 2 | cut -d '"' -f 2 | cut -d '/' -f $N)
  if [ ! -d /opt/artifacts/maf-file-system/$PERSONAL_SPACE_FOLDER ]; then
    mkdir -p /opt/artifacts/maf-file-system/$PERSONAL_SPACE_FOLDER
  fi

  N=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.report.custom.root | cut -d '=' -f 2 | cut -d '"' -f 2 | grep -o "/" | wc -l)
  FTP_FOLDER=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.report.custom.root | cut -d '=' -f 2 | cut -d '"' -f 2 | cut -d '/' -f $N)
  if [ ! -d /opt/artifacts/maf-file-system/$FTP_FOLDER ]; then
    mkdir -p /opt/artifacts/maf-file-system/$FTP_FOLDER
  fi

  N=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.attachments.root | cut -d '=' -f 2 | cut -d '"' -f 2 | grep -o "/" | wc -l)
  ATTACHMENTS_FOLDER=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.attachments.root | cut -d '=' -f 2 | cut -d '"' -f 2 | cut -d '/' -f $N)
  if [ ! -d /opt/artifacts/maf-file-system//opt/artifacts/maf-file-system/$ATTACHMENTS_FOLDER ]; then
    mkdir -p /opt/artifacts/maf-file-system/$ATTACHMENTS_FOLDER
  fi

  N=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.ext.directory | cut -d '=' -f 2 | cut -d '"' -f 2 | grep -o "/" | wc -l)
  EXTENSIONS_FOLDER=$(cat /opt/start-config/maf-desktop/framework.conf | grep maf.ext.directory | cut -d '=' -f 2 | cut -d '"' -f 2 | cut -d '/' -f $N)
  if [ ! -d /opt/artifacts/maf-file-system/$EXTENSIONS_FOLDER ]; then
    mkdir -p /opt/artifacts/maf-file-system/$EXTENSIONS_FOLDER
  fi

  if [ ! -d /opt/artifacts/maf-file-system/outputs ]; then
    mkdir -p /opt/artifacts/maf-file-system/outputs
  fi

  if [ ! -d /opt/artifacts/maf-file-system/inputs ]; then
    mkdir -p /opt/artifacts/maf-file-system/inputs
  fi

  chown -R $userName.$userName /opt/artifacts/maf-file-system/

  echo "---- COPYING THE DEFAULT EXTENTIONS ----"
  cp -f /opt/maf/*.jar /opt/artifacts/maf-file-system/$EXTENSIONS_FOLDER
  ls /opt/artifacts/maf-file-system/$EXTENSIONS_FOLDER

  echo "---- LAUNCHING BIZDOCK APPLICATION ----"
  /opt/maf/maf-desktop/server/maf-desktop-app-dist/bin/maf-desktop-app -Dcom.agifac.appid=maf-desktop-docker -Dconfig.file=/opt/maf/maf-desktop/conf/application.conf -Dlogger.file=/opt/maf/maf-desktop/conf/application-logger.xml -Dhttp.port=$BIZDOCK_PORT -DapplyEvolutions.default=false
else
  echo "You should use a valid user"
fi

