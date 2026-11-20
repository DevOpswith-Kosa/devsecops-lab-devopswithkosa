# Shift-left policy: the same rules Gatekeeper enforces in the cluster,
# checked on the rendered manifests BEFORE anything is deployed.
#   conftest test --policy policies rendered.yaml
# Every message starts with a rule id so a failed pipeline is easy to grep.
package main

import rego.v1

workload_kinds := {"Deployment", "StatefulSet", "DaemonSet", "Job", "ReplicaSet"}

pod_spec := input.spec.template.spec if input.kind in workload_kinds

pod_spec := input.spec.jobTemplate.spec.template.spec if input.kind == "CronJob"

pod_spec := input.spec if input.kind == "Pod"

containers contains c if some c in pod_spec.containers

containers contains c if some c in pod_spec.initContainers

name := sprintf("%s/%s", [input.kind, input.metadata.name])

allowed_registry := "localhost:5001/"

# ---------------------------------------------------------------- images
deny contains msg if {
	some c in containers
	not startswith(c.image, allowed_registry)
	msg := sprintf("IMG-001 %s: container '%s' uses image '%s'; only images from %s may be deployed", [name, c.name, c.image, allowed_registry])
}

deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("IMG-002 %s: container '%s' uses the ':latest' tag; pin a version or a digest", [name, c.name])
}

deny contains msg if {
	some c in containers
	not contains(c.image, "@sha256:")
	not regex.match(`:[^/]+$`, c.image)
	msg := sprintf("IMG-002 %s: container '%s' image '%s' has no tag or digest", [name, c.name, c.image])
}

# ------------------------------------------------------- security context
deny contains msg if {
	pod_spec
	not pod_spec.securityContext.runAsNonRoot
	some c in containers
	not c.securityContext.runAsNonRoot
	msg := sprintf("SEC-001 %s: container '%s' may run as root; set securityContext.runAsNonRoot: true", [name, c.name])
}

deny contains msg if {
	some c in containers
	c.securityContext.privileged
	msg := sprintf("SEC-002 %s: container '%s' is privileged", [name, c.name])
}

deny contains msg if {
	some c in containers
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("SEC-003 %s: container '%s' must set allowPrivilegeEscalation: false", [name, c.name])
}

deny contains msg if {
	some c in containers
	not c.securityContext.readOnlyRootFilesystem
	msg := sprintf("SEC-004 %s: container '%s' must set readOnlyRootFilesystem: true", [name, c.name])
}

deny contains msg if {
	some c in containers
	not "ALL" in object.get(c, ["securityContext", "capabilities", "drop"], [])
	msg := sprintf("SEC-005 %s: container '%s' must drop ALL capabilities", [name, c.name])
}

deny contains msg if {
	pod_spec.hostNetwork
	msg := sprintf("SEC-006 %s: hostNetwork is not allowed", [name])
}

deny contains msg if {
	some v in pod_spec.volumes
	v.hostPath
	msg := sprintf("SEC-007 %s: hostPath volume '%s' is not allowed", [name, v.name])
}

warn contains msg if {
	pod_spec
	not pod_spec.automountServiceAccountToken == false
	msg := sprintf("SEC-008 %s: set automountServiceAccountToken: false unless the app calls the Kubernetes API", [name])
}

# ------------------------------------------------------------ reliability
deny contains msg if {
	some c in pod_spec.containers
	some r in ["cpu", "memory"]
	not c.resources.limits[r]
	msg := sprintf("REL-001 %s: container '%s' has no %s limit", [name, c.name, r])
}

deny contains msg if {
	input.kind in workload_kinds
	some c in pod_spec.containers
	some p in ["readinessProbe", "livenessProbe"]
	not c[p]
	msg := sprintf("REL-002 %s: container '%s' has no %s", [name, c.name, p])
}

deny contains msg if {
	input.kind in workload_kinds
	not input.metadata.labels["app.kubernetes.io/name"]
	msg := sprintf("META-001 %s: missing label app.kubernetes.io/name", [name])
}
