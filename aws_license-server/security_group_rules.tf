## Security groups for the license server
# Ingress - inbound ICMP
resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_3_master" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = format("%s/32", element(data.dns_a_record_set.master.addrs, 0))
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_4_master" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = format("%s/32", element(data.dns_a_record_set.master.addrs, 0))
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_3" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_4" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

# Egress - outbound ICMP
resource "aws_vpc_security_group_egress_rule" "outbound_icmp_3_master" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = format("%s/32", element(data.dns_a_record_set.master.addrs, 0))
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_egress_rule" "outbound_icmp_4_master" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = format("%s/32", element(data.dns_a_record_set.master.addrs, 0))
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

resource "aws_vpc_security_group_egress_rule" "outbound_icmp_3" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_egress_rule" "outbound_icmp_4" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

# Ingress - inbound TCP from the VPC's CIDR
resource "aws_vpc_security_group_ingress_rule" "inbound_tcp" {
  security_group_id = aws_security_group.sentieon_license_server.id

  from_port   = 8990
  to_port     = 8990
  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "tcp"
}

# Egress - https
resource "aws_vpc_security_group_egress_rule" "outbound_https_all" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# Egress - http
resource "aws_vpc_security_group_egress_rule" "outbound_http_all" {
  security_group_id = aws_security_group.sentieon_license_server.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}


## Security groups for the compute nodes
# Ingress - inbound ssh
resource "aws_vpc_security_group_ingress_rule" "inbound_ssh_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "inbound_ssh_v6_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv6   = "::/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

# Ingress - inbound ICMP
resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_compute_3" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_ingress_rule" "inbound_icmp_compute_4" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

# Egress - outbound ICMP
resource "aws_vpc_security_group_egress_rule" "outbound_icmp_compute_3" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "icmp"
  from_port   = 3
  to_port     = -1
}

resource "aws_vpc_security_group_egress_rule" "outbound_icmp_compute_4" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "icmp"
  from_port   = 4
  to_port     = -1
}

# Egress - ssh
resource "aws_vpc_security_group_egress_rule" "outbound_ssh_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "outbound_ssh_v6_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv6   = "::/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

# Egress - outbound TCP to the VPC's CIDR
resource "aws_vpc_security_group_egress_rule" "outbound_tcp_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  from_port   = 8990
  to_port     = 8990
  cidr_ipv4   = data.aws_vpc.default.cidr_block
  ip_protocol = "tcp"
}

# Egress - https
resource "aws_vpc_security_group_egress_rule" "outbound_https_all_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# Egress - http
resource "aws_vpc_security_group_egress_rule" "outbound_http_all_compute" {
  security_group_id = aws_security_group.sentieon_compute_nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}
