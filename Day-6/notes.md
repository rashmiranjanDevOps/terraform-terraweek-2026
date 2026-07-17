# Day 6 - Terraform Workspaces, Testing, Security & CI/CD

## Task 1: Workspaces - The Why

So today started with Workspaces, and honestly my first reaction was "wait, isn't this just... folders?" No — it's actually simpler and a bit more dangerous than that, which is why it took a minute to click.

**What is a Terraform Workspace?**

A workspace is a named "slot" of state within the same backend. Same `.tf` files, same provider config — but each workspace gets its own separate state file. So `default`, `staging`, and `prod` can all exist from the exact same config, just pointing at different state.

**Commands I actually ran**

```bash
terraform workspace list
terraform workspace new staging
terraform workspace new prod
terraform workspace select default
terraform workspace show
```

`list` shows every workspace with a `*` next to whichever one is active. `new` creates one AND switches you into it immediately, with a totally empty state — which means the very next `plan` will show everything needs to be created, since that workspace has never tracked anything before. `select` switches without creating. `show` just prints the current one, mostly useful for scripts/CI so you can confirm you're not about to do something in the wrong environment.

**Why this is isolated but also a little risky**

Isolated state means a `destroy` in `staging` literally cannot touch anything in `prod`, because Terraform is reading a completely different state file. That part's genuinely safe. The risky part is the *switching itself* — if I `terraform workspace select prod` by mistake and then run `apply`, there's nothing stopping that. The config doesn't know or care which workspace it's in unless I explicitly reference `terraform.workspace` somewhere.

**Workspaces vs separate backends (this is the part that actually matters for interviews)**

I used to think workspaces WERE the "proper" way to do multi-environment Terraform. Turns out, most production teams treat workspaces as fine for small/similar environments (like short-lived feature branches or dev/staging), but for prod specifically, a lot of teams use a completely separate backend config — different state file, sometimes even a different AWS account — so that a wrong `workspace select` physically can't put prod at risk. Workspaces isolate *state*. They don't isolate *access* or *credentials*.

**Interview tip:** if asked "are workspaces enough for managing prod safely," the honest answer is "they isolate state, not access" — don't just say yes.

## Task 2: Terraform Testing Framework

This is the part that genuinely surprised me — I didn't know Terraform had a real, native testing framework built in until today.

**What is `terraform test`?**

It's a command (available since Terraform 1.6+) that runs test files written in HCL, usually sitting in a `tests/` folder, ending in `.tftest.hcl`. Each test file has one or more `run` blocks, and each `run` block can either just `plan` or actually `apply`, then check the results with `assert` blocks.

**Why this matters**

Before today my only way of "testing" a module was: run `plan`, eyeball the output, hope I didn't miss anything. Now I can actually write something like "if environment = dev, instance size MUST equal micro" and Terraform will fail loudly if that's not true — instead of me just visually scanning a plan output and maybe missing it.

**Plan tests vs apply tests**

A plan-based test (`command = plan`) just generates a plan and checks values against it — fast, no real infrastructure touched. An apply-based test (`command = apply`) actually creates real resources, checks them, and then — this is the part I liked most — Terraform automatically destroys everything created during that test once the file finishes running. No manual cleanup, no orphaned resources sitting around racking up cost.

**Tests I wrote/ran**

```
Success! 4 passed, 0 failed.
```

- `dev_uses_micro` — passes `environment = dev` and asserts the resolved instance size is micro.
- `prod_uses_medium` — same idea but for prod, expecting medium.
- `name_has_prefix` — checks the generated resource name actually carries the expected prefix, so naming conventions aren't just "hoped for," they're enforced.
- `rejects_bad_environment` — this one's actually a negative test — passes an invalid environment value on purpose and asserts the run FAILS, proving my variable `validation` block actually works instead of just assuming it does.

**Why the negative test mattered most to me**

It's easy to write tests that check "good input works." It's a different mindset to write a test that checks "bad input correctly gets rejected." That one gave me way more confidence than the other three combined, honestly.

**`terraform fmt -recursive` and `terraform validate` — quick refresher**

`fmt -recursive` just auto-formats every `.tf` file in every subfolder, not only the top level — keeps diffs clean across the whole project. `validate` is a fully offline check — no credentials needed, no real infra touched — it just confirms the syntax and internal references (variable types, correct arguments) are actually valid. It does NOT catch logic bugs like "dev should use micro" — that's exactly what `terraform test` is for, which is why both matter together, not one instead of the other.

