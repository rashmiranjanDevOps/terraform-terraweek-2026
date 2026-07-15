# TerraWeek Challenge 2026 – Day 3 Notes
*(Organized by concept for interview revision, not by task order)*

---

## 1. Cloud Authentication

Terraform doesn't own any cloud account of its own. It's basically a messenger that goes to AWS/Azure/GCP and says "please create this." But cloud providers won't listen to a random request — they need proof of who's asking. That's why authentication comes first, even before any real Terraform code runs.

**Why never hard-code credentials?** If I put access keys directly inside a `.tf` file and push it to GitHub, it's exposed to the world. There are bots scanning GitHub every few minutes for leaked AWS keys — once found, people spin up mining instances on your account and the bill is scary. I actually did this mistake once in an earlier project (uploaded a zip with a live key inside), had to rotate it immediately. So this isn't just theory for me.

**AWS** – `aws configure` asks for Access Key, Secret Key, region, and output format, one by one, and saves them locally.

**Azure** – `az login` opens a browser, I log in like a normal Microsoft account login, and it stores a session token. No typing keys at all — feels safer.

**GCP** – `gcloud auth application-default login` same idea, opens browser, logs in with Google account, creates local "Application Default Credentials."

**Environment Variables** – for tools like Utho, we set something like `export UTHO_API_TOKEN="xxxx"` and Terraform reads it from environment automatically. Same principle — key stays outside code.

**`~/.aws/credentials`** – this is just a plain text file sitting quietly in my home folder after running `aws configure`. Think of it like a locked personal diary on my own laptop — only my machine reads it, nothing goes near GitHub unless I do something silly.

**Best practice:** CLI-based auth or env variables, never hardcoded keys. One thing I noticed — this is usually the first question interviewers ask about security, so good to have my own leaked-key story ready as an example of "lesson learned."

---

## 2. Networking Fundamentals

This part took longer to click for me, but real-life analogies really helped.

**VPC** – my own private slice of the cloud. Like renting one full floor of an apartment building — other tenants can't just walk into my floor.

**Subnet** – smaller divisions inside the VPC, like individual rooms on my floor. Public subnet has a "window" to the street (internet), private subnet has no windows, kept isolated.

**Internet Gateway** – a VPC is completely sealed by default. IGW is literally the main door that lets traffic in and out of the whole building.

**Route Table** – doesn't build the door, just gives directions. It says "if traffic wants to reach 0.0.0.0/0 (internet), send it through the IGW." One thing I noticed — I used to think IGW alone makes a subnet public. Wrong. Subnet is public only when its route table actually points to the IGW. Both together make it public.

**Security Group** – rules attached to my EC2 that decide what traffic is allowed in/out. Called a "virtual firewall" because it filters traffic just like a real firewall, but it's pure software config, nothing physical. Also it's stateful — allow inbound, and the reply traffic is automatically allowed back out, don't need a separate rule.

**EC2 Instance** – simply a rented virtual machine sitting inside AWS's data center instead of under my desk.

**How they connect:** Someone from internet wants to reach my server → first hits the **Internet Gateway** (main gate) → **Route Table** checks and gives directions ("this goes to public subnet") → lands in the **Public Subnet** (the room) → before touching my server it passes through the **Security Group** (a guard checking ID at my door) → finally reaches the **EC2 Instance**.

---

## 3. Terraform Providers

A **Provider** is a plugin that lets Terraform actually talk to a specific cloud. Terraform core doesn't know anything about AWS by itself — the AWS provider is what translates my `.tf` code into real AWS API calls. This confused me initially — I thought Terraform "natively" understood AWS, but no, it's all through this plugin layer.

**Provider Configuration** looks like:
```hcl
provider "aws" {
  region = "ap-south-1"
}
```
This just tells Terraform which region to work in by default.

**required_version** – tells Terraform "don't run this code unless CLI version is at least X." Stops confusing errors if a teammate has an old Terraform version.

