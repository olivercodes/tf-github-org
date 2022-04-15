package test

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/google/go-github/v35/github" // with go modules enabled (GO111MODULE=on or outside GOPATH)
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"golang.org/x/oauth2"
)

func TestTerraformHelloWorldExample(t *testing.T) {
	ctx := context.Background()
	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: os.Getenv("github_token")},
	)
	fmt.Printf("%s", ts)
	tc := oauth2.NewClient(ctx, ts)
	git01 := "https://git01.pfsfhq.com"

	client, _ := github.NewEnterpriseClient(git01, git01, tc)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples",
		VarFiles:     []string{"repos.tfvars"},
		BackendConfig: map[string]interface{}{
			"endpoint":                    "minio_url"
			"bucket":                      "terraform",
			"key":                         "terratest/terraform-github-org/terraform.tfstate",
			"region":                      "us-east-1",
			"skip_credentials_validation": true,
			"skip_metadata_api_check":     true,
			"skip_region_validation":      true,
			"force_path_style":            true,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	_, _, err := client.Repositories.Get(ctx, "terratest", "test-github-org-module")
	if err != nil {
		t.Errorf("Failed to get repo: %v", err)
	}

	protection, _, err := client.Repositories.GetBranchProtection(ctx, "terratest", "test-github-org-module", "main")
	if err != nil {
		t.Errorf("Repository branch protection check failed: %v", err)
	}

	want := &github.Protection{
		RequiredStatusChecks: &github.RequiredStatusChecks{
			Strict:   true,
			Contexts: []string{"build", "tf-apply"},
		},
		RequiredPullRequestReviews: &github.PullRequestReviewsEnforcement{
			DismissStaleReviews:          true,
			DismissalRestrictions:        nil,
			RequireCodeOwnerReviews:      false,
			RequiredApprovingReviewCount: 1,
		},
		EnforceAdmins: &github.AdminEnforcement{
			URL:     github.String("/repos/o/r/branches/b/protection/enforce_admins"),
			Enabled: true,
		},
		Restrictions: &github.BranchRestrictions{
			Users: []*github.User{
				{Login: github.String("prow-git"), ID: github.Int64(355)},
			},
		},
	}

	assert.Equal(t, protection.RequiredStatusChecks.Contexts, want.RequiredStatusChecks.Contexts)
	assert.Equal(t, protection.RequiredPullRequestReviews.RequiredApprovingReviewCount, want.RequiredPullRequestReviews.RequiredApprovingReviewCount)
	assert.Equal(t, protection.EnforceAdmins.Enabled, want.EnforceAdmins.Enabled)

	_, _, err = client.Repositories.DownloadContents(ctx, "terratest", "test-github-org-module", ".github/workflows/build.yml", nil)
	if err != nil {
		t.Errorf("Repositories.DownloadContents returned error: %v", err)
	}

	_, _, err = client.Repositories.DownloadContents(ctx, "terratest", "test-github-org-module", ".github/workflows/deploy.yml", nil)
	if err != nil {
		t.Errorf("Repositories.DownloadContents returned error: %v", err)
	}

	_, _, err = client.Repositories.DownloadContents(ctx, "terratest", "test-github-org-module", "Makefile", nil)
	if err != nil {
		t.Errorf("Repositories.DownloadContents returned error: %v", err)
	}

	_, _, err = client.Repositories.DownloadContents(ctx, "terratest", "test-github-org-module", "OWNERS", nil)
	if err != nil {
		t.Errorf("Repositories.DownloadContents returned error: %v", err)
	}

	_, _, err = client.Repositories.DownloadContents(ctx, "terratest", "test-github-org-module", "OWNERS_ALIASES", nil)
	if err != nil {
		t.Errorf("Repositories.DownloadContents returned error: %v", err)
	}

	// TODO - we should use client.Teams.ListTeams and iterate/print through the list of returned teams to know what WAS created in event of failure
	_, _, err = client.Teams.GetTeamBySlug(ctx, "terratest", "terratest-contributors")
	if err != nil {
		t.Errorf("Failed to get repository: %v", err)
	}

	_, _, err = client.Teams.GetTeamBySlug(ctx, "terratest", "terratest-owners")
	if err != nil {
		t.Errorf("Failed to get repository: %v", err)
	}

	_, _, err = client.Teams.IsTeamRepoBySlug(ctx, "terratest", "terratest-owners", "Terratest", "test-github-org-module")
	if err != nil {
		t.Errorf("Failed to validate repo has been added to team: %v", err)
	}

	_, _, err = client.Teams.IsTeamRepoBySlug(ctx, "terratest", "terratest-contributors", "Terratest", "test-github-org-module")
	if err != nil {
		t.Errorf("Failed to validate repo has been added to team: %v", err)
	}

}
