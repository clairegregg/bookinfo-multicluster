############################
# 1. Setup MongoDB cluster #
############################

kind create cluster --name mongodb --config mongodb-kind-profile.yaml
istioctl install -y -f mongodb-istio-profile.yaml
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo-db.yaml

# Run port-forwarding in background
Start-Process -NoNewWindow -RedirectStandardOutput "port-forward.log" -ArgumentList `
    "kubectl --context kind-mongodb port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 27017:27017"

# Wait for MongoDB pod to be ready
kubectl --context kind-mongodb wait --for=condition=ready pod -l app=mongodb --timeout=300s

########################
# 2. Configure MongoDB #
########################

Start-Sleep -Seconds 5

$mongoCommands = @"
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
"@

mongosh 127.0.0.1:27017 --eval $mongoCommands

# Verify BookInfo User Access
$output = mongosh 127.0.0.1:27017 -u bookinfo -p 'bookinfo' --authenticationDatabase test --eval "db.ratings.find({});"

if ($output -match "rating") {
    Write-Host "bookinfo user is able to access the required database!"
} else {
    Write-Host "Something failed to configure for the bookinfo user:"
    Write-Host $output
    Exit 1
}

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

# Run port-forwarding in background
Start-Process -NoNewWindow -RedirectStandardOutput "bookinfo-port-forward.log" -ArgumentList `
    "kubectl --context kind-bookinfo port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 8080:80"

kubectl --context kind-bookinfo wait --for=condition=ready pod -l app=reviews --timeout=300s