**required_providers** block:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```
- `source` – exact registry path to download the provider from (namespace/provider-name format).
- `version` – which version(s) of that provider are acceptable.

---

## 4. Version Pinning

**Why it matters:** Providers keep releasing new versions, and sometimes they change behaviour or remove old arguments. If I don't pin, code that works today might silently break tomorrow when someone else runs `terraform init` and pulls a newer version. Pinning avoids the classic "works on my machine" problem.

**`>=` vs `~>`**
- `>= 5.0` → any version 5.0 or above, no ceiling. Risky, could jump straight to 6.0 or 7.0.
- `~> 5.0` → the pessimistic constraint operator. Allows upgrades but only within the same major version. So 5.1, 5.5, 5.99 are fine, but 6.0 is blocked.

**Pessimistic operator examples:**
- `~> 5.0` → allows 5.x, blocks 6.0
- `~> 5.1.0` → allows only 5.1.x, blocks even 5.2.0

This helped me remember it as: "trust small updates, don't trust big ones automatically." The word "pessimistic" makes sense once I saw it that way — Terraform is being cautious about big jumps.

---

## 5. Provider Alias

Normally only one config per provider is allowed in a project. **Alias** lets me define multiple configs of the same provider under different nicknames.

```hcl
provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}
```

**Multi-region:** same account, different regions — like the example above.
**Multi-account:** same idea but with different credentials/profiles per alias, useful when a company has separate AWS accounts for prod and staging.

**Real production example:** disaster recovery setup — main servers in Mumbai, a backup copy in Virginia, so if Mumbai region has an outage, traffic can shift over. Alias lets me manage both in one Terraform project instead of two separate codebases.

---

## 6. Resources

A **resource** block is how Terraform actually creates and manages something real in the cloud — a VPC, an EC2 instance, a security group, anything. Once created, Terraform "owns" it and tracks it in state. If I delete the resource block and run apply, Terraform destroys that real object.

Example:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-xxxx"
  instance_type = "t2.micro"
}
```

**Why Terraform manages resources:** so that infra stays in sync with code — if someone manually changes something in the AWS console, next `terraform plan` will show the drift.

---

## 7. Data Sources

A **data** block only reads existing information — it never creates, modifies, or destroys anything. Terraform just asks the cloud "what's already there" and brings that info back for use elsewhere in the code.

Example:
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

**Why use it:** instead of hardcoding an AMI ID (which changes per region and goes stale as new patched images release), I let Terraform fetch the current correct one automatically. Same idea for `aws_availability_zones` — don't hardcode "ap-south-1a," just ask what's actually available.

---

## 8. Resource vs Data Source

This confused me initially because both blocks look almost identical in syntax. Here's the comparison I made for myself:

| | Resource | Data Source |
|---|---|---|
| Purpose | Create/manage infra | Read existing info |
| Creates? | Yes | No |
| Reads? | Yes (its own state) | Yes (only reads) |
| Managed? | Yes, Terraform owns it | No, Terraform doesn't own it |
| Destroyed on `terraform destroy`? | Yes | No, untouched |
| Examples | `aws_instance`, `aws_vpc`, `aws_security_group` | `aws_ami`, `aws_availability_zones`, `aws_vpc` (default VPC lookup) |

One thing I noticed — the same type name like `aws_vpc` can exist as both a `resource` (create new VPC) and a `data` source (look up an existing/default VPC). It's the keyword in front that decides behaviour, not the type itself. Good interview point to mention.

---

## 9. Building My First AWS Infrastructure

Today I actually provisioned a small real setup instead of just theory. Built: a **VPC**, a **Public Subnet** inside it, an **Internet Gateway** attached to the VPC, a **Route Table** pointing default traffic to the IGW and associated with the public subnet, a **Security Group** allowing SSH and HTTP, and finally an **EC2 Instance** launched inside that public subnet using the security group.

One nice touch — the EC2's AMI wasn't hardcoded, it was fetched dynamically using the `aws_ami` data source, so the instance always picks the latest Ubuntu image available in that region instead of relying on an AMI ID I copy-pasted from the console.

---

## 10. Meta Arguments

**count**

*Concept:* lets me create multiple copies of the same resource using a number.
*Syntax:*
```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}
```
This creates `aws_instance.web[0]`, `[1]`, `[2]`.
*When to use:* when all copies are basically identical, only difference is index number.
*Interview Tip:* mention that removing an item from the middle of a `count` list can cause Terraform to destroy/recreate resources with shifted index — this is a common gotcha.

**for_each**

