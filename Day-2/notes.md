TASK-1
------

Master HCL Syntax

1. Anatomy of a block

Ans --> block_type "label_one" "label_two" { argument = value }

block type = what kind of thing we defining (resource, variable, provider, output etc)
labels = name/identifier for that block. some blocks need 2 labels, some need only 1, some need 0 (depends on block type)
{ } = body of the block, this is where all the arguments/settings go

ex:
resource "aws_instance" "web" {
  ami           = "ami-123456"
  instance_type = "t2.micro"
}

here "resource" is block type, "aws_instance" is 1st label (means what type of resource), "web" is 2nd label (name we giving it so we can refer later like aws_instance.web). everything inside { } is the actual config for it.

another ex with only 1 label:
variable "region" {
  default = "us-east-1"
}

"variable" is block type, "region" is the only label.

2. argument vs block (difference)

Ans --> argument is just a simple key = value pair, single line setting inside a block.
block is a bigger structure with its own { }, and can repeat multiple times or have other blocks nested inside it.

ex:
resource "aws_instance" "web" {
  instance_type = "t2.micro"     # this is argument, simple key=value

  tags = {                       # this is also argument actually (value is a map)
    Name = "web-server"
  }

  ebs_block_device {             # this is a nested BLOCK not argument
    volume_size = 20
  }
}

so basic rule i understood - if its "key = value" its argument. if it has its own { } after the name (no = sign) its a block. and blocks can be written again and again if needed (like multiple ebs_block_device for multiple disks) but argument is single value only. (An argument assigns one value to a key. That value itself can be a string, number, boolean, list, map, object, or expression.)

3. Expressions

Ans -->

string interpolation - when we want to put a variable or reference value inside a string, we wrap it in ${ }

ex: 
"Hello ${var.username}, your server is ${aws_instance.web.id}"

references - way to point to some other resource/variable/data's value, using dot notation

ex:
aws_instance.web.id      -> gets id of the instance we created
var.instance_type        -> gets the value of a variable
local.full_name          -> gets value from locals block
data.aws_ami.ubuntu.id   -> gets id from a data source

operators - normal operators like other languages, can use for math/comparison/logic

ex:
var.count + 1
var.environment == "prod"
var.is_prod && var.enable_backup
var.age > 18 ? "adult" : "minor"     # this is ternary/conditional expression

note: in newer terraform version we don't always need ${ } if the whole value is just one reference (like instance_type = var.type works fine without ${ }). ${ } mainly needed when we mixing plain text + variable together in same string.

TASK-2
------

# Primitive types


variable "project_name" {
  description = "Name of the project, used as a prefix when naming resources"
  type        = string
  default     = "terraweek"
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "enable_monitoring" {
  description = "Enable or disable detailed monitoring"
  type        = bool
  default     = true
}


# Collection types


variable "availability_zones" {
  description = "Availability zones to deploy resources into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    Owner       = "terraweek"
    Environment = "dev"
  }
}

variable "allowed_ports" {
  description = "Ports allowed through the security group"
  type        = set(string)
  default     = ["22", "80", "443"]
}


# Structural types


variable "server_config" {
  description = "Server settings grouped into one object"
  type = object({
    name     = string
    size     = string
    replicas = number
  })
  default = {
    name     = "web-server"
    size     = "t2.micro"
    replicas = 1
  }
}

variable "instance_spec" {
  description = "Tuple of [name, cpu count, is spot instance]"
  type        = tuple([string, number, bool])
  default     = ["app-node", 2, false]
}


# Default + validation


variable "environment" {
  description = "Which environment we're deploying to"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}


# Sensitive variable


variable "db_password" {
  description = "Database password — sensitive, so it never shows up in plan/apply output"
  type        = string
  sensitive   = true
  # no default on purpose, this should come from a tfvars file or env var, not hardcoded
}

TASK-3
------

# locals

locals {
  # prefix we'll reuse for naming stuff
  name_prefix = "${var.project_name}-${var.environment}"

  # merge() - combining tags from variables.tf with couple more here
  common_tags = merge(
    var.common_tags,
    {
      Name      = local.name_prefix
      ManagedBy = "terraform"
    }
  )

  # join() - turns AZ list into one readable string
  az_list_joined = join(", ", var.availability_zones)

  # upper() - just uppercasing the project name
  project_name_upper = upper(var.project_name)

  # length() - counting how many AZs we have
  az_count = length(var.availability_zones)

  # lookup() - grab a tag from the map, fallback if not there
  owner_tag = lookup(var.common_tags, "Owner", "unknown")
}

# outputs

output "name_prefix" {
  description = "prefix used for naming resources"
  value       = local.name_prefix
}

output "common_tags" {
  description = "final tags after merge"
  value       = local.common_tags
}

output "availability_zones_joined" {
  description = "AZs joined into one string"
  value       = local.az_list_joined
}

output "availability_zone_count" {
  description = "how many AZs we using"
  value       = local.az_count
}

output "project_name_upper" {
  description = "project name in uppercase"
  value       = local.project_name_upper
}

output "owner_tag" {
  description = "owner tag pulled from common_tags using lookup()"
  value       = local.owner_tag
}