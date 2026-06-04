###############################################################
# variables.tf — 可調整參數
###############################################################
variable "region" {
  description = "AWS 區域"
  type        = string
  default     = "ap-northeast-1" # 東京，離台灣近、延遲低
}

variable "cluster_name" {
  description = "EKS cluster 名稱"
  type        = string
  default     = "asiayo-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes 版本"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "跨幾個 AZ 部署（高可用至少 3）"
  type        = number
  default     = 3
}

# EKS public API endpoint 的來源白名單。
# 預設 0.0.0.0/0 僅為示範，正式環境務必收斂到辦公室/VPN/跳板 IP，
# 或乾脆關閉 public access 改走 private endpoint。
variable "api_allowed_cidrs" {
  description = "允許存取 EKS public API endpoint 的來源 CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "共用標籤"
  type        = map(string)
  default = {
    Project     = "asiayo"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
