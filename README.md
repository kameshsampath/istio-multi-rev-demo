# Istio Multi Revision Demo

A simple hello world application that shows how to install and use multiple revisions of [Istio](https://istio.io).
As part of the demo, we will deploy the app that will use Istio Proxy from version 1.8.6 and 1.10.2. The application also uses [Gloo Edge](https://docs.solo.io/gloo-edge/latest) as the application gateway to route the traffic between multiple revisions of istio.

## Pre-requisites

* [asdf-vm](https://asdf-vm.com)
* [kubectl](https://kubernetes.io/docs/tasks/tools)
* [httpie](https://httpie.io)
* [glooctl](https://docs.solo.io/gloo-edge/latest/getting_started)
* Kubernetes Cluster e.g [KinD](https://kind.sigs.k8s.io)
* [Gloo Edge](https://docs.solo.io/gloo-edge/latest/getting_started/)

## Download Sources

```shell
git clone https://github.com/kameshsampath/istio-multi-rev-demo istio-multi-rev-demo && cd $_
```

We will refer to the cloned folder as `$PROJECT_HOME`:

```shell
export PROJECT_HOME="$(pwd)"
```

## Setup Kubernetes Cluster

For the examples we will be using the KinD as our Kubernetes cluster, run the following command to start single node Kubernetes cluster:

```shell
$PROJECT_HOME/start-kind.sh
```

## Install asdf-istio plugin

```
asdf plugin-add istio https://github.com/kameshsampath/asdf-istio
```

## Download and install Istio

Download and install Istio v1.8.6:

```
cd $PROJECT_HOME
asdf local istio 1.8.6#<1>
asdf install
```

## Deploy Istio Control Plane - Istio v1.8.6

Once Istio is downloaded, let us set up an Istio control plane with a pinned revision `1-8-6`,

```
$PROJECT_HOME/istio/installControlPlane.sh
```

Let us now verify the installation by selecting the pods in `istio-system` namespace and list the label `istio.io/rev':

```shell
kubectl get pods -n istio-system -L'istio.io/rev'
```

```shell
NAME                             READY   STATUS    RESTARTS   AGE     REV
istiod-1-8-6-869d57f467-dkxpq    1/1     Running   0          21h     1-8-6#<1>
```

<1> Istio Control Plane configured with `v1.8.6`

__NOTE__:
The Istio revision name could be any string but for easier clarity we use the semantic version numbers with `.` replaced with `-`

## Deploy application

The application is a simple greeter application with a REST API at `/api/hello` that sends a JSON response with a greeting, Istio revision used and service revision.

```shell
kubectl apply -k $PROJECT_HOME/k8s/app
```

Wait for pods to be in running state:

```shell
kubectl rollout status -n demo-1-8-6 deploy/hello-world --timeout=60s
```

## Accessing the application

We will use https://docs.solo.io/gloo-edge/latest/introduction/[Gloo Edge] as API gateway to access the application:

## Install Gloo Edge

As part of this demo, we will install Gloo Edge in to our custom namespace called `my-gloo`, the following values can be used to override the Gloo Edge setup:

* [`install-overrides.yaml`](https://github.com/kameshsampath/istio-multi-rev-demo/blob/main/gloo/install-overrides.yaml) - Use Cloud Provider Load Balancer
* [`install-overrides-no-discovery.yaml`](https://github.com/kameshsampath/istio-multi-rev-demo/blob/main/gloo/install-overrides-no-discovery.yaml) - Use Cloud Provider Load Balancer with discovery disabled
* [`install-overrides-nodeport.yaml`](https://github.com/kameshsampath/istio-multi-rev-demo/blob/main/gloo/install-overrides-nodeport.yaml) - Use KinD cluster with gloo-proxy available via NodePort
* [`install-overrides-no-discovery.yaml`](https://github.com/kameshsampath/istio-multi-rev-demo/blob/main/gloo/install-overrides-no-discovery.yaml) - Use KinD cluster with gloo-proxy available via NodePort with discovery disabled

__IMPORTANT__:
By default, `glooctl install gateway` installs all the components in `gloo-system` namespace.
As we will be using custom namespace `my-gloo`, its very important that you provide the `-n` or `--namespace` option with value as `my-gloo`.


```
#e.g. glooctl install gateway -n my-gloo \
#   --values $PROJECT_HOME/gloo/install-overrides-nodeport.yaml
glooctl install gateway --values $PROJECT_HOME/gloo/<your-config-from-list-above>
```

__NOTE__:The Gloo Edge installation might take few minutes to complete depending upon your internet speed. Wait for the gloo to be ready before proceeding.

Run the following check command to verify if its installed and ready:

```shell
glooctl check -n my-gloo
```

```shell
Checking deployments... OK
Checking pods... OK
Checking upstreams... OK
Checking upstream groups... OK
Checking auth configs... OK
Checking rate limit configs... OK
Checking VirtualHostOptions... OK
Checking RouteOptions... OK
Checking secrets... OK
Checking virtual services... OK
Checking gateways... OK
Checking proxies... OK
No problems detected.
I0702 21:09:18.553303   68173 request.go:645] Throttling request took 1.048233536s, request: GET:https://192.168.99.101:8443/apis/rbac.authorization.k8s.io/v1?timeout=32s
Skipping Gloo Instance check -- Gloo Federation not detected
```

__NOTE__: To know more details on Gloo Edge installation [here](https://docs.solo.io/gloo-edge/latest/installation/gateway/kubernetes/)

### Upstreams

####  With Discovery

If you have enabled discovery then, Gloo Edge should discover the upstreams automatically as shown below:

```
glooctl get upstreams -n my-gloo
```

Let's check its status,

```
+-----------------------------+------------+----------+----------------------------+
|          UPSTREAM           |    TYPE    |  STATUS  |          DETAILS           |
+-----------------------------+------------+----------+----------------------------+
| demo-1-8-6-hello-world-8080 | Kubernetes | Accepted | svc name:      hello-world |
|                             |            |          | svc namespace: demo-1-8-6  |
|                             |            |          | port:          8080        |
|                             |            |          |                            |
+-----------------------------+------------+----------+----------------------------+
```

#### No Discovery

With Gloo discovery disabled, you need to create the upstream manually to be used with gateway.

```
kubectl apply -n my-gloo -f $PROJECT_HOME/k8s/gloo/istio-1-8-6/upstream.yaml
```

Now running the command `glooctl get upstreams -n my-gloo` will show one upstream as shown above.

### Route

Let us now update the route all the traffic to `1.8.6`,

```
kubectl apply -n my-gloo -f  $PROJECT_HOME/k8s/gloo/istio-1-8-6/gateway.yaml
```

Check the status of the route:

```
glooctl get virtualservice -n my-gloo
```

```
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
|   VIRTUAL SERVICE    | DISPLAY NAME | DOMAINS | SSL  |  STATUS  | LISTENERPLUGINS |       ROUTES        |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
| istio-multi-rev-demo |              | *       | none | Accepted |                 | / -> 1 destinations |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
```

Run the script `$PROJECT_HOME/run.sh` to send few requests to our API and you should see the following responses with traffic getting to the demo service with revision `1-8-6`:

```
{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-dbb687654-jvnxw from greeting service 'v1.0': 2",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-dbb687654-jvnxw from greeting service 'v1.0': 3",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-dbb687654-jvnxw from greeting service 'v1.0': 4",
    "serviceVersion": "v1.0"
}

```

Let us also make sure the right version of `istio-proxy` is injected,

```
kubectl get  pod -lapp=hello-world -n demo-1-8-6 -ojsonpath='{.items[*].spec.containers[?(@.name == "istio-proxy")].image}'
```

The command should return an output like `docker.io/istio/proxyv2:1.8.6`

## Download and install Istio v1.10.2:

Let's have some fun with Gloo Edge by routing to multiple destinations.
Though it is not needed but to make things spicy let us now install another version of Istio v1.10.2. A matter of fact you can  have any number of Istio revisions installed and use different versions for different services.

```
cd $PROJECT_HOME
asdf local istio 1.10.2#<1>
asdf install
```
<1> This make your local Istio install to use Istio v1.10.2

## Deploy Istio Control Plane - Istio v1.10.2

Once Istio is downloaded, let us set up an Istio control plane with a pinned revision `1.10.2`,

```
$PROJECT_HOME/istio/installControlPlane.sh
```

The installation should show an output like:

```
Applying Istio Revision: 1-10-2
Skipping creation of namespace istio-system - already exists
Skipping creation of service istiod - already exists
WARNING: Istio is being upgraded from 1.8.6 -> 1.10.2.
WARNING: Before upgrading, you may wish to use 'istioctl analyze' to check forIST0002 and IST0135 deprecation warnings.
✔ Istio core installed
✔ Istiod installed
✔ Installation complete                                                                                            Thank you for installing Istio 1.10.  Please take a few minutes to tell us about your install/upgrade experience!  https://forms.gle/KjkrDnMPByq7akrYA
```

Let us now verify the installation by selecting the pods in `istio-system` namespace and list the label `istio.io/rev':

```
kubectl get pods -n istio-system -L'istio.io/rev'
```

```
NAME                             READY   STATUS    RESTARTS   AGE   REV
istiod-1-10-2-79d64cf497-ltqx9   1/1     Running   0          43s   1-10-2 #<1>
istiod-1-8-6-869d57f467-vnz29    1/1     Running   0          77m   1-8-6 #<2>
```
<1> Istio Control Plane configured with revision `1-10-2` corresponding to `v1.10.2`
<2> The revision `1-8-6` is that of `v1.8.6` version that was installed earlier

## Deploy application

The application is a simple greeter application with a REST API at `/api/hello` that sends a JSON response with a greeting, Istio revision used and service revision.

```
kubectl apply -k $PROJECT_HOME/k8s/app/istio-1-10-2
```

Wait for pods to be in running state,

```
kubectl rollout status -n demo-1-10-2 deploy/hello-world --timeout=60s
```

### Upstreams

#### With Discovery

If you have enabled discovery then, Gloo Edge should discover the upstreams automatically as shown below:

```
glooctl get upstreams -n my-gloo
```

Let's check its status,

```
+------------------------------+------------+----------+----------------------------+
|           UPSTREAM           |    TYPE    |  STATUS  |          DETAILS           |
+------------------------------+------------+----------+----------------------------+
| demo-1-10-2-hello-world-8080 | Kubernetes | Accepted | svc name:      hello-world |
|                              |            |          | svc namespace: demo-1-10-2 |
|                              |            |          | port:          8080        |
|                              |            |          |                            |
| demo-1-8-6-hello-world-8080  | Kubernetes | Accepted | svc name:      hello-world |
|                              |            |          | svc namespace: demo-1-8-6  |
|                              |            |          | port:          8080        |
|                              |            |          |                            |
+------------------------------+------------+----------+----------------------------+
```

#### No Discovery

With Gloo discovery disabled, you need to create the upstream of the `1-10-2` version of th service.

```
kubectl apply -n my-gloo -f $PROJECT_HOME/k8s/gloo/istio-1-10-2/upstream.yaml
```

Now running the command `glooctl get upstreams -n my-gloo` will show one upstream as shown above.

### Route

Let us now update the route all the traffic between `1-8-6` and `1-10-2`,

```
kubectl apply -n my-gloo -f  $PROJECT_HOME/k8s/gloo/istio-1-10-2/gateway.yaml
```

Check the status of the route,

```
glooctl get virtualservice -n my-gloo
```

```
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
|   VIRTUAL SERVICE    | DISPLAY NAME | DOMAINS | SSL  |  STATUS  | LISTENERPLUGINS |       ROUTES        |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
| istio-multi-rev-demo |              | *       | none | Accepted |                 | / -> 2 destinations |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
```

__NOTE__:
The `ROUTES` in the above output, which now shows *2 destinations* as we now distribute the traffic between `istio-1-8-6` and `istio-1-10-2`.

Run the script `$PROJECT_HOME/run.sh` to send few requests to our API and you should see the following responses with traffic getting distributed between two revision `1-8-6` and `1-10-2`,

```json
{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 6",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-10-2",
    "message": "HelloWorld  hello-world-57b8b665d4-wc9rb from greeting service 'v2.0': 1",
    "serviceVersion": "v2.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 7",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 8",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 9",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 10",
    "serviceVersion": "v1.0"
}


{
    "istioRevision": "1-10-2",
    "message": "HelloWorld  hello-world-57b8b665d4-wc9rb from greeting service 'v2.0': 2",
    "serviceVersion": "v2.0"
}


{
    "istioRevision": "1-8-6",
    "message": "HelloWorld  hello-world-674f69bf69-47cb5 from greeting service 'v1.0': 11",
    "serviceVersion": "v1.0"
}
```

Let us also make sure the right version of `istio-proxy` is injected,

```
kubectl get  pod -lapp=hello-world -n demo-1-10-2 -ojsonpath='{.items[*].spec.containers[?(@.name == "istio-proxy")].image}'
```

The command should return an output like `docker.io/istio/proxyv2:1.10.2`.

## Build Application (Optional)

If you plan to build and push the application to your container registry run the command:

```
$PROJECT_HOME/buildAndPush.sh <your-registry-fqn>
```

Once you do this make sure to update the application deployments in [deployment.yaml](https://github.com/kameshsampath/istio-multi-rev-demo/tree/main/k8s/app/istio-1-8-6/deployment.yaml) and [deployment.yaml](https://github.com/kameshsampath/istio-multi-rev-demo/tree/main/k8s/app/istio-1-10-2/deployment.yaml) container images to your container image name.
