# Unit tests for the policy: conftest verify --policy policies
package main

import rego.v1

good := {
	"kind": "Deployment",
	"metadata": {"name": "web", "labels": {"app.kubernetes.io/name": "web"}},
	"spec": {"template": {"spec": {
		"automountServiceAccountToken": false,
		"securityContext": {"runAsNonRoot": true},
		"containers": [{
			"name": "app",
			"image": "localhost:5001/web@sha256:abc",
			"securityContext": {
				"allowPrivilegeEscalation": false,
				"readOnlyRootFilesystem": true,
				"capabilities": {"drop": ["ALL"]},
			},
			"resources": {"limits": {"cpu": "100m", "memory": "64Mi"}},
			"readinessProbe": {},
			"livenessProbe": {},
		}],
	}}},
}

with_container(patch) := json.patch(good, [{"op": "add", "path": sprintf("/spec/template/spec/containers/0/%s", [k]), "value": v} | some k, v in patch])

test_good_manifest_passes if {
	count(deny) == 0 with input as good
	count(warn) == 0 with input as good
}

test_latest_tag_denied if {
	some msg in deny with input as with_container({"image": "localhost:5001/web:latest"})
	startswith(msg, "IMG-002")
}

test_untagged_image_denied if {
	some msg in deny with input as with_container({"image": "localhost:5001/web"})
	startswith(msg, "IMG-002")
}

test_foreign_registry_denied if {
	some msg in deny with input as with_container({"image": "docker.io/nginx:1.27"})
	startswith(msg, "IMG-001")
}

test_privileged_denied if {
	sc := object.union(good.spec.template.spec.containers[0].securityContext, {"privileged": true})
	some msg in deny with input as with_container({"securityContext": sc})
	startswith(msg, "SEC-002")
}

test_root_denied if {
	bad := json.patch(good, [{"op": "remove", "path": "/spec/template/spec/securityContext"}])
	some msg in deny with input as bad
	startswith(msg, "SEC-001")
}

test_missing_limits_denied if {
	some msg in deny with input as with_container({"resources": {}})
	startswith(msg, "REL-001")
}

test_service_is_ignored if {
	count(deny) == 0 with input as {"kind": "Service", "metadata": {"name": "web"}}
}
