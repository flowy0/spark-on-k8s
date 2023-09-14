# spark-on-k8s

This repo shows how to deploy Spark operator on Kubernetes, with role based access for multiple namespaces. 
Spark Jobs can be created in multiple namespaces via the Kubernetes Python API and their inputs are configurable via a python script.


Note: 
As of 31 May 2023, this does not work with Rancher Desktop/kind/colima, as there are some issues with `tini` and `qemu`. Will re-test at a later stage.
I have only tested with Docker Desktop (for mac).


Pre-requisites
1. Docker Engine (Docker Desktop)
1. Local K8s cluster (minikube or kind)
2. Helm 
3. Python Environment/Poetry (only if you want to use python to trigger spark jobs via the API)


Deployment Steps

1. We are using `kind` to create our local k8s cluster.

a. Create a local cluster with ingress

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


b. Add Ingress nginx - https://kind.sigs.k8s.io/docs/user/ingress/
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

c. Check for pod readiness
```
kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=120s
```

Successful Output:
```
pod/ingress-nginx-controller-69dfcc796b-xd26b condition met
```

d. Create namespace for `spark-operator`
```
kubectl create namespace spark-operator
```

Create 2 more namespaces for running jobs
```
kubectl create namespace spark-runner-1                                                            
kubectl create namespace spark-runner-2
```

e. Set your kubecontext to `spark-operator` namespace

```
kubectl config set-context --current --namespace=spark-operator
```

You can run all the commands via this script: [create_k8s_cluster.sh](create_k8s_cluster.sh)


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
  
    - priorities.yaml
    - spark-application-rbac.yaml
    - python-sa.yaml


```
kubectl apply -f k8s/priorities.yaml     
kubectl apply -f k8s/spark-application-rbac.yaml 
```

Output:
```
priorityclass.scheduling.k8s.io/routine created
priorityclass.scheduling.k8s.io/urgent created
priorityclass.scheduling.k8s.io/exceptional created
priorityclass.scheduling.k8s.io/rush created

Warning: resource namespaces/spark-runner-1 is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
namespace/spark-runner-1 configured
Warning: resource namespaces/spark-runner-2 is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
namespace/spark-runner-2 configured
serviceaccount/spark-sa-1 created
serviceaccount/spark-sa-2 created
clusterrole.rbac.authorization.k8s.io/sparkoperator-clusterrole created
rolebinding.rbac.authorization.k8s.io/spark-sa-rolebinding-1 created
rolebinding.rbac.authorization.k8s.io/spark-sa-rolebinding-2 created
```




5a. Multi-Namespaces:
- k8s/python-sa.yaml has been updated to create multiple service accounts for the new namespaces.
- We also create service account tokens manually, as in kubernetes version 1.24 onwards, its not created automatically.

- For multi-namespace, you would need a separate kubeconfig per namespace as they use different service accounts.
- use the script: generate_kubeconfig_input.sh and enter the namespace and service account name, service account token secret name.
- update the trigger-spark-operator.py with the kubeconfig file name and namespaces accordingly.

```
kubectl apply -f k8s/python-sa.yaml
```

```
serviceaccount/python-client-sa created
secret/python-client-sa-token created
serviceaccount/python-client-sa-runner-1 created
secret/python-client-sa-1-token created
serviceaccount/python-client-sa-runner-2 created
secret/python-client-sa-2-token created
role.rbac.authorization.k8s.io/python-client-role created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding created
clusterrole.rbac.authorization.k8s.io/node-reader created
clusterrolebinding.rbac.authorization.k8s.io/python-client-cluster-role-binding created
clusterrole.rbac.authorization.k8s.io/python-client-clusterrole created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding-runner-1 created
rolebinding.rbac.authorization.k8s.io/python-client-role-binding-runner-2 created
```




6. Generate a custom kubeconfig only to be used by this service account in a python script

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









### Try to create a sparkapplication using python k8s api
1. Create your python environment

```
conda env create -f spark.yml   
conda activate spark-demo 
poetry install
```


2. run python file
```
python trigger-spark-operator.py
```

References:
- Great thanks to Pascal (this repo is based on this article):
  - https://dev.to/stack-labs/my-journey-with-spark-on-kubernetes-in-python-1-3-4nl3
  - https://github.com/pgillet/k8s-python-client-examples




