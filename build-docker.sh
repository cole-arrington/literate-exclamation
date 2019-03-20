#!/bin/bash

set -ex

ECR="415868856706.dkr.ecr.us-east-1.amazonaws.com"
APP_DIR="./app"
images=( "mysql" "portal" "hardware")

for i in "${images[@]}"
do
	docker build -f ${APP_DIR}/${i}/Dockerfile -t ${i} ${APP_DIR}/${i}
    docker tag ${i}:latest ${ECR}/${i}:latest
    docker push ${ECR}/${i}:latest
done
