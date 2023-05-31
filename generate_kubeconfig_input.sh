#!/usr/bin/env bash

# set -eux

SA_NAME=$1
SA_TOKEN_NAME=$2
NAMESPACE_INPUT=$3
if [[ -z $SA_NAME ]] || [[ -z $SA_TOKEN_NAME ]] || [[ -z $NAMESPACE_INPUT ]] 
then
  echo "what is the name of the service-account?"
  read SA_NAME
  echo "what is the name of the service-account token?"
  read SA_TOKEN_NAME
  echo "what is the name of the namespace?"
  read NAMESPACE_INPUT
fi


# Reads the API server name from the default `kubeconfig` file.
# Here we suppose that the kubectl command-line tool is already configured to communicate with our cluster.
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

SERVICE_ACCOUNT_NAME=${SA_NAME}
NAMESPACE=${NAMESPACE_INPUT}
# SECRET_NAME=$(kubectl get serviceaccount ${SERVICE_ACCOUNT_NAME} -n ${NAMESPACE} -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret ${SA_TOKEN_NAME} -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 --decode)
CACERT=$(kubectl get secret ${SA_TOKEN_NAME} -n ${NAMESPACE} -o jsonpath="{['data']['ca\.crt']}")

echo $APISERVER
echo $TOKEN


FILE_OUT=${NAMESPACE_INPUT}-kubeconfig-sa

cat > $FILE_OUT << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CACERT}
    server: ${APISERVER}
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    namespace: ${NAMESPACE}
    user: ${SERVICE_ACCOUNT_NAME}
  name: default-context
current-context: default-context
users:
- user:
    token: ${TOKEN}
  name: ${SERVICE_ACCOUNT_NAME}
EOF

echo "`pwd`/$FILE_OUT generated"
echo "Test this command by running \`KUBECONFIG=`pwd`/$FILE_OUT kubectl get po\`"
