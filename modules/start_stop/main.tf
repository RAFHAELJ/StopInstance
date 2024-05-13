data "aws_caller_identity" "current" {}


###### EVENT BRIDGE ######
resource "aws_cloudwatch_event_rule" "stop_instances" {
  name                = "StopInstance"
  description         = "Stop instances every day at midnight"
  schedule_expression = "cron(0 0 * * ? *)" # Executar à meia-noite todos os dias
}

resource "aws_cloudwatch_event_target" "invoke_lambda_stop" {
  depends_on = [aws_lambda_function.autotag]
  rule       = aws_cloudwatch_event_rule.stop_instances.name
  target_id  = "InvokeLambdaStop"

  arn = aws_lambda_function.autotag.arn

  input = jsonencode({
    "instances" : var.instances_ids,
    "action" : "Stop"
  })
}

resource "aws_cloudwatch_event_rule" "start_instances" {
  name                = "StartInstance"
  description         = "Start instances every day at 6 AM"
  schedule_expression = "cron(0 6 * * ? *)" # Executar às 6 da manhã todos os dias
}

resource "aws_cloudwatch_event_target" "invoke_lambda_start" {
  depends_on = [aws_lambda_function.autotag]
  rule       = aws_cloudwatch_event_rule.start_instances.name
  target_id  = "InvokeLambdaStart"

  arn = aws_lambda_function.autotag.arn

  input = jsonencode({
    "instances" : var.instances_ids,
    "action" : "Start"
  })
}

###### ROLES IN POLICIES' ######
resource "aws_iam_role" "scheduler_role" {
  name = "EventBridgeSchedulerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_policy" {
  name = "EventBridgeInvokeLambdaPolicy"
  role = aws_iam_role.scheduler_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEventBridgeToInvokeLambda",
        "Action" : [
          "lambda:InvokeAsync",
          "lambda:InvokeFunction"

        ],
        "Effect" : "Allow",
        "Resource" : aws_lambda_function.autotag.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_stop_instance_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

  depends_on = [aws_iam_role_policy.lambda_logs_policy]
}
resource "aws_iam_role_policy" "lambda_instance_actions_policy" {
  name   = "LambdaInstanceActionsPolicy"
  role   = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowStartStopInstance"
        Effect    = "Allow",
        Action    = [
          "ec2:StartInstances",
          "ec2:StopInstances",
        ],
        Resource  = "*"
      }
    ]
  })
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs_policy" {
  name = "PublishLogsPolicy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowLambdaFunctionToCreateLogs",
        "Action" : [
          "logs:*"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.autotag.function_name}:*" # Corrigido para referenciar a função Lambda autotag
        ]
      }
    ]
  })
}

###### LAMBDA FUNCTION ######
resource "aws_lambda_function" "autotag" {
  function_name    = "lambda_function"
  role             = aws_iam_role.iam_for_lambda.arn
  filename         = var.lambda_zip_file_path.output_path 
  source_code_hash = var.lambda_zip_file_path.output_base64sha256
  description      = "stop instances and five minutes"
  publish          = true

  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 300
  memory_size   = 128
  architectures = ["arm64"]


}