**Interview tip:** if asked "what's the difference between validate and test" — validate checks the config is *written correctly*, test checks the config *behaves correctly*.

## Task 3: Security Scanning with Trivy

**What is Trivy?**

Heard of Trivy before as a container image scanner, but didn't realize it also scans Terraform/IaC directly for misconfigurations. Ran it today for the first time on my own code, felt a bit like handing in an assignment for grading.

**The command**

```bash
trivy config .
```

This recursively scans every IaC file in the current folder — no AWS credentials needed at all, it's purely reading the `.tf` files themselves and checking them against known-bad patterns.

**My result**

```
Tests: 24 (SUCCESSES: 24, FAILURES: 0)
Misconfigurations: 0
```

Zero misconfigurations, which honestly felt good, but I also went and actually read what it WOULD have flagged, just so I'd recognize it if it ever showed up:

- Security groups wide open to `0.0.0.0/0` on ports that shouldn't be public
- Storage without encryption at rest
- Missing access logging
- IAM policies that are way more permissive than they need to be

**Why scan the code instead of the deployed infrastructure**

This is the "shift-left" idea — catching a misconfiguration in the `.tf` file itself, before it's ever applied, is way cheaper and safer than catching it after it's already live in the cloud and someone has to go fix a real running resource. Scanning code = catching the mistake at the cheapest possible point.

**Interview tip:** if asked "why not just audit the cloud environment after deployment" — because by then the misconfiguration is already live and potentially already exploited; scanning the code catches it before it ever exists as real infrastructure.

## Task 4: GitHub Actions CI/CD

This tied everything from today (and honestly from Day 5 too) together into something that actually runs automatically instead of me remembering to do it manually every time.

**The pipeline, step by step**

```
Checkout Repository → Setup Terraform → Terraform fmt → Terraform init
→ Terraform validate → Terraform test → Trivy Scan → Pipeline Passed
```

- **Checkout Repository** — pulls the repo onto the GitHub runner so it actually has the files to work with.
- **Setup Terraform** — installs a specific, pinned Terraform CLI version onto the runner.
- **Terraform fmt** — runs in check mode, fails the whole pipeline if anything isn't formatted properly, instead of silently reformatting it.
- **Terraform init** — set this up with `-backend=false` since this pipeline doesn't need real state, just enough initialization to validate and test.
- **Terraform validate / test** — same commands from Task 2, just running automatically now instead of me typing them.
- **Trivy Scan** — same `trivy config .` from Task 3, scoped to the same folder.

**Why `working-directory` matters here**

My repo has Day-1 through Day-6 all sitting in the same place. Without explicitly setting `working-directory` to `Day-6/example` on every step, the pipeline would try to run Terraform commands against the repo root, which isn't even a real Terraform project — it'd just fail immediately.

**Why the Terraform version is pinned in the setup step**

If CI just grabbed "latest" every time, my pipeline could pass today and mysteriously break next month because some new Terraform version changed something — with zero code changes on my part. Pinning the exact version means what I tested locally is exactly what runs in CI, always.

**Why `-backend=false` specifically**

Because this pipeline is only formatting, validating, testing, and scanning — none of that actually needs a real remote backend or real credentials. Passing `-backend=false` to init keeps things fast and avoids needing to wire up cloud secrets just to run checks that don't touch real infrastructure anyway.

**Why `terraform plan` is commented out (for now)**

A real `plan` needs actual cloud credentials and would try to compare against real infrastructure — which is a bigger step than this pipeline is meant for right now. Left it commented out on purpose as a clear "next step," rather than pretending this pipeline already does deployment.

**What I'd add before this becomes a real deploy pipeline**

Real credentials via GitHub Secrets (or better, OIDC instead of long-lived keys), an actual `plan` step, and probably a manual approval gate before any `apply` — especially for anything touching prod.

**Interview tip:** if asked "why isn't apply in this pipeline yet" — be honest that plan/apply need real credentials and approval gates, and that's a deliberate next step, not something skipped by accident.

## Bonus Concepts

**Trivy in CI as a blocking check** — the scan step can be set to fail the whole job if any misconfiguration is found, and that check can be marked "required" in branch protection so nothing insecure can even get merged.

**Why negative tests matter as much as positive ones** — `rejects_bad_environment` proved just as much (arguably more) than the three passing tests, since it confirms the validation logic actually blocks bad input instead of just assuming it does.

