# Makefile for Rocky 9 FIPS Terraform module

EXAMPLE_DIR = examples/complete
SSH_KEY     = ./id_rsa_rocky9_fips
KEY_NAME    = ironsmith-rocky9-fips

# Reusable fragments for instance access targets
PUBLIC_IP = $$(cd $(EXAMPLE_DIR) && terraform output -raw public_ip 2>/dev/null)
INSTANCE_ID = $$(cd $(EXAMPLE_DIR) && terraform output -raw instance_id 2>/dev/null)
SSH_CMD = ssh -i $(SSH_KEY) rocky@$(PUBLIC_IP)

# Guard: require a deployed instance (used by access/debug targets)
# Pipes terraform output through grep to match a valid IP, filtering out
# ANSI warning text that terraform writes to stdout when no outputs exist.
define require-instance
	@IP=$$(cd $(EXAMPLE_DIR) && terraform output -raw public_ip 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'); \
	if [ -z "$$IP" ]; then \
		echo "No instance deployed. Run 'make apply' first."; \
		exit 1; \
	fi
endef

# Terminal colors (graceful degradation for non-interactive shells)
GREEN  := $(shell tput -Txterm setaf 2 2>/dev/null)
YELLOW := $(shell tput -Txterm setaf 3 2>/dev/null)
CYAN   := $(shell tput -Txterm setaf 6 2>/dev/null)
RESET  := $(shell tput -Txterm sgr0 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: help help-all init plan apply destroy pre-commit reset ssh ssm keygen setup \
	dashboard logs fips-verify cloud-init status output \
	test test-unit test-integration test-all test-setup \
	validate fmt fmt-check lint docs clean clean-aws diagram

help:
	@echo "$(CYAN)Rocky 9 FIPS Terraform Module$(RESET)"
	@echo ""
	@echo "$(YELLOW)Getting started:$(RESET)"
	@echo "  $(GREEN)setup$(RESET)              - One-time: create tfvars + SSH keypair"
	@echo "  $(GREEN)init$(RESET)               - Initialize terraform"
	@echo "  $(GREEN)apply$(RESET)              - Apply with auto-approve"
	@echo "  $(GREEN)destroy$(RESET)            - Destroy with auto-approve"
	@echo ""
	@echo "$(YELLOW)Testing:$(RESET)"
	@echo "  $(GREEN)test$(RESET)               - Lint + unit tests (no AWS, ~30s)"
	@echo "  $(GREEN)test-integration$(RESET)   - Terratest integration tests (~15min, deploys AWS)"
	@echo "                          RUN=TestName to run a single test"
	@echo "  $(GREEN)test-all$(RESET)           - Everything"
	@echo ""
	@echo "$(YELLOW)Code quality:$(RESET)"
	@echo "  $(GREEN)fmt$(RESET)                - Format terraform files"
	@echo "  $(GREEN)pre-commit$(RESET)         - Run all pre-commit hooks"
	@echo ""
	@echo "Run $(CYAN)make help-all$(RESET) for all targets (access, debug, CloudWatch, etc.)"

help-all: help
	@echo ""
	@echo "$(YELLOW)Terraform:$(RESET)"
	@echo "  $(GREEN)plan$(RESET)               - Run terraform plan"
	@echo "  $(GREEN)reset$(RESET)              - Destroy and reapply"
	@echo "  $(GREEN)output$(RESET)             - Show terraform outputs"
	@echo ""
	@echo "$(YELLOW)Access:$(RESET)"
	@echo "  $(GREEN)ssh$(RESET)                - SSH into EC2 instance"
	@echo "  $(GREEN)ssm$(RESET)                - Connect via SSM Session Manager"
	@echo "  $(GREEN)keygen$(RESET)             - Generate RSA-3072 keypair + import to AWS"
	@echo ""
	@echo "$(YELLOW)CloudWatch:$(RESET)"
	@echo "  $(GREEN)dashboard$(RESET)          - Open CloudWatch dashboard in browser"
	@echo "  $(GREEN)logs$(RESET)               - Tail CloudWatch logs"
	@echo ""
	@echo "$(YELLOW)Debug:$(RESET)"
	@echo "  $(GREEN)fips-verify$(RESET)        - Verify FIPS mode on instance"
	@echo "  $(GREEN)cloud-init$(RESET)         - View cloud-init output log"
	@echo "  $(GREEN)status$(RESET)             - Check service status"
	@echo ""
	@echo "$(YELLOW)Additional:$(RESET)"
	@echo "  $(GREEN)test-unit$(RESET)          - Unit tests only"
	@echo "  $(GREEN)validate$(RESET)           - terraform validate"
	@echo "  $(GREEN)fmt-check$(RESET)          - Check formatting (CI-friendly)"
	@echo "  $(GREEN)lint$(RESET)               - Run tflint"
	@echo "  $(GREEN)docs$(RESET)               - Regenerate terraform-docs"
	@echo "  $(GREEN)diagram$(RESET)            - Generate architecture diagram"
	@echo "  $(GREEN)clean$(RESET)              - Remove local build artifacts"
	@echo "  $(GREEN)clean-aws$(RESET)          - Delete AWS key pair"

init:
	cd $(EXAMPLE_DIR) && terraform init

plan:
	cd $(EXAMPLE_DIR) && terraform plan

output:
	cd $(EXAMPLE_DIR) && terraform output

apply:
	cd $(EXAMPLE_DIR) && terraform apply --auto-approve

destroy:
	cd $(EXAMPLE_DIR) && terraform destroy --auto-approve

pre-commit:
	pre-commit run --all-files

validate:
	terraform validate

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

lint:
	tflint --recursive

docs:
	terraform-docs markdown table --output-file README.md .

clean:
	@echo "Cleaning local build artifacts..."
	rm -rf .terraform
	rm -rf examples/complete/.terraform examples/complete/.terraform.lock.hcl examples/complete/terraform.tfstate*
	rm -rf examples/minimal/.terraform examples/minimal/.terraform.lock.hcl examples/minimal/terraform.tfstate*
	rm -rf $(VENV_DIR)
	rm -f $(SSH_KEY) $(SSH_KEY).pub
	@echo "Done. Run 'make clean-aws' to also delete the AWS key pair."

clean-aws:
	@echo "Deleting AWS key pair '$(KEY_NAME)'..."
	@aws ec2 delete-key-pair --key-name $(KEY_NAME) && \
		echo "Deleted: $(KEY_NAME)" || \
		echo "Key pair '$(KEY_NAME)' not found or already deleted."

reset: destroy
	cd $(EXAMPLE_DIR) && terraform apply --auto-approve

ssh:
	@if [ ! -f "$(SSH_KEY)" ]; then \
		echo "SSH key not found: $(SSH_KEY)"; \
		echo "Run 'make keygen' to generate one."; \
		exit 1; \
	fi
	$(require-instance)
	$(SSH_CMD)

ssm:
	$(require-instance)
	aws ssm start-session --target $(INSTANCE_ID)

keygen:
	@if [ -f "$(SSH_KEY)" ]; then \
		echo "Key already exists: $(SSH_KEY)"; \
		echo "Delete it first to regenerate: rm $(SSH_KEY) $(SSH_KEY).pub"; \
		exit 1; \
	fi
	@echo "Generating FIPS-compliant RSA-3072 key pair..."
	ssh-keygen -t rsa -b 3072 -f $(SSH_KEY) -N ""
	@echo ""
	@echo "Importing to AWS as '$(KEY_NAME)'..."
	aws ec2 import-key-pair --key-name $(KEY_NAME) \
		--public-key-material fileb://$(SSH_KEY).pub \
		--query 'KeyName' --output text
	@echo ""
	@echo "Done. Set key_pair_name = \"$(KEY_NAME)\" in your terraform.tfvars"

setup:
	@echo "$(CYAN)Setting up local development environment...$(RESET)"
	@echo ""
	@if [ ! -f "$(EXAMPLE_DIR)/terraform.tfvars" ]; then \
		cp $(EXAMPLE_DIR)/terraform.tfvars.example $(EXAMPLE_DIR)/terraform.tfvars; \
		echo "$(GREEN)Created$(RESET) $(EXAMPLE_DIR)/terraform.tfvars"; \
	else \
		echo "$(YELLOW)Exists$(RESET)  $(EXAMPLE_DIR)/terraform.tfvars"; \
	fi
	@if [ -f "$(SSH_KEY)" ]; then \
		echo "$(YELLOW)Exists$(RESET)  $(SSH_KEY)"; \
	else \
		echo "$(GREEN)Generating FIPS-compliant RSA-3072 key pair...$(RESET)"; \
		ssh-keygen -t rsa -b 3072 -f $(SSH_KEY) -N ""; \
		echo "$(GREEN)Importing to AWS as '$(KEY_NAME)'...$(RESET)"; \
		aws ec2 import-key-pair --key-name $(KEY_NAME) \
			--public-key-material fileb://$(SSH_KEY).pub \
			--query 'KeyName' --output text; \
	fi
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Edit $(EXAMPLE_DIR)/terraform.tfvars — set your subnet_id"
	@echo "  2. make init"
	@echo "  3. make apply"
	@echo "  4. make ssh"

# CloudWatch targets
dashboard:
	@URL=$$(cd $(EXAMPLE_DIR) && terraform output -raw cloudwatch_dashboard_url 2>/dev/null); \
	if [ -z "$$URL" ] || [ "$$URL" = "null" ]; then \
		echo "CloudWatch not enabled. Set enable_cloudwatch_logs = true"; \
	else \
		case "$$(uname)" in \
			"Darwin") open "$$URL" ;; \
			"Linux") xdg-open "$$URL" ;; \
			*) echo "Open $$URL" ;; \
		esac \
	fi

