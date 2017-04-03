#!/bin/bash
BIZDOCK_VERSION=$(cat target/version.properties)

echo "Pushing BizDock ${BIZDOCK_VERSION} on Docker HUB"
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push bizdock/bizdock:${BIZDOCK_VERSION}

if [ ! -z "$TRAVIS_TAG" ]
then
    echo "Tagging and pushing new release with 'latest'"
    docker tag bizdock/bizdock:${BIZDOCK_VERSION} bizdock/bizdock:latest
    docker push bizdock/bizdock:latest
fi

echo "Deploying on CI"
chmod 600 deploy_key && ssh -i deploy_key ${CI_USER}@ci.bizdock.io ${BIZDOCK_VERSION}