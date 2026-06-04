###############################################################
# lb-controller.tf — 安裝 AWS Load Balancer Controller
#
# 為什麼需要：k8s/23-app-ingress.yaml 用的是 ALB Ingress，
#   必須有這個 controller 在叢集裡，Ingress 才會真的長出對外 ALB。
#   沒有它，Ingress 會一直沒有 address（題目的 ing -> ALB 斷掉）。
#
# IAM 權限來自 pod-identity.tf 的 lb_controller_pod_identity（綁定本 SA）。
# chart 預設會建立名為 "alb" 的 IngressClass，Ingress 以 ingressClassName: alb 取用。
###############################################################
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "~> 1.8"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  # 由 chart 建立 SA，名稱需與 pod-identity 關聯一致
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    module.eks,
    module.lb_controller_pod_identity,
  ]
}
