# Instructions for AI Agents — Spec-Driven Development & Stacked PRs

## 1. Project Context & Documentation Resolution

- **Target Project:** atlas — a single Debian node described entirely in code. One Ansible repository, two container runtimes, roughly a dozen hardened services behind one reverse proxy and one sign-on gate. Deliberately no orchestrator ([ADR 001](https://doc.laucoin.fr/atlas/technical/adr/001-debian-docker-over-talos-kubernetes)).
- **Default Documentation URL:** `https://doc.laucoin.fr/atlas`
- **Implementation Repository:** the private `atlas/` Ansible repository. It is **separate** from the documentation source — Atlas implementation code never lands in the documentation repository.

### Agent Rule for Doc Resolution

Before implementing any feature or reading a specification:

1. Check if a local path (e.g., `documentation/atlas`) or specific URL was supplied in the user's prompt.
2. If unspecified, ask the user before proceeding:
   > *"Should I fetch the specification from the default URL (`https://doc.laucoin.fr/atlas`) or a local path?"*

### Where specs live within that source

| Section | Holds |
| ------- | ----- |
| `functional/features/` | One page per capability — rules, actors, BDD scenarios. The **what** and **why**. |
| `functional/roles-and-permissions` | The security baseline: actors, roles, trust boundary. Read before any gated feature. |
| `technical/` | Architecture, storage layout, network topology, security model, backup runbooks, Ansible conventions. The **how**. |
| `technical/implementation-plan` | **The step index.** Its five phases and their role deliverables are the numbered, atomic steps this protocol refers to. |

## 2. Communication Style & Behavioral Rules

- **Absolute Conciseness:** Direct, factual, no pleasantries or theoretical ramblings.
- **Simplicity:** No academic or unnecessarily complex jargon. Explain actions in 1–2 simple sentences.
- **Strict Scope:** Address only the requested task. Do not refactor surrounding code or fix unrelated items.
- **English only:** Every page, commit message and comment is written in English.

## 3. Spec-Driven Development (SDD) Protocol

Strict separation must be maintained between documentation/specs and implementation code.

### Phase 1: Specification (VitePress)

- Create or update specifications in the designated documentation location.
- **Functional before technical.** A capability is described in `functional/features/` and its actors placed in `functional/roles-and-permissions` before anything is written in `technical/`.
- Break specs into explicit, numbered, atomic steps mapped onto the phases in `technical/implementation-plan` — one step per Ansible role deliverable (e.g., `Phase 1 / Step 3: storage`, `Phase 2 / Step 1: traefik`).
- Every step carries **acceptance criteria that are either met or not** — never "mostly done". Each step's criteria end with: *a second immediate converge reports zero changes*.
- Links between pages are **root-absolute** from the docs root (`/atlas/technical/architecture`), never relative; index pages keep their trailing slash.
- **FORBIDDEN:** Do not touch application source code or `.vitepress/config.ts` during this phase.

### Phase 2: Implementation via GitHub PR Stacks

- Base implementation **exclusively** on the validated specification step fetched from the resolved documentation source.
- Deliver every single implementation step as an isolated GitHub PR stacked on the previous step's branch.
- Implementation is one Ansible role per concern under `roles/`, composed by `playbooks/site.yml` and tagged so a single service can be converged alone.
- The **idempotency rules** in `technical/ansible-conventions` replace the absent test harness and are non-negotiable — in particular: no bare commands; render, compare, restart; generate once, persist, reuse; never destroy data outside `playbooks/storage.yml`.
- **FORBIDDEN:** Do not modify documentation files during code implementation steps.

## 4. Git Strategy & GitHub Stacked PRs Execution

To ensure easy, precise, and hazard-free code reviews:

1. **Stack Branching:** For step $N$, create branch `feat/<feature>/0N-<step-name>` branching from `0N-1` (or `main` for step 1). Feature names follow the role names — `feat/hardening/01-ssh-lockdown`, `feat/traefik/02-wildcard-certificate`.
2. **Atomic Implementation:** Implement ONLY the scope of step $N$ on this branch.
3. **GitHub PR Creation:** Create/open a Pull Request targeting base branch `feat/<feature>/0N-1` (using `gh pr create --base feat/<feature>/0N-1`).
4. **Sequential Blocking:** Never start step $N+1$ until step $N$ PR is reviewed or validated.
5. **Phase order is a dependency order.** Do not open a phase-3 stack while phase 2 is unmerged — the front door exists before anything sits behind it.

## 5. Requirement Validation & Internal Documentation / README Updates

Before marking any task or PR step as complete:

1. **Validation Against Specification:**
  - Explicitly verify that the written code strictly matches every functional and technical requirement stated in the documentation — the step's acceptance criteria in `technical/implementation-plan`, and the scenarios in `functional/workflows`.
  - Atlas has **no automated test suite, by choice.** The verification that replaces it is mandatory and has three parts:
    - `ansible-playbook playbooks/site.yml --check --diff` reviewed before applying.
    - The converge applied.
    - **The converge re-run immediately, reporting zero changes.** Anything else is a defect in the role, not a quirk of the run.
  - Documentation changes are verified with `pnpm build`, which fails on dead links.

2. **README.md & Internal Doc Synchronization:**
  - Update (or create if missing) `README.md` and internal configuration/documentation files whenever a role interface, service, inventory variable, secret, image tag or dependency changes.
  - Image tags and digests live in exactly one file — `inventory/group_vars/all/images.yml`. A version bump touches that file and nothing else.
  - The `README.md` MUST include an exhaustive **"How to install and use it? ⚙️"** section detailing:
    - Prerequisites & runtime versions (Debian stable, Ansible on the workstation, `age`, Docker on the host, `gh`).
    - Configuration variables with defaults and descriptions — Atlas has no `.env` file; configuration is inventory variables and encrypted secrets:

      | Where | Holds |
             | ----- | ----- |
      | `inventory/group_vars/all` | Domain, timezone, palette, volume sizes, retention |
      | `inventory/group_vars/all/images.yml` | Every image tag and digest |
      | `inventory/host_vars/atlas` | Anything genuinely specific to this machine |
      | `roles/*/defaults` | Sensible defaults, overridable |
      | Encrypted values | Secrets, encrypted **per value** with an age key so diffs stay reviewable |

    - Local setup & installation steps, including that the **age key stays on the workstation and never reaches Atlas**, and that nothing is decrypted at rest on the host.
    - Build, run, test, and verification commands (see §8).

## 6. Micro-Diff Limits

- **Max Diff Scope:** Never modify more than **10 files** or **100 lines of code** per stacked PR (excluding necessary `README.md` or doc synchronization updates).
- **Atomic Commits:** Format: `feat(<scope>): [Step N] <short summary>` — scope is the role or doc section (`feat(storage): [Step 3] declare registry volume`).
- If a step exceeds these limits, stop and split it into smaller stacked sub-branches/PRs.

## 7. Adjustments & Error Recovery

- **Misunderstanding / Bug:** Stop immediately. Do not stack patch commits on a broken PR. Explain the issue in 1 sentence to allow a `git reset`.
- **Scope Change / Unforeseen Case:** Update the specification documentation FIRST. Do not code until the spec commit is created.
- **Cosmetic / UI Tweaks:** Keep modifications localized strictly to the relevant visual component within the active branch. Inline `<style scoped>` blocks are split OOCSS-style into `OBJECTS` and `SKINS` sections; no container-descendant selectors.
- **Deviation from the documented design** is either corrected, or written down in the specs as an accepted risk. It is never left undocumented.

## 8. Project Commands

### Documentation source (VitePress repository)

- **Local Specs Preview:** `pnpm dev`
- **Tests:** none — this repository has no test suite. `pnpm build` is the verification gate.
- **Build / Verification:** `pnpm build` — fails on dead links; run it after touching any link or moving a page. `pnpm preview` serves the built output.

### Implementation (the private `atlas/` Ansible repository)

- **Tests:** none, by choice. Idempotency is enforced by the rules in `technical/ansible-conventions`, not by a harness.
- **Review before applying, always:** `ansible-playbook playbooks/site.yml --check --diff`
- **Apply:** `ansible-playbook playbooks/site.yml`
- **One service only:** `ansible-playbook playbooks/site.yml --tags <role>`
- **Build / Verification:** re-run the converge immediately. **Zero changes is the proof.**
- **Destructive volume work** lives only in `playbooks/storage.yml` and requires an explicit confirmation variable.

## 9. Atlas Invariants

Never violate these without an ADR recording the change:

- **One node.** No clustering, no failover, no second server. If the node is down, Atlas is down — accepted, not a defect.
- **Ansible only.** No Kubernetes, Talos, Helm, Nomad or Swarm.
- **Manual, watched converges.** No deploy key on the host, no scheduled convergence, no automation with a path into the machine. The age key stays on the workstation.
- **Everything behind the gate,** except the three named exceptions — registry pull/push, the code-quality scanner API, and home automation. Adding a fourth requires an ADR.
- **Re-running never destroys data.** Declared volumes survive every converge.