**Workspace-aware naming inside config** — referencing `terraform.workspace` inside resource names/tags is a common pattern so it's obvious from the AWS console alone which workspace/environment a resource belongs to.

---

## Today's Key Learnings

- A workspace is a named slot of state within one shared backend/config — not a separate project.
- Workspaces isolate state completely, but do NOT isolate access or credentials — that's still on the team to manage.
- Production environments often use separate backend configs instead of relying only on workspaces, for stronger isolation.
- `terraform test` is a native, built-in testing framework (1.6+) using `.tftest.hcl` files with `run` and `assert` blocks.
- Plan-based tests are fast and touch nothing real; apply-based tests create real resources but clean them up automatically afterward.
- Writing a negative test (bad input should fail) is just as important as testing that good input works.
- `terraform validate` checks that code is written correctly; `terraform test` checks that it behaves correctly — they're not interchangeable.
- Trivy scans Terraform code itself for security misconfigurations, with no cloud credentials required.
- Scanning code before deployment is cheaper and safer than auditing already-live cloud resources afterward.
- GitHub Actions can automate fmt, init, validate, test, and security scanning on every single push.
- `working-directory` is essential in a multi-project repo so CI doesn't run against the wrong folder.
- Pinning the Terraform version in CI keeps local and pipeline behavior identical.
- `-backend=false` is appropriate when a CI job only needs to validate/test, not manage real state.
- `terraform plan`/`apply` were deliberately left out of this pipeline until real credentials and approval gates are in place.

---

## Interview Questions

1. **What is a Terraform workspace?**
   A named instance of state within the same backend and configuration.

2. **Do workspaces isolate access/credentials as well as state?**
   No — they only isolate state. Access control still depends on the backend/credentials setup.

3. **Why might a team avoid using workspaces alone for production?**
   A mistaken `workspace select` could target prod with the wrong intent; separate backends give stronger isolation.

4. **What is `terraform test` and when was it introduced?**
   A native testing command introduced in Terraform 1.6+, using `.tftest.hcl` files.

5. **What's the difference between a plan test and an apply test?**
   A plan test only generates a plan; an apply test provisions real resources, then Terraform destroys them automatically afterward.

6. **Why write a "negative" test like `rejects_bad_environment`?**
   To prove that invalid input is actually rejected by a `validation` block, not just assumed to be.

7. **What's the difference between `terraform validate` and `terraform test`?**
   `validate` checks syntax/internal consistency; `test` checks actual runtime behavior against defined expectations.

8. **What does Trivy check when scanning Terraform code?**
   Static misconfigurations — like open security groups, missing encryption, or overly permissive IAM — without needing cloud credentials.

9. **Why scan IaC before deployment instead of after?**
   Catching an issue in code is cheaper and safer than fixing it in already-live infrastructure.

10. **Why use `working-directory` in a CI pipeline covering multiple Terraform projects?**
    So each pipeline step runs against the correct subfolder instead of the repo root.

11. **Why pin the Terraform version in a GitHub Actions workflow?**
    So CI always uses the same version as local development, avoiding version-drift issues.

12. **Why run `terraform init -backend=false` in this pipeline?**
    Because the pipeline only validates and tests — it doesn't need a real backend or real state.

13. **Why is `terraform plan` commented out in this pipeline?**
    Because a real plan needs live cloud credentials and compares against real infrastructure — out of scope until credentials/approvals are added.

14. **What would you add before turning this into a real deployment pipeline?**
    Real credentials (ideally via OIDC), an actual plan step, and a manual approval gate before apply.

---

## Quick Revision (One-Page Summary)

- **Workspace** = named slot of state in the same backend/config. Isolates state, not access.
- Prod often gets its own separate backend instead of relying only on workspaces.
- `terraform test` runs `.tftest.hcl` files with `run` + `assert` blocks — native since 1.6+.
- Plan tests = fast, no real infra. Apply tests = real infra, auto-destroyed after.
- Always include at least one negative test to prove validation actually blocks bad input.
- `validate` = written correctly. `test` = behaves correctly. Not the same thing.
- Trivy (`trivy config .`) scans Terraform code for misconfigurations, no credentials needed.
- Scan code before deploying — cheaper and safer than fixing live infrastructure later.
- CI pipeline: checkout → setup terraform → fmt → init (`-backend=false`) → validate → test → trivy scan.
- `working-directory` scopes CI steps correctly in a multi-project repo.
- Pin the Terraform version in CI so local and pipeline behavior always match.
- `plan`/`apply` left out of CI on purpose until credentials + approval gates exist.