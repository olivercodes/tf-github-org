terraform {
  required_providers {
    github = {
      source  = "hashicorp/github"
      version = "~> 4.9.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 2.19.1"
    }
  }
}
