# Day 6 – Terraform Workspaces, Testing Framework, Security Scanning & CI/CD

**TerraWeek Challenge 2026** · Organized by TrainWithShubham

[![Terraform](https://img.shields.io/badge/Terraform-1.9%2B-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Trivy](https://img.shields.io/badge/Security-Trivy-1904DA?logo=aquasecurity&logoColor=white)](https://aquasecurity.github.io/trivy/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Status](https://img.shields.io/badge/Day-6%20of%207-success)]()

---

## 📌 Project Overview

Day 6 of the TerraWeek Challenge moves from "does my Terraform code work" to "can I actually trust my Terraform code." Day 5 was about building reusable modules — today is about proving those modules (and the projects that call them) behave correctly, are safe to deploy, and get checked automatically instead of by hand.

Four things came together today: **Workspaces** to manage `dev`/`staging`/`prod` from one configuration, the native **Terraform Test Framework** to catch logic bugs before they ever reach a real apply, **Trivy** to scan for security misconfigurations before anything is deployed, and a **GitHub Actions** pipeline that runs all of it automatically on every push.

---

## 🎯 Learning Objectives

- [x] Understand Terraform Workspaces
- [x] Create, switch, and inspect workspaces
- [x] Understand isolated state per workspace
- [x] Understand workspaces vs. separate backends
- [x] Write native Terraform tests (`.tftest.hcl`)
- [x] Understand plan tests vs. apply tests
- [x] Understand automatic test cleanup
- [x] Scan Terraform code with Trivy
- [x] Build a GitHub Actions CI/CD pipeline
- [x] Understand `working-directory`, `scan-ref`, and version pinning in CI

---

## 📂 Project Structure

```text
Day-6/
│
├── README.md
├── notes.md
│
└── example/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    └── tests/
        └── main.tftest.hcl

.github/
└── workflows/
    └── terraform.yml
```

---

## 🏗️ Architecture

**Local workflow:**

```text
Developer
   │
   ▼
terraform fmt / validate / test
   │
   ▼
trivy config .
   │
   ▼
git push
   │
   ▼
GitHub Actions Pipeline
```

**Pipeline flow:**

```text
Checkout Repository
   │
   ▼
Setup Terraform
   │
   ▼
Terraform fmt
   │
   ▼
Terraform init
   │
   ▼
Terraform validate
   │
   ▼
Terraform test
   │
   ▼
Trivy Scan
   │
   ▼
Pipeline Passed ✅
```

---

## 🗂️ Workspaces

```bash
terraform workspace list
terraform workspace new staging
terraform workspace new prod
terraform workspace select default
terraform workspace show
```

Each workspace keeps its own isolated state file, so the same configuration can safely represent `dev`, `staging`, and `prod` without any code duplication.

| | Workspaces | Separate Backends |
|---|---|---|
| Config | Shared | Can differ per environment |
| State | Isolated per workspace | Fully independent |
| Best for | Similar, lower-risk environments | Production, compliance-heavy setups |

---

## 🧪 Terraform Tests

```
Success! 4 passed, 0 failed.
```

| Test | Verifies |
|---|---|
| `dev_uses_micro` | dev resolves to a micro instance |
| `prod_uses_medium` | prod resolves to a medium instance |
| `name_has_prefix` | naming convention is enforced |
| `rejects_bad_environment` | invalid environment values are rejected |

---

## 🛡️ Security Scan (Trivy)

```bash
trivy config .
```
```
Tests: 24 (SUCCESSES: 24, FAILURES: 0)
Misconfigurations: 0
```

---

## ⚙️ GitHub Actions Pipeline

`.github/workflows/terraform.yml` runs on every push: checkout → setup Terraform → fmt → init (`-backend=false`) → validate → test → Trivy scan. `terraform plan`/`apply` are intentionally left commented out until real cloud credentials are wired in.

---

## ✅ Best Practices Learned

- Use workspaces for similar environments; use separate backends when prod needs stronger isolation.
- Write tests for logic, not just syntax — `validate` isn't enough on its own.
- Scan IaC before deploying, not after.
- Pin the Terraform version in CI so local and pipeline behavior match.
- Scope every CI step to the correct `working-directory` in a multi-project repo.
- Keep `plan`/`apply` out of CI until credentials and approvals are properly set up.

---

## 🖼️ Screenshots

See [SCREENSHOTS.md](./SCREENSHOTS.md).

---

## 💬 Interview Questions

See [INTERVIEW.md](./INTERVIEW.md) for 40+ questions covering workspaces, testing, Trivy, and CI/CD.

---

## 🧠 Key Learnings

- Workspaces isolate state, not access — production still needs separate backends for real isolation.
- `terraform test` runs real plan/apply cycles and cleans up after itself automatically.
- Security scanning belongs in the dev loop, not just at audit time.
- A green CI pipeline means every change was formatted, validated, tested, and scanned the same way.

---

## 🏁 Conclusion

Day 6 turned Terraform code that "works" into Terraform code that's actually **trustworthy** — verified by automated tests, scanned for security issues, and gated by a real CI/CD pipeline instead of manual review.

---

⭐ Part of the **TerraWeek Challenge 2026** — Day 6 of 7.