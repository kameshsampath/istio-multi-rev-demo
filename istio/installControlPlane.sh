#!/bin/bash
set -e
set -o pipefail 

ISTIO_NS=istio-system
ISTIO_INGRESS_NS=istio-ingress

basedir() {
  # Default is current directory
  local script=${BASH_SOURCE[0]}

  # Resolve symbolic links
  if [ -L "$script" ]; then
      if readlink -f "$script" >/dev/null 2>&1; then
          script=$(readlink -f "$script")
      elif readlink "$script" >/dev/null 2>&1; then
          script=$(readlink "$script")
      elif realpath "$script" >/dev/null 2>&1; then
          script=$(realpath "$script")
      else
          printf "ERROR: Cannot resolve symbolic link %s" "$script"
          exit 1
      fi
  fi

  local dir
  dir=$(dirname "$script")
  local full_dir
  full_dir=$(cd "${dir}" && pwd)
  echo "${full_dir}"
}

###########################################
# Deploy Control Plane
###########################################

# Compute the revision name
ISTIO_VERSION=$(asdf current istio | awk '{print $2}' )
ISTIO_REVISION=$(awk 'BEGIN { dot = "[\\.]";dash ="-" } { gsub(dot, dash); print }' <<< "$ISTIO_VERSION")

echo "Applying Istio Revision: $ISTIO_REVISION"

NS=$(kubectl get namespace $ISTIO_NS --ignore-not-found);
if [[ "$NS" ]]; then
  echo "Skipping creation of namespace $ISTIO_NS - already exists";
else
  echo "Creating namespace $ISTIO_NS";
  kubectl create namespace $ISTIO_NS;
fi;

SVC=$(kubectl get svc istiod -n $ISTIO_NS --ignore-not-found);
if [[ "$SVC" ]]; then
  echo "Skipping creation of service istiod - already exists";
else
  echo "Creating service istiod";
  kubectl create -n $ISTIO_NS \
  -f "$(basedir)/istiod-service.yaml"
fi;

istioctl install -y -n $ISTIO_NS --revision "$ISTIO_REVISION" -f "$(basedir)/control-plane.yaml"
