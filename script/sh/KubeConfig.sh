#!/bin/bash
set -e
set -o noglob
SERVER=${SERVER:-'kubernetes'}
CLUSTER=${CLUSTER:-'local'}
NAMESPACE=${NAMESPACE:-'default'}
CONTEXT=${CONTEXT:-'dev'}
USER=${USER:-'client'}
DOMAIN="$(echo "${SERVER}" | sed -e 's#^.*//##' -e 's#/.*$##')"

IS_NEW=1
IS_CLUSTER=0
OPT="${@:-'admin - new'}"
if [ "$OPT" = "admin - new" ]; then
	IS_CLUSTER=0
	IS_NEW=1
elif [ "$OPT" = "admin - export" ]; then
	IS_CLUSTER=0
	IS_NEW=0
elif [ "$OPT" = "cluster-admin - new" ]; then
	IS_CLUSTER=1
	IS_NEW=1
elif [ "$OPT" = "cluster-admin - export" ]; then
	IS_CLUSTER=1
	IS_NEW=0
else
	OPT="admin - new"
	IS_CLUSTER=0
	IS_NEW=1
fi

if [ $IS_CLUSTER -eq 1 ]; then
	GROUP=${NAMESPACE}:${USER}:cluster-admin
	IMPERSONATE_USER=${IMPERSONATE_USER:-'cluster-admin'}
else
	GROUP=${NAMESPACE}:${USER}:admin
	IMPERSONATE_USER=${IMPERSONATE_USER:-'admin'}
fi

# RKE2集群master
cd ~/
rm -fr ~/.kube/${USER} 
mkdir -p ~/.kube/${USER} 
cd ~/.kube/${USER}

# 确保命名空间存在
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: List
items:
  - apiVersion: v1
    kind: Namespace
    metadata:
      name: ${NAMESPACE}
EOF

if [ $IS_NEW -eq 0 ]; then
# 导出凭证
kubectl get secret "${USER}-sa-token" -n ${NAMESPACE} --ignore-not-found --output="jsonpath={.data.token}" | base64 -d > ${USER}.token
kubectl get secret "${USER}-key.kubeconfig.pem" -n kube-system --ignore-not-found --output="jsonpath={.data.tls\.crt}" | base64 -d > ${USER}.crt
kubectl get secret "${USER}-key.kubeconfig.pem" -n kube-system --ignore-not-found --output="jsonpath={.data.tls\.key}" | base64 -d > ${USER}-key.pem
kubectl get secret rke2-serving -n kube-system --ignore-not-found --output="jsonpath={.data.tls\.crt}" |  \
  base64 -d |  \
  tac |  \
  sed -n '1,/\(.*\)-----BEGIN CERTIFICATE-----.*/p' |  \
  tac > server-ca.crt
fi

# 凭证缺失
if [ ! -s ${USER}.token ] || [ ! -s ${USER}.crt ] || [ ! -s ${USER}-key.pem ] || [ ! -s server-ca.crt ]; then
	IS_NEW=1
fi

if [ $IS_NEW -eq 1 ]; then
####################################################################################################################
# 创建证书签名请求
# API Server 会把客户端证书的CN字段作为User，把names.O字段作为Group
cat <<EOF | cfssl genkey - | cfssljson -bare ${USER}
{
    "hosts": [
        "${DOMAIN}"
    ],
    "CN": "${USER}",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "${GROUP}",
            "OU": "${NAMESPACE}"
        }
    ]
}
EOF

# 发送CSR到 Kubernetes API
# Kubernetes API 用户与服务账号授权
kubectl delete csr ${USER} --ignore-not-found
kubectl delete Secret "${USER}-sa-token" -n ${NAMESPACE} --ignore-not-found
kubectl delete Secret "${USER}-key.kubeconfig.pem" -n kube-system --ignore-not-found
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: List
items:
  - apiVersion: certificates.k8s.io/v1
    kind: CertificateSigningRequest
    metadata:
      name: ${USER}
    spec:
      request: $(cat ${USER}.csr | base64 | tr -d '\n')
      signerName: kubernetes.io/kube-apiserver-client
      expirationSeconds: 31536000
      usages:
      - digital signature
      - key encipherment
      - client auth
  - apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ${USER}
      namespace: ${NAMESPACE}
  - apiVersion: v1
    kind: Secret
    metadata:
      name: ${USER}-sa-token
      namespace: ${NAMESPACE}
      annotations:
        kubernetes.io/service-account.name: "${USER}"
    type: kubernetes.io/service-account-token
EOF

