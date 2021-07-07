# Istio Multi Revision Demo (Gloo Enterprise)

A simple hello world application that shows how to install and use multiple revisions of [Istio](https://istio.io).
As part of the demo, we will deploy the app that will use Istio Proxy from version 1.8.6 and 1.10.2. The application also uses [Gloo Edge](https://docs.solo.io/gloo-edge/latest) as the application gateway to route the traffic between multiple revisions of istio.

## Pre-requisites

* [Docker Desktop](https://docs.docker.com/desktop/)
* [pipx](https://pypa.github.io/pipx)
* [kubectl](https://kubernetes.io/docs/tasks/tools)
* [httpie](https://httpie.io)
* Kubernetes Cluster e.g [KinD](https://kind.sigs.k8s.io)
* [Gloo Edge](https://docs.solo.io/gloo-edge/latest/getting_started/)

## Download Sources

```shell
git clone https://github.com/kameshsampath/istio-multi-rev-demo -b all-in-one istio-multi-rev-demo && cd $_
```

We will refer to the cloned folder as `$PROJECT_HOME`:

```shell
export PROJECT_HOME="$(pwd)"
```

## Setup Project

Install `pipx` as described here https://pypa.github.io/pipx/installation/

```shell
cd $PROJECT_HOME
pipx install poetry
# cretae virtual env locally via .venv file
poetry config virtualenvs.in-project true
poetry install
poetry shell
```

## Install Ansible Collection

```shell
ansible-galaxy collection install -r requirements.yml
```

## Setup Kubernetes Cluster and Install Istio and Gloo Edge

```shell
ansible-playbook cluster-setup-ee.yaml
```

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

We will use https://docs.solo.io/gloo-edge/latest/introduction/[Gloo Edge] as API gateway to access the application.

Run the following check command to verify if Gloo Edge is installed and ready:

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
Checking rate limit server... OK
```

__NOTE__: To know more details on Gloo Edge installation [here](https://docs.solo.io/gloo-edge/latest/installation/gateway/kubernetes/)

### Upstreams

#### With Discovery

If you have enabled discovery then, Gloo Edge should discover the upstreams automatically as shown below:

```shell
glooctl get upstreams -n my-gloo
```

Let's check its status,

```shell
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

```shell
kubectl apply -n my-gloo -f $PROJECT_HOME/k8s/gloo/istio-1-8-6/upstream.yaml
```

Now running the command `glooctl get upstreams -n my-gloo` will show one upstream as shown above.

### Route

Let us now update the route all the traffic to `1.8.6`,

```shell
kubectl apply -n my-gloo -f  $PROJECT_HOME/k8s/gloo/istio-1-8-6/gateway.yaml
```

Check the status of the route:

```shell
glooctl get virtualservice -n my-gloo
```

```shell
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
|   VIRTUAL SERVICE    | DISPLAY NAME | DOMAINS | SSL  |  STATUS  | LISTENERPLUGINS |       ROUTES        |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
| istio-multi-rev-demo |              | *       | none | Accepted |                 | / -> 1 destinations |
+----------------------+--------------+---------+------+----------+-----------------+---------------------+
```

Run the script `$PROJECT_HOME/run.sh` to send few requests to our API and you should see the following responses with traffic getting to the demo service with revision `1-8-6`:

```shell
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

```shell
kubectl get  pod -lapp=hello-world -n demo-1-8-6 -ojsonpath='{.items[*].spec.containers[?(@.name == "istio-proxy")].image}'
```

The command should return an output like `docker.io/istio/proxyv2:1.8.6`

## Download and install Istio v1.10.2:

Let's have some fun with Gloo Edge by routing to multiple destinations.
Though it is not needed but to make things spicy let us now install another version of Istio v1.10.2. A matter of fact you can  have any number of Istio revisions installed and use different versions for different services.

## Deploy application Istio v1.10.2

The application is a simple greeter application with a REST API at `/api/hello` that sends a JSON response with a greeting, Istio revision used and service revision.

```shell
kubectl apply -k $PROJECT_HOME/k8s/app/istio-1-10-2
```

Wait for pods to be in running state,

```shell
kubectl rollout status -n demo-1-10-2 deploy/hello-world --timeout=60s
```

### Upstreams v1.10.2

#### With Discovery v1.10.2

If you have enabled discovery then, Gloo Edge should discover the upstreams automatically as shown below:

```shell
glooctl get upstreams -n my-gloo
```

Let's check its status,

```shell
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

#### No Discovery v1.10.2

With Gloo discovery disabled, you need to create the upstream of the `1-10-2` version of th service.

```shell
kubectl apply -n my-gloo -f $PROJECT_HOME/k8s/gloo/istio-1-10-2/upstream.yaml
```

Now running the command `glooctl get upstreams -n my-gloo` will show one upstream as shown above.

### Route v1.8.6 + v1.10.2

Let us now update the route all the traffic between `1-8-6` and `1-10-2`,

```shell
kubectl apply -n my-gloo -f  $PROJECT_HOME/k8s/gloo/istio-1-10-2/gateway.yaml
```

Check the status of the route,

```shell
glooctl get virtualservice -n my-gloo
```

```text
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

```shell
kubectl get  pod -lapp=hello-world -n demo-1-10-2 -ojsonpath='{.items[*].spec.containers[?(@.name == "istio-proxy")].image}'
```

The command should return an output like `docker.io/istio/proxyv2:1.10.2`.

## Build Application (Optional)

If you plan to build and push the application to your container registry run the command:

```shell
$PROJECT_HOME/buildAndPush.sh <your-registry-fqn>
```

Once you do this make sure to update the application deployments in [deployment.yaml](https://github.com/kameshsampath/istio-multi-rev-demo/tree/main/k8s/app/istio-1-8-6/deployment.yaml) and [deployment.yaml](https://github.com/kameshsampath/istio-multi-rev-demo/tree/main/k8s/app/istio-1-10-2/deployment.yaml) container images to your container image name.
