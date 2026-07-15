# Day 4 - Terraform State

## Task 1: Why State Matters

Today's topic was state file. Honestly before today I was treating `terraform.tfstate` as just some random file that gets created and I never bothered opening it. Turns out it's actually the most important file in the whole project, more important than the `.tf` files themselves in some sense.

**What is terraform.tfstate?**

It's basically Terraform's memory. When we run `terraform apply`, Terraform creates real resources in AWS, and then it writes down everything about those resources into this state file — like the actual resource IDs, IP addresses, ARNs, current attribute values, everything. Next time we run `plan` or `apply`, Terraform reads this file first to know "what already exists" before comparing it with our `.tf` code.

I opened the file and looked inside once (it's JSON), and I could literally see my EC2 instance ID, subnet ID, security group ID sitting there in plain text. Without this file, Terraform would have no idea that my VPC or EC2 already exists in AWS — it would try to create everything again from scratch, or just get completely confused.

So basically:
- `.tf` files = what I want
- `.tfstate` file = what actually exists right now

Terraform compares these two things every time to figure out what to change.

**Why never edit it by hand?**

Because it's not really meant for humans to touch. It's auto generated and auto managed by Terraform itself. If I manually open it and change something, or delete a line, I can easily corrupt the mapping between my code and real AWS resources. Then next apply, Terraform might think a resource is missing and try to create a duplicate, or worse, think something needs to be destroyed that's actually fine.

Basically one wrong edit and my whole infra tracking can go out of sync. Senior in my team told me — if you ever *really* need to change state, use `terraform state` commands (like `mv`, `rm`), never open the file in a text editor and start typing.

**Why never commit it to Git?**

Two reasons I understood:

1. It has real, sensitive data inside — actual resource IDs, and sometimes even secrets (explained below). Pushing this to GitHub is basically leaking info about your live infra to anyone who can see the repo.
2. If two people on a team are working on the same project and both have their own local state file, and both push to Git, it becomes a mess — whose state is correct now? This is actually why remote state (S3 + DynamoDB lock, or Terraform Cloud) exists, so everyone reads/writes to one shared state instead of having their own local copies. Something to explore more on later days probably.

For now just added `terraform.tfstate` and `terraform.tfstate.backup` to `.gitignore` so it never accidentally gets pushed.

**State Drift**

This one took me a min to actually get. Drift basically means — the real infrastructure in AWS and what's written in the state file don't match anymore.

How does this even happen? Simple example — say I created an EC2 instance through Terraform. Now someone (maybe me, maybe a teammate) goes into AWS Console directly and manually changes the instance type, or adds a tag, or even terminates the instance manually. Terraform has no idea this happened because nobody told it. So now state file says one thing, but real AWS has something else. That mismatch = drift.

`terraform plan` is actually how you catch this. Every time plan runs, it doesn't just blindly trust the state file — it goes and checks the real resource in AWS again, compares it to state, and shows me if anything is different than expected.

`terraform refresh` is more specific — it just updates the state file to match whatever is actually running in AWS right now, without changing any real infrastructure. So refresh fixes the state file's "memory," plan just tells you if there's a mismatch (and plan actually runs a refresh internally before showing the diff, from what I read/tested).

Basically:
- drift = real world and state file don't agree anymore
- plan = shows you where they don't agree
- refresh = updates state to match real world (doesn't touch real infra)

Small thing I noticed while testing — I manually renamed a tag on my EC2 from AWS console just to see what happens, then ran `terraform plan`, and it immediately flagged it and said it wants to change the tag back to what's in my `.tf` file. That's when this whole topic actually clicked for me instead of just reading about it.

**Why state is sensitive**

This part honestly surprised me a bit. I always assumed state file just has resource IDs and basic metadata, nothing risky. But no — if any resource has an attribute that Terraform considers "sensitive" (or even ones that aren't marked sensitive), the actual value still gets stored in plaintext inside the state file. Things like:
- DB passwords set through a `resource` block
- API keys or tokens passed as variables into a resource
- any secret used inside the tfvars that ends up as an attribute on a resource

Even though Terraform hides sensitive values from the CLI output (shows `(sensitive value)` when you run plan/apply), the state file itself does NOT hide it — open the JSON and it's sitting right there in plain text. That's a big reason remote state with encryption + restricted access is the real practice in actual teams, not just keeping a local file around on your laptop.

Also this is exactly why never committing state to Git matters even more now — it's not just resource IDs, it can literally be a live database password sitting in a public or even private repo.

---

Overall today's task made me actually respect the state file instead of ignoring it like day 1-3. Also realized I should go check if any of my old practice projects accidentally have state committed to Git... need to check that later today.

## Task 2: Playing Around With State Commands

For this one I just reused my Day 3 config (the VPC + subnet + EC2 setup), ran `terraform apply` again to make sure everything's up and state is fresh, and then went through each command one by one instead of just reading what they do. Actually running them helped way more than reading docs tbh.

**`terraform state list`**

This just prints out every resource that Terraform is currently tracking in state. Ran it and got something like:

```
data.aws_ami.amazon_linux
aws_instance.web
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_security_group.web_sg
aws_subnet.public
aws_vpc.main
```

Basically it's like asking Terraform "hey what all are you actually managing right now." Good first command to run when you open an old project and forgot what's inside it. I'll probably use this a lot before doing any state surgery, just to get the exact resource address right (copy paste from here instead of typing manually and making a typo).

**`terraform state show <resource_address>`**

This one goes deep into ONE specific resource and shows every single attribute it currently has in state. Ran:

```
terraform state show aws_instance.web
```

and it dumped the full detail — instance id, private ip, public ip, ami id, subnet id, tags, everything. Basically this is like `terraform show` but zoomed into just one resource instead of the whole project. Useful when I don't want to scroll through a huge state dump and just need to check like "wait what AMI did this actually end up using" without going to AWS console.

**`terraform state mv <src> <dest>`**

This one is for renaming or moving a resource inside the state file, WITHOUT touching the real infra at all. I tested this by renaming my security group:

```
terraform state mv aws_security_group.web_sg aws_security_group.web_sg_old
```

then updated the resource name in my `.tf` file to match (`web_sg_old`), ran plan again, and it showed "no changes" — meaning Terraform understood this is still the same real security group, just renamed in code/state. If I had just renamed it in `.tf` without doing `state mv` first, Terraform would've gotten confused and tried to destroy the old one and create a brand new one with the new name — which for a security group might be fine, but for something like a database would be a disaster (destroy + recreate = data loss).

So basically: use `state mv` whenever refactoring code (renaming resources, moving them into a module, splitting files) and you want the real infra to stay exactly as it is, just re-labeled in Terraform's tracking.

**`terraform state rm <resource_address>`**

This one confused me initially cause I thought it deletes the resource. It does NOT. It just tells Terraform "stop tracking this, I don't want you to manage it anymore" — the actual thing in AWS stays exactly as it is, running fine, untouched. Terraform just forgets about it.

Tested on a throwaway resource:

```
terraform state rm aws_security_group.test_temp
```

ran `terraform state list` again after, and yep, that resource was gone from the list, but I checked AWS console and the security group was still sitting there alive. So this command basically "orphans" a resource from Terraform's control.

When would I actually use this — thought about it and I think the real use case is when:
- You want to manually manage something outside Terraform going forward (like handing it off to another team's setup)
- You're about to import the same resource into a different/better structured state and don't want a conflict
- Something in state is broken/corrupted for that one resource and you want to re-import it clean

**`terraform show`**

This is basically the human-readable version of the whole state file. Instead of opening the raw JSON and trying to read it, `terraform show` prints it out nicely formatted, resource by resource, with all current attribute values. Ran it after apply and it's basically like a live report of "here's everything that exists and here's every value each thing currently has."

I'd use this mainly when I just want to eyeball the full picture quickly, like before handing off a project to a teammate, or just double checking everything looks right after an apply, without digging into the actual `.tfstate` json file manually.

---

**Quick recap I made for myself (this is basically my cheat sheet now):**

| Command | What it does | When I'd use it |
|---|---|---|
| `terraform state list` | Lists all resources being tracked | First thing to run to see what's in a project |
| `terraform state show <addr>` | Shows full details of one resource | Checking specific values without going to AWS console |
| `terraform state mv <src> <dest>` | Renames/moves a resource in state, infra untouched | Refactoring code without destroying real resources |
| `terraform state rm <addr>` | Stops tracking a resource, does NOT delete it | Handing off a resource, fixing broken state, re-importing |
| `terraform show` | Human-readable dump of entire state | Quick full picture check, before handoff/review |

One thing I want to remember for interviews — the big difference between `state rm` and actually deleting a resource from `.tf` and applying. If I remove it from `.tf` and apply, Terraform DESTROYS the real resource. If I do `state rm`, the real resource survives, Terraform just stops caring about it. Very different outcomes, easy to mix up if you're not careful.

## Task 3 – Bootstrap the Backend Infrastructure

Okay so this task made me realize there's a bit of a chicken-and-egg problem with remote state, and I hadn't even thought about it until today.

The idea is — I want Terraform to store its state file in an S3 bucket instead of on my laptop. Makes sense so far. But then... where does THAT S3 bucket come from? If I try to tell Terraform "store your state in this S3 bucket" before the bucket even exists, it's just going to fail, because there's nothing there to write to. Terraform can't point its own backend config at a bucket that doesn't exist yet — it's not going to magically create the bucket first and then also use it as backend in the same breath.

So the actual first step (which honestly I wouldn't have guessed on my own) is to create the S3 bucket using a completely separate, small Terraform config — in my case this lives in a folder called `backend_infra`. This config's ONLY job is to create the S3 bucket (and enable a couple settings on it), nothing else.

**Why versioning is enabled on the bucket**

Turned on versioning so that every time the state file gets updated, S3 keeps the old version instead of just overwriting it. This felt like a safety net — if state ever gets corrupted or something goes wrong during an apply, I can go back to a previous version of the state file instead of losing everything. Small observation: this is basically like Git history but for my state file specifically.

**Why server-side encryption is enabled**

Already knew from Task 1 that state can have secrets in plaintext, so it made total sense to turn on encryption at rest for the bucket. Even if somehow someone got access to the raw S3 object, the underlying storage is encrypted. Doesn't stop someone with proper AWS permissions from reading it, but it protects against a lot of other risk (stolen backups, etc).

**Why this step still uses LOCAL state**

This is the part that actually made the whole thing click for me. The `backend_infra` config itself — the one creating the S3 bucket — has to use plain old local state. Because think about it, this config is literally creating the very bucket that would be used for remote state. It can't use itself as its own backend before it exists. So `backend_infra` just runs normally with a local `terraform.tfstate` sitting on my machine, and that's actually totally fine here because this bucket rarely changes after it's created — it's basically "one and done" infra, not something I'm applying every day.

**What I observed after apply**

Ran `terraform apply` inside `backend_infra`, and it created the bucket + turned on versioning + encryption. Went and checked in AWS console, bucket was there, versioning was "Enabled," encryption showed as SSE (AES256 in my case). Also noticed a `terraform.tfstate` file sitting locally in the `backend_infra` folder — which felt a little funny at first (state file... for the thing that stores state) but made sense once I thought about it properly.

**Interview tip I noted down:** if asked "why can't you just use S3 backend from day one," the answer is basically — the backend has to already exist as a real resource before Terraform can point its state storage at it. It's a bootstrapping problem, and that's literally why this is called "bootstrap the backend."

## Task 4 – Configure Remote Backend

Now that the S3 bucket actually exists, this task was about pointing my real project (the `backend_demo` one, same VPC+EC2 style setup) to actually USE that bucket as its backend, instead of storing state locally.

**What is a remote backend, in my own words**

Instead of my `terraform.tfstate` sitting on my own laptop, it now lives inside the S3 bucket I created in Task 3. Every time I run plan/apply, Terraform reaches out to S3, reads the current state from there, does its thing, and writes the updated state back to S3.

**Why teams don't use local state**

This is obvious once you think about a team of like 5 people. If state is local, everyone has their own separate copy on their own laptop. Person A applies something, but Person B's local state file has no idea that happened. Next time Person B runs apply, their outdated state has zero knowledge of A's changes, and everything gets extremely messy extremely fast — duplicate resources, conflicting changes, resources going out of sync. Remote state fixes this because there's only ONE source of truth that everyone reads and writes to.

**Migrating local state to S3**

Added a `backend "s3"` block inside my `backend_demo` config with the bucket name, key (path inside bucket), and region. Then ran `terraform init` again.

**What happened during init**

Terraform actually noticed I already had a local state file, and it asked me straight up — "do you want to copy existing state to the new backend?" Said yes, and it migrated my whole local state into S3 automatically. Went and checked the bucket, and yep, there was a `terraform.tfstate` object sitting inside it now, matching exactly what I had locally before. My local `terraform.tfstate` still exists on disk after this but it's basically not being used anymore going forward — S3 is now the real source.

**`use_lockfile = true`**

This one I had to actually look into a bit because it wasn't something I expected. Setting this in the backend config tells Terraform to use S3's own native locking mechanism instead of needing a separate DynamoDB table for locking (which is the older way most tutorials online still show).

**Native S3 locking / why DynamoDB isn't needed anymore**

Before, locking state (so two people can't run apply at the exact same time and corrupt things) required setting up a whole separate DynamoDB table alongside the S3 bucket, just for locks. With `use_lockfile = true`, S3 handles the locking on its own using a lock file object directly inside the bucket — no DynamoDB needed at all. Honestly felt like a relief because DynamoDB setup felt like an unnecessary extra step for something that's really just "please don't let two people touch this at the same time."

**The `.tflock` object**

While an apply was running, I peeked into the S3 bucket console mid-apply and actually saw a lock-related object show up temporarily, then disappear once the apply finished. That's the lock file doing its job — while it exists, it's basically saying "someone is currently running an operation, wait your turn." Once the operation finishes, the lock clears and the object goes away.

**How I verified state inside S3**

Just opened the S3 bucket in AWS console, went into the key path I set in the backend config, and downloaded/opened the `terraform.tfstate` object from there directly — same JSON content I was seeing locally before, confirming migration actually worked and wasn't just Terraform pretending.

**This was the point where I finally understood why every company stores Terraform state remotely.** Genuinely, up until this task I thought remote state was just "a best practice people mention" without really getting WHY. Doing the actual migration and watching the lock object appear/disappear during apply made it click — it's not just about convenience, it's literally what prevents a whole team from stepping on each other's applies and corrupting shared infrastructure. Small hands-on moment but honestly this was probably the biggest "aha" of the whole day.

**Why remote state is safer for teams**

- one single source of truth, nobody working off a stale local copy
- locking prevents two people applying at the same exact time
- encryption + versioning (from Task 3) protects against corruption and leaks
- access can be controlled through IAM instead of "whoever has the laptop with the file on it"

## Task 5 – Import Existing Resources

This task was about a different problem entirely — what happens when a resource already exists in AWS (maybe someone created it manually through console, or an old script), but Terraform has zero knowledge of it.

**Why we created an S3 bucket manually first**

For this task, deliberately created a bucket by hand through AWS console (not through Terraform) — basically simulating the real situation where "someone already made this thing before Terraform was involved." Point was to then bring that existing bucket UNDER Terraform's management without destroying and recreating it.

**Import blocks**

Older Terraform used a separate `terraform import` CLI command to do this, but newer versions (1.5+) added an `import` block that can live right inside the `.tf` code itself:

```hcl
import {
  to = aws_s3_bucket.manual_bucket
  id = "my-manually-created-bucket-name"
}
```

**Why 1.5+ moved to import blocks**

Instead of running a one-off CLI command that isn't tracked anywhere, the import block is actual code that lives in version control. So the "this resource was imported" step is documented right there in the repo instead of being some command someone ran once on their laptop and forgot about. Makes it repeatable and visible to the whole team.

**Generating config automatically**

Ran:

```
terraform plan -generate-config-out=generated.tf
```

and this is genuinely one of the coolest things I did today — Terraform actually WROTE the resource block for me based on what it found in real AWS, since I hadn't written the `aws_s3_bucket` resource block myself yet.

Quick note — I'm on Windows using PowerShell, and running it plain like above actually threw an error:

```
Too many command line arguments
```

Had to wrap the whole flag in quotes for PowerShell to parse it correctly:

```
terraform plan "-generate-config-out=generated.tf"
```

after that it worked fine. Apparently PowerShell handles `=` inside flags differently than bash does, so this is just a Windows-specific quirk, not a Terraform issue. Noting this down because I'll for sure forget this by next week otherwise.

**generated.tf**

This new file had a full `resource "aws_s3_bucket" "manual_bucket" { ... }` block written out, matching all the real settings the bucket already had in AWS (region config, tags if any, etc).

**Reviewing the generated config**

Didn't just trust it blindly — opened `generated.tf` and actually read through it properly. Some of it was slightly messy/verbose compared to how I'd normally hand-write a resource block, so cleaned it up a bit, renamed the file content into my actual `.tf` files, removed the import block after (since it's a one-time operation, not something that needs to stay forever), and ran `terraform plan` again — got "no changes," which confirmed the import + generated config was accurate.

**Why importing is actually useful**

Real world example that clicked for me — imagine joining a company where half the AWS infra was set up manually years ago before anyone used Terraform, and now the team wants everything under IaC. You can't just delete and recreate a live production database or S3 bucket that already has real data in it just to "start clean with Terraform." Import lets you bring already-existing, already-running things under Terraform's management without touching them at all. Genuinely feels like one of those practical skills that'll actually matter on a real job, not just a challenge exercise.

## Cleanup

Learned (a bit the hard way after seeing my AWS bill dashboard) that leaving practice infra running is a bad habit, so made this its own step now instead of an afterthought.

- Ran `terraform destroy` inside `backend_demo` first — this tears down the actual EC2/VPC/networking stuff.
- Then ran `terraform destroy` inside `backend_infra` — this removes the S3 bucket itself, but only AFTER backend_demo is destroyed (since backend_demo's state was living inside that bucket, destroying the bucket first would've been a problem).
- One extra gotcha — versioned S3 buckets don't just delete cleanly if they have old versions of objects sitting inside. Had to manually empty all versions (not just current objects, but every past version created by versioning) before the bucket would actually delete. AWS console has an "empty bucket" option that handles this, otherwise `terraform destroy` on a non-empty versioned bucket just fails.
- Cleanup matters because leaving stuff running (even small things like an S3 bucket or a t2.micro) adds up, and also because half-finished practice infra lying around makes it confusing later which stuff is "real" vs which was just for learning.

## Bonus Concepts

**HCP Terraform** – HashiCorp's own managed platform (formerly Terraform Cloud) that handles remote state, locking, and even running plan/apply for you in the cloud instead of your own machine. Basically removes the need to manually set up S3+locking yourself.

**Azure Storage Backend** – Azure's equivalent of what I did with S3 today, but state gets stored in an Azure Storage Account/container instead. Same core idea, different cloud.

**Google Cloud Storage Backend** – same concept again but using a GCS bucket for GCP-based projects.

**S3 Versioning** – already covered above in Task 3, but worth repeating as its own bonus point — it's what let me imagine "restoring an older state" as a safety net, and also caused the whole "empty bucket before delete" issue during cleanup.

**moved block** – tells Terraform "this resource used to be named X, now call it Y" inside the code itself, so state gets updated automatically without needing to manually run `terraform state mv`. Basically same result as Task 2's `state mv` but written declaratively in `.tf` code instead of a CLI command.

**removed block** – newer addition, lets you say "stop managing this resource" directly in code (like a code-based version of `terraform state rm`), instead of running the command manually every time.

**check block** – lets you write custom validation conditions that run during plan/apply to catch problems (like an endpoint not responding, or a value being outside an expected range) without failing the whole apply — just warns you if a condition isn't met.

## Today's Key Takeaways

- `terraform.tfstate` is Terraform's memory of real infrastructure — never edit it by hand, never commit it to Git.
- State drift = real AWS and state file disagreeing; `plan` shows it, `refresh` fixes the state's view of it.
- State can contain secrets in plaintext, even values marked "sensitive" in CLI output.
- Backend infra (the S3 bucket for state) has to be created first, using its own local state, because Terraform can't point at a bucket that doesn't exist yet.
- Versioning on the state bucket gives a safety net to roll back to older state versions.
- Encryption on the state bucket protects secrets sitting inside state at rest.
- `terraform init` handles migrating local state into a new S3 backend automatically, just needs a yes/no confirmation.
- `use_lockfile = true` enables native S3 locking, no DynamoDB table needed anymore.
- Watched a lock object appear and disappear in S3 during an apply — that's what stops two people applying at once.
- Remote state is the real reason teams don't step on each other's infra changes.
- `terraform state list/show/mv/rm` let me inspect and reorganize state without touching real infra.
- `state rm` orphans a resource from Terraform tracking, it does NOT destroy the real thing — very different from removing it from `.tf` and applying.
- Import blocks (Terraform 1.5+) bring already-existing infra under Terraform management, and live in code instead of being a one-off CLI command.
- `-generate-config-out` can auto-write the resource block for an imported resource — huge time saver but still needs manual review.
- On Windows PowerShell, flags with `=` sometimes need to be wrapped in quotes or they throw "too many command line arguments."
- Cleanup order matters — destroy the config using the backend before destroying the backend itself.
- Versioned S3 buckets need to be fully emptied (all versions) before they can actually be deleted.
- `moved` and `removed` blocks are basically declarative, code-based versions of `state mv` and `state rm`.
- Overall today felt like the "why does anyone bother with all this backend setup" question finally got answered through actually doing it, not just reading about it.