#!/bin/bash
BIZDOCK_VERSION=$(cat target/version.properties)

# Push version on Docker HUB
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push bizdock/bizdock:${BIZDOCK_VERSION}

# Deploy on CI
chmod 600 deploy_key && ssh -i deploy_key ${CI_USER}@ci.bizdock.io ${BIZDOCK_VERSION}