#=============================================================================
# IAM (conditional)
#=============================================================================

resource "aws_iam_instance_profile" "this" {
  count = local.use_instance_profile ? 1 : 0
  name  = "${var.name}-instance-profile"
  role  = aws_iam_role.this[count.index].name
  tags  = local.common_tags
}

resource "aws_iam_role" "this" {
  count = local.use_instance_profile ? 1 : 0
  name  = "${var.name}-role"
  tags  = local.common_tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach custom managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.aws_iam_policy_arns)
  role       = aws_iam_role.this[0].name
  policy_arn = var.aws_iam_policy_arns[count.index]
}

#=============================================================================
# SSM Session Manager (conditional)
#=============================================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
