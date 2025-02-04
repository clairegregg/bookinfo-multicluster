############################
# 1. Setup MongoDB cluster #
############################
kind create cluster --name mongodb --config mongodb-kind-profile.yaml
#kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
#kubectl apply -f mongodb-metallb.yaml
#kubectl wait --namespace metallb-system --for=condition=available deployment --all --timeout=120s
istioctl install -y -f mongodb-istio-profile.yaml
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo-db.yaml
# This needs to run in the background
nohup kubectl --context kind-mongodb port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 27017:27017 > port-forward.log 2>&1 &
kubectl --context kind-mongodb wait --for=condition=ready pod -l app=mongodb --timeout=300s


########################
# 2. Configure MongoDB #
########################
sleep 5
mongosh 127.0.0.1:27017 <<EOF
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
    roles: ['read']
});
db.createCollection('ratings');
db.ratings.insertMany([{rating: 1}, {rating: 1}]);
EOF


# Connect to MongoDB as bookinfo and query the ratings collection
output=$(mongosh 127.0.0.1:27017 -u bookinfo -p 'bookinfo' --authenticationDatabase test --eval "db.ratings.find({});")

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
istioctl install -y
kubectl label --context kind-bookinfo namespace default istio-injection=enabled
kubectl apply --context kind-bookinfo -f platform/kube/bookinfo.yaml
kubectl apply --context kind-bookinfo -f networking/bookinfo-gateway.yaml
kubectl apply --context kind-bookinfo -f networking/destination-rule-all.yaml
kubectl apply --context kind-bookinfo -f platform/kube/bookinfo-ratings-v2.yaml
kubectl set --context kind-bookinfo env deployment/ratings-v2 "MONGO_DB_URL=mongodb://bookinfo:bookinfo@127.0.0.1/test?authSource=test&ssl=true"
kubectl apply --context kind-bookinfo -f networking/virtual-service-ratings-db.yaml
# This needs to run in the background
nohup kubectl --context kind-bookinfo port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 8080:80 > bookinfo-port-forward.log 2>&1 &
kubectl --context kind-bookinfo wait --for=condition=ready pod -l app=reviews --timeout=300s

