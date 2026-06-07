
# Remote state stored in S3 — survives across sessions and machines

# DynamoDB table prevents simultaneous applies from corrupting state

terraform {

  backend "s3" {

    bucket = "devops-lab-tofu-state-278515800488"

    key = "lab/tofu.tfstate"

    region = "ap-south-1"

    encrypt = true

    dynamodb_table = "devops-lab-tofu-locks"

  }

}

