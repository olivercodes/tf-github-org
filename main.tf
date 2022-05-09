locals {
  org_members = toset(distinct(concat(var.owners_aliases.contributors)))
  org_admins  = toset(distinct(concat(var.owners_aliases.leads)))
}

resource "github_repository" "repos" {
   for_each    = var.repositories
   name        = each.key
   description = each.value.description
   visibility  = each.value.visibility

   allow_merge_commit = true
   allow_rebase_merge = true
   allow_squash_merge = true

   auto_init          = true
   gitignore_template = "Terraform"
 }

resource "github_repository_file" "OWNERS" {
  depends_on = [github_repository.repos]
  for_each   = github_repository.repos
  repository = each.value.name
  branch     = "main"
  file       = "OWNERS"
  content = replace(yamlencode({
    approvers : var.repositories[each.key].base_owners,
  reviewers : var.repositories[each.key].base_reviewers }), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
  # content             = "OWNERSALIASES"
  commit_message      = "OWNERSALIASES Managed by Terraform"
  commit_author       = "Terraform"
  commit_email        = "terraform@olivercodes.com"
  overwrite_on_create = true
}

resource "github_repository_file" "OWNERSALIASES" {
  depends_on = [github_repository.repos]
  for_each   = github_repository.repos
  repository = each.value.name
  branch     = "main"
  file       = "OWNERS_ALIASES"
  content    = replace(yamlencode({ aliases : var.owners_aliases }), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")

  # content             = "OWNERSALIASES"
  commit_message      = "OWNERSALIASES Managed by Terraform"
  commit_author       = "Terraform"
  commit_email        = "terraform@olivercodes.com"
  overwrite_on_create = true
}

# resource "github_repository_file" "build_yml" {
#   depends_on = [github_repository.repos]
#   for_each   = github_repository.repos
#   repository = each.value.name
#   branch     = "main"
#   file       = ".github/workflows/build.yml"
#   content    = file("${path.root}/common-files/build.yml")
#   commit_message      = "Github actions build.yml, Managed by Terraform"
#   commit_author       = "Terraform"
#   commit_email        = "terraform@olivercodes.com"
#   overwrite_on_create = true
# }

# resource "github_repository_file" "makefile" {
#   depends_on = [github_repository.repos]
#   for_each   = github_repository.repos
#   repository = each.value.name
#   branch     = "main"
#   file       = "./Makefile"
#   content    = file("${path.root}/common-files/Makefile")
#   commit_message      = "Github actions build.yml, Managed by Terraform"
#   commit_author       = "Terraform"
#   commit_email        = "terraform@olivercodes.com"
#   overwrite_on_create = true
# }

# resource "github_repository_file" "deploy_yml" {
#   depends_on = [github_repository.repos]
#   for_each   = github_repository.repos
#   repository = each.value.name
#   branch     = "main"
#   file       = ".github/workflows/deploy.yml"
#   content    = file("${path.root}/common-files/deploy.yml")
#   commit_message      = "Github actions deploy.yml, Managed by Terraform"
#   commit_author       = "Terraform"
#   commit_email        = "terraform@olivercodes.com"
#   overwrite_on_create = true
# }

data "github_user" "oc-ci-robot" {
  username = "oc-ci-robot"
}

# resource "github_branch_protection" "repos_branch_protection" {
#   depends_on     = [github_repository_file.OWNERSALIASES]
#   for_each       = github_repository.repos
#   required_status_checks {
#     strict   = true
#     contexts = ["build", "tf-apply"]
#   }
#   required_pull_request_reviews {
#     dismiss_stale_reviews = true
#   }
#   enforce_admins = false
#   push_restrictions = [
#     data.github_user.oc-ci-robot.node_id,
#   ]
#   repository_id  = each.value.name
#   pattern        = var.org_config.default_branch
# }

resource "github_membership" "org_members" {
  for_each = local.org_members
  username = each.value
  role     = "member"
}

resource "github_membership" "org_admins" {
  for_each = local.org_admins
  username = each.value
  role     = "admin"
}

resource "github_team" "repo_owners" {
  name        = join("-", [var.org_config.org_name, "owners"])
  description = "Prow Repo OWNERS"
  privacy     = "closed"
}

resource "github_team" "repo_contributors" {
  name        = join("-", [var.org_config.org_name, "contributors"])
  description = "Prow Repo Reviewers"
  privacy     = "closed"
}

resource "github_team_membership" "add_repo_owners" {
  depends_on = [github_team.repo_owners]
  for_each = toset(var.owners_aliases.leads)
  team_id = github_team.repo_owners.id
  username = each.value
  role = "member"
}

resource "github_team_membership" "add_repo_contributors" {
  depends_on = [github_team.repo_owners]
  for_each = toset(var.owners_aliases.contributors)
  team_id = github_team.repo_contributors.id
  username = each.value
  role = "member"
}

resource "github_team_repository" "add_repos_to_owners" {
  depends_on = [github_team.repo_owners, github_repository.repos]
  for_each = github_repository.repos
  team_id    = github_team.repo_owners.id
  repository = each.value.name
  permission = "admin"
}

resource "github_team_repository" "add_repos_to_contributors" {
  depends_on = [github_team.repo_owners, github_repository.repos]
  for_each = github_repository.repos
  team_id    = github_team.repo_contributors.id
  repository = each.value.name
  permission = "push"
}
