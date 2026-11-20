# Structured authentication config for the kube-apiserver.
#
# It makes the cluster trust ONE extra identity provider: GitHub Actions.
# A workflow job asks GitHub for a short-lived OIDC token (a signed JWT),
# sends it to the API server as a bearer token, and the API server:
#   1. downloads GitHub's public keys and checks the signature
#   2. checks the token was minted for this cluster (audience)
#   3. runs the CEL rules below against the token's claims
#   4. turns the claims into a Kubernetes username for RBAC
# No kubeconfig, no password, no long-lived secret anywhere in GitHub.
#
# Rendered by platform/oidc.sh: __REPO__ becomes your repository (lowercase).
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt:
  - issuer:
      url: https://token.actions.githubusercontent.com
      audiences:
        - __AUDIENCE__
      audienceMatchPolicy: MatchAny
    claimValidationRules:
      - expression: "claims.repository.lowerAscii() == '__REPO__'"
        message: "token was not issued to the expected repository"
      - expression: "claims.ref == 'refs/heads/main'"
        message: "only workflows running on the main branch may talk to the cluster"
      - expression: "has(claims.environment) && claims.environment in ['dev', 'prod']"
        message: "only jobs bound to the dev or prod GitHub environment may talk to the cluster"
    claimMappings:
      # sub looks like repo:<owner>/<repo>:environment:<env>
      username:
        expression: "'github:' + claims.sub.lowerAscii()"
      groups:
        expression: "['github-actions']"
