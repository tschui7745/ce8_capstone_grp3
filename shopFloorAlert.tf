locals {
  name_prefix = "chek" # provide your name prefix
}

##SES##

resource "aws_ses_email_identity" "source_alert_email" {
  email = "chekyeaw@gmail.com"
}

resource "aws_ses_email_identity" "delivery_alert_email" {
  email = "chekyeaw+ce8@gmail.com"
}

## shopFloorAlert Lambda Execution Role ##

resource "aws_iam_policy" "shopFloorAlert_lambda_policy" {
  name        = "shopFloorAlert_lambda_policy"
  path        = "/"
  description = "Policy to be attached to lambda"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "ses:*",
          "logs:*",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "shopFloorAlert_lambda_role" {
  name = "shopFloorAlert_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "shopFloorAlert_lambda_role_attach" {
  role       = aws_iam_role.shopFloorAlert_lambda_role.name
  policy_arn = aws_iam_policy.shopFloorAlert_lambda_policy.arn
}

## shopFloorAlert Lambda Function ##

data "archive_file" "lambdaalert" {
  type        = "zip"
  source_file = "${path.module}/lambdaAlert/sendAlertEmail/index.js"
  output_path = "sendAlertEmail.zip"
}

resource "aws_lambda_function" "send_alert_email" {
  function_name = "SendAlertEmail"
  role          = aws_iam_role.shopFloorAlert_lambda_role.arn
  runtime       = "nodejs16.x"
  filename      = "sendAlertEmail.zip"
  handler       = "index.handler"
  timeout       = "15"

  source_code_hash = data.archive_file.lambdaalert.output_base64sha256

}

##dynamodb##

resource "aws_dynamodb_table" "shop_floor_alerts" {
  name             = "shop_floor_alerts"
  billing_mode     = "PROVISIONED"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "PK"
  range_key        = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
}

resource "aws_lambda_event_source_mapping" "trigger" {
  batch_size        = 100
  event_source_arn  = aws_dynamodb_table.shop_floor_alerts.stream_arn
  function_name     = aws_lambda_function.send_alert_email.arn
  starting_position = "LATEST"
}