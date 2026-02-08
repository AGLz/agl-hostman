# Terraform Module Template: Outputs
# Define output values for the module

# Primary Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

# Internet Gateway Outputs

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

# Subnet Outputs - Public

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "List of availability zones for public subnets"
  value       = aws_subnet.public[*].availability_zone
}

# Subnet Outputs - Private

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "List of availability zones for private subnets"
  value       = aws_subnet.private[*].availability_zone
}

# Subnet Outputs - Database

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = length(aws_subnet.database) > 0 ? aws_subnet.database[*].id : []
}

output "database_subnet_cidrs" {
  description = "List of database subnet CIDR blocks"
  value       = length(aws_subnet.database) > 0 ? aws_subnet.database[*].cidr_block : []
}

output "database_subnet_availability_zones" {
  description = "List of availability zones for database subnets"
  value       = length(aws_subnet.database) > 0 ? aws_subnet.database[*].availability_zone : []
}

# Route Table Outputs - Public

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = [aws_route_table.public.id]
}

# Route Table Outputs - Private

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = var.enable_nat_gateway ? [aws_route_table.private[0].id] : []
}

# Route Table Outputs - Database

output "database_route_table_ids" {
  description = "List of database route table IDs"
  value       = var.num_database_subnets > 0 ? [aws_route_table.database[0].id] : []
}

# NAT Gateway Outputs

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[*].id : []
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

output "nat_gateway_allocation_ids" {
  description = "List of NAT Gateway allocation IDs"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].id : []
}

# VPC Endpoints Outputs

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

# Flow Logs Outputs

output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = var.enable_flow_log ? aws_flow_log.this[0].id : null
}

output "flow_log_iam_role_arn" {
  description = "ARN of the Flow Log IAM role"
  value       = var.enable_flow_log ? aws_iam_role.flow_log[0].arn : null
}

output "flow_log_cloudwatch_log_group_name" {
  description = "Name of the Flow Log CloudWatch log group"
  value       = var.enable_flow_log ? aws_cloudwatch_log_group.flow_log[0].name : null
}

# VPN Gateway Outputs

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = var.enable_vpn_gateway ? aws_vpn_gateway.this[0].id : null
}

# DHCP Options Outputs

output "dhcp_options_set_id" {
  description = "ID of the DHCP Options Set"
  value       = var.enable_dhcp_options ? aws_vpc_dhcp_options.this[0].id : null
}

# Computed Outputs

output "az_count" {
  description = "Number of availability zones used"
  value       = length(var.availability_zones)
}

output "max_subnets" {
  description = "Maximum number of subnets available in the VPC CIDR"
  value       = pow(2, 32 - split(".", var.cidr)[2] - var.newbits)
}

# Useful Combinations

output "this_vpc_config" {
  description = "VPC configuration object for use in other modules"
  value = {
    vpc_id              = aws_vpc.this.id
    vpc_cidr            = aws_vpc.this.cidr_block
    public_subnet_ids   = aws_subnet.public[*].id
    private_subnet_ids  = aws_subnet.private[*].id
    database_subnet_ids = length(aws_subnet.database) > 0 ? aws_subnet.database[*].id : []
  }
}

output "public_network_config" {
  description = "Public network configuration for load balancers"
  value = {
    vpc_id              = aws_vpc.this.id
    subnet_ids          = aws_subnet.public[*].id
    internet_gateway_id = aws_internet_gateway.this.id
  }
}

output "private_network_config" {
  description = "Private network configuration for application servers"
  value = {
    vpc_id         = aws_vpc.this.id
    subnet_ids     = aws_subnet.private[*].id
    nat_gateway_ids = var.enable_nat_gateway ? aws_nat_gateway.this[*].id : []
  }
}

output "database_network_config" {
  description = "Database network configuration for RDS instances"
  value = {
    vpc_id              = aws_vpc.this.id
    subnet_ids          = length(aws_subnet.database) > 0 ? aws_subnet.database[*].id : []
    route_table_ids     = var.num_database_subnets > 0 ? [aws_route_table.database[0].id] : []
  }
}

# Security Group Reference

output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_vpc.this.default_security_group_id
}
