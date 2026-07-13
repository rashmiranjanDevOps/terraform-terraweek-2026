TASK-1
------

1.What is Infrastructure as Code, and what problems does it solve compared to clicking around a cloud console?

Ans --> Basically instead of going to AWS/Azure/GCP console and clicking buttons to create servers,VMs,databases etc,we write code for it.IaC means writing all that in a script/file instead, and running it to create everything automatically.

Why it's better than clicking in console:

- if you click manually, you forget what you clicked later.
- 2 environments (dev/prod) never match exactly if done manually. (if I create dev environment today and prod next week, both will be slightly different.)
- no history/backup of changes,hard to undo.
- with code we can put it on GitHub, take review, rollback if something breaks
- can reuse same code to create same setup again and again.

2.What is Terraform, and why is it so popular?

Ans --> Terraform is a tool where we write our infrastructure requirement in a file (extension .tf, language is HCL) and terraform takes care of creating/updating/deleting resources on cloud to match what we wrote. (ex: like "I want 1 EC2 server" and terraform creates it for me on AWS.)

why is it so popular ?

- it's a declarative - we just say WHAT we want, not the steps. Terraform figures out how.
- we works with almost every cloud (AWS, GCP, Azure) not just one this is big plus for every one.
- "terraform plan" command which shows preview before actually creating anything, so less chance   of mistake
- lots of ready-made modules online, don't need to write everything from scratch.
- it's so popular, community support is huge, easy to find help

3.Terraform vs alternatives — write one line each on how Terraform compares to OpenTofu, Pulumi, CloudFormation, and Ansible.

Ans --> 
1.OpenTofu -> same as terraform basically, it's a copy/fork made because terraform changed license. Free and open source version.
2.Pulumi -> same purpose but you write in normal languages like python/JS instead of HCL
3.CloudFormation -> AWS's own tool, only works for AWS. Terraform works for all clouds so terraform wins here
4.Ansible -> this is more for configuring servers (installing software etc), not really for creating infra like terraform does. Different use case mainly.

TASK-2
------
1. terraform version
Terraform v1.15.8
on windows_amd64

2. terraform -help
Usage: terraform [global options] <subcommand> [args]

The available commands for execution are listed below.
The primary workflow commands are given first, followed by
less common or more advanced commands.

Main commands:
  init          Prepare your working directory for other commands
  validate      Check whether the configuration is valid
  plan          Show changes required by the current configuration
  apply         Create or update infrastructure
  destroy       Destroy previously-created infrastructure

  --------

TASK-3
------

Task 3: 6 Crucial Terraform Terminologies

1. Provider

Ans --> Provider is like a plugin/connector which lets terraform talk to a particular platform (AWS, Azure, GCP, Docker etc). Without provider, terraform doesn't know how to create resources on that platform.

Example: if I want to create stuff on AWS, I need to add AWS provider in my .tf file first, then only terraform can create resources there.

2. Resource

Ans --> Resource is the actual infra thing we want to create — like a server, database, storage bucket etc. This is the main building block in terraform, almost everything we write is to create some resource.

Example: writing a resource block to create 1 EC2 instance on AWS.

3. State

Ans --> State is basically terraform's memory — it keeps track of what all resources it already created and their current details. It's stored in a file called terraform.tfstate. Terraform uses this file to know what exists already, so next time when we run terraform it compares our code vs this file and decides what to add/change/delete.

Example: after creating an EC2 instance, terraform.tfstate file will have all details of that instance saved in it.

4. Plan

Ans --> Plan is like a preview/summary of what changes terraform is going to make before actually doing it. Running "terraform plan" shows what will be added, changed or destroyed — so we can check before applying, less chance of mistake happening in prod.

Example: running terraform plan shows "1 to add, 0 to change, 0 to destroy" before we actually create anything.

5. HCL

Ans --> HCL means HashiCorp Configuration Language, it's the language/syntax we use to write our .tf files. It's made specifically for terraform, easy to read compared to normal programming language.

Example: writing resource "aws_instance" "my_server" { ... } — this whole syntax is HCL.

6. Module

Ans --> Module is a group of terraform files/config packaged together so we can reuse it. Instead of writing same code again and again for similar setup, we just call the module and pass different values.

Example: making a module for "create EC2 instance" once, then reusing same module for dev, test, prod just by changing input values.

TASK-4
------

