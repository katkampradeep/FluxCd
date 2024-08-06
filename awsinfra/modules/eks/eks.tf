terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws]
    }
  }
}

################################################################
# Eks Role Creation
################################################################
resource "aws_iam_policy" "eks_cluster_policy" {
  name        = "${var.eks_cluster_name}-eks-cluster-policy"
  description = "IAM policy created for the given eks cluster"

  policy = file("${path.module}/policies/eks-cluster-policy.json")
}
resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.eks_cluster_name}-eks-cluster-role"
  assume_role_policy = file("${path.module}/policies/eks-trust-policy.json")

  tags = { Name = "${var.eks_cluster_name}-eksClusterRole" }
}

resource "aws_iam_policy_attachment" "v3_eks_cluster_policy_attachment" {
  name       = "${var.eks_cluster_name}-eks-cluster-policy-attachment"
  policy_arn = aws_iam_policy.eks_cluster_policy.arn
  roles      = [aws_iam_role.eks_cluster_role.name]
  depends_on = [aws_iam_role.eks_cluster_role, aws_iam_policy.eks_cluster_policy]
}

#################################################################
## Eks Security Group Creation
#################################################################
resource "aws_security_group" "eks_public_sg" {
  name        = "${var.eks_cluster_name}-eks-public-sg"
  description = "eks security group - public subnet"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = jsondecode(file("${path.module}/SecurityGroupRules/eks-public-inbound-rules.json"))

    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      description      = ingress.value.description
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = jsondecode(file("${path.module}/SecurityGroupRules/eks-public-outbound-rules.json"))

    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      description      = egress.value.description
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }

  tags = { Name = "${var.eks_cluster_name}-eks-public-sg" }

}

resource "aws_security_group" "eks_cluster_public_sg" {
  name        = "${var.eks_cluster_name}-eks-private-sg"
  description = "eks security group - cluster subnet"
  vpc_id      = var.vpc_id

  dynamic "egress" {
    for_each = jsondecode(file("${path.module}/SecurityGroupRules/eks-cluster-outbound-rules.json"))

    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      description      = egress.value.description
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }

  tags = { Name = "${var.eks_cluster_name}-eks-private-sg" }

}

resource "aws_security_group_rule" "public_ec2_to_eks" {
  description              = "Allowing Traffic from public to cluster"
  security_group_id        = aws_security_group.eks_cluster_public_sg.id
  source_security_group_id = aws_security_group.eks_public_sg.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  type                     = "ingress"

  depends_on = [aws_security_group.eks_public_sg, aws_security_group.eks_cluster_public_sg]
}
#################################################################
## Eks Cluster Creation
#################################################################
# Create the EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster_public_sg.id]
    subnet_ids              = var.eks_subnet_ids_list
    endpoint_private_access = true
  }

  timeouts {
    create = lookup(var.cluster_timeouts, "create", null)
    update = lookup(var.cluster_timeouts, "update", null)
    delete = lookup(var.cluster_timeouts, "delete", null)
  }

  depends_on = [aws_iam_role.eks_cluster_role]
}

resource "aws_ssm_parameter" "eks_cluster_ssm_parameter" {
  name       = "/v3/eks-cluster/name"
  type       = "String"
  value      = aws_eks_cluster.eks_cluster.name
  depends_on = [aws_eks_cluster.eks_cluster]
}
#################################################################
## Eks Cluster Node Key Creation
#################################################################
resource "tls_private_key" "eks_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "eks_key" {
  content  = tls_private_key.eks_rsa.private_key_pem
  filename = "${path.module}/NodeGroupKeys/eks-key-pair.pem"

  depends_on = [tls_private_key.eks_rsa]
}

resource "aws_key_pair" "v3_eks_key_pair" {
  key_name   = "${var.eks_cluster_name}-eks-key-pair"
  public_key = tls_private_key.eks_rsa.public_key_openssh

  tags = { Name = "${var.eks_cluster_name}-eks-key-pair" }

  depends_on = [tls_private_key.eks_rsa]
}
#################################################################
## Eks Cluster Node Group Creation
#################################################################
resource "aws_iam_role" "eks_node_group_role" {
  name               = "${var.eks_cluster_name}-eks-nodegroup-role"
  assume_role_policy = file("${path.module}/policies/eks-node-group-trust-policy.json")
}

resource "aws_iam_policy" "eks_node_group_container_read_only_policy" {
  name        = "${var.eks_node_group_name}-ec2-container-read-only-policy"
  description = "Provides read-only access to Amazon EC2 Container Registry repositories."

  policy = file("${path.module}/policies/ec2-container-read-only-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_group_role_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_container_read_only_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_cloud_watch_agent_server_policy" {
  name        = "${var.eks_node_group_name}-eks-cloud-watch-agent-server-policy"
  description = "Permissions required to use AmazonCloudWatchAgent on servers"

  policy = file("${path.module}/policies/eks-cloud-watch-agent-server-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_cloud_watch_agent_server_policy_attachment" {
  policy_arn = aws_iam_policy.eks_cloud_watch_agent_server_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_xray_write_only_access_policy" {
  name        = "${var.eks_node_group_name}-eks-xray-write-only-access-policy"
  description = "AWS X-Ray write only managed policy."

  policy = file("${path.module}/policies/eks-xray-write-only-access-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_xray_write_only_access_policy_attachment" {
  policy_arn = aws_iam_policy.eks_xray_write_only_access_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_node_group_cni_policy" {
  name        = "${var.eks_node_group_name}-eks-cni-policy"
  description = "This policy provides the Amazon VPC CNI Plugin (amazon-vpc-cni-k8s) the permissions it requires to modify the IP address configuration on your EKS worker nodes. This permission set allows the CNI to list, describe, and modify Elastic Network Interfaces on your behalf."

  policy = file("${path.module}/policies/eks-cni-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_group_cni_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_cni_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_node_group_eks_worker_policy" {
  name        = "${var.eks_node_group_name}-eks-worker-node-policy"
  description = "This policy allows Amazon EKS worker nodes to connect to Amazon EKS Clusters."

  policy = file("${path.module}/policies/eks-worker-node-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_node_group_worker_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_eks_worker_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_node_group_ssm_policy" {
  name        = "${var.eks_node_group_name}-ssm-managed-core-instance-policy"
  description = "The policy for Amazon EC2 Role to enable AWS Systems Manager service core functionality."

  policy = file("${path.module}/policies/ssm-managed-core-instance-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_group_ssm_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_ssm_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_role.eks_node_group_role]
}

resource "aws_iam_policy" "eks_node_group_ec2_full_access_policy" {
  name        = "${var.eks_node_group_name}-ec2-full-access-policy"
  description = "Provides full access to Amazon EC2 via the AWS Management Console."

  policy = file("${path.module}/policies/ec2-full-access-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_group_ec2_full_access_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_ec2_full_access_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_policy.eks_node_group_ec2_full_access_policy]
}

resource "aws_iam_policy" "eks_node_group_ebscsi_driver_policy" {
  name        = "${var.eks_node_group_name}-ebs-csi-driver-policy"
  description = "IAM Policy that allows the CSI driver service account to make calls to related services such as EC2 on your behalf."

  policy = file("${path.module}/policies/ebs-csi-driver-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_node_group_ebscsi_driver_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_group_ebscsi_driver_policy.arn
  role       = aws_iam_role.eks_node_group_role.name

  depends_on = [aws_iam_policy.eks_node_group_ebscsi_driver_policy]
}

resource "aws_iam_instance_profile" "eks_node_group_instance_profile" {
  name = "${var.eks_cluster_name}-node-group-instance-profile"
  role = aws_iam_role.eks_node_group_role.name

  depends_on = [ aws_iam_role.eks_node_group_role ]
}


resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.eks_cluster_name}-${var.eks_node_group_name}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = var.eks_subnet_ids_list

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.large"]
  disk_size      = 20

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "${var.eks_cluster_name}-eks-general"
  }

  remote_access {
    ec2_ssh_key = "${var.eks_cluster_name}-eks-key-pair"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role.eks_node_group_role,
    aws_key_pair.v3_eks_key_pair,
    aws_iam_instance_profile.eks_node_group_instance_profile
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

#################################################################
## Eks IRSA Creation
#################################################################
data "tls_certificate" "this" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = { Name = "${var.eks_cluster_name}-eks-irsa" }

  depends_on = [aws_eks_node_group.eks_node_group]
}

#################################################################
# Installing eks cluster Add-ons
#################################################################

resource "aws_eks_addon" "this" {
  for_each     = { for addon in var.addons : addon.name => addon }
  cluster_name = aws_eks_cluster.eks_cluster.id
  addon_name   = each.value.name
  # addon_version     = each.value.version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  depends_on = [aws_iam_openid_connect_provider.oidc_provider]
}

#################################################################
# Configuring ALB for eks
#################################################################
# create iam role and policy for eks to be used during alb deployment 
resource "aws_iam_policy" "eks_alb_policy" {
  name        = "${var.eks_cluster_name}-eks-alb-policy"
  description = "IAM policy created for the given eks albcluster"
  policy      = file("${path.module}/policies/eks-alb-policy.json")
}

resource "aws_ssm_parameter" "v3_alb_policy_ssm_parameter" {
  name  = "/v3/eks-alb-policy/arn"
  type  = "String"
  value = aws_iam_policy.eks_alb_policy.arn
}

resource "aws_ssm_parameter" "v3_eks_cluster_endpoint" {
  name  = "/v3/eks-cluster-endpoint/endpoint"
  type  = "String"
  value = aws_eks_cluster.eks_cluster.endpoint
}
