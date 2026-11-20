# What a pipeline job may do once the API server has accepted its GitHub
# OIDC token. Rendered by platform/oidc.sh for each environment.
#
# Least privilege: one namespace, only the kinds the app is made of,
# and no access to Secrets, RBAC, nodes or other namespaces.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: __ENV__
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "serviceaccounts"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log", "events"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["events.k8s.io"]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-deployer
  namespace: __ENV__
subjects:
  # Only a job running in the GitHub environment with the same name.
  # A dev job's token cannot touch prod, and vice versa.
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: "github:repo:__REPO__:environment:__ENV__"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-deployer
