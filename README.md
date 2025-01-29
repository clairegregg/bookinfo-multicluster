# Bookinfo Sample

Forked from https://github.com/istio/istio for @clairegregg's Master Thesis, as an example application.

See <https://istio.io/docs/examples/bookinfo/>.

## Set up MongoDB cluster
This project is developed using Minikube to manage Kubernetes clusters.

First, create the cluster.
```
minikube start -p mongodb
```

Now in another terminal, bring up a dashboard to help view what's going on in the cluster
```
minikube profile mongodb
minikube dashboard --url
```

In the original terminal, install istio in the with the appropriate configuration to allow mongodb to be accessed through istio's ingress:
```
istioctl install -f mongodb-profile.yaml
```

Next, enable istio sidecar injection
```
kubectl label namespace default istio-injection=enabled
```

Now, deploy mongodb and the associated resources:
```
kubectl apply -f platform/kube/bookinfo-db.yaml
```

In another tab, open a minikube tunnel so that the cluster's ingress can be accessed on the local machine's localhost:
```
minikube profile mongodb
minikube tunnel
```

Finally, back in the original tab, you can verify that the ingress is up and running, and confirm that the external IP is set up correctly:
```
export INGRESS_NAME=istio-ingressgateway
export INGRESS_NS=istio-system
kubectl get svc "$INGRESS_NAME" -n "$INGRESS_NS"
```

Now, mongodb should be accessible on mongodb://127.0.0.1:27018/
