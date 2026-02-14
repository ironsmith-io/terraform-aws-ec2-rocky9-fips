plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
