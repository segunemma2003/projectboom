resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-subnet-group"
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.name_prefix}-redis"
  description                  = "Redis cluster for ${var.name_prefix}"

  node_type                    = var.node_type
  port                         = 6379
  parameter_group_name         = "default.redis7"

  num_cache_clusters           = var.num_cache_nodes
  automatic_failover_enabled   = var.num_cache_nodes > 1
  multi_az_enabled            = var.num_cache_nodes > 1

  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = var.security_group_ids

  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-cluster"
  })
}