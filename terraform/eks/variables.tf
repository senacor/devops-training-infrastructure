#
# Variables Configuration
#

variable "resource-prefix" {
  # Insert your unique prefix here (e.g. initials or CWID)
  default = "tg"
  type    = string
}

variable "owner" {
  default = ""
  type    = "string"
}

variable "workstation-external-ip" {
  # Insert the IP of your workstation here
  default = "127.0.0.1"
  type    = "string"
}

resource "random_id" "prefix" {
  byte_length = 4
}

locals {
  resource_prefix = var.resource-prefix != "" ? var.resource-prefix : random_id.prefix.hex
}

data "aws_vpcs" "main" {
  tags = {
    Name = "devops-training-cluster"
  }
}

data "aws_subnet_ids" "subnets" {
  vpc_id = tolist(data.aws_vpcs.main.ids)[0]
}

# Override with variable or hardcoded value if necessary
locals {
  workstation-external-cidr = "${chomp(var.workstation-external-ip)}/32"
}
