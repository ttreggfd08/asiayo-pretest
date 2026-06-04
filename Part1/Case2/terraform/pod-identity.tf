###############################################################
# pod-identity.tf — 用 EKS Pod Identity 給叢集元件最小權限的 IAM
#
# 為什麼需要：
#   - EBS CSI controller 要有 ec2:CreateVolume/AttachVolume... 才能動態建 EBS
#   - EFS CSI controller 要能操作 EFS access point 才能動態佈建 RWX 卷
#   - AWS Load Balancer Controller 要能建立/管理 ALB
#   只把權限綁到對應的 ServiceAccount（namespace + SA 名稱），
#   比掛在節點 InstanceProfile 上更符合最小權限原則。
#
# 前置：eks.tf 已啟用 eks-pod-identity-agent addon。
###############################################################

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name                      = "${var.cluster_name}-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = var.tags
}

module "efs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name                      = "${var.cluster_name}-efs-csi"
  attach_aws_efs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
    }
  }

  tags = var.tags
}

module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name                            = "${var.cluster_name}-aws-lbc"
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}
