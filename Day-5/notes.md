# Day 5 - Terraform Modules: Reusable, Composable Infrastructure

## Task 1: Modules - The Why

Okay so today's topic is Modules, and honestly this is the first day where I actually felt like "oh this is how real companies structure their Terraform code," not just single files with a bunch of resources dumped in.

**What is a Terraform Module?**

In the simplest way I can put it — a module is just a folder containing `.tf` files that does one specific job, and can be reused wherever needed. Every Terraform project is technically already a module, even the one I've been writing since Day 1. There's nothing magically different about the file structure, it's more about how you organize and reuse it.

**Root Module vs Child Module**

This confused me for like 5 mins until I actually saw it in practice. The **root module** is just the main folder where I run `terraform apply` from — the top level of my project. A **child module** is any module that the root module calls into, usually sitting in something like a `modules/` folder. So root module = the "caller," child module = the "thing being called." Root can call multiple child modules, and honestly child modules can even call other child modules (nested), though I didn't go that deep today.

**Why modules are important / why copy-paste is bad**

Before today, if I needed 3 EC2 instances with slightly different configs, I would've literally copy-pasted the `resource "aws_instance"` block 3 times and just changed a few values. Now I actually understand why that's a bad habit:

- If I find a bug or need to change something (like adding a new tag to every instance), I'd have to go and manually update it in every single copy-pasted block. Easy to miss one.
- Code gets messy and huge really fast, hard to read what's actually happening.
- No single "source of truth" for how an EC2 instance should be configured in my project.

Modules basically solve this by letting me write the logic ONCE, and then just call it multiple times with different inputs.

**Benefits I actually understood today (not just memorized):**

- **Reusability** – write once, use in root module or even other projects.
- **Consistency** – every EC2 created through my module follows the exact same standard (naming, tags, security defaults) because it's all coming from one place.
- **Encapsulation** – the module hides the messy details inside it. Root module doesn't need to know HOW the EC2 gets created, just what inputs to give and what outputs to expect. Kind of like a black box.
- **Maintainability** – fix a bug once inside the module, every place using that module benefits automatically next apply.
- **Versioning** – (more on this in Task 4/5) modules can be pinned to specific versions, so upgrading is a deliberate choice, not an accident.
- **Team collaboration** – one person can build and maintain the "networking module," another person just consumes it without needing to understand every single line inside.
- **Testing** – smaller, focused modules are easier to test in isolation compared to one giant tangled config.

**Difference between writing resources directly vs using a module**

Writing directly = I'm telling Terraform exactly what to build, every single time, in full detail, right there in my main code.
Using a module = I'm calling a pre-built "recipe" and just handing it a few specific inputs (like instance type, name), and the module handles the actual resource creation internally.

**Real-world example that made this click for me**

Imagine a company that needs to launch a new microservice every month. Each microservice needs: a VPC, a subnet, a security group, and an EC2 instance (or ECS service). Without modules, someone re-writes or copy-pastes all of this every single time a new microservice launches, and every dev might set it up slightly differently — one forgets to add a tag, another opens up a port they shouldn't. With a module, there's ONE "microservice infra module" that everyone calls, and it's always consistent, always follows company standards, and only takes a few lines to call.

**Analogy that stuck with me**

Honestly the LEGO blocks comparison makes the most sense. A single LEGO brick is like one resource block. A pre-built LEGO "wall" or "wheel set" that you snap onto different builds is like a module — you don't rebuild the wheel from scratch every time you make a new car, you just reuse the wheel design.

Also thought about it like functions in programming (makes sense given my MCA background) — instead of writing the same 10 lines of logic everywhere, I write a function once, and just call `create_ec2(name, type)` wherever I need it, passing different arguments each time. Terraform module = exactly this idea, just for infrastructure instead of code logic.

**Files usually inside a module**

- `main.tf` – the actual resource logic (what gets created)
- `variables.tf` – input parameters the module accepts from whoever is calling it
- `outputs.tf` – values the module returns back to the caller after creation
- `README.md` – documentation, explaining what the module does, what inputs it needs, what it returns — this matters way more than I thought, especially if other people (or future me) will use this module later.

**Interview tip I noted for myself:** if asked "what's the difference between root and child module," keep the answer simple — root is where you run apply, child is what root calls into. Don't overcomplicate it.

## Task 2: Writing My Own Module

This is where things actually got real. Built my own module folder:

