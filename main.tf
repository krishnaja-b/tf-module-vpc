resource "aws_vpc" "main" {
   cidr_block = var.vpc_cidr
   tags = merge(
    var.tags,
    { Name = "${var.env}-vpc" }
  )
}
# peering connection
resource "aws_vpc_peering_connection" "peer" {
  peer_owner_id = data.aws_caller_identity.account.account_id
  peer_vpc_id   = var.default_vpc_id
  vpc_id        = aws_vpc.main.id
  auto_accept = true
  tags = merge(
    var.tags,
    { Name = "${var.env}-peer" }
  )
}

# public subnets
resource "aws_subnet" "public_subnets" {
  for_each = var.public_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]
  availability_zone = each.value["availability_zone"]
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
}
# public route table
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
  for_each = var.public_subnets
}
# attach igw to public route table

route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
# adding peering in public route table
route {
  cidr_block = data.aws_vpc.default_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}


# internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
  for_each = var.public_subnets
}

# natgate way
resource "aws_eip" "nat" {
  for_each = var.public_subnets
  vpc = true
}
resource "aws_nat_gateway" "nat-gateways" {
  for_each =  var.public_subnets
  allocation_id = aws_eip.nat.each.value["name"].id
  subnet_id     = aws_subnet.public_subnets.each.value["name"].id
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
}




#associate route table
resource "aws_route_table_association" "public-association" {
  for_each = var.public_subnets
  subnet_id      =lookup(lookup(aws_subnet.public_subnets,each.value["name"],null),"id",null)
  route_table_id = aws_route_table.public-route-table[each.value["name"]].id
}

# private subnets

resource "aws_subnet" "private_subnets" {
  for_each = var.private_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]
  availability_zone = each.value["availability_zone"]
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
}
# private route table
resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
  for_each = var.private_subnets
}
# attach natgateway to private route table

route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
# adding peering in private route table
route {
  cidr_block = data.aws_vpc.default_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

#associate route table
resource "aws_route_table_association" "private-association" {
  for_each = var.private_subnets
  subnet_id      =lookup(lookup(aws_subnet.private_subnets,each.value["name"],null),"id",null)
  route_table_id = aws_route_table.private-route-table[each.value["name"]].id
}
# adding peering in the default route table

resource "aws_route" "route" {
  route_table_id = var.default_route_table
  destination_cidr_block = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}
















