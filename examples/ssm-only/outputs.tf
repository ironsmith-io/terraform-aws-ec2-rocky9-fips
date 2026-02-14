output "instance_id" {
  value = module.rocky9_fips.instance_id
}

output "private_ip" {
  value = module.rocky9_fips.private_ip
}

output "ami_id" {
  value = module.rocky9_fips.ami_id
}

output "iam_role_arn" {
  value = module.rocky9_fips.iam_role_arn
}
