###############################################################
# eks.tf — EKS Cluster 與 Managed Node Group
#
# 高可用設計重點：
#   - EKS control plane 由 AWS 託管，本身即跨多 AZ（SLA 99.95%）
#   - Managed node group 的 subnet 橫跨 3 個 AZ，節點分散不同機房
#   - desired=3 / min=3 / max=6：起步每 AZ 一台，可水平擴充
#   - 啟用 EKS addons（CoreDNS、kube-proxy、VPC CNI、EBS CSI），
#     其中 EBS CSI 讓 PVC 能動態建立 EBS volume（題目的 pvc/pv 用得到）
#   - 使用 access entry（v21 預設機制）取代舊的 aws-auth ConfigMap
###############################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # API endpoint：示範開公網但「限制來源 CIDR」；正式環境建議走 private + 跳板/VPN。
  # 預設 var.api_allowed_cidrs = 0.0.0.0/0 僅為示範，請務必收斂。
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs

  # 讓執行 terraform 的身分自動取得 cluster admin，方便首次部署
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets # 工作節點放 private subnet
  control_plane_subnet_ids = module.vpc.private_subnets

  # 叢集核心 addon（由 EKS 託管升級）
  # 註：EBS/EFS CSI controller 需要 AWS API 權限才能建立磁碟，
  #     權限透過 pod-identity.tf 的 Pod Identity 關聯給予（最小權限，
  #     只授權給 CSI controller 的 ServiceAccount，而非整台節點）。
  addons = {
    coredns                 = {}
    kube-proxy              = {}
    vpc-cni                 = {}
    eks-pod-identity-agent  = {} # 啟用 Pod Identity（CSI / LB Controller 取得 IAM 用）
    aws-ebs-csi-driver      = {} # 動態佈建 EBS（MySQL StatefulSet 的 PVC 需要）
    aws-efs-csi-driver      = {} # 動態佈建 EFS（App 多副本 RWX 共享儲存需要）
    metrics-server          = {} # HPA 取用指標需要
  }

  # Managed node group：跨 3 AZ，提供高可用的運算層
  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 3 # 每 AZ 至少一台
      max_size     = 6
      desired_size = 3

      # 明確指定跨多 AZ 的 subnet，確保節點分散
      subnet_ids = module.vpc.private_subnets

      labels = {
        workload = "general"
      }
    }
  }

  tags = var.tags
}
