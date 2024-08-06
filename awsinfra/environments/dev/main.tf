provider "aws" {
  alias   = "remote"
  region  = "eu-west-2"
  profile = "pocawsadmin"
}

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "remote-state-bucket-024848458616"
    dynamodb_table = "tf-state-lock-dynamo"
    key            = "dev-terraform.tfstate"
    region         = "eu-west-2"
    profile        = "pocawsadmin"
  }
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~>5.0"
      configuration_aliases = [aws.remote]
    }
  }

  required_version = "~>1.6"

}

locals {
  remote_account_id          = "024848458616"
  prefix                     = "dev"
  aws_region                 = "eu-west-2"
  eks_cluster_name           = "${local.prefix}-eksCluster"
  eks_cluster_version        = "1.28"
  eks_worker_node_group_name = "eksWorkerNodeGroup"
}

module "v3networkmodule" {
  source = "../../modules/network"

  providers = { aws = aws.remote }

  prefix         = local.prefix
  vpc_cidr_range = "20.10.0.0/16"


  private_subnet_info = {
    privatesubnet1 = {
      cidr_range = "20.10.1.0/24"
      az         = "eu-west-2b"
      public_ip  = false
      tags = {
        "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
        "kubernetes.io/role/internal-elb"                 = 1
        "Name"                                            = "privsub1b"
      }
    }

    privatesubnet2 = {
      cidr_range = "20.10.3.0/24"
      az         = "eu-west-2c"
      public_ip  = false
      tags = {
        "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
        "kubernetes.io/role/internal-elb"                 = 1
        "Name"                                            = "privsub1c"
      }
    }
  }

  public_subnet_info = {

    publicsubnet1 = {
      cidr_range = "20.10.0.0/24"
      az         = "eu-west-2b"
      public_ip  = true

      tags = {
        "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
        "kubernetes.io/role/elb"                          = 1
        "Name"                                            = "pubsub1b"
      }
    }

    publicsubnet2 = {
      cidr_range = "20.10.2.0/24"
      az         = "eu-west-2c"
      public_ip  = true
      tags = {
        "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
        "kubernetes.io/role/elb"                          = 1
        "Name"                                            = "pubsub1c"
      }
    }
  }

  natgateway_public_subnet_name = "publicsubnet1"

}

module "v3eksmodule" {
  source              = "../../modules/eks"
  prefix              = local.prefix
  eks_cluster_name    = local.eks_cluster_name
  eks_node_group_name = local.eks_worker_node_group_name
  cluster_version     = local.eks_cluster_version
  vpc_region          = local.aws_region

  providers = { aws = aws.remote }

  vpc_id = module.v3networkmodule.vpc_id
  eks_subnet_ids_list = [
    module.v3networkmodule.private_subnet_ids["privatesubnet1"],
    module.v3networkmodule.private_subnet_ids["privatesubnet2"]
  ]
}
