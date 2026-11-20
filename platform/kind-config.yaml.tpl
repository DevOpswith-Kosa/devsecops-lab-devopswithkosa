# kind cluster for the DevSecOps track. Rendered by platform/up.sh:
# __AUTH_DIR__ and __NODE_IMAGE__ are replaced before kind reads it.
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: __CLUSTER_NAME__
networking:
  # A fixed address and port, so the self-hosted runner (same machine)
  # always finds the API server at https://127.0.0.1:6443.
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
# Let containerd read per-registry config from /etc/containerd/certs.d,
# where up.sh tells it that localhost:5001 means the kind-registry container.
containerdConfigPatches:
  - |-
    [plugins."io.containerd.cri.v1.images".registry]
      config_path = "/etc/containerd/certs.d"
nodes:
  - role: control-plane
    image: __NODE_IMAGE__
    extraMounts:
      # The API server's authentication config (GitHub OIDC trust) and audit
      # policy live on your laptop, so you can edit them without rebuilding.
      - hostPath: __AUTH_DIR__
        containerPath: /etc/kubernetes/auth
        readOnly: true
      # The API audit log is written here and appears on your laptop, so the
      # Part 4 detector can read it. (Created by platform/up.sh.)
      - hostPath: __AUDIT_DIR__
        containerPath: /var/log/kubernetes
    extraPortMappings:
      # NodePort 30080 (dev) and 30081 (prod) appear on your laptop.
      - { containerPort: 30080, hostPort: 8080, listenAddress: "127.0.0.1" }
      - { containerPort: 30081, hostPort: 8081, listenAddress: "127.0.0.1" }
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        apiServer:
          extraArgs:
            - name: authentication-config
              value: /etc/kubernetes/auth/auth-config.yaml
            # API audit logging -- the evidence trail Part 4 detects on.
            - name: audit-policy-file
              value: /etc/kubernetes/auth/audit-policy.yaml
            - name: audit-log-path
              value: /var/log/kubernetes/audit.log
            - name: audit-log-maxsize
              value: "50"
            - name: audit-log-maxbackup
              value: "3"
          extraVolumes:
            - name: auth-config
              hostPath: /etc/kubernetes/auth
              mountPath: /etc/kubernetes/auth
              readOnly: true
              pathType: Directory
            - name: audit-log
              hostPath: /var/log/kubernetes
              mountPath: /var/log/kubernetes
              pathType: DirectoryOrCreate
