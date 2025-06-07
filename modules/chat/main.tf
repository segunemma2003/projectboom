resource "aws_dynamodb_table" "chat_messages" {
  name           = "${var.name_prefix}-chat-messages"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "conversation_id"
  range_key      = "timestamp_message_id"

  attribute {
    name = "conversation_id"
    type = "S"
  }

  attribute {
    name = "timestamp_message_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "message_type"
    type = "S"
  }

  global_secondary_index {
    name            = "UserMessagesIndex"
    hash_key        = "user_id"
    range_key       = "timestamp_message_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "MessageTypeIndex"
    hash_key        = "conversation_id"
    range_key       = "message_type"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = var.enable_message_ttl
  }

  point_in_time_recovery {
    enabled = true
  }

  # FIXED: Remove kms_key_id completely for PAY_PER_REQUEST
  server_side_encryption {
    enabled = true
    # AWS automatically uses AWS-managed keys
    # NO kms_key_id attribute here!
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-chat-messages"
  })
}

# All other tables - same fix
resource "aws_dynamodb_table" "conversations" {
  name         = "${var.name_prefix}-conversations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "conversation_id"

  attribute {
    name = "conversation_id"
    type = "S"
  }

  attribute {
    name = "conversation_type"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "ConversationTypeIndex"
    hash_key        = "conversation_type"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  # FIXED: No kms_key_id
  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-conversations"
  })
}

resource "aws_dynamodb_table" "user_conversations" {
  name         = "${var.name_prefix}-user-conversations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "conversation_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "conversation_id"
    type = "S"
  }

  attribute {
    name = "last_read_timestamp"
    type = "S"
  }

  global_secondary_index {
    name            = "ConversationParticipantsIndex"
    hash_key        = "conversation_id"
    range_key       = "user_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "UnreadMessagesIndex"
    hash_key        = "user_id"
    range_key       = "last_read_timestamp"
    projection_type = "KEYS_ONLY"
  }

  point_in_time_recovery {
    enabled = true
  }

  # FIXED: No kms_key_id
  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-user-conversations"
  })
}

resource "aws_dynamodb_table" "user_presence" {
  name         = "${var.name_prefix}-user-presence"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # No encryption needed for presence data (not sensitive)
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-user-presence"
  })
}

# OPTIONAL: Keep KMS key for other services (Lambda, SNS, etc.)
resource "aws_kms_key" "chat_encryption" {
  description             = "KMS key for chat-related services (not DynamoDB)"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-chat-services-encryption"
  })
}

resource "aws_kms_alias" "chat_encryption" {
  name          = "alias/${var.name_prefix}-chat-services"
  target_key_id = aws_kms_key.chat_encryption.key_id
}