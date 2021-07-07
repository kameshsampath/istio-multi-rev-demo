#!/usr/bin/env bash

set -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REPO=${1:-localhost:5000/example}
TAG=${2:-latest}


# change this if you want to push to real cluster
docker build -t "$REPO:$TAG" "$CURRENT_DIR"
docker push "$REPO:$TAG"