```
modules/
└── ec2_instance/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**Why this folder became a reusable module**

Because it doesn't hardcode anything project-specific inside it — no hardcoded subnet ID, no hardcoded name. Everything that could change between usages is exposed as a variable. That's really the whole trick to making something reusable — the module shouldn't assume anything about WHO is calling it or WHERE it's being used.

**Why the root module called it**

In my root config, I called it like:

```hcl
module "web" {
  source        = "../modules/ec2_instance"
  instance_name = "web-server"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  sg_id         = aws_security_group.web_sg.id
  ami_id        = data.aws_ami.amazon_linux.id
}
```

**Why inputs are passed through variables**

Because the module itself has zero clue what subnet, AMI, or security group I want to use — it's not the module's job to decide that, it's the root module's job (since root knows the full picture of the project). Variables are literally the "settings" I feed into the module from outside.

**Why outputs are returned**

Once the module creates the EC2, I still need to actually USE information about it in my root module — like the public IP, or the instance ID, maybe to reference it somewhere else, or just to see it after apply. Outputs are how the module "hands back" useful info to whoever called it.

**Input variables I defined, explained simply**

- `instance_name` – just a string for naming/tagging the instance, so every server made through this module has a clear name.
- `instance_type` – lets me control size (t2.micro, t2.medium, etc.) per usage instead of hardcoding one size inside the module forever.
- `subnet_id` – WHERE the instance goes. Passed in because different callers might want it in different subnets.
- `sg_id` – WHICH security group controls its traffic. Again, module doesn't decide this, caller does.
- `ami_id` – WHICH image to boot from. Passed in from root, which already fetched it using a data source.

**Outputs I defined**

- `instance_id` – so root module (or me manually) can reference exactly which instance this is.
- `public_ip` – so I can actually go SSH into it or check it's alive without manually going to AWS console every time.

**Why the module doesn't perform unnecessary lookups**

At first I actually tried putting a `data "aws_ami"` block INSIDE the module itself, thinking it'd be convenient. But then realized — that's actually bad practice. If the module does its own AMI lookup internally, every single caller is forced to use whatever logic the module decided, with zero flexibility. Worse, it also means the module is quietly making decisions about the project that maybe not every caller wants.

**Why IDs are passed from the root module instead**

Root module already has full context — it knows which VPC, which subnet, which AMI makes sense for that specific project. The module doesn't need that context, it just needs to be told "use this one." This keeps the module dumb-but-flexible instead of smart-but-rigid, which is actually the right way to think about it. One thing I noticed — this is basically the same principle as writing clean functions in code, don't hardcode dependencies inside a function, pass them in as arguments.

**Commands I ran and what I observed**

`terraform init` — this actually initialized the LOCAL module too, not just the provider. I could see it printed something about the module being installed/registered, not just the AWS provider like previous days. That's when it clicked that modules need to be "initialized" just like providers do, even local ones sitting in a folder right next to my project.

`terraform validate` — passed clean, just confirmed my module call syntax and variable types were all correct.

`terraform plan` — showed the EC2 instance being created THROUGH the module, but interestingly the resource address in the plan output looked like `module.web.aws_instance.this` instead of just `aws_instance.web` like I'm used to seeing. That's the module namespacing at play — Terraform prefixes everything with the module name so state doesn't get confusing when multiple modules exist.

`terraform apply` — created the instance, and the module's outputs got printed at the end (instance_id and public_ip), confirming the module correctly passed data back.

`terraform output` — showed just those specific outputs cleanly, without needing to scroll through the whole apply log again.

`terraform destroy` — tore everything down cleanly, module and all, no leftover mess.

**Why this is useful in production**

Realized that in a real company, this exact `ec2_instance` module could get called 20 different times across 20 different projects/teams, each with their own subnet/AMI/instance type — but every single one follows the exact same tested, standardized logic underneath. If there's ever a security fix needed (like adding IMDSv2 enforcement or a missing tag), fixing it once inside the module fixes it everywhere it's used, next time everyone re-applies.

## Task 3: Module Composition using for_each

**What is Module Composition?**

This is basically calling the SAME module multiple times with different inputs, to build multiple similar-but-distinct pieces of infrastructure, instead of writing separate `module` blocks manually for each one.

**Why for_each is useful with modules**

Because without it, if I wanted 3 more servers besides my original "web" one, I'd have to write 3 separate `module "app" {}`, `module "worker" {}`, `module "cache" {}` blocks manually, basically copy-pasting the module call itself (defeats some of the purpose). `for_each` lets ONE module block loop through a set of names and create all of them in one shot.

**Explaining the code:**

```hcl
module "servers" {
  source   = "../modules/ec2_instance"
  for_each = toset(["app", "worker", "cache"])