logs:
	@LOG_GROUP=$$(cd $(EXAMPLE_DIR) && terraform output -raw cloudwatch_log_group_name 2>/dev/null); \
	if [ -z "$$LOG_GROUP" ] || [ "$$LOG_GROUP" = "null" ]; then \
		echo "CloudWatch not enabled. Set enable_cloudwatch_logs = true"; \
	else \
		aws logs tail "$$LOG_GROUP" --follow; \
	fi

# Debug targets
fips-verify:
	$(require-instance)
	@echo "Verifying FIPS mode on instance..."
	@$(SSH_CMD) \
		"echo '=== FIPS Verification ===' && \
		echo 'fips_enabled:' \$$(cat /proc/sys/crypto/fips_enabled) && \
		echo 'crypto_policy:' \$$(update-crypto-policies --show) && \
		sudo fips-mode-setup --check"

cloud-init:
	$(require-instance)
	$(SSH_CMD) "sudo tail -100 /var/log/cloud-init-output.log"

status:
	$(require-instance)
	$(SSH_CMD) "sudo systemctl status sshd --no-pager"

#=============================================================================
# Testing targets
#=============================================================================

test: pre-commit test-unit
	@echo "Static analysis and unit tests passed"

test-unit:
	@echo "Running terraform test (unit tests)..."
	terraform init -backend=false
	terraform test -filter=tests/unit.tftest.hcl

test-integration: test-setup
	@echo "Running Terratest integration tests..."
	@echo "WARNING: This will deploy real AWS resources and incur costs"
	@if [ ! -f "$(SSH_KEY)" ]; then echo "ERROR: SSH key not found: $(SSH_KEY). Run 'make keygen' first."; exit 1; fi
	@SUBNET=$$(grep '^subnet_id' $(EXAMPLE_DIR)/terraform.tfvars 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/'); \
	if [ -z "$$SUBNET" ]; then echo "ERROR: Set subnet_id in $(EXAMPLE_DIR)/terraform.tfvars. Run 'make setup' first."; exit 1; fi; \
	export TEST_SUBNET_ID=$$SUBNET; \
	cd test && go test -v -timeout 45m -run $(or $(RUN),TestRocky9FIPS)

test-all: test test-integration
	@echo "All tests passed"

test-setup:
	@echo "Setting up Terratest dependencies..."
	cd test && go mod tidy && go mod download

#=============================================================================
# Diagram generation
#=============================================================================

VENV_DIR = .venv

diagram: $(VENV_DIR)/bin/diagrams
	@echo "Generating architecture diagram..."
	cd docs && ../$(VENV_DIR)/bin/python generate-diagram.py
	@echo "Output: docs/architecture.png"

$(VENV_DIR)/bin/diagrams: $(VENV_DIR)/bin/pip
	$(VENV_DIR)/bin/pip install --quiet diagrams

$(VENV_DIR)/bin/pip:
	python3 -m venv $(VENV_DIR)
