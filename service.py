from flask import Flask
from kubernetes import config, client

import os

app = Flask(__name__)


def setup_app(svc):
    in_cluster = os.getenv("IN_CLUSTER", "no")
    print(f"Setting up Service with kube config in cluster ? {in_cluster}")
    if in_cluster.lower() == 'yes':
        config.load_incluster_config()
    else:
        config.load_kube_config()


@app.route("/live")
def live():
    return "live"


@app.route("/ready")
def ready():
    return "ready"


@app.route("/api/hello")
def hello_default_ns():
    return _hello(os.getenv('MY_POD_NAMESPACE', 'default'))


@app.route("/api/hello/<ns>", methods=['GET'])
def hello(ns):
    return _hello(ns)


def _hello(ns):
    _hello.count += 1

    v1 = client.CoreV1Api()
    label = "app=hello-world"
    pods = v1.list_namespaced_pod(namespace=ns, label_selector=label)

    istio_rev = "unknown"
    service_version = "unknown"

    for p in pods.items:
        app.logger.debug(f"Pod Name {p.metadata.name}")
        for key, value in p.metadata.labels.items():
            if key == "istio.io/rev":
                istio_rev = value
            elif key == "version":
                service_version = value
    host_name = os.getenv("HOSTNAME")
    return {
        "message": f"HelloWorld  {host_name} from greeting service '{service_version}': {_hello.count}",
        "istioRevision": istio_rev,
        "serviceVersion": service_version
    }


_hello.count = 0
setup_app(app)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080, debug=True)
