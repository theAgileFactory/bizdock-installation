#!/bin/bash

# This script creates the Docker images for BizDock

echo "----------------------------------------"
echo " Collecting the software components     "
echo "----------------------------------------"
mvn clean install
STATUS=$?
if [ $STATUS -ne 0 ]; then
  exit 1
fi

echo "----------------------------------------"
echo " Building the BizDock Utils image          "
echo "----------------------------------------"
docker build -f ./bizdockutils/Dockerfile -t bizdock/bizdockutils:1.0 .
STATUS=$?
if [ $STATUS -ne 0 ]; then
  exit 1
fi

echo "----------------------------------------"
echo " Building the BizDock DB image          "
echo "----------------------------------------"
docker build -f ./bizdockdb/Dockerfile -t bizdock/bizdock_mariadb:10.1.12 .
STATUS=$?
if [ $STATUS -ne 0 ]; then
  exit 1
fi

echo "----------------------------------------"
echo " Building the BizDock Application image "
echo "----------------------------------------"
echo ">> STEP-1 : Merging the packages with the default configuration"

cd target/dependency

echo ">>>> SETP-1.1 : Merging the DBMDL FRAMEWORK"
versionNumber=$(ls dbmdl-framework-*.zip | grep -oP '(?<=dbmdl-framework-).*(?=.zip)')
echo ">> Found version number for dbmdl-framework $versionNumber"
mvn com.agifac.deploy:replacer-maven-plugin:replace -Dsource=dbmdl-framework-$versionNumber.zip -Denv=../../default-configuration/bizdockdb-dbmdl-framework.properties
STATUS=$?
if [ $STATUS -ne 0 ]; then
  cd ../..
  exit 1
fi

echo ">>>> SETP-1.2 : Merging the MAF DBMDL"
versionNumber=$(ls maf-dbmdl-*.zip | grep -oP '(?<=maf-dbmdl-).*(?=.zip)')
echo ">> Found version number for maf-dbmdl $versionNumber"
mvn com.agifac.deploy:replacer-maven-plugin:replace -Dsource=maf-dbmdl-$versionNumber.zip -Denv=../../default-configuration/bizdockdb-maf-dbmdl.properties
STATUS=$?
if [ $STATUS -ne 0 ]; then
  cd ../..
  exit 1
fi

echo ">>>> SETP-1.3 : Merging the MAF PACKAGING"
versionNumber=$(ls maf-desktop-*.zip | grep -oP '(?<=maf-desktop-).*(?=.zip)')
echo ">> Found version number for bizdock-packaging $versionNumber"
mvn com.agifac.deploy:replacer-maven-plugin:replace -Dsource=maf-desktop-$versionNumber.zip -Denv=../../default-configuration/bizdock-packaging.properties
STATUS=$?
if [ $STATUS -ne 0 ]; then
  cd ../..
  exit 1
fi

cd ../..

echo ">> STEP-2 : Building the image according to the right version"
echo ">>>> SETP-2.1 : Copying the merged packages to the workdir"
cp target/dependency/merged-*.zip bizdock/
cp target/dependency/maf-defaultplugins-extension-*.jar bizdock/

echo ">>>> SETP-2.2 : Building the BizDock image"
BIZDOCK_VERSION=$(cat target/version.properties)
docker build -f ./bizdock/Dockerfile -t bizdock/bizdock:${BIZDOCK_VERSION} .
STATUS=$?
if [ $STATUS -ne 0 ]; then
  exit 1
fi



