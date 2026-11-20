# Optional: runtime detection with Falco

The audit log (Part 4) records what hits the **Kubernetes API**. Falco watches
**syscalls** inside your containers, so it sees things the API never does: a
shell starting in a container, `/etc/shadow` being read, an unexpected outbound
connection, a package manager running at runtime.

## Why it's optional here

Falco reads kernel events via eBPF or a kernel module. In **kind on Docker
Desktop** (macOS/Windows) the node is a container inside a Linux VM, and the
eBPF probe is unreliable there. On a real Linux host (or a Linux CI runner) it
works well. So this is an enrichment lab, not a dependency — the audit-log
detector is the course's dependable detection layer.

## If you're on Linux and want to try it

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true
kubectl -n falco logs -l app.kubernetes.io/name=falco -f
```

Then run `attack/a2-pod-compromise/exploit.sh` and watch Falco fire a
"Terminal shell in container" alert the instant the exec happens — the runtime
complement to the API-level `RUNTIME-EXEC` finding from `detect/detect.py`.

The default Falco ruleset already covers the attacks in this lab: terminal
shells, writes below sensitive directories, and reads of the ServiceAccount
token path.