  instance_name = each.key
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  sg_id         = aws_security_group.web_sg.id
  ami_id        = data.aws_ami.amazon_linux.id
}
```

**What `each.key` means**

Since I passed a set of strings into `for_each`, Terraform loops through each string one at a time, and `each.key` just refers to whichever string is currently being processed in that loop iteration. So on the "app" iteration, `each.key` = "app", and it gets used as the instance name for that specific server.

**Why only one module block can create multiple servers**

Because `for_each` turns this single `module "servers" {}` declaration into multiple actual module instances internally — `module.servers["app"]`, `module.servers["worker"]`, `module.servers["cache"]`. So visually it's one block in code, but Terraform treats it as three separate, independently tracked module instances in state.

**count vs for_each (same lesson from EC2 resources, but now with modules)**

Same logic I learned with resources on Day... whichever day we did meta arguments — `count` uses numeric index (0,1,2...), so removing a middle item shifts everything after it and can cause unnecessary destroy/recreate. `for_each` uses named keys, so removing "worker" only affects the worker instance specifically, "app" and "cache" stay completely untouched. This matters even more with modules since each module instance might be managing several resources internally, not just one — so an index shift with `count` could mean a LOT of resources getting recreated unnecessarily.

**Why for_each is preferred for named infrastructure**

Because servers like "app," "worker," "cache" aren't really interchangeable/identical — they have distinct purposes, so giving them actual names instead of numbers just makes more sense logically AND is safer for the reasons above.

**What I observed after apply**

Ended up with 4 EC2 instances total — my original `web` one from Task 2, plus `app`, `worker`, `cache` from this for_each loop, all created from the exact same reusable module, just called with different inputs. Genuinely satisfying to see 4 servers spin up from what's really just ONE module definition being reused smartly.

**Why this demonstrates reusability**

This is basically the entire point of Task 1 proven in real practice — I wrote the EC2 creation logic exactly once, and used it 4 different times with different names, without duplicating a single line of resource logic. That's the whole "write once, use everywhere" idea actually working.

**Interview tip:** if asked to explain module composition in one line — "calling the same module multiple times, usually with for_each, to create multiple similar resources from one reusable definition."

## Task 4: Registry Modules

**What is Terraform Registry?**

It's basically a public library of pre-built, community and vendor maintained modules that anyone can use instead of writing everything from scratch. HashiCorp runs the official public registry, and companies also run their own private registries internally.

**Why companies use Registry Modules**

Because things like a "production-grade VPC setup" are honestly complex — proper subnetting, NAT gateways, route tables for multiple AZs, etc. Someone at HashiCorp or in the community already built, tested, and battle-hardened a VPC module used by thousands of projects. Writing that from scratch every time is just reinventing the wheel, and probably worse quality than the well-tested community version.

**Local Module vs Registry Module vs Git Module**

- **Local Module** – sits in a folder on my own machine/repo (like my `ec2_instance` module from Task 2), referenced with a relative path (`../modules/ec2_instance`).
- **Registry Module** – published on the Terraform Registry, referenced by name (`namespace/name/provider`), versioned and easy to pull with just `terraform init`.
- **Git Module** – pulled directly from a git repository URL, useful for private/internal modules not published to any registry, or when you want to point at a specific branch/tag/commit.

**Explaining the code:**

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}
```

- `source` – for registry modules this isn't a file path, it's a namespace pattern: `<namespace>/<module-name>/<provider>`. Terraform knows to go fetch this from the public registry automatically during init.
- `version` – exactly the same version pinning concept from earlier days, just applied to a module instead of a provider. `~> 5.0` allows 5.x updates but blocks a jump to 6.0.

**Why version pinning matters here too**

Same reasoning as pinning providers — registry modules get updated by their maintainers, and a new major version could remove variables, rename outputs, or completely change internal resource structure. Pinning protects my project from breaking because of someone else's unrelated update.

**Why I did NOT run terraform apply for this**

Because the whole point of this task was just to understand HOW registry modules are referenced and consumed, not to actually replace my existing hand-built VPC from earlier days with this community one. Running apply would've created a whole separate, real VPC (with real cost) just for a learning exercise, which doesn't make sense here. So I only ran `terraform init` to confirm the module downloads correctly, and looked at `terraform plan` briefly to see what it WOULD create, without actually applying it.

**Simple example to remember this by:** it's like browsing a recipe book (the registry) to see how a professional chef would make a dish, without actually cooking the whole meal myself right now — just understanding the recipe structure.

## Task 5: Module Version Locking

Went through the different ways to pin a module version today, and honestly each one has a slightly different "how strict do I want to be" vibe.