if [ $IS_CLUSTER -eq 1 ]; then
# 集群管理员
kubectl delete ClusterRoleBinding "${GROUP}-crb" --ignore-not-found
kubectl delete ClusterRoleBinding "${GROUP}-view-crb" --ignore-not-found
kubectl delete ClusterRoleBinding "${GROUP}-impersonate" --ignore-not-found
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: List
items:
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: ${GROUP}-crb
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
      - kind: User
        name: ${IMPERSONATE_USER}
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: ${GROUP}-view-crb
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: view
    subjects:
      - kind: ServiceAccount
        name: ${USER}
        namespace: ${NAMESPACE}
      - kind: Group
        name: ${GROUP}
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: ${GROUP}-impersonator
    rules:
      - apiGroups: [""]
        resources: ["users"]
        verbs: ["impersonate"]
        resourceNames: ["${IMPERSONATE_USER}"]
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: ${GROUP}-impersonate
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: ${GROUP}-impersonator
    subjects:
      - kind: ServiceAccount
        name: ${USER}
        namespace: ${NAMESPACE}
      - kind: Group
        name: ${GROUP}
EOF
else
# 应用开发者
kubectl delete RoleBinding "${GROUP}-rb" -n ${NAMESPACE} --ignore-not-found
kubectl delete RoleBinding "${GROUP}-view-rb" -n ${NAMESPACE} --ignore-not-found
kubectl delete ClusterRoleBinding "${GROUP}-impersonate" --ignore-not-found
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: List
items:
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: ${GROUP}-rb
      namespace: ${NAMESPACE}
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: admin
    subjects:
      - kind: User
        name: ${IMPERSONATE_USER}
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: ${GROUP}-view-rb
      namespace: ${NAMESPACE}
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: view
    subjects:
      - kind: ServiceAccount
        name: ${USER}
        namespace: ${NAMESPACE}
      - kind: Group
        name: ${GROUP}
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: ${GROUP}-impersonator
    rules:
      - apiGroups: [""]
        resources: ["users"]
        verbs: ["impersonate"]
        resourceNames: ["${IMPERSONATE_USER}"]
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: ${GROUP}-impersonate
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: ${GROUP}-impersonator
    subjects:
      - kind: ServiceAccount
        name: ${USER}
        namespace: ${NAMESPACE}
      - kind: Group
        name: ${GROUP}
EOF
fi

# 批准证书签名请求（CSR）
kubectl certificate approve ${USER}
kubectl get csr/${USER} --ignore-not-found
kubectl get csr/${USER} -o jsonpath='{.status.certificate}'| base64 -d > ${USER}.crt
kubectl get secret "${USER}-sa-token" -n ${NAMESPACE} --output="jsonpath={.data.token}" | base64 -d > ${USER}.token

# 创建秘钥
kubectl create secret tls ${USER}-key.kubeconfig.pem --cert ${USER}.crt --key ${USER}-key.pem -n kube-system

# 导出凭证
kubectl get secret rke2-serving -n kube-system --output="jsonpath={.data.tls\.crt}" |  \
  base64 -d |  \
  tac |  \
  sed -n '1,/\(.*\)-----BEGIN CERTIFICATE-----.*/p' |  \
  tac > server-ca.crt
####################################################################################################################
fi

# 代理kube-apiserver
# 启用ssl透传：Rancher 集群管理 > 工作负载 > DaemonSets > rke2-ingress-nginx-controller > 编辑配置，命令加启动参数--enable-ssl-passthrough
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#ssl-passthrough
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#backend-protocol
kubectl delete ingress kube-apiserver -n kube-system --ignore-not-found
kubectl delete svc kube-apiserver -n kube-system --ignore-not-found
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: List
items:
  - apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: kube-apiserver
      namespace: kube-system
      labels:
        component: kube-apiserver
        tier: control-plane
      annotations:
        nginx.ingress.kubernetes.io/ssl-passthrough: "true"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    spec:
      ingressClassName: nginx-ssl
      tls:
      - hosts:
        - ${DOMAIN}
        secretName: ${USER}-key.kubeconfig.pem
      rules:
      - host: ${DOMAIN}
        http:
          paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: kube-apiserver
                port:
                  number: 443
  - apiVersion: v1
    kind: Service
    metadata:
      name: kube-apiserver
      namespace: kube-system
      labels:
        component: kube-apiserver
        tier: control-plane
    spec:
      type: ClusterIP
      ports:
        - name: https
          port: 443
          protocol: TCP
          targetPort: 6443
      selector:
        component: kube-apiserver
        tier: control-plane
EOF

# 生成kubeconfig
# https://kubernetes.io/docs/reference/kubectl/generated
KC_EXEC="kubectl --kubeconfig ${USER}.kubeconfig config"
$KC_EXEC set-cluster ${CLUSTER} --server=${SERVER} --certificate-authority=server-ca.crt --embed-certs=true
$KC_EXEC set-credentials ${USER} --client-key=${USER}-key.pem --client-certificate=${USER}.crt --embed-certs=true --token=$(cat ${USER}.token)
$KC_EXEC set-context "${CONTEXT}" --cluster=${CLUSTER} --user=${USER} --namespace=${NAMESPACE}
$KC_EXEC use-context "${CONTEXT}"
sed -i '/- name: '${USER}'/{n;s/  user:/  as: '${IMPERSONATE_USER}'\n&/g}' ${USER}.kubeconfig
echo "cat ~/.kube/${USER}/${USER}.kubeconfig"