*Concept:* lets me create multiple resources based on a map or set, each with its own unique key instead of a plain index number.
*Syntax:*
```hcl
resource "aws_instance" "web" {
  for_each      = toset(["dev", "staging", "prod"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  tags = { Name = each.key }
}
```
*Difference from count:* `count` uses numeric index, `for_each` uses named keys — so removing "staging" only removes that one resource, doesn't shift/recreate others. This is the main reason `for_each` is usually the safer choice.
*Interview Tip:* if asked "count vs for_each, which is better," answer: for_each when items are distinct and named, count when items are truly identical and order doesn't matter.

**depends_on**

*Concept:* forces Terraform to wait for one resource before creating another, even when there's no natural reference between them.
*Why usually not needed:* Terraform already figures out dependency order automatically whenever one resource references another (like using `data.aws_ami.ubuntu.id` inside a resource) — it builds a dependency graph on its own.
*When explicit dependency helps:* when two resources don't reference each other directly in code but still have a real-world ordering requirement (like an IAM policy needing to exist before an app that assumes it works, but nothing in the code links them).
```hcl
resource "aws_instance" "web" {
  depends_on = [aws_internet_gateway.main]
}
```

**lifecycle**

- `create_before_destroy` – creates the new resource first, then destroys the old one, instead of destroying first. Useful for things like servers where downtime should be avoided during replacement.
- `prevent_destroy` – blocks `terraform destroy` from removing this specific resource, even by accident. Good for something critical like a production database.
- `ignore_changes` – tells Terraform to ignore changes to specific attributes even if they drift, useful when something outside Terraform (like an auto-scaling process) keeps changing a value and I don't want Terraform fighting it every plan.

```hcl
lifecycle {
  create_before_destroy = true
  prevent_destroy        = true
  ignore_changes          = [tags]
}
```

---

## 11. Update vs Replace

**In-place Update:** Terraform just modifies the existing resource without destroying it — like changing a tag or increasing disk size (if the cloud API supports resizing live).

**Resource Replacement:** some attributes can't just be changed live — the cloud API doesn't support modifying them after creation. In that case Terraform has no choice but to destroy the old one and create a brand new one. Example: changing the AMI of an EC2 instance usually forces replacement, because you can't "swap the OS" on a running instance.

**How Terraform decides:** it depends on the provider's schema for each attribute — some are marked as updatable in-place, others are marked "ForceNew," meaning any change to them always triggers a replace. This isn't something I control directly, `terraform plan` shows me clearly with a `-/+` symbol when it means replace, versus a plain `~` for in-place update.

---

## 12. Bonus Concepts

**Elastic IP** – a static public IP address that stays fixed even if I stop/start the EC2 instance. Without it, a normal EC2's public IP can change every time it restarts.

**User Data** – a script I can attach to an EC2 instance that runs automatically the very first time it boots up — useful for installing packages or starting services without logging in manually.

**terraform graph** – generates a visual dependency graph of all resources and how they're connected, mainly useful for debugging complex projects.

**moved block** – tells Terraform "this resource used to be called X, now it's called Y" so it updates state without destroying and recreating the actual infra. Handy when refactoring code without wanting real downtime.

---

## 13. Today's Key Takeaways

- Never hardcode cloud credentials in `.tf` files — use CLI auth or environment variables always.
- `~/.aws/credentials` is just a local file storing my AWS keys after `aws configure`.
- VPC = private floor, Subnet = room, IGW = main door, Route Table = directions, Security Group = guard at my door.
- A subnet is only truly "public" when its route table points to the IGW, not just because IGW exists.
- Providers are plugins that let Terraform actually talk to a cloud — Terraform core knows nothing on its own.
- `required_providers` locks down exact source and version so builds stay predictable.
- `~>` is safer than `>=` for version pinning — allows small updates, blocks risky major jumps.
- Provider alias lets one project manage multiple regions/accounts — real use case is disaster recovery.
- `resource` creates and owns infra; `data` only reads and is never touched by destroy.
- Same type name (like `aws_vpc`) can be both resource and data — the keyword decides behaviour.
- Fetching AMI dynamically via `data "aws_ami"` avoids stale, hardcoded, region-specific IDs.
- `count` uses numeric index (risk of shifting), `for_each` uses named keys (safer for distinct items).
- `depends_on` is rarely needed since Terraform auto-detects dependencies through references.
- `prevent_destroy` is something I should always add to production databases going forward.
- Terraform decides update vs replace based on whether an attribute supports live modification in that provider's schema.