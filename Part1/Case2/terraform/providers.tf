###############################################################
# providers.tf
###############################################################
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# 取得目前可用的 AZ 清單，挑前 az_count 個來部署
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Helm provider：用來安裝 AWS Load Balancer Controller ---
# 以 EKS cluster 的 endpoint + 短期 token 認證。
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
