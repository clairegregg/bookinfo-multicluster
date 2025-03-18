##############################
# 1. Setup MongoDB cluster 1 #
##############################
kubectl config use-context cluster-1
kubectl create namespace mongodb
kubectl label namespace mongodb istio-injection=enabled
sed -e "s/{i}/1/g" -e "s/{j}/2/g" platform/kube/bookinfo-db.yaml | kubectl apply -n mongodb -f -

# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml
sleep 2s
echo "Waiting for mongodb to be ready"
kubectl wait --for=condition=ready pod -l app=mongodb1 --timeout=300s -n mongodb

##############################
# 2. Setup MongoDB cluster 2 #
##############################
kubectl config use-context cluster-2
kubectl create namespace mongodb
kubectl label namespace mongodb istio-injection=enabled
sed -e "s/{i}/2/g" -e "s/{j}/1/g" platform/kube/bookinfo-db.yaml | kubectl apply -n mongodb -f  -

# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml
sleep 2s
echo "Waiting for mongodb to be ready"
kubectl wait --for=condition=ready pod -l app=mongodb2 --timeout=300s -n mongodb
sleep 5s


#########################
# 3. Set up replication #
#########################
kubectl config use-context cluster-1
kubectl exec -n mongodb svc/mongodb1 -- mongosh --eval 'rs.initiate(
    {
        _id: "rs0",
        members: [
            { _id: 0, host: "mongodb1.mongodb.svc.cluster.local:27017" }
        ]
    }
)'
sleep 5s
kubectl exec -n mongodb svc/mongodb1 -- mongosh --eval 'rs.add("mongodb2.mongodb.svc.cluster.local:27017")'
sleep 5s

########################
# 4. Configure MongoDB #
########################
kubectl exec -n mongodb svc/mongodb1 -- sh -c "echo '
use admin;
db.createUser({
    user: \"admin\",
    pwd: \"admin\",
    roles: [\"root\"]
});
use test;
db.createUser({
    user: \"bookinfo\",
    pwd: \"bookinfo\",
    roles: [\"readWrite\"]
});
db.createCollection(\"ratings\");
db.ratings.insertMany([{ \"productid\": 0, \"rating\": 3 }, { \"productid\": 0, \"rating\": 3 }]);
' | mongosh mongodb1.mongodb.svc.cluster.local:27017"


output=$(kubectl exec -n mongodb svc/mongodb1 -- mongosh -u bookinfo -p 'bookinfo' --authenticationDatabase test --eval "db.ratings.find({});")

# Check if the expected result is in the output
if [[ "$output" == *"rating"* ]]; then
    echo "bookinfo user is able to access the required database!"
else
    echo "Something failed to configure for the bookinfo user:\n"
    echo $output
    exit 0
fi

###############################
# 5. Setup BookInfo cluster 1 #
###############################
kubectl config use-context cluster-3
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo.yaml
kubectl apply -f networking/bookinfo-gateway.yaml
kubectl apply -f networking/destination-rule-all.yaml
kubectl apply -f platform/kube/bookinfo-ratings-v2.yaml
kubectl apply -f networking/virtual-service-ratings-db.yaml

kubectl create namespace mongodb
kubectl apply -n mongodb -f platform/kube/bookinfo-db-service.yaml
kubectl set env deployment/ratings-v2 "MONGO_DB_URL=mongodb://mongodb1.mongodb.svc.cluster.local:27017,mongodb2.mongodb.svc.cluster.local:27017/test?authSource=test&replicaSet=rs0"

# This needs to run in the background
nohup kubectl port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 5501:80 > bookinfo-port-forward.log 2>&1 &
kubectl wait --for=condition=ready $(kubectl get pod -o name) --timeout 300s

# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
# kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml

###############################
# 6. Setup BookInfo cluster 2 #
###############################
kubectl config use-context cluster-4
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo.yaml
kubectl apply -f networking/bookinfo-gateway.yaml
kubectl apply -f networking/destination-rule-all.yaml
kubectl apply -f platform/kube/bookinfo-ratings-v2.yaml
kubectl apply -f networking/virtual-service-ratings-db.yaml

kubectl create namespace mongodb
kubectl apply -n mongodb -f platform/kube/bookinfo-db-service.yaml
kubectl set env deployment/ratings-v2 "MONGO_DB_URL=mongodb://mongodb1.mongodb.svc.cluster.local:27017,mongodb2.mongodb.svc.cluster.local:27017/test?authSource=test&replicaSet=rs0"

# This needs to run in the background
nohup kubectl port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 5502:80 > bookinfo-port-forward.log 2>&1 &
kubectl wait --for=condition=ready $(kubectl get pod -o name) --timeout 300s

kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml