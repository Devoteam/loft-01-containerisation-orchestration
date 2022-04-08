provider "aws" {
  region = var.region
  default_tags {
    tags = {
      automation = "terraform"
    }
  }
}
