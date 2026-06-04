###############################################################
# outputs.tf
###############################################################
output "cluster_name" {
  description = "EKS cluster 名稱"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "部署完成後設定 kubectl 的指令"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "efs_file_system_id" {
  description = "App 共享儲存的 EFS id；需填入 k8s/02-efs-storageclass.yaml 的 fileSystemId"
  value       = aws_efs_file_system.app.id
}

# 套用 k8s 前，用這行把 EFS id 寫進 StorageClass（macOS / BSD sed 用法）。
# Linux 請改成：sed -i "s/fs-REPLACE_WITH_TERRAFORM_OUTPUT/<id>/" ../k8s/02-efs-storageclass.yaml
output "patch_efs_storageclass_cmd" {
  description = "把 EFS id 寫入 efs-sc 的便捷指令"
  value       = "sed -i '' 's/fs-REPLACE_WITH_TERRAFORM_OUTPUT/${aws_efs_file_system.app.id}/' ../k8s/02-efs-storageclass.yaml"
}