**1. `version = "~> 5.0"`** — pessimistic constraint, same as providers. Allows 5.1, 5.9, but blocks 6.0. Good default for most teams — get bug fixes/minor improvements automatically, but stay protected from big breaking changes.

**2. `version = "=5.1.2"`** — exact pin, no wiggle room at all. Only ever uses 5.1.2, nothing else, ever, until I manually change it. Advantage: maximum predictability, everyone on the team gets the literal exact same module every time. Disadvantage: I don't get ANY automatic bug fixes either, have to manually bump the version myself even for tiny patches.

**3. `version = ">=5.0,<6.0"`** — a range instead of a single constraint, basically manually writing out what `~>` does under the hood but with more control over the exact boundaries. Useful if I want something slightly different than the standard pessimistic behavior, like `>=5.2,<5.8` for some specific reason.

**4. Git Tag** — `source = "git::https://github.com/org/repo.git//modules/vpc?ref=v1.2.0"`. Used when the module isn't published to any registry (internal/private module), but the team still tags releases properly in git, so pinning to a tag gives the same kind of predictability as registry versioning.

**5. Git Commit SHA** — `source = "git::https://github.com/org/repo.git//modules/vpc?ref=<full-sha>"`. The most locked-down option possible — points to one exact, immutable commit. Even if someone deletes or moves a tag later, the commit SHA can't lie about what code it actually points to. Used in really strict environments where absolute reproducibility matters more than convenience.

**Why production teams pin module versions**

**Reproducible builds** — if I run `terraform init` today and a teammate runs it next month, both should get the EXACT same module code, not whatever happens to be "latest" at that moment. Pinning guarantees this.

