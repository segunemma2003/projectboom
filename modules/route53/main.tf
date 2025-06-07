resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hosted-zone"
  })
}

# Health checks for multi-region setup
resource "aws_route53_health_check" "primary" {
  count = var.enable_health_checks ? 1 : 0
  
  fqdn                            = var.primary_endpoint
  port                            = 443
  type                            = "HTTPS_STR_MATCH"
  resource_path                   = "/health/"
  failure_threshold               = "3"
  request_interval                = "30"
  search_string                  = "healthy"
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = "${var.name_prefix}-primary-health"
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-primary-health-check"
  })
}

resource "aws_route53_health_check" "secondary" {
  count = var.enable_health_checks && var.secondary_endpoint != "" ? 1 : 0
  
  fqdn                            = var.secondary_endpoint
  port                            = 443
  type                            = "HTTPS_STR_MATCH"
  resource_path                   = "/health/"
  failure_threshold               = "3"
  request_interval                = "30"
  search_string                  = "healthy"
  cloudwatch_alarm_region         = var.secondary_region
  cloudwatch_alarm_name           = "${var.name_prefix}-secondary-health"
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-secondary-health-check"
  })
}

# Failover records for high availability
resource "aws_route53_record" "primary" {
  count = var.enable_failover ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  set_identifier = "primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  health_check_id = var.enable_health_checks ? aws_route53_health_check.primary[0].id : null

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  count = var.enable_failover && var.secondary_alb_dns != "" ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  set_identifier = "secondary"
  
  failover_routing_policy {
    type = "SECONDARY"
  }
  
  health_check_id = var.enable_health_checks ? aws_route53_health_check.secondary[0].id : null

  alias {
    name                   = var.secondary_alb_dns
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }
}

# Geolocation routing for global distribution
resource "aws_route53_record" "geo_us" {
  count = var.enable_geo_routing ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  set_identifier = "us-east-1"
  
  geolocation_routing_policy {
    country = "US"
  }

  alias {
    name                   = var.us_alb_dns
    zone_id                = var.us_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "geo_eu" {
  count = var.enable_geo_routing ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  set_identifier = "eu-west-1"
  
  geolocation_routing_policy {
    continent = "EU"
  }

  alias {
    name                   = var.eu_alb_dns
    zone_id                = var.eu_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "geo_ap" {
  count = var.enable_geo_routing ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  set_identifier = "ap-southeast-1"
  
  geolocation_routing_policy {
    continent = "AS"
  }

  alias {
    name                   = var.ap_alb_dns
    zone_id                = var.ap_alb_zone_id
    evaluate_target_health = true
  }
}

# Default geo record for other locations
resource "aws_route53_record" "geo_default" {
  count = var.enable_geo_routing ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  set_identifier = "default"
  
  geolocation_routing_policy {
    country = "*"
  }

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}