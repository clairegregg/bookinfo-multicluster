#!/bin/bash
# Copied from https://github.com/mongodb/mongodb-enterprise-kubernetes/blob/master/tools/multicluster/install_istio_separate_network.sh

set -eux

# define here or provide the cluster names externally
export CTX_CLUSTER1=${CTX_CLUSTER1}
export CTX_CLUSTER2=${CTX_CLUSTER2}
export CTX_CLUSTER3=${CTX_CLUSTER3}
export ISTIO_VERSION=1.24.3

# download Istio under the path
curl -L https://istio.io/downloadIstio | sh -

# checks if external IP has been assigned to a service object, in our case we are interested in east-west gateway
function_check_external_ip_assigned() {
 while : ; do
   ip=$(kubectl --context="$1" get svc istio-eastwestgateway -n istio-system --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
   if [ -n "$ip" ]
   then
     echo "external ip assigned $ip"
     break
   else
     echo "waiting for external ip to be assigned"
   fi
done
}

# Create clusters and install metalLB, instructions from https://github.com/sedflix/multi-cluster-istio-kind
# Base IP address from docker network inspect -f '{{$map := index .IPAM.Config 0}}{{index $map "Subnet"}}' kind, which usually gives 172.18.0.0/16
kind create cluster --name $CTX_CLUSTER1
export CTX_CLUSTER1="kind-"$CTX_CLUSTER1
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --context $CTX_CLUSTER1
sleep 5
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s --context $CTX_CLUSTER1
kubectl apply --context $CTX_CLUSTER1 -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: demo-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.1-172.18.255.25
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: demo-advertisement
  namespace: metallb-system
EOF

kind create cluster --name $CTX_CLUSTER2
export CTX_CLUSTER2="kind-"$CTX_CLUSTER2
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --context $CTX_CLUSTER2
sleep 5
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s --context $CTX_CLUSTER2
kubectl apply --context $CTX_CLUSTER2 -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: demo-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.26-172.18.255.50
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: demo-advertisement
  namespace: metallb-system
EOF

# kind create cluster --name $CTX_CLUSTER3
# export CTX_CLUSTER3="kind-"$CTX_CLUSTER3
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --context $CTX_CLUSTER3
# sleep 5
# kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s --context $CTX_CLUSTER3
# kubectl apply --context $CTX_CLUSTER3 -f - <<EOF
# apiVersion: metallb.io/v1beta1
# kind: IPAddressPool
# metadata:
#   name: demo-pool
#   namespace: metallb-system
# spec:
#   addresses:
#   - 172.18.255.51-172.18.255.75
# ---
# apiVersion: metallb.io/v1beta1
# kind: L2Advertisement
# metadata:
#   name: demo-advertisement
#   namespace: metallb-system
# EOF

cd istio-${ISTIO_VERSION}
mkdir -p certs
pushd certs

# create root trust for the clusters
make -f ../tools/certs/Makefile.selfsigned.mk root-ca
make -f ../tools/certs/Makefile.selfsigned.mk ${CTX_CLUSTER1}-cacerts
make -f ../tools/certs/Makefile.selfsigned.mk ${CTX_CLUSTER2}-cacerts
# make -f ../tools/certs/Makefile.selfsigned.mk ${CTX_CLUSTER3}-cacerts

kubectl --context="${CTX_CLUSTER1}" create ns istio-system
kubectl --context="${CTX_CLUSTER1}" create secret generic cacerts -n istio-system \
      --from-file=${CTX_CLUSTER1}/ca-cert.pem \
      --from-file=${CTX_CLUSTER1}/ca-key.pem \
      --from-file=${CTX_CLUSTER1}/root-cert.pem \
      --from-file=${CTX_CLUSTER1}/cert-chain.pem

kubectl --context="${CTX_CLUSTER2}" create ns istio-system
kubectl --context="${CTX_CLUSTER2}" create secret generic cacerts -n istio-system \
      --from-file=${CTX_CLUSTER2}/ca-cert.pem \
      --from-file=${CTX_CLUSTER2}/ca-key.pem \
      --from-file=${CTX_CLUSTER2}/root-cert.pem \
      --from-file=${CTX_CLUSTER2}/cert-chain.pem

# kubectl --context="${CTX_CLUSTER3}" create ns istio-system
# kubectl --context="${CTX_CLUSTER3}" create secret generic cacerts -n istio-system \
#       --from-file=${CTX_CLUSTER3}/ca-cert.pem \
#       --from-file=${CTX_CLUSTER3}/ca-key.pem \
#       --from-file=${CTX_CLUSTER3}/root-cert.pem \
#       --from-file=${CTX_CLUSTER3}/cert-chain.pem
popd

# label namespace in cluster1
kubectl --context="${CTX_CLUSTER1}" get namespace istio-system && \
  kubectl --context="${CTX_CLUSTER1}" label namespace istio-system topology.istio.io/network=network1

cat <<EOF > cluster1.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
EOF
bin/istioctl install --context="${CTX_CLUSTER1}" -y -f cluster1.yaml
samples/multicluster/gen-eastwest-gateway.sh \
    --mesh mesh1 --cluster cluster1 --network network1 | \
    bin/istioctl --context="${CTX_CLUSTER1}" install -y -f -


# check if external IP is assigned to east-west gateway in cluster1
function_check_external_ip_assigned "${CTX_CLUSTER1}"


# expose services in cluster1
kubectl --context="${CTX_CLUSTER1}" apply -n istio-system -f \
    samples/multicluster/expose-services.yaml


kubectl --context="${CTX_CLUSTER2}" get namespace istio-system && \
  kubectl --context="${CTX_CLUSTER2}" label namespace istio-system topology.istio.io/network=network2


cat <<EOF > cluster2.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2
      network: network2
EOF

bin/istioctl install --context="${CTX_CLUSTER2}" -y -f cluster2.yaml

samples/multicluster/gen-eastwest-gateway.sh \
    --mesh mesh1 --cluster cluster2 --network network2 | \
    bin/istioctl --context="${CTX_CLUSTER2}" install -y -f -

# check if external IP is assigned to east-west gateway in cluster2
function_check_external_ip_assigned "${CTX_CLUSTER2}"

kubectl --context="${CTX_CLUSTER2}" apply -n istio-system -f \
    samples/multicluster/expose-services.yaml

# cluster3
# kubectl --context="${CTX_CLUSTER3}" get namespace istio-system && \
#   kubectl --context="${CTX_CLUSTER3}" label namespace istio-system topology.istio.io/network=network3

# cat <<EOF > cluster3.yaml
# apiVersion: install.istio.io/v1alpha1
# kind: IstioOperator
# spec:
#   values:
#     global:
#       meshID: mesh1
#       multiCluster:
#         clusterName: cluster3
#       network: network3
# EOF

# bin/istioctl install --context="${CTX_CLUSTER3}" -f cluster3.yaml

# samples/multicluster/gen-eastwest-gateway.sh \
#     --mesh mesh1 --cluster cluster3 --network network3 | \
#     bin/istioctl --context="${CTX_CLUSTER3}" install -y -f -


# # check if external IP is assigned to east-west gateway in cluster3
# function_check_external_ip_assigned "${CTX_CLUSTER3}"

# kubectl --context="${CTX_CLUSTER3}" apply -n istio-system -f \
#     samples/multicluster/expose-services.yaml


# enable endpoint discovery
bin/istioctl create-remote-secret \
  --context="${CTX_CLUSTER1}" \
  --namespace="istio-system" \
  --name="cluster1" | kubectl --context="${CTX_CLUSTER2}" apply -f - 

# bin/istioctl x create-remote-secret \
#   --context="${CTX_CLUSTER1}" \
#   -n istio-system \
#   --name=cluster1 | \
#   kubectl apply -f - --context="${CTX_CLUSTER3}"

bin/istioctl create-remote-secret \
  --context="${CTX_CLUSTER2}" \
  --namespace="istio-system" \
  --name="cluster2" | kubectl --context="${CTX_CLUSTER1}" apply -f - 

# bin/istioctl x create-remote-secret \
#   --context="${CTX_CLUSTER2}" \
#   -n istio-system \
#   --name=cluster2 | \
#   kubectl apply -f - --context="${CTX_CLUSTER3}"

# bin/istioctl x create-remote-secret \
#   --context="${CTX_CLUSTER3}" \
#   -n istio-system \
#   --name=cluster3 | \
#   kubectl apply -f - --context="${CTX_CLUSTER1}"

# bin/istioctl x create-remote-secret \
#   --context="${CTX_CLUSTER3}" \
#   -n istio-system \
#   --name=cluster3 | \
#   kubectl apply -f - --context="${CTX_CLUSTER2}"

  # cleanup: delete the istio repo at the end
cd ..
rm -r istio-${ISTIO_VERSION}
rm -f cluster1.yaml cluster2.yaml cluster3.yaml