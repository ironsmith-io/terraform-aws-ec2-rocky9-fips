# GitHub Workflow

How this repo is developed and released. Solo maintainer, public Terraform
Registry module, **trunk-based (GitHub Flow)**: `main` is the only long-lived
branch and is always releasable. (The old `develop` branch was retired 2026-08.)

## Branching

- Every change happens on a **short-lived branch off `main`**, never directly on `main`.
- Name branches `type/short-description`, where `type` matches Conventional Commits:
  `feat/`, `fix/`, `chore/`, `build/`, `ci/`, `docs/`, `test/`, `refactor/`.
  Examples: `fix/ebs-null-check`, `ci/provider-matrix`, `feat/spot-support`.
- After merge, delete the branch: GitHub auto-deletes the *remote*; locally use `git branch -D`
  (squash-merge makes git consider the branch "unmerged") followed by `git fetch --prune`.

## Make a change

```bash
git checkout main && git pull origin main
git checkout -b fix/thing
# ...work, commit (Conventional Commits)...
git push -u origin fix/thing
gh pr create --base main --fill
# wait for CI to pass, then Squash and merge in the GitHub UI
git checkout main && git pull origin main   # resync local main
git branch -D fix/thing                     # -D: squash-merge leaves the branch "unmerged" to git
git fetch --prune                           # drop stale origin/<branch> (GitHub auto-deleted the remote)
```

## Commits & PRs

- **Conventional Commits** for both commit messages and PR titles:
  `feat:`, `fix:`, `chore:`, `build:`, `ci:`, `docs:`, `test:`, `refactor:`
  (Dependabot uses `build(deps):` and `ci(deps):`).
- Breaking change: add `!` (e.g. `feat!:`) or a `BREAKING CHANGE:` footer.
- Claude-assisted commits include a `Co-Authored-By:` trailer.

## Merging — always PR, squash-and-merge

- **Everything goes through a PR.** No direct pushes to `main`; CI gates every change.
- **Squash and merge** is the standard → one clean commit per PR, linear history,
  no merge commits. The **PR title becomes the squash commit**, so keep it
  Conventional-Commits clean.

## CI (`.github/workflows/ci.yml`)

- Runs on **PRs to `main`** and **pushes to `main`**. PR must be green before merge.
- Jobs: `fmt`/`validate` and unit tests across an **AWS provider matrix (`~> 5.0`
  and `~> 6.0`)**, example `validate`, `tflint`, `checkov`, and Go `build`/`vet`/`lint`.
- **Terratest integration tests are NOT in CI** (they deploy real AWS resources and
  cost money). Run locally: `make test-integration` (or `RUN=TestName` for one).

## Dependabot

- **Monthly**, **grouped** version-update PRs for `gomod` (the `test/` module) and
  `github-actions`.
- **Security updates are not on that schedule**: Dependabot opens them as soon as an
  advisory is published, as individual (ungrouped) PRs. Merge those promptly.
- Merge like any other PR: **squash** → one `build(deps): ...` (Go) or `ci(deps): ...`
  (Actions) commit authored by `dependabot[bot]`.
- Security alerts are scored against the **default branch (`main`)** and only clear
  once the fix is merged to `main`.

## Releases (Terraform Registry)

The Registry publishes on new **SemVer tags**. Process:

```bash
# 1. Update CHANGELOG.md by hand (Conventional-Commits style, v-prefixed headers)
# 2. Merge the change to main via PR
# 3. Tag main and push the tag:
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

- CHANGELOG.md is maintained **manually** (no semantic-release or release-please).
- After pushing the tag, create the matching **GitHub Release** from that version's
  CHANGELOG section (`gh release create vX.Y.Z --title vX.Y.Z --notes-file <section>`),
  so the repo's "Latest" release stays in step with the Registry.
- SemVer: `fix` → patch, `feat` → minor, breaking → major. Provider-floor bumps
  that drop a supported major are breaking.
- **Tag only consumer-facing changes** (the `.tf` files). Test/CI/dev-dependency changes
  (e.g. a security bump in `test/`) merge to `main` **without a tag** — Dependabot alerts clear
  on *merge, not tag*. Stage such changes under a `## [Unreleased]` heading in CHANGELOG.md and
  fold them into the next real release (rename `[Unreleased]` → the version when you tag).

## Local environment

- Don't leave `TF_VAR_*` / `TEST_*` exported (e.g. via `.envrc`/direnv). They override the unit
  tests' variable defaults and the integration tests' subnet/key inputs, causing confusing
  "subnet not found" and precondition failures. Keep them commented, and open a **fresh shell**
  to clear any already-exported ones — commenting `.envrc` does not unset a live shell.

## Repo settings checklist (one-time, GitHub UI)

**General → Pull Requests** (`/settings`)
- [ ] Allow **Squash merging** only — uncheck *merge commits* and *rebase*.
- [ ] Squash default commit message → **Pull request title**.
- [ ] **Automatically delete head branches**.

**Rules → Rulesets → branch ruleset for `main`** (`/settings/rules`)
- [ ] Enforcement **Active**; target the **default branch** (`main`).
- [ ] **Require a pull request before merging** → set **Required approvals = 0**
      (solo: you can't approve your own PRs, so CI is the gate — nested under that checkbox).
- [ ] *Require status checks*: **leave OFF** for solo — the matrix check names are brittle and a
      single mistyped required check blocks every merge (a `ci` that no job reports waits forever).
      Eyeball CI green before merging instead. For a hard gate, add one `ci-success` aggregator job
      (`needs:` all jobs) and require only that context — never the individual matrix names.
- [ ] **Restrict deletions** + **Block force pushes** (each is its own rule; neither is
      implied by enabling the ruleset, so check both).

**Rules → Rulesets → tag ruleset for release tags** (`/settings/rules`)
- [ ] Enforcement **Active**; **Target tags** → *Include by pattern* → **`v*`**.
- [ ] **Restrict deletions** + **Restrict updates** + **Block force pushes**
      (leave *Restrict creations* OFF so new `vX.Y.Z` tags can still be pushed).
- [ ] Protects published release tags the Registry serves from being moved/deleted.

**Code security** (`/settings/security_analysis`)
- [ ] **Secret scanning** + **Push protection**.
- [ ] **Private vulnerability reporting**.
- [ ] **Dependabot security updates** (separate from version-update PRs).

**Actions → General** (`/settings/actions`)
- [ ] Workflow permissions → **Read repository contents (read-only)** default.
- [ ] "Allow GitHub Actions to create and approve pull requests" → off (unless needed).

**General → Features**
- [ ] Disable unused **Wiki / Projects / Discussions**.

**Dependabot PRs:** no approval is needed (required approvals = 0). Wait for CI to go
green, then `gh pr merge <PR> --squash`. (`--auto` needs *Allow auto-merge* enabled,
and with no required status checks it merges immediately instead of waiting for CI.)
