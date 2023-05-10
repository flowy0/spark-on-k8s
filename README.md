# spark-on-k8s

Pre-requisites

1. Local K8s cluster (minikube or kind)
2. Helm 
3. Python Environment/Poetry (only if you want to use python to trigger spark jobs via the API)







Deployment Steps

1. Create a local cluster with ingress

```bash
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

```

You should see this 
```shell
❯ kind create cluster                                                                           
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind
```


Add Ingress nginx - https://kind.sigs.k8s.io/docs/user/ingress/
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```
output:
```shell
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
serviceaccount/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
configmap/ingress-nginx-controller created
service/ingress-nginx-controller created
service/ingress-nginx-controller-admission created
deployment.apps/ingress-nginx-controller created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
ingressclass.networking.k8s.io/nginx created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created
```

kubectl wait --namespace ingress-nginx \                                                      
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
pod/ingress-nginx-controller-69dfcc796b-xd26b condition met


Create namespace for `spark-operator`
```
kubectl create namespace spark-operator
```

Create 2 more namespaces for running jobs
k create namespace spark-runner-1                                                            
k create namespace spark-runner-2

2. Add Helm repo
```
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
```

3. Install Spark Operator on specific namespace with webhook
```
helm install spark-operator spark-operator/spark-operator --namespace spark-operator --set sparkJobNamespace=spark-operator  --set webhook.enable=true
```
3a. For multiple name space monitoring
helm install spark-operator spark-operator/spark-operator --namespace spark-operator --set webhook.enable=true

```
NAME: spark-operator
LAST DEPLOYED: Tue Apr 11 18:51:55 2023
NAMESPACE: spark-operator
STATUS: deployed
REVISION: 1
TEST SUITE: None
```



4. Apply the following manifests
a. priorities.yaml
b. spark-application-rbac.yaml
c. python-sa.yaml


Create the secret for the service accounts manually, as kubernetes 1.24 sets this process as manual
```
kubectl create token python client-sa
```


Multi-Namespaces:
- k8s/python-sa.yaml has been updated to create multiple service accounts for the new namespaces.

```
kubectl apply -f k8s/python-sa.yaml
```

```
serviceaccount/python-client-sa created
serviceaccount/python-client-sa-runner-1 created
serviceaccount/python-client-sa-runner-2 created
role.rbac.authorization.k8s.io/python-client-role created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding created
clusterrole.rbac.authorization.k8s.io/node-reader created
clusterrolebinding.rbac.authorization.k8s.io/python-client-cluster-role-binding created
clusterrole.rbac.authorization.k8s.io/python-client-clusterrole created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding-runner-1 created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding-runner-2 created
```

- For multi-namespace, you would need a separate kubeconfig per namespace as they use different service accounts.
- use the script: generate_kubeconfig_input.sh and enter the namespace and service account name, service account token secret name.
- update the trigger-spark-operator.py with the kubeconfig file name and namespaces accordingly.


```
sh generate_kubeconfig_input.sh python-client-sa python-client-sa-token spark-operator                            
```
output:
```
spark-operator-kubeconfig-sa generated
```


## Examples
Try to Run examples:

### jar file
kubectl apply -f examples/spark-pi.yaml










Create your python environment

```
conda env create -f spark.yml   
conda activate spark-demo 
poetry install
```










### python file
```
python trigger-spark-operator.py
```

References:
- Great thanks to Pascal (this repo is based on this article):
  - https://dev.to/stack-labs/my-journey-with-spark-on-kubernetes-in-python-1-3-4nl3
  - https://github.com/pgillet/k8s-python-client-examples




