terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # NOTE: This bootstrap config uses LOCAL state on purpose — it creates the
  # very bucket that other configs will use as their remote backend.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "terraweek-2026"
      ManagedBy = "terraform"
      Purpose   = "tf-state-backend"
    }
  }
}