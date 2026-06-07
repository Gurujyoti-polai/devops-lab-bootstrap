# ─────────────────────────────────────────────────────────────────────────────
# devops-lab-bootstrap — single entry point for all lab operations
# ─────────────────────────────────────────────────────────────────────────────

# Colours
GREEN  := \033[0;32m
RED    := \033[0;31m
YELLOW := \033[1;33m
NC     := \033[0m

# Directories
TOFU_DIR    := tofu
ANSIBLE_DIR := ansible

.PHONY: check cost fmt validate up down ssh ping clean

# ── check ────────────────────────────────────────────────────────────────────
# Verify all tools are installed and AWS credentials work
check:
	@echo -e "$(GREEN)► Running prerequisites check...$(NC)"
	@bash scripts/check_prereqs.sh

# ── cost ─────────────────────────────────────────────────────────────────────
# Show estimated hourly cost before applying
cost:
	@echo -e "$(GREEN)► Running cost estimate...$(NC)"
	@bash scripts/cost_estimate.sh

# ── fmt ──────────────────────────────────────────────────────────────────────
# Format all .tf files — run before every commit
fmt:
	@echo -e "$(GREEN)► Formatting OpenTofu files...$(NC)"
	@cd $(TOFU_DIR) && tofu fmt -recursive
	@echo -e "$(GREEN)✓ Done$(NC)"

# ── validate ─────────────────────────────────────────────────────────────────
# Syntax check + security scan — catches errors before they hit AWS
validate:
	@echo -e "$(GREEN)► Validating OpenTofu configuration...$(NC)"
	@cd $(TOFU_DIR) && tofu init -backend=false -input=false > /dev/null
	@cd $(TOFU_DIR) && tofu validate
	@echo -e "$(GREEN)► Running Checkov security scan...$(NC)"
	@checkov -d $(TOFU_DIR) --framework terraform \
		--skip-check CKV_AWS_130 --skip-check CKV2_AWS_11 --skip-check CKV2_AWS_12 \
		--quiet 2>/dev/null || true
	@echo -e "$(GREEN)✓ Validation complete$(NC)"

# ── up ───────────────────────────────────────────────────────────────────────
# Full spin-up: check → cost → validate → tofu apply → ansible bootstrap
up: check cost validate
	@echo -e "$(GREEN)► Initialising OpenTofu with remote backend...$(NC)"
	@cd $(TOFU_DIR) && tofu init -input=false
	@echo ""
	@echo -e "$(YELLOW)Ready to apply. This will create AWS resources.$(NC)"
	@echo -e "$(YELLOW)NAT Gateway will start billing immediately (~₹3.50/hr).$(NC)"
	@echo -e "$(YELLOW)Remember to run 'make down' when done.$(NC)"
	@echo ""
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo -e "$(GREEN)► Applying OpenTofu configuration...$(NC)"
	@cd $(TOFU_DIR) && tofu apply -auto-approve
	@echo -e "$(GREEN)► Waiting 30s for EC2 to boot...$(NC)"
	@sleep 30
	@echo -e "$(GREEN)► Running Ansible bootstrap playbook...$(NC)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/bootstrap.yml
	@echo ""
	@echo -e "$(GREEN)✓ Lab is up!$(NC)"
	@echo -e "$(GREEN)► SSH command:$(NC)"
	@cd $(TOFU_DIR) && tofu output ssh_command

# ── ssh ──────────────────────────────────────────────────────────────────────
# Open SSH session into the lab EC2
ssh:
	@echo -e "$(GREEN)► Connecting to lab instance...$(NC)"
	@cd $(TOFU_DIR) && eval $$(tofu output -raw ssh_command)

# ── ping ─────────────────────────────────────────────────────────────────────
# Verify Ansible can reach the instance
ping:
	@echo -e "$(GREEN)► Pinging lab instances via Ansible...$(NC)"
	@cd $(ANSIBLE_DIR) && ansible all -m ping

# ── down ─────────────────────────────────────────────────────────────────────
# Full teardown — destroys ALL AWS resources, stops billing
down:
	@echo ""
	@echo -e "$(RED)WARNING: This will destroy all lab resources.$(NC)"
	@echo -e "$(RED)All EC2 instances, VPC, NAT Gateway, and EIP will be deleted.$(NC)"
	@echo ""
	@read -p "Are you sure you want to destroy all lab resources? [y/N] " confirm \
		&& [ "$$confirm" = "y" ] || exit 1
	@echo -e "$(GREEN)► Destroying OpenTofu resources...$(NC)"
	@cd $(TOFU_DIR) && tofu destroy -auto-approve
	@echo ""
	@echo -e "$(GREEN)✓ Lab destroyed. No resources running. No charges accruing.$(NC)"

# ── clean ────────────────────────────────────────────────────────────────────
# Remove local OpenTofu cache — does NOT touch AWS resources
clean:
	@echo -e "$(YELLOW)► Cleaning local OpenTofu cache...$(NC)"
	@rm -rf $(TOFU_DIR)/.terraform
	@rm -rf $(TOFU_DIR)/.terraform.lock.hcl
	@rm -f  $(TOFU_DIR)/tofu.tfstate.backup
	@echo -e "$(GREEN)✓ Clean complete$(NC)"
