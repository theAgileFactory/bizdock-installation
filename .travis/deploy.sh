#!/bin/bash
BIZDOCK_VERSION=$(cat ../target/version.properties)
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push bizdock/bizdock:${BIZDOCK_VERSION}