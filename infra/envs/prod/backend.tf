terraform {
  backend "s3" {
    bucket         = "ronaldo-auguste-tf-state"
    key            = "cloud-resume/prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "ronaldo-auguste-tf-lock"
    encrypt        = true
  }
}