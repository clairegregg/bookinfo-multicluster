source .env

############################
# 1. Setup MongoDB cluster #
############################
kind create cluster --name mongodb --config platform/kind/mongodb-profile.yaml
istioctl install -y -f platform/istio/mongodb-profile.yaml --set=hub=gcr.io/istio-release
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo-db.yaml

kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml

echo "Waiting for mongodb to be ready"
kubectl --context kind-mongodb wait --for=condition=ready pod -l app=mongodb --timeout=300s
# This needs to run in the background
nohup kubectl --context kind-mongodb port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 27018:27017 > port-forward.log 2>&1 &

########################
# 2. Configure MongoDB #
########################
sleep 5
mongosh 127.0.0.1:27018 <<EOF
use admin;
db.createUser({
    user: 'admin',
    pwd: 'admin',
    roles: ['root']
});
use test;
db.createUser({
    user: 'bookinfo',
    pwd: 'bookinfo',
    roles: ['readWrite']
});
db.createCollection('ratings');
db.ratings.insertMany([{"productid": 0, "rating": 3}, {"productid": 0, "rating": 3}]);
EOF


# Connect to MongoDB as bookinfo and query the ratings collection
output=$(mongosh 127.0.0.1:27018 -u bookinfo -p 'bookinfo' --authenticationDatabase test --eval "db.ratings.find({});")

# Check if the expected result is in the output
if [[ "$output" == *"rating"* ]]; then
    echo "bookinfo user is able to access the required database!"
else
    echo "Something failed to configure for the bookinfo user:\n"
    echo $output
    exit 0
fi

#############################
# 3. Setup BookInfo cluster #
#############################
kind create cluster --name bookinfo
istioctl install -y --set meshConfig.accessLogFile=/dev/stdout --set=hub=gcr.io/istio-release
kubectl label --context kind-bookinfo namespace default istio-injection=enabled
kubectl apply --context kind-bookinfo -f platform/kube/bookinfo.yaml
kubectl apply --context kind-bookinfo -f networking/bookinfo-gateway.yaml
kubectl apply --context kind-bookinfo -f networking/destination-rule-all.yaml
kubectl apply --context kind-bookinfo -f platform/kube/bookinfo-ratings-v2.yaml
kubectl set --context kind-bookinfo env deployment/ratings-v2 "MONGO_DB_URL=mongodb://${MONGODB_IP}:${MONGODB_PORT}/test?authSource=test"
kubectl apply --context kind-bookinfo -f networking/virtual-service-ratings-db.yaml
kubectl apply --context kind-bookinfo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: mongo
spec:
  hosts:
  - my-mongo.tcp.svc
  addresses:
  - ${MONGODB_IP}/32
  ports:
  - number: ${MONGODB_PORT}
    name: tcp
    protocol: TCP
  location: MESH_EXTERNAL
  resolution: STATIC
  endpoints:
  - address: ${MONGODB_IP}
EOF

# This needs to run in the background
nohup kubectl --context kind-bookinfo port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 8080:80 > bookinfo-port-forward.log 2>&1 &
kubectl wait --context kind-bookinfo --for=condition=ready $(kubectl get pod -o name) --timeout 300s

kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml
