variable "prefix" { type = string }
variable "eks_cluster_name" { type = string }

variable "eks_node_group_name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_region" { type = string }
variable "cluster_version" { type = string }

variable "cluster_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster"
  type        = map(string)
  default = {}
}
variable "eks_subnet_ids_list" { type = list(string)}

variable "addons" {
  type = list(object({
    name    = string
    # version = string
  }))

  default = [
    {
      name    = "kube-proxy"
      # version = "v1.27.6-eksbuild.2"
    },
    {
      name    = "vpc-cni"
      # version = "v1.16.0-eksbuild.1"
    },
    {
      name    = "aws-ebs-csi-driver"
      # version = "v1.26.0-eksbuild.1"
    },
    {
      name    = "amazon-cloudwatch-observability"
      # version = "v1.2.1-eksbuild.1"
    },
    {
      name    = "coredns"
      # version = "v1.10.1-eksbuild.6"
    },
    {
      name    = "aws-mountpoint-s3-csi-driver"
      # version = "v1.1.0-eksbuild.1"
    },
    {
      name    = "aws-efs-csi-driver"
      # version = "v1.7.1-eksbuild.1"
    }
  ]
}


