output "eks_cluster" {
  value = aws_eks_cluster.eks_cluster
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_cluster_ca_certificate" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}
output "eks_node_group_role" {
  value = aws_iam_role.eks_node_group_role
}