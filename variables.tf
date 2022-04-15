variable "org_config" {
  description = "configs for the github organization"
  type = object({
    org_name       = string
    default_branch = string
    base_url       = string
  })
}

variable "repositories" {
  description = "repos"
  type        = map(any)
}

variable "github_org" {
  description = "the org or user owner"
  default     = "aws"
}

variable "owners_aliases" {
  type = map(list(string))
}
