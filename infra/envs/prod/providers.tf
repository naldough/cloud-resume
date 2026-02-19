provider "aws" {
  region  = "us-east-2"
  profile = "default"
}

provider "aws" {
  alias   = "use1"
  region  = "us-east-1"
  profile = "default"
}
