# Runs the CIS Kubernetes Benchmark against THIS cluster's node (kube-bench).
# `make cis` substitutes __KUBEBENCH_IMAGE__ from tools.env and applies this.
#
# On kind you will see many FAILs and WARNs: kind is a developer cluster, not a
# CIS-hardened distribution. That is the lesson -- a benchmark measures the gap
# between what you run and the standard, so you can see it and close it.
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: kube-system
  labels:
    app: kube-bench
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: kube-bench
    spec:
      hostPID: true
      # Run on the control-plane node so the master/etcd checks have something
      # to read. kind taints it, so we tolerate the taint.
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      restartPolicy: Never
      containers:
        - name: kube-bench
          image: __KUBEBENCH_IMAGE__
          command: ["kube-bench"]
          args: ["run", "--targets", "master,controlplane,node,etcd,policies"]
          volumeMounts:
            - name: var-lib-cni
              mountPath: /var/lib/cni
              readOnly: true
            - name: var-lib-etcd
              mountPath: /var/lib/etcd
              readOnly: true
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: var-lib-kube-scheduler
              mountPath: /var/lib/kube-scheduler
              readOnly: true
            - name: var-lib-kube-controller-manager
              mountPath: /var/lib/kube-controller-manager
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: lib-systemd
              mountPath: /lib/systemd
              readOnly: true
            - name: srv-kubernetes
              mountPath: /srv/kubernetes
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
            - name: usr-bin
              mountPath: /usr/local/mount-from-host/bin
              readOnly: true
            - name: etc-cni-netd
              mountPath: /etc/cni/net.d
              readOnly: true
            - name: opt-cni-bin
              mountPath: /opt/cni/bin
              readOnly: true
      volumes:
        - name: var-lib-cni
          hostPath:
            path: /var/lib/cni
        - name: var-lib-etcd
          hostPath:
            path: /var/lib/etcd
        - name: var-lib-kubelet
          hostPath:
            path: /var/lib/kubelet
        - name: var-lib-kube-scheduler
          hostPath:
            path: /var/lib/kube-scheduler
        - name: var-lib-kube-controller-manager
          hostPath:
            path: /var/lib/kube-controller-manager
        - name: etc-systemd
          hostPath:
            path: /etc/systemd
        - name: lib-systemd
          hostPath:
            path: /lib/systemd
        - name: srv-kubernetes
          hostPath:
            path: /srv/kubernetes
        - name: etc-kubernetes
          hostPath:
            path: /etc/kubernetes
        - name: usr-bin
          hostPath:
            path: /usr/bin
        - name: etc-cni-netd
          hostPath:
            path: /etc/cni/net.d
        - name: opt-cni-bin
          hostPath:
            path: /opt/cni/bin
