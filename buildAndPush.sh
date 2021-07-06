#!/usr/bin/env bash

set -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TAG=${1:-latest}

# change this if you want to push to real cluster
docker build -t "localhost:5000/example/istio-multi-rev-demo:$TAG" "$CURRENT_DIR"
docker push "localhost:5000/example/istio-multi-rev-demo:$TAG"