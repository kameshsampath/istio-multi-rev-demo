#!/bin/bash

set -eu
set -o pipefail

export CLUSTER_NAME=${CLUSTER_NAME:-istio-multi-rev-demo}

# create registry container unless it already exists
export CONTAINER_REGISTRY_NAME='kind-registry.local'
export CONTAINER_REGISTRY_PORT='5000'

running="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_REGISTRY_NAME}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${CONTAINER_REGISTRY_PORT}:5000" --name "${CONTAINER_REGISTRY_NAME}" \
    registry:2
fi

# connect the registry to the cluster network only for new
if [ "${running}" != 'true' ]; then
  docker network connect "kind" "${CONTAINER_REGISTRY_NAME}"
fi

cat <<EOF | kind create cluster --name="$CLUSTER_NAME" --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  ## make ingress controller deployed on control plane only
  kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
  extraPortMappings:
    - containerPort: 80
      hostPort: 80
      listenAddress: 0.0.0.0
    - containerPort: 443
      hostPort: 443
      listenAddress: 0.0.0.0
    - containerPort: 30080
      hostPort: 30080
      listenAddress: 0.0.0.0
    - containerPort: 30443
      hostPort: 30443
      listenAddress: 0.0.0.0
- role: worker
containerdConfigPatches:
  - |-
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
      endpoint = ["http://kind-registry.local:5000"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."kind-registry.local:5000"]
      endpoint = ["http://kind-registry.local:5000"]
EOF

## Label nodes for using registry
# tell https://tilt.dev to use the registry
# https://docs.tilt.dev/choosing_clusters.html#discovering-the-registry
for node in $(kind get nodes --name="$CLUSTER_NAME"); do
  kubectl annotate node "${node}" \
    "tilt.dev/registry=localhost:${CONTAINER_REGISTRY_PORT}" \
    "tilt.dev/registry-from-cluster=${CONTAINER_REGISTRY_NAME}:${CONTAINER_REGISTRY_PORT}";
done

## Label worker nodes
kubectl  get nodes --no-headers -l '!node-role.kubernetes.io/master' \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' \
   | xargs -I{} kubectl label node {} node-role.kubernetes.io/worker=''
