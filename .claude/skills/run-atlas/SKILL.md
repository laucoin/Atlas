---
name: run-atlas
description: Drive a clean end-to-end Atlas deployment (Talos → Argo → SSO → apps) following documentation/atlas/technical/getting-started.md. Use when bootstrapping a fresh node, validating the IaC, or recovering a stuck phase. Encodes the manual checkpoints and the recovery patterns that aren't obvious from the guide.
---

# Running the Atlas IaC

Atlas = one Git repo. You run `tofu apply` 3 times (Phases 2–4), then Argo CD
reconciles everything in `apps/` from the tracked branch. Follow
`documentation/atlas/technical/getting-started.md` for the canonical steps; this
skill adds the operational reality and the recovery moves.

## Before you start — gather inputs
- Node: LAN IP, gateway, NIC name, install disk — the NIC + disk are **only**
  visible on the Talos console (`F1 Summary`, `F3 Network Config`). Ask the user.
- Domain (wildcard `*.atlas.<domain>` → router public IP; router NATs 80/443 → node).
- Branch Argo tracks: confirm `main` vs a feature branch. If a feature branch,
  set it in **both** `apps/_root/applicationset.yaml` (`revision` + `targetRevision`)
  and `bootstrap/argo/terraform.tfvars` (`repo_revision`). The repo must be
  **pushed and public** (or Argo needs creds) before Phase 4.
- Velero: S3 bucket name, region, endpoint, access/secret key (Phase 9).

## Pushing
The agent usually has **no SSH key / `gh`** here. Commit locally, then ask the
user to `! git push`. Argo only sees pushed commits, so push before expecting any
`apps/` change to reconcile.

## Phase cheat-sheet
1. **Talos** (`bootstrap/talos`): write `terraform.tfvars`, `tofu init && apply`.
   Validates config on the node *before* wiping the disk — a rejected apply is
   harmless, so iterate freely.
2. **Baseline** (`bootstrap/baseline`): `lb_ip` = node IP, `acme_email`. Installs
   local-path, MetalLB, cert-manager + issuers.
3. **Argo** (`bootstrap/argo`): `repo_url`, `repo_revision`, `tofu apply`. After
   this, never `kubectl apply` app changes — edit `apps/`, commit, push.
4. **Phase 5+** are all Argo-reconciled and auto-sync in parallel.

## Manual checkpoints (the guide's "do this by hand")
- **`infisical-bootstrap`** secret (ns `infisical`): ENCRYPTION_KEY + AUTH_SECRET.
  Out-of-band, unrecoverable — have the user save them.
- **Infisical UI** (project slug **`atlas`**, env `prod`, two Universal-Auth
  identities `eso` read-only + `seeder` read-write). The hostname is **not
  reachable yet** at this point (see deadlock below) — reach it with
  `kubectl -n infisical port-forward svc/infisical-infisical-standalone-infisical 8080:8080`.
- **`infisical-credentials`** (ns `external-secrets`) + **`infisical-seeder-credentials`**
  (ns `infisical`) from those identities.
- **Velero** S3 keys: seed `VELERO_S3_ACCESS_KEY` / `VELERO_S3_SECRET_KEY` into
  Infisical `/velero` (the seeder does NOT create these).

## Recovery patterns (hit during the first real run — expect them)

- **Talos ≥1.13 hostname**: the config has both `machine.network.hostname` and an
  auto-generated `HostnameConfig{auto: stable}` → "static hostname is already set
  in v1alpha1 config". Set the hostname via a `HostnameConfig{auto: off, hostname: …}`
  patch and drop `machine.network.hostname` (see `bootstrap/talos/patches/hostname.yaml.tftpl`).
  `talos_version` must be ≥1.13 for this.
- **Node booted but Talos API (50000) refused**: the USB has `talos.halt_if_installed`
  and the disk already has Talos → it halts. Reboot from USB and remove that token
  from the GRUB kernel line to enter maintenance mode.
- **ServiceMonitor before Prometheus CRDs**:
  - In **tofu** (baseline cert-manager) it *hard-fails* — there's no self-heal,
    so disable the chart ServiceMonitor and ship a standalone one in
    `apps/observability/` (with `SkipDryRunOnMissingResource`).
  - In **Argo** charts (traefik, etc.) it self-heals once kube-prometheus-stack
    installs the `monitoring.coreos.com` CRDs — just wait for reconcile.
- **Infisical seeder fails (exit 22, no logs)**: this Infisical API needs
  `workspaceId` (not `workspaceSlug`) for writes and won't auto-create folders.
  The fixed `apps/platform/infisical-seeder.yaml` resolves the workspace UUID and
  creates each folder first. Verify with the live API via the port-forward.
- **ESO `ClusterSecretStore` stuck `InvalidProviderConfig`**:
  - "secret not found" right after you created the credentials secret → stale
    informer cache: `kubectl -n external-secrets rollout restart deploy/external-secrets`.
  - "folder not found (404)" → the seeder hasn't created that folder yet.
- **ESO `ExternalSecret` `SecretSyncedError` after the value now exists** (long
  backoff): force it — `kubectl -n <ns> annotate externalsecret <name> force-sync=$(date +%s) --overwrite`.
- **`platform` app sync deadlocked** "waiting for completion of hook …" with
  IngressRoutes/ExternalSecrets `SyncFailed: no matches for kind` (applied before
  the CRDs existed): the stuck Sync hook prevents the retry. Release it once the
  CRDs exist: `kubectl -n argocd patch app platform --type=json -p='[{"op":"remove","path":"/operation"}]'`
  — Argo re-syncs cleanly.
- **A pod started before its Secret/PVC existed** (Velero, Authentik, seeder):
  `kubectl delete pod …` (or `rollout restart`) so it picks up the dependency.
- **Authentik SSO "invalid_request: malformed" / "Invalid grant_type"**: Authentik
  2026.x defaults `OAuth2Provider.grant_types` to `[]`. Set
  `grant_types: [authorization_code, refresh_token]` on each oauth2provider in
  `apps/identity/authentik-blueprints.yaml` (the proxy/forward-auth provider is
  unaffected).
- **Velero node-agent 0 pods**: its hostPath mounts violate baseline PSS — label
  the `velero` namespace `pod-security.kubernetes.io/enforce: privileged`.
- **Velero BSL `Unavailable` / S3 403 `AccessDenied`**: creds authenticate but
  aren't authorized — fix on the S3 provider side (bucket region + a policy/role
  granting the user access to the bucket). The BSL re-validates ~every minute.
- **SonarQube "Background initialization failed" creating `extensions/downloads`**:
  the chart's `init-fs` chowns data/temp/logs but not `extensions`, and local-path
  ignores `fsGroup`. Add an `extraInitContainers` chown for `/opt/sonarqube/extensions`.

## Verifying
- `kubectl -n argocd get applications` → all `Synced/Healthy`.
- Each hostname over HTTPS returns 200/302 with `ssl_verify_result=0` (trusted
  Let's Encrypt prod cert) — `CN=TRAEFIK DEFAULT CERT` means the IngressRoute
  isn't wired/applied yet.
- SSO authorize smoke test (no browser): hitting `/application/o/authorize/?…`
  should 302 to `/if/flow/default-authentication-flow/`, not redirect back with
  `error=invalid_request`.

## Notes on design intent (don't "fix" these)
- SonarQube Community Build and Home Assistant use **native login** by design
  (no usable OIDC / forward-auth breaks their APIs).
- `infisical-velero` ClusterSecretStore is `ReadOnly` (the `eso` identity is a
  viewer) — that's correct, not a bug.
