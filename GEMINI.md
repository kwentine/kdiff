
# Table of Contents

1.  [KUBECTL<sub>EXTERNAL</sub><sub>DIFF</sub> calling conventions](#orga9c8259)

The goal of this project is to enhance `argocd diff` and `kubectl diff`
by pre-processing manifests with arbitrary `yq` expression,
before applying the user's `KUBECTL_EXTERNAL_DIFF` program.

-   The main script is `src/kdiff`
-   You should regularly commit your changes to the current branch


<a id="orga9c8259"></a>

# KUBECTL<sub>EXTERNAL</sub><sub>DIFF</sub> calling conventions

The script  `src/kdiff-inspect` was shows the calling conventions used by `kubectl` and `argocd-diff`

`kubectl diff` calls `KUBECTL_EXTERNAL_DIFF` once,
with two directories containing all the files to compare.

    $ export KUBECTL_EXTERNAL_DIFF=kdiff-inspect
    $ k diff -f v1_configmap_argocd-cm.yaml -f v1_configmap_argocd-cmd-params-cm.yaml
    Argument list: /tmp/LIVE-3407625460 /tmp/MERGED-4175425960
    Left: /tmp/LIVE-3407625460
    v1.ConfigMap.argocd.argocd-cm
    v1.ConfigMap.argocd.argocd-cmd-params-cm
    Right: /tmp/MERGED-4175425960
    v1.ConfigMap.argocd.argocd-cm
    v1.ConfigMap.argocd.argocd-cmd-params-cm

`argocd diff` calls `KUBECTL_EXTERNAL_DIFF` once for each pair of files to compare.

    $ export KUBECTL_EXTERNAL_DIFF=kdiff-inspect
    $ argocd app diff myapp
    ===== /ServiceAccount argocd/argocd-redis-ha-haproxy ======
    Argument list: /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy-live.yaml /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy
    Left: /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy-live.yaml
    /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy-live.yaml
    Right: /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy
    /tmp/argocd-diff3488706002/argocd-redis-ha-haproxy
    
    ===== /ServiceAccount argocd/argocd-repo-server ======
    Argument list: /tmp/argocd-diff74211896/argocd-repo-server-live.yaml /tmp/argocd-diff74211896/argocd-repo-server
    Left: /tmp/argocd-diff74211896/argocd-repo-server-live.yaml
    /tmp/argocd-diff74211896/argocd-repo-server-live.yaml
    Right: /tmp/argocd-diff74211896/argocd-repo-server
    /tmp/argocd-diff74211896/argocd-repo-server

