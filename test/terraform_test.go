package test

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Give this Bucket an environment to operate as a part of, for the purposes of resource tagging
// Give it a random string so we're sure it's created this test run
var expectedEnvironment string
var expectedProject string
var testPreq *testing.T
var terraformOptions *terraform.Options
var blacklistRegions []string
var tmpAssertsSubnet string
var tmpGKESubnet string
var tmpVpc string
var tmpGKESA string
var tmpKMSKey string

func TestMain(m *testing.M) {
	expectedEnvironment = fmt.Sprintf("terratest %s", strings.ToLower(random.UniqueId()))
	expectedProject = fmt.Sprintf("tft%s", strings.ToLower(random.UniqueId()))
	blacklistRegions = []string{"asia-east2"}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func(){
		<-c
		TestCleanup(testPreq)
		Clean()
		os.Exit(1)
	}()

	result := 0
	defer func() {
		TestCleanup(testPreq)
		Clean()
		os.Exit(result)
	}()
	result = m.Run()
}

// -------------------------------------------------------------------------------------------------------- //
// Utility functions
// -------------------------------------------------------------------------------------------------------- //
func setTerraformOptions(dir string, region string, subnet string, projectId string) {
	terraformOptions = &terraform.Options {
		TerraformDir: dir,
		// Pass the expectedEnvironment for tagging
		Vars: map[string]interface{}{
			"environment": expectedEnvironment,
			"project": expectedProject,
			"location": region,
			"network": tmpVpc,
			"subnetwork": subnet,
			"service_account": tmpGKESA,
			"database_encryption_kms_key": tmpKMSKey,
		},
		EnvVars: map[string]string{
			"GOOGLE_CLOUD_PROJECT": projectId,
		},
	}
}

// A build step that removes temporary build and test files
func Clean() error {
	fmt.Println("Cleaning...")

	return filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == "vendor" {
			return filepath.SkipDir
		}
		if info.IsDir() && info.Name() == ".terraform" {
			os.RemoveAll(path)
			fmt.Printf("Removed \"%v\"\n", path)
			return filepath.SkipDir
		}
		if !info.IsDir() && (info.Name() == "terraform.tfstate" ||
		info.Name() == "terraform.tfplan" ||
		info.Name() == "terraform.tfstate.backup") {
			os.Remove(path)
			fmt.Printf("Removed \"%v\"\n", path)
		}
		return nil
	})
}

func Test_Prereq(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions(".", region, "", projectId)
	testPreq = t

	terraform.InitAndPlan(t, terraformOptions)
	terraform.Apply(t, terraformOptions)

	terraform.OutputRequired(t, terraformOptions, "subnets")
	terraform.OutputRequired(t, terraformOptions, "vpc_id")

	outputs := terraform.OutputAll(t, terraformOptions)
	subnets := outputs["subnets"].(map[string]interface{})
	tmpAssertsSubnetData := subnets["gke-asserts"].(map[string]interface{})
	tmpGKESubnetData := subnets["gke-k8nodes"].(map[string]interface{})

	tmpAssertsSubnet = tmpAssertsSubnetData["name"].(string)
	tmpGKESubnet = tmpGKESubnetData["name"].(string)
	tmpVpc = outputs["vpc_id"].(string)
	tmpGKESA = outputs["gke_sa"].(string)
	tmpKMSKey = outputs["crypto_key"].(string)
}

// -------------------------------------------------------------------------------------------------------- //
// Unit Tests
// -------------------------------------------------------------------------------------------------------- //
func TestUT_Assertions(t *testing.T) {
	// Pick a random GCP region to test in. This helps ensure your code works in all regions.
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)

	expectedAssertNameTooLong := "'s generated name is too long"
	expectedAssertNameInvalidChars := "does not match regex"
	expectedAssertKeyLocation := "ETCD Database Encryption Key specified"

	setTerraformOptions("assertions", region, tmpAssertsSubnet, projectId)

	out, err := terraform.InitAndPlanE(t, terraformOptions)

	require.Error(t, err)
	assert.Contains(t, out, expectedAssertNameTooLong)
	assert.Contains(t, out, expectedAssertNameInvalidChars)
	assert.Contains(t, out, expectedAssertKeyLocation)
}

func TestUT_Defaults(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("defaults", region, tmpGKESubnet, projectId)
	terraform.InitAndPlan(t, terraformOptions)
}

func TestUT_Overrides(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("overrides", region, tmpGKESubnet, projectId)
	terraform.InitAndPlan(t, terraformOptions)
}

// -------------------------------------------------------------------------------------------------------- //
// Integration Tests
// -------------------------------------------------------------------------------------------------------- //

func TestIT_Defaults(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("defaults", region, tmpGKESubnet, projectId)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	outputs := terraform.OutputAll(t, terraformOptions)

	// Ugly typecasting because Go....
	gkeMap := outputs["gke"].(map[string]interface{})
	gkeEndpoint := gkeMap["gke_cluster_endpoint"].(string)

	// Make sure our bucket is created
	fmt.Printf("Found GKE endpoint %s...\n", gkeEndpoint)
}

func TestIT_Overrides(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("overrides", region, tmpGKESubnet, projectId)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	outputs := terraform.OutputAll(t, terraformOptions)

	// Ugly typecasting because Go....
	gkeMap := outputs["gke"].(map[string]interface{})
	gkeEndpoint := gkeMap["gke_cluster_endpoint"].(string)

	// Make sure our bucket is created
	fmt.Printf("Found GKE endpoint %s...\n", gkeEndpoint)
}

func TestCleanup(t *testing.T) {
	fmt.Println("Cleaning possible lingering resources..")
	defer cleanPreq()
	terraform.Destroy(t, terraformOptions)
}

func cleanPreq() {
	// Also clean up prereq. resources
	fmt.Println("Cleaning our prereq resources...")
	projectId := gcp.GetGoogleProjectIDFromEnvVar(testPreq)
	region := gcp.GetRandomRegion(testPreq, projectId, nil, blacklistRegions)
	setTerraformOptions(".", region, "", projectId)
	terraform.Destroy(testPreq, terraformOptions)
}
