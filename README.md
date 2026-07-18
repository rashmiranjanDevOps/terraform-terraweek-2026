# 🚀 TerraWeek Challenge 2026 — Terraform IaC Journey

## 📌 Project Overview

This repository is my submission for the **TerraWeek Challenge 2026**, documenting the practical work completed across **Day 1 to Day 6**. It covers Terraform fundamentals with no cloud account required, progresses through real AWS infrastructure provisioning, remote state management, reusable modules, and culminates in a capstone project featuring Terraform workspaces, native testing, Infrastructure as Code (IaC) security scanning with Trivy, and CI/CD automation using GitHub Actions.

Day 7 focused on reviewing the repository, verifying the submission requirements, and preparing the project for final submission.

Each day is self-contained with its own working Terraform code, a detailed README, and supporting notes — this root README ties the whole journey together.

---

## 🎯 About TerraWeek Challenge

**TerraWeek** is a 7-day Terraform learning challenge organized by **TrainWithShubham**, designed to take participants from Infrastructure-as-Code fundamentals to a production-style, tested, and automated Terraform project — one day, one concept at a time.

---

## 🛠️ Skills & Technologies Used (Day 1–Day 6)

- **Terraform** (HCL) — resources, variables, outputs, expressions, `.tf` configuration
- **Terraform CLI workflow** — `init`, `fmt`, `validate`, `plan`, `apply`, `destroy`
- **AWS** — EC2 provisioning, S3 remote backend with native state locking
- **Terraform State Management** — local state, remote state, `terraform import`
- **Terraform Modules** — reusable/composable infrastructure, public Terraform Registry modules
- **Terraform Workspaces** — multi-environment (`dev`/`staging`/`prod`) state isolation
- **Terraform Test Framework** — native `.tftest.hcl` automated tests
- **Trivy** — static security scanning for IaC misconfigurations
- **GitHub Actions** — CI/CD automation (fmt, init, validate, test, security scan)
- **Git & GitHub** — version control and project submission

---

## 🗂️ Repository Structure

```text
terraform-terraweek-2026/
│
├── README.md                     ← this file
├── .gitignore                    ← ignores state, .terraform/, secrets
├── .github/
│   └── workflows/
│       └── terraform.yml         ← CI: fmt, init, validate, test, Trivy scan
│
├── Day-1/     Terraform basics (local & random providers)
├── Day-2/     HCL deep dive — variables, types, expressions
├── Day-3/     Provisioning real AWS infrastructure
├── Day-4/     Terraform state & remote backends (S3)
├── Day-5/     Reusable, composable Terraform modules
└── Day-6/     Capstone — workspaces, testing, security & CI/CD
```

Every `Day-N/` folder contains its own `README.md`, `notes.md`, working Terraform code, and screenshots. Detailed explanations, learning objectives, and architecture diagrams live inside each day's own README — this file intentionally does not repeat them.

---

## 📅 Day-wise Summary

| Day | Focus | What It Covers |
|---|---|---|
| **Day 1** | Terraform Basics | IaC fundamentals, Terraform CLI workflow, local/random providers — no cloud account needed |
| **Day 2** | HCL Deep Dive | Variables, types, expressions, formatting, a Docker-based example |
| **Day 3** | AWS Provisioning | Real AWS resources (EC2), provider setup, production-grade HCL |
| **Day 4** | State & Remote Backends | Local vs. remote state, S3 backend, native S3 state locking, `terraform import` |
| **Day 5** | Terraform Modules | Reusable/composable modules, root module composition, Registry modules |
| **Day 6** | Capstone Project | Workspaces, native `terraform test`, Trivy security scanning, GitHub Actions CI/CD |

---

## ✅ Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.10` (Day 4–6 use features from 1.11+)
- An [AWS account](https://aws.amazon.com/) with configured credentials — required for Day 3–6 only (Day 1–2 need no cloud account)
- [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
- [Trivy](https://aquasecurity.github.io/trivy/) (optional locally — runs automatically in CI)
- Git

---

## ▶️ How to Use This Repository

```bash
# 1. Clone the repository
git clone <this-repo-url>
cd terraform-terraweek-2026

# 2. Move into any day's example folder
cd Day-1/example    # or Day-2/example, Day-3/example, etc.

# 3. Initialize, validate, and preview
terraform init
terraform fmt -recursive
terraform validate
terraform plan

# 4. Apply, then destroy when finished
terraform apply
terraform destroy
```

- **Day 1 & 2** run entirely locally — no AWS credentials required.
- **Day 3, 5 & 6** provision real AWS resources — configure credentials first and always `destroy` afterward.
- **Day 4** has two folders (`backend_demo/` and `backend_infra/`); see `Day-4/README.MD` for the required run order.
- **Day 6** additionally supports `terraform test` and `trivy config .` for local testing/scanning, both of which also run automatically in CI.

---

## ⚙️ GitHub Actions Overview

`.github/workflows/terraform.yml` runs automatically on every push and pull request against `main`:

**Checkout → Setup Terraform → `fmt -check` → `init -backend=false` → `validate` → `test` → Trivy security scan**

- Uses a pinned Terraform version so CI behavior always matches local development.
- Runs against the Day-6 capstone project (`working-directory: ./Day-6/example`).
- `plan`/`apply` are intentionally left out of CI until real cloud credentials and an approval gate are configured — the pipeline currently validates, tests, and scans, without touching real infrastructure.

---

## 🧠 Learning Outcomes

By completing this challenge, I'm able to:

- Write, format, and validate Terraform configurations confidently using core HCL syntax
- Provision and manage real AWS infrastructure with Terraform
- Understand, migrate, and safely manage Terraform state, including remote backends and locking
- Design reusable, composable infrastructure using modules
- Isolate environments with Terraform workspaces and understand their limits
- Write native automated tests for Terraform logic, including negative/validation tests
- Scan Infrastructure as Code for security misconfigurations before deployment
- Build a CI/CD pipeline that automatically formats, validates, tests, and scans Terraform code on every change

---

## 🙏 Acknowledgements

- **[TrainWithShubham](https://www.trainwithshubham.com/)** — for designing and organizing the TerraWeek Challenge 2026
- **[HashiCorp](https://www.hashicorp.com/)** — for Terraform and its official documentation

---
