# Terraform Module Template: Variables
# Define input variables for the module

# Required Variables

variable "name" {
  description = "Name of the VPC and associated resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "CIDR block must be valid."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone must be specified."
  }
}

# Optional Variables - Network Configuration

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "newbits" {
  description = "Number of additional bits for subnet CIDR (subnet size)"
  type        = number
  default     = 8

  validation {
    condition     = var.newbits > 0 && var.newbits < 32
    error_message = "newbits must be between 1 and 31."
  }
}

# Optional Variables - Subnet Configuration

variable "num_public_subnets" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.num_public_subnets > 0 && var.num_public_subnets <= 16
    error_message = "num_public_subnets must be between 1 and 16."
  }
}

variable "num_private_subnets" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.num_private_subnets >= 0 && var.num_private_subnets <= 16
    error_message = "num_private_subnets must be between 0 and 16."
  }
}

variable "num_database_subnets" {
  description = "Number of database subnets to create (0 to disable)"
  type        = number
  default     = 0

  validation {
    condition     = var.num_database_subnets >= 0 && var.num_database_subnets <= 16
    error_message = "num_database_subnets must be between 0 and 16."
  }
}

variable "public_subnet_offset" {
  description = "Starting offset for public subnets (0-indexed)"
  type        = number
  default     = 0
}

variable "private_subnet_offset" {
  description = "Starting offset for private subnets (0-indexed)"
  type        = number
  default     = 10
}

variable "database_subnet_offset" {
  description = "Starting offset for database subnets (0-indexed)"
  type        = number
  default     = 20
}

# Optional Variables - NAT Gateway

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "num_nat_gateways" {
  description = "Number of NAT Gateways (one per AZ recommended for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.num_nat_gateways > 0 && var.num_nat_gateways <= var.num_public_subnets
    error_message = "num_nat_gateways must be between 1 and num_public_subnets."
  }
}

# Optional Variables - Flow Logs

variable "enable_flow_log" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_log_traffic_type" {
  description = "Type of traffic to log (ACCEPT, REJECT, ALL)"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "flow_log_retention_days" {
  description = "Number of days to retain flow logs"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a valid CloudWatch retention period."
  }
}

# Optional Variables - VPC Endpoints

variable "enable_s3_endpoint" {
  description = "Enable VPC endpoint for S3"
  type        = bool
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "Enable VPC endpoint for DynamoDB"
  type        = bool
  default     = false
}

# Optional Variables - Tags

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for public subnets"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnets"
  type        = map(string)
  default     = {}
}

variable "database_subnet_tags" {
  description = "Additional tags for database subnets"
  type        = map(string)
  default     = {}
}

# Optional Variables - Secondary CIDR Blocks

variable "secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks to attach to VPC"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.secondary_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All secondary CIDR blocks must be valid."
  }
}

# Optional Variables - VPN Gateway

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "vpn_gateway_asn" {
  description = "ASN for VPN Gateway"
  type        = number
  default     = 64512
}

# Optional Variables - DHCP Options

variable "enable_dhcp_options" {
  description = "Enable custom DHCP options"
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "DNS domain name for DHCP options"
  type        = string
  default     = ""
}

variable "dhcp_options_domain_name_servers" {
  description = "List of DNS servers for DHCP options"
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_ntp_servers" {
  description = "List of NTP servers for DHCP options"
  type        = list(string)
  default     = null
}

variable "dhcp_options_netbios_name_servers" {
  description = "List of NetBIOS name servers for DHCP options"
  type        = list(string)
  default     = null
}

variable "dhcp_options_netbios_node_type" {
  description = "NetBIOS node type for DHCP options"
  type        = number
  default     = null

  validation {
    condition     = var.dhcp_options_netbios_node_type == null || (var.dhcp_options_netbios_node_type >= 1 && var.dhcp_options_netbios_node_type <= 8)
    error_message = "dhcp_options_netbios_node_type must be between 1 and 8."
  }
}
