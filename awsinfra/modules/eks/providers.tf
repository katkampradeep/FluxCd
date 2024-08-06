# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       configuration_aliases = [ aws ]
#     }
#   }
# }

# data "aws_eks_cluster" "this" {
#   name = aws_eks_cluster.v3_eksCluster.id

#   depends_on = [ aws_eks_node_group.v3_eksNodeGroup ]
# }

# data "aws_eks_cluster_auth" "this" {
#   name = aws_eks_cluster.v3_eksCluster.id

#   depends_on = [ aws_eks_node_group.v3_eksNodeGroup ]
# }

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.this.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.this.token
# }

