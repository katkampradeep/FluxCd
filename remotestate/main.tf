provider "aws" {
  region = "eu-west-2"
  profile = "pocawsadmin"
}

data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  account_id           = data.aws_caller_identity.this.account_id
  region               = data.aws_region.this.name
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "tf-state-lock-dynamo"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
 
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket" "this" {
  bucket = "remote-state-bucket-${local.account_id}"

}
