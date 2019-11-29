#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name       = "devops-training-cluster"
    CostCenter = "ACD"
    Owner      = ""
  }
}

resource "aws_subnet" "demo1" {

  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block        = "10.0.0.0/17"
  vpc_id            = "${aws_vpc.demo.id}"

  tags = {
    Name       = "devops-training-cluster"
    CostCenter = "ACD"
    Owner      = ""
  }
}

resource "aws_subnet" "demo2" {

  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  cidr_block        = "10.0.128.0/17"
  vpc_id            = "${aws_vpc.demo.id}"

  tags = {
    Name       = "devops-training-cluster"
    CostCenter = "ACD"
    Owner      = ""
  }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = "${aws_vpc.demo.id}"

  tags = {
    Name       = "devops-training-cluster"
    CostCenter = "ACD"
    Owner      = ""
  }
}

resource "aws_route_table" "demo" {
  vpc_id = "${aws_vpc.demo.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.demo.id}"
  }
}

resource "aws_route_table_association" "demo1" {

  subnet_id      = "${aws_subnet.demo1.id}"
  route_table_id = "${aws_route_table.demo.id}"
}


resource "aws_route_table_association" "demo2" {

  subnet_id      = "${aws_subnet.demo2.id}"
  route_table_id = "${aws_route_table.demo.id}"
}
