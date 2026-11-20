# 04 — It only works as root

**Story.** A change needs to write to `/app`, so someone "fixes" it by running
the container as root and making the filesystem writable.

**Break.** Deploy the insecure manifest:
```bash
kubectl --context kind-devsecops -n dev apply -f k8s/insecure/
```

**Observe / catch it (two layers).**
```bash
# shift-left: the policy would have failed CI
ci/render.sh dev sha256:$(printf '%064d' 0) x > /tmp/r.yaml
docker run --rm -v "$PWD:/src" -w /src openpolicyagent/conftest:v0.71.1 test --policy policies /tmp/r.yaml || true
# at admission, once Part 3 is on:
platform/psa-restricted.sh
kubectl --context kind-devsecops -n dev apply -f k8s/insecure/   # REJECTED
```

**Fix.** Deploy the hardened set (`make deploy ENV=dev`): non-root, read-only
root FS, drop all capabilities, write only to an `emptyDir` mounted at `/tmp`.

**Why.** Root in a container plus a mounted SA token is how Part 2's A2 attack
owned the namespace. Pod Security + conftest make "run it as root" something
you can't do by accident.
