###############################################################
# versions.tf — Terraform 與 Provider 版本約束
# 截至 2026-06，EKS module 已到 v21、AWS provider 已到 v6、
# EKS 支援的 Kubernetes 版本最新為 1.33。
###############################################################
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # 安裝 AWS Load Balancer Controller 用（Ingress -> ALB 需要它）
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }

  # 正式環境請改為 S3 遠端後端，做狀態鎖與團隊共享。
  # 註：Terraform 1.10+ 的 S3 backend 已支援原生 use_lockfile，
  #     可不再依賴 DynamoDB 鎖表。
  # backend "s3" {
  #   bucket       = "asiayo-tfstate"
  #   key          = "eks/terraform.tfstate"
  #   region       = "ap-northeast-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
