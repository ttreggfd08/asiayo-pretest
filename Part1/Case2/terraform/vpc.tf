###############################################################
# vpc.tf — 跨多 AZ 的 VPC，是 EKS 高可用的基礎
#
# 高可用設計重點：
#   - 橫跨 3 個 AZ：任一 AZ 故障，control plane 與節點仍可運作
#   - private subnet 放工作節點（不對外曝露），public subnet 放對外 LB
#   - 每個 AZ 各一個 NAT Gateway（single_nat_gateway=false）：
#     避免單一 NAT 成為單點故障；若要省成本可改 single（但犧牲 HA）
#   - 子網路打上 EKS 需要的 tag，讓 LB Controller 能自動辨識
###############################################################
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  # 依 AZ 數量切出對應的子網段
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway     = true
  single_nat_gateway     = false # 每 AZ 一個 NAT，符合高可用
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true

  # 對外型 LB（Ingress）放這裡
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  # 內部型 LB 放這裡
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}