**Breaking changes** — module maintainers (whether it's a public registry module or an internal company module) can and do introduce breaking changes in major versions. Without pinning, an unrelated `terraform init` by someone on the team could silently pull in a new incompatible version and break the whole plan/apply.

**CI/CD consistency** — pipelines need to behave predictably every single run. If module versions aren't locked, a pipeline that worked yesterday could mysteriously fail today just because a module got updated upstream, with zero code change on my end. That's a nightmare to debug if you don't already know to check module versions first.

## Bonus Concepts

**Validation inside a module** — modules can include `validation` blocks inside variable definitions to reject bad inputs early (like enforcing instance_type must be from an approved list), instead of letting AWS reject it later with a confusing error.

**README.md for a module** — writing proper docs (inputs, outputs, example usage) inside the module folder itself, so anyone (including future me) can understand how to use it without reading through every line of `main.tf`.

**Publishing modules to GitHub** — just means putting the module folder in its own git repo (or a clearly separated path within a bigger repo), so it can be referenced via `source = "git::..."` by other projects, even outside my own.

**Consuming modules through `git::`** — same syntax from Task 5, letting me pull a module directly from any git repo URL instead of only from the official registry — useful for private/internal modules.

**Passing one module's output into another module** — this is basically how modules "chain" together in bigger projects. Like: `module "vpc"` outputs a `subnet_id`, and then `module "ec2"` uses `module.vpc.subnet_id` as one of its input variables. This is exactly how real production Terraform projects are structured — small focused modules feeding into each other instead of one giant tangled file.

---

## Today's Key Learnings

- A module is just a folder of `.tf` files organized to do one specific, reusable job.
- Root module = where I run apply from. Child module = anything the root module calls into.
- Copy-pasting Terraform code is a bad habit because bugs/changes then need to be fixed in multiple places manually.
- Modules give reusability, consistency, encapsulation, maintainability, versioning, easier team collaboration, and easier testing.
- A module should stay flexible by accepting inputs through variables instead of hardcoding project-specific values.
- Outputs are how a module hands useful information back to whoever called it.
- Doing lookups (like fetching an AMI) inside a module removes flexibility from the caller — better to pass IDs in from root.
- `terraform init` initializes local modules too, not just providers — confirmed this by actually seeing it in the output.
- Module resources show up in state/plan prefixed with the module name, like `module.web.aws_instance.this`.
- Module composition means calling the same module multiple times to create multiple similar pieces of infra.
- `for_each` with modules creates separate, independently tracked module instances identified by key, not index.
- `for_each` is safer than `count` for modules because removing one named instance doesn't shift/recreate the others.
- Terraform Registry is a library of pre-built, tested modules maintained by HashiCorp partners and the community.
- Registry modules are referenced by namespace pattern (`namespace/name/provider`), not by file path.
- Git modules are useful for private/internal modules not published anywhere public.
- Version pinning applies to modules exactly like it applies to providers, using the same `~>`, `=`, and range syntax.
- Git tag pinning and git commit SHA pinning are the two ways to lock down non-registry modules.
- Commit SHA pinning is the strictest option since a tag can technically be moved/deleted later, but a commit can't lie.
- Reproducible builds, protection from breaking changes, and CI/CD consistency are the three big reasons production teams pin versions.
- Chaining module outputs into other modules' inputs is how real, larger Terraform projects are actually structured.

---

## Interview Questions

1. **What is a Terraform module?**
   A folder of `.tf` files organized to perform a specific, reusable piece of infrastructure logic.

2. **What is the difference between a root module and a child module?**
   Root module is where `terraform apply` is run from; child module is any module the root calls into.

3. **Why is copy-pasting Terraform code considered bad practice?**
   Because fixes and changes then need to be manually repeated everywhere the code was duplicated, increasing the chance of mistakes.

4. **Name three benefits of using modules.**
   Reusability, consistency, and maintainability (also encapsulation, versioning, easier collaboration, easier testing).

5. **What files are typically found inside a module?**
   `main.tf`, `variables.tf`, `outputs.tf`, and usually a `README.md`.

6. **Why do modules accept inputs through variables instead of hardcoding values?**
   So the same module can be reused safely across different projects/environments without modification.

7. **Why should a module avoid doing its own data source lookups when possible?**
   Because it removes flexibility from the caller and forces every user of the module into the same internal decision.

8. **Does `terraform init` initialize local modules?**
   Yes — it registers and prepares local modules just like it initializes providers.

9. **What is module composition?**
   Calling the same module multiple times, often with `for_each`, to create multiple similar pieces of infrastructure.

10. **What does `each.key` refer to inside a `for_each` module block?**
    The current item from the set/map being looped through in that iteration.

11. **Why is `for_each` generally preferred over `count` for modules?**
    Because removing a named entry only affects that specific instance, without shifting or recreating others like index-based `count` can.

12. **What is the Terraform Registry?**
    A public library of pre-built, versioned modules maintained by HashiCorp partners and the community.

13. **How is a registry module's source different from a local module's source?**
    Registry modules use a namespace pattern (`namespace/name/provider`); local modules use a relative file path.

14. **What's the difference between a local module, a registry module, and a git module?**
    Local = own filesystem path, Registry = published on Terraform Registry, Git = pulled directly from a git repository URL.

15. **Why pin a module version?**
    To guarantee reproducible builds and avoid unexpected breaking changes from upstream updates.

16. **What does `~> 5.0` mean when pinning a module version?**
    Allows updates within the 5.x line but blocks a jump to a new major version like 6.0.

17. **What is the strictest way to pin a git-based module?**
    Pinning to a specific commit SHA, since tags can be moved or deleted but a commit can't change.

18. **Why do production teams care about CI/CD consistency in relation to module versions?**
    Unpinned modules can silently change between pipeline runs, causing failures unrelated to any actual code change.

19. **How does one module pass data into another module?**
    By referencing the first module's output as an input value for the second module, like `module.vpc.subnet_id`.

20. **What does encapsulation mean in the context of Terraform modules?**
    The internal implementation details of a module are hidden from the caller, who only interacts with its defined inputs and outputs.

---

## Quick Revision (One-Page Summary)

- **Module** = reusable folder of `.tf` files. **Root module** = where apply runs. **Child module** = what root calls.
- Modules solve copy-paste problems: give reusability, consistency, encapsulation, maintainability, versioning, collaboration, testing.
- Standard module files: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`.
- Inputs come in via variables, results go out via outputs — module itself should stay flexible, not hardcoded.
- Avoid doing internal data lookups inside a module; pass IDs in from the root module instead.
- `terraform init` sets up local modules too, not just providers.
- Module resources appear namespaced in plan/state: `module.<name>.<resource>`.
- Module composition = same module called multiple times, usually via `for_each` on a set of names.
- `for_each` > `count` for modules — named keys avoid unwanted shifting/recreation.
- Terraform Registry = public library of tested modules; source uses `namespace/name/provider` format.
- Local vs Registry vs Git module = differ only in where the source code is fetched from.
- Version pinning for modules works exactly like providers: `~>`, `=`, or explicit ranges.
- Git modules can be pinned via tag (`?ref=v1.2.0`) or commit SHA (most strict, immutable).
- Pin versions for: reproducible builds, protection from breaking changes, stable CI/CD pipelines.
- Chaining module outputs into other modules' inputs = how real production Terraform projects are structured.