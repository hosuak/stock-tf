# 다양한 서브넷(IPv4 및 IPv6) 길이를 계산하고 각 유형의 최대 길이를 찾습니다.
locals {
  len_public_subnets  = max(length(var.public_subnets), length(var.public_subnet_ipv6_prefixes))
  len_private_subnets = max(length(var.private_subnets), length(var.private_subnet_ipv6_prefixes))

  # 다양한 서브넷 유형(IPv4 및 IPv6) 중 최대 서브넷 길이를 찾습니다.
  max_subnet_length = max(
    local.len_private_subnets,
    local.len_public_subnets,
  )

  # 서브넷이 삭제되기 전에 보조 CIDR 블록이 해제되어야 함을 Terraform에 힌트로 전달하기 위해
  # IPv4 CIDR 블록 연관성을 기반으로 VPC ID를 찾습니다.
  vpc_id = try(aws_vpc.this[0].id, "")
  # vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  # 사용자 입력에 따라 VPC를 생성할지 여부를 결정합니다.
  create_vpc = var.create_vpc
}
################################################################################
# VPC
################################################################################
resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0 # default = true

  cidr_block          = var.use_ipam_pool ? null : var.cidr
  ipv4_ipam_pool_id   = var.ipv4_ipam_pool_id
  ipv4_netmask_length = var.ipv4_netmask_length

  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  #   enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags,
  )
}
resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}
################################################################################
# DHCP Options Set
################################################################################
resource "aws_vpc_dhcp_options" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  # DHCP 옵션 세트의 DNS 도메인 이름 설정
  domain_name = var.dhcp_options_domain_name
  # DHCP 옵션 세트의 DNS 서버 주소 목록
  domain_name_servers = var.dhcp_options_domain_name_servers
  # DHCP 옵션 세트의 NTP (Network Time Protocol) 서버 목록
  ntp_servers = var.dhcp_options_ntp_servers
  # DHCP 옵션 세트의 NetBIOS 이름 서버 목록
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  # DHCP 옵션 세트의 NetBIOS 노드 유형 설정
  netbios_node_type = var.dhcp_options_netbios_node_type

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.dhcp_options_tags,
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}
################################################################################
# Internet Gateway
################################################################################
resource "aws_internet_gateway" "this" {
  count = local.create_public_subnets && var.create_igw ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.igw_tags,
  )
}
################################################################################
# Publiс Subnets
################################################################################

locals {
  create_public_subnets = local.create_vpc && local.len_public_subnets > 0
}

resource "aws_subnet" "public" {
  count = local.create_public_subnets && (!var.one_nat_gateway_per_az || local.len_public_subnets >= length(var.azs)) ? local.len_public_subnets : 0

  availability_zone       = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block              = var.public_subnet_ipv6_native ? null : element(concat(var.public_subnets, [""]), count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch
  vpc_id                  = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.public_subnet_names[count.index],
        format("${var.name}-${var.public_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.public_subnet_tags,
    lookup(var.public_subnet_tags_per_az, element(var.azs, count.index), {})
  )
}

resource "aws_route_table" "public" {
  count = local.create_public_subnets ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${var.name}-${var.public_subnet_suffix}-rt" },
    var.tags,
    var.public_route_table_tags,
  )
}

resource "aws_route_table_association" "public" {
  count = local.create_public_subnets ? local.len_public_subnets : 0

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route" "public_internet_gateway" {
  count = local.create_public_subnets && var.create_igw ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}
################################################################################
# Private Subnets
################################################################################

locals {
  create_private_subnets = local.create_vpc && local.len_private_subnets > 0
}

resource "aws_subnet" "private" {
  count = local.create_private_subnets ? local.len_private_subnets : 0

  availability_zone = element(var.azs, count.index)
  cidr_block        = var.private_subnet_ipv6_native ? null : element(concat(var.private_subnets, [""]), count.index)
  vpc_id            = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.private_subnet_names[count.index],
        format("${var.name}-${var.private_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.private_subnet_tags,
    lookup(var.private_subnet_tags_per_az, element(var.azs, count.index), {})
  )
}

# # There are as many routing tables as the number of NAT gateways
# resource "aws_route_table" "private" {
#   count = local.create_private_subnets && local.max_subnet_length > 0 ? (var.single_nat_gateway ? local.nat_gateway_count : (var.single_nat_instance ? local.nat_instance_count : 0)) : 0

#   vpc_id = local.vpc_id

#   dynamic "route" {
#     for_each = var.enable_nat_instance ? [1] : []
#     content {
#       cidr_block = "0.0.0.0/0"

#       // Use primary_network_interface_id instead of primary_network_interface_ids
#       network_interface_id = count.index < length(aws_instance.nat_instance) ? aws_instance.nat_instance[count.index].primary_network_interface_id : aws_instance.nat_instance[0].primary_network_interface_id
#     }
#   }

#   tags = merge(
#     {
#       "Name" = var.single_nat_gateway || var.single_nat_instance ? "${var.name}-${var.private_subnet_suffix}" : format(
#         "${var.name}-${var.private_subnet_suffix}-%s",
#         element(var.azs, count.index),
#       )
#     },
#     var.tags,
#     var.private_route_table_tags
#   )
# }
resource "aws_route_table" "private" {
  count = local.create_private_subnets ? local.len_private_subnets : 0

  vpc_id = local.vpc_id

  dynamic "route" {
    for_each = var.enable_nat_instance ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"

      network_interface_id = count.index < length(aws_instance.nat_instance) ? aws_instance.nat_instance[count.index].primary_network_interface_id : aws_instance.nat_instance[0].primary_network_interface_id
    }
  }

  tags = merge(
    {
      "Name" = var.single_nat_gateway || var.single_nat_instance ? "${var.name}-${var.private_subnet_suffix}-rt" : format(
        "${var.name}-${var.private_subnet_suffix}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.private_route_table_tags
  )
}

# resource "aws_route_table_association" "private" {
#   count = local.create_private_subnets ? local.len_private_subnets : 0

#   subnet_id = element(aws_subnet.private[*].id, count.index)
#   route_table_id = element(
#     aws_route_table.private[*].id,
#     var.single_nat_gateway || var.single_nat_instance ? 0 : count.index,
#   )
# }

# aws_route_table_association.private 리소스를 간소화하여 각 private 서브넷에 해당하는 private 라우팅 테이블을 연결합니다.
resource "aws_route_table_association" "private" {
  for_each = local.create_private_subnets ? { for idx, subnet in aws_subnet.private : idx => subnet.id } : {}

  subnet_id      = each.value
  route_table_id = local.create_private_subnets ? aws_route_table.private[each.key].id : null
}
################################################################################
# NAT Gateway
################################################################################

locals {
  nat_gateway_count  = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length
  nat_gateway_ips    = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])
  nat_instance_count = var.single_nat_instance ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

}

resource "aws_eip" "nat" {
  count = local.create_vpc && var.enable_nat_gateway && !var.reuse_nat_ips ? local.nat_gateway_count : 0

  domain = "vpc"

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
    var.nat_eip_tags,
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(
    local.nat_gateway_ips,
    var.single_nat_gateway ? 0 : count.index,
  )
  subnet_id = element(
    aws_subnet.public[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
    var.nat_gateway_tags,
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  count = local.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}





