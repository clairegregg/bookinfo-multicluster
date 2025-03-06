source .env

##############################
# 1. Setup MongoDB cluster 1 #
##############################
kubectl config use-context mdb-1
# istioctl install -y -f platform/istio/mongodb-profile.yaml --set=hub=gcr.io/istio-release
kubectl create namespace mongodb
kubectl label namespace mongodb istio-injection=enabled
sed -e "s/{i}/1/g" -e "s/{j}/2/g" platform/kube/bookinfo-db.yaml | kubectl apply -n mongodb -f -

kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml

echo "Waiting for mongodb to be ready"
kubectl wait --for=condition=ready pod -l app=mongodb1 --timeout=300s -n mongodb

##############################
# 2. Setup MongoDB cluster 2 #
##############################
kubectl config use-context mdb-2
# istioctl install -y -f platform/istio/mongodb-profile.yaml --set=hub=gcr.io/istio-release
kubectl create namespace mongodb
kubectl label namespace mongodb istio-injection=enabled
sed -e "s/{i}/2/g" -e "s/{j}/1/g" platform/kube/bookinfo-db.yaml | kubectl apply -n mongodb -f  -

kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml

echo "Waiting for mongodb to be ready"
kubectl wait --for=condition=ready pod -l app=mongodb2 --timeout=300s -n mongodb


#########################
# 3. Set up replication #
#########################
kubectl config use-context mdb-1
kubectl exec -n mongodb svc/mongodb1 -- mongosh --eval '
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb1.mongodb.svc.cluster.local:27017" },
    { _id: 1, host: "mongodb2.mongodb.svc.cluster.local:27017" }
  ]
})'
