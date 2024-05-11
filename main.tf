provider "aws" {
  region = "us-east-1"

}

data "archive_file" "lambda_autotag" {
  type        = "zip"
  source_dir  = "${path.module}/code"
  output_path = "${path.module}/code/lambda_package.zip"
}


module "start_stop" {
  source        = "./modules/start_stop"
  instances_ids = var.instances_ids
  lambda_zip_file_path = data.archive_file.lambda_autotag

}