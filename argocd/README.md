# ArgoCD (Phase 9, untested draft)

Install (pin a release; `stable` moves):
    kubectl create namespace argocd
    TAG=$(gh api repos/argoproj/argo-cd/releases/latest --jq .tag_name)
    kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$TAG/manifests/install.yaml
    kubectl -n argocd get pods
ArgoCD adds roughly a gigabyte of memory: the single 8 GB node will probably need a second node.

Admin access: port-forward `svc/argocd-server`, read the initial password from the
`argocd-initial-admin-secret` secret, change it, then delete that secret.

Open problem: k8s manifests contain `${...}` placeholders (ACR name, DB hosts, identity client IDs).
Options: (1) put the values in the Application spec as kustomize `images`/`patches`, applied from a
private file and never committed; (2) commit the identifiers (not secrets) and drop envsubst.

Apply when ready: `kubectl apply -f argocd/appproject.yaml -f argocd/application-dev.yaml`.
Prod should stay manual-sync with approval.
