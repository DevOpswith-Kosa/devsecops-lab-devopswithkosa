# 06 — The leaked kubeconfig

**Story.** A CI kubeconfig ends up in a log, a Slack message, a laptop backup.
If it's a long-lived admin credential, that's game over.

**Break (Part 1 world).** The insecure pipeline keeps `KUBECONFIG_ADMIN` as a
secret; Part 2's A1 attack exfiltrated it. Once copied, it works from anywhere,
forever.

**Fix — change the model, not the password.**
```bash
make oidc     # cluster trusts GitHub OIDC (from this repo)
make oidc-vars
gh secret delete KUBECONFIG_ADMIN
```
Now the pipeline authenticates with a **short-lived** token minted per run,
valid only from your repo/branch/environment, mapped to a **least-privilege**
Role in one namespace. There is no durable credential to leak, and a `dev`
token can't touch `prod`.

**Observe.** A leaked token is useless minutes later; the audit log
(`make detect`) shows exactly which identity did what.

**Why.** Most breaches are a valid credential used by the wrong person.
Federated, short-lived identity removes the thing attackers want most.
