# Terraform Module Template: Main Configuration
# This module demonstrates best practices for reusable Terraform components

# Resource: VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # Assign assigned tags
  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

# Resource: Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

# Resource: Public Subnets
resource "aws_subnet" "public" {
  count                   = var.num_public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, var.newbits, count.index + var.public_subnet_offset)
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.name}-public-${count.index + 1}"
      Type = "public"
    },
    var.tags
  )
}

# Resource: Private Subnets
resource "aws_subnet" "private" {
  count                   = var.num_private_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, var.newbits, count.index + var.private_subnet_offset)
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(
    {
      Name = "${var.name}-private-${count.index + 1}"
      Type = "private"
    },
    var.tags
  )
}

# Resource: Database Subnets (optional)
resource "aws_subnet" "database" {
  count = var.num_database_subnets > 0 ? var.num_database_subnets : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, var.newbits, count.index + var.database_subnet_offset)
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(
    {
      Name = "${var.name}-database-${count.index + 1}"
      Type = "database"
    },
    var.tags
  )
}

# Resource: NAT Gateway (optional)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? var.num_nat_gateways : 0

  domain = "vpc"

  tags = merge(
    {
      Name = "${var.name}-nat-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? var.num_nat_gateways : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index % length(aws_subnet.public)].id

  tags = merge(
    {
      Name = "${var.name}-nat-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

# Resource: Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    {
      Name = "${var.name}-public"
    },
    var.tags
  )
}

# Resource: Private Route Table
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }

  tags = merge(
    {
      Name = "${var.name}-private"
    },
    var.tags
  )
}

# Resource: Database Route Table (optional)
resource "aws_route_table" "database" {
  count = var.num_database_subnets > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${var.name}-database"
    },
    var.tags
  )
}

# Resource: Public Route Table Association
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Resource: Private Route Table Association
resource "aws_route_table_association" "private" {
  count = var.enable_nat_gateway ? length(aws_subnet.private) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# Resource: Database Route Table Association (optional)
resource "aws_route_table_association" "database" {
  count = var.num_database_subnets > 0 ? length(aws_subnet.database) : 0

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# Resource: VPC Flow Logs (optional)
resource "aws_flow_log" "this" {
  count = var.enable_flow_log ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = aws_vpc.this.id
}

# Resource: Flow Log IAM Role
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name = "${var.name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# Resource: Flow Log IAM Policy
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name = "${var.name}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Resource: Flow Log CloudWatch Log Group
resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name              = "${var.name}-vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = var.tags
}

# Resource: VPC Endpoint for S3 (optional)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  tags = merge(
    {
      Name = "${var.name}-s3"
    },
    var.tags
  )
}

# Resource: S3 VPC Endpoint Route Table Association
resource "aws_vpc_endpoint_route_table_association" "s3" {
  count = var.enable_s3_endpoint ? length(aws_route_table.private) : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.private[0].id
}

# Data Source: Current Region
data "aws_region" "current" {}

# Data Source: Current Account
data "aws_caller_identity" "current" {}
