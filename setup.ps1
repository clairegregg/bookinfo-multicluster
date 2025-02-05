$MONGODB_IP=10.6.65.8
$MONGODB_PORT=27017

############################
# 1. Setup MongoDB cluster #
############################

kind create cluster --name mongodb --config platform/kind/mongodb-profile.yaml
istioctl install -y -f platform/istio/mongodb-profile.yaml
kubectl label namespace default istio-injection=enabled
kubectl apply -f platform/kube/bookinfo-db.yaml

# Run port-forwarding in background
Start-Process -FilePath "kubectl" -ArgumentList `
    "--context kind-mongodb port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 27017:27017" `
    -NoNewWindow -RedirectStandardOutput "port-forward.log" -RedirectStandardError "port-forward.err" -PassThru

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

$mongoCommands | mongosh 127.0.0.1:27017

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
kubectl set --context kind-bookinfo env deployment/ratings-v2 "MONGO_DB_URL=mongodb://${MONGODB_IP}:${MONGODB_PORT}/test?authSource=test&ssl=true"
kubectl apply --context kind-bookinfo -f networking/virtual-service-ratings-db.yaml
kubectl apply --context kind-bookinfo -f networking/mongo-serviceentry.yaml

# Run port-forwarding in background
Start-Process -FilePath "kubectl" -ArgumentList `
    "--context kind-bookinfo port-forward --address 0.0.0.0 -n istio-system svc/istio-ingressgateway 8080:80" `
    -NoNewWindow -RedirectStandardOutput "bookinfo-port-forward.log" -RedirectStandardError "bookinfo-port-forward.err" -PassThru

kubectl --context kind-bookinfo wait --for=condition=ready pod -l app=ratings --timeout=300s