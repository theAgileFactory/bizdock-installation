#!/bin/bash
BIZDOCK_VERSION=$(cat target/version.properties)

echo "Pushing BizDock ${BIZDOCK_VERSION} on Docker HUB"
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push bizdock/bizdock:${BIZDOCK_VERSION}

if [[ $BIZDOCK_VERSION != *-SNAPSHOT ]]
then
    echo "Tagging and pushing new release with 'latest'"
    docker tag bizdock/bizdock:${BIZDOCK_VERSION} bizdock/bizdock:latest
    docker push bizdock/bizdock:latest
fi

echo "Deploying on CI"
chmod 600 deploy_key
echo "Copying create script"
wget https://raw.githubusercontent.com/theAgileFactory/bizdock-installation/${TRAVIS_BRANCH}/cli/create.sh
scp -i deploy_key create.sh ${CI_USER}@ci.bizdock.io:~/scripts/
echo "Copying test data script"
wget https://raw.githubusercontent.com/theAgileFactory/maf-desktop-app/${TRAVIS_BRANCH}/development/tools/sample-data/init_data.sql
scp -i deploy_key init_data.sql ${CI_USER}@ci.bizdock.io:~/scripts/
echo "Triggering bizdock installation"
ssh -i deploy_key ${CI_USER}@ci.bizdock.io /home/${CI_USER}/scripts/install.sh ${BIZDOCK_VERSION}