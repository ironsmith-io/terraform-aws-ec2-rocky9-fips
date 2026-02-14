#=============================================================================
# Elastic IP (conditional)
#=============================================================================

resource "aws_eip" "this" {
  count  = var.associate_elastic_ip ? 1 : 0
  domain = "vpc"
  tags   = local.common_tags
}

resource "aws_eip_association" "this" {
  count         = var.associate_elastic_ip ? 1 : 0
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this[0].id
}
