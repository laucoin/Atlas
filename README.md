# Atlas 🪐

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Talos-326CE5?logo=kubernetes&logoColor=white)
![GitOps](https://img.shields.io/badge/GitOps-Argo%20CD-EF7B4D?logo=argo&logoColor=white)

**Atlas** turns a single bare-metal machine into a small, opinionated, self-hosted home cloud. The entire stack is described as code and rebuilt automatically by pushing to Git — there is no click-ops and no manual server administration.

## This repository 📖

Atlas is **one Git repository** that holds two kinds of code: a one-time **OpenTofu bootstrap** that installs the cluster, and a continuously-reconciled set of **GitOps manifests** that Argo CD keeps in sync forever after.

You run `tofu apply` three times to stand up the node, then Argo CD takes over. From that point on you change the platform by editing YAML under `apps/`, committing, and pushing — never by hand on the server.

### Core tenets

- **Declarative first** — everything is code; no interactive administration.
- **Single node by design** — one bare-metal box running Talos Linux. Multi-node HA is out of scope.
- **SSO everywhere** — every exposed service sits behind Authentik.
- **Disaster recovery built in** — a hardware failure is an inconvenience, not a catastrophe. State is rebuilt from OpenTofu bootstrap and Velero backups.

### What's in the box

| Concern         | Tooling                                           |
| --------------- | ------------------------------------------------- |
| OS & Kubernetes | Talos Linux + k3s                                 |
| GitOps engine   | Argo CD (`app-of-apps` via `ApplicationSet`)      |
| Ingress & TLS   | Traefik + cert-manager (Let's Encrypt HTTP-01)    |
| Identity / SSO  | Authentik (forward-auth front door)               |
| Secrets         | Infisical + External Secrets Operator             |
| Registry        | Harbor (private images + vulnerability scanning)  |
| Observability   | Prometheus, Loki, Promtail, Grafana, Alertmanager |
| Backups & DR    | Velero (offsite, S3-compatible)                   |
| Storage         | `local-path-provisioner`, MetalLB                 |

### Layout

```text
bootstrap/        OpenTofu modules — run once with `tofu apply`
  talos/            installs Talos Linux on the node
  baseline/         cluster floor: storage, MetalLB, cert-manager, issuers
  argo/             installs Argo CD and points it at this repo
apps/             GitOps manifests — reconciled continuously by Argo CD
  _root/            the root ApplicationSet (one App per apps/ subdir)
  infra/            Traefik, External Secrets Operator, ClusterSecretStore
  identity/         Authentik + TLS / IngressRoute / forward-auth
  platform/         Infisical, Harbor, Velero
  observability/    kube-prometheus-stack, Loki, Promtail, ServiceMonitors
charts/           Helm charts
```

## How to install and use it? ⚙️

The full end-to-end procedure — taking a bare-metal machine on your home LAN all the way to a running platform — is documented step by step, including every manual `kubectl` command, DNS record, and UI action.

👉 **[Read the Getting Started guide](https://doc.laucoin.fr/atlas/technical/getting-started.html)**

> **Warning:** Atlas serves everything on ports **80** and **443** and expects your home router to forward both to the node's LAN IP, plus a wildcard `*.atlas.<your-domain>` A record pointing at your public IP. Make sure you have a domain and router access before you start.

For a conceptual overview of the architecture, personas, and contribution rules, see [`AGENTS.md`](./AGENTS.md).

## Contributing 💻

1. **Declarative first** — new deployments go under `apps/` as Helm charts or raw manifests so the Argo CD `app-of-apps` pattern picks them up.
2. **Never hardcode secrets** — reference Infisical through `ExternalSecret` resources.
3. **Keep the docs in sync** — when you add a service or workflow, update the corresponding VitePress pages.
4. **Validate before pushing** — the repo ships `pre-commit`, `yamllint`, and `.editorconfig` configs; run them locally.

## Contributors 🧑‍💻

- [Luc AUCOIN](https://github.com/laucoin)
- [My Friend](http://github.com/claude)

## License

Distributed under the MIT License. See [`LICENSE`](./LICENSE) for details.
