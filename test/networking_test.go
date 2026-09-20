package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestNetworkingModule(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "./fixtures/networking",
	}

	// Runs terraform destroy at the end of the test, no matter what happens above -
	// including if an assertion fails partway through. This is what keeps a failed
	// test run from leaving real Azure resources behind.
	defer terraform.Destroy(t, terraformOptions)

	// Runs terraform init and terraform apply for real, against real Azure -
	// this test costs real (small) money and real time to run, same as any
	// other apply in this project.
	terraform.InitAndApply(t, terraformOptions)

	// Reads the aks_subnet_id output, exactly like running
	// `terraform output aks_subnet_id` would show in a terminal.
	subnetID := terraform.Output(t, terraformOptions, "aks_subnet_id")

	// The actual assertion: fail the test if the subnet ID doesn't contain
	// "snet-aks" - a cheap, meaningful check that the module produced a real,
	// correctly-named resource, not an empty or malformed value.
	assert.Contains(t, subnetID, "snet-aks")
}