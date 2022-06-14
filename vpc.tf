#VPC Creation
resource "aws_vpc" "ge_digital_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  tags                 = "${merge(map("Name",var.vpc_name),var.tags)}"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = false
  enable_classiclink   = false
}

#Public subnet (This will create 2 public subnet in two diffrent zone)
resource "aws_subnet" "public_subnet" {
  count                   = "${length(var.aws_zones)}"
  vpc_id                  = "${aws_vpc.ge_digital_vpc.id}"
  cidr_block              = "${cidrsubnet(var.vpc_cidr, 8, count.index)}"
  availability_zone       = "${var.aws_zones[count.index]}"
  map_public_ip_on_launch = true
  tags                    = "${merge(map("Name", format("%v-public-%v", var.vpc_name, var.aws_zones[count.index])), var.tags)}"
}

#Intenet gateway
resource "aws_internet_gateway" "ge_digital_ig" {
  vpc_id = "${aws_vpc.ge_digital_vpc.id}"
  tags   = "${merge(map("Name",var.ig_name),var.tags)}"
}

# Route Table  (public subnets)
resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.ge_digital_vpc.id}"

  # Default route through Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ge_digital_ig.id}"
  }

  tags = "${merge(map("Name", format("%v-public-route-table", var.vpc_name)), var.tags)}"
}

# Route  Table Association  public
resource "aws_route_table_association" "route" {
  count          = "${length(var.aws_zones)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_route.id}"
}

#Private subnet (This will create 2 private subnet in two diffrent zone)
resource "aws_subnet" "private_subnet" {
  count                   = "${length(var.aws_zones)}"
  vpc_id                  = "${aws_vpc.ge_digital_vpc.id}"
  cidr_block              = "${cidrsubnet(var.vpc_cidr, 8, count.index + length(var.aws_zones))}"
  availability_zone       = "${var.aws_zones[count.index]}"
  map_public_ip_on_launch = false
  tags                    = "${merge(map("Name", format("%v-private-%v", var.vpc_name, var.aws_zones[count.index])), var.tags)}"
}

#EIP for Nat Gateway
resource "aws_eip" "nat" {
  count = 1
  vpc   = true

  tags {
    Name = "ge_digital_eip"
  }
}

#NAT Gateway creation  for private subnet
resource "aws_nat_gateway" "nat" {
  count         = 1
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnet.0.id}"
  depends_on    = ["aws_eip.nat", "aws_internet_gateway.ge_digital_ig", "aws_subnet.public_subnet"]

  tags {
    Name = "ge_digital_nat_gateway"
  }
}

#Route Table  (private subnets)
resource "aws_route_table" "private_route" {
  count  = "1"
  vpc_id = "${aws_vpc.ge_digital_vpc.id}"

  # Default route through NAT
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags = "${merge(map("Name", format("%v-private-route-table-%v", var.vpc_name, var.aws_zones[count.index])), var.tags)}"
}

# Route  Table Association  private
resource "aws_route_table_association" "private_route" {
  count          = "${length(var.aws_zones)}"
  subnet_id      = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_route.*.id, count.index)}"
}

#NACL for public subnet - default nacl
resource "aws_default_network_acl" "public_nacl" {
  default_network_acl_id = "${aws_vpc.ge_digital_vpc.default_network_acl_id}"
  subnet_ids             = ["${aws_subnet.public_subnet.*.id}"]

  tags {
    Name = "ge_digital_default_nacl"
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

#NACL for private subnet
resource "aws_network_acl" "private_nacl" {
  vpc_id     = "${aws_vpc.ge_digital_vpc.id}"
  subnet_ids = ["${aws_subnet.private_subnet.*.id}"]

  tags {
    Name = "ge_digital_private_nacl"
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 8080
    to_port    = 8080
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

#Security group Public
resource "aws_security_group" "public_SG" {
  name        = "ge_digital_public_SG"
  description = "Allow SSH and TCP 80 inbound traffic"
  vpc_id      = "${aws_vpc.ge_digital_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ge_digital_public_SG"
  }
}

#Security group Private
resource "aws_security_group" "private_SG" {
  name        = "ge_digital_private_SG"
  description = "Allow all 8080 inbound traffic"
  vpc_id      = "${aws_vpc.ge_digital_vpc.id}"

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    self      = false

    #  security_groups = ["${aws_security_group.internal-sg-lb.id}"]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = false

    #  security_groups = ["${aws_security_group.public_SG.id}"]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ge_digital_private_SG"
  }
}

#Security Group for External ELB
resource "aws_security_group" "external-lb" {
  name        = "external_SG"
  description = "SG for External load blancer"
  vpc_id      = "${aws_vpc.ge_digital_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    #    security_groups = ["${aws_security_group.sg-public.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#FLOWLOG
resource "aws_flow_log" "vpc_flow_log" {
  log_group_name = "${var.cloudwatch_group_name}"
  iam_role_arn   = "${var.vpc_flowlog_arn}"
  vpc_id         = "${aws_vpc.ge_digital_vpc.id}"
  traffic_type   = "ALL"
}

#Customer Gateway
resource "aws_customer_gateway" "main" {
  bgp_asn    = 65000
  ip_address = "172.83.124.10"
  type       = "ipsec.1"

  tags {
    Name = "main-customer-gateway"
  }
}

#Outputs
output "vpc_id" {
  description = "ID of Vpc"
  value       = "${aws_vpc.ge_digital_vpc.id}"
}

output "vpc_CIDR" {
  description = "ID of Vpc"
  value       = "${aws_vpc.ge_digital_vpc.cidr_block}"
}

output "public_subnet_ids" {
  description = "List with IDs of the public subnets"
  value       = "${aws_subnet.public_subnet.*.id}"
}

output "private_subnet_ids" {
  description = "List with IDs of the private subnets"
  value       = "${aws_subnet.private_subnet.*.id}"
}

output "private_security_group_id" {
  description = "Public security Group Id"
  value       = "${aws_security_group.private_SG.id}"
}

output "public_security_group_id" {
  description = "Public security Group Id"
  value       = "${aws_security_group.public_SG.id}"
}

output "elb_security_group_id" {
  description = "ELB security Group Id"
  value       = "${aws_security_group.external-lb.*.id}"
}

output "private_security_list_id" {
  description = "Public security Group Id"
  value       = "${aws_security_group.private_SG.*.id}"
}

output "public_security_list_id" {
  description = "Public security Group Id"
  value       = "${aws_security_group.public_SG.*.id}"
}

output "public_route_table_ids" {
  description = "Public Route Table Ids"
  value       = "${aws_route_table.public_route.*.id}"
}

output "private_route_table_ids" {
  description = "Private Route Table Ids"
  value       = "${aws_route_table.private_route.*.id}"
}

output "private_route_table_id" {
  description = "Private Route Table Ids"
  value       = "${aws_route_table.private_route.id}"
}
