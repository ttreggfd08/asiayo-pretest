###############################################################
# efs.tf — 給 App 多副本共享儲存（ReadWriteMany）用的 EFS
#
# 為什麼用 EFS 而非 EBS：
#   - EBS(gp3) 是 ReadWriteOnce，只能掛單一節點，多副本共寫會卡住
#   - App Deployment 有 3 副本分散在不同 AZ，需要 RWX -> EFS
#
# 高可用：每個 private subnet（每 AZ）各建一個 mount target，
#         任一 AZ 故障，其他 AZ 的 Pod 仍能掛載。
#
# 對應 k8s/02-efs-storageclass.yaml 的 efs-sc（fileSystemId 需填本檔輸出的 id）。
###############################################################

# 只允許 VPC 內（節點）以 NFS(2049) 連到 EFS
resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs"
  description = "Allow NFS from EKS nodes within the VPC"
  vpc_id      = module.vpc.vpc_id
  tags        = merge(var.tags, { Name = "${var.cluster_name}-efs" })
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  security_group_id = aws_security_group.efs.id
  description       = "NFS from VPC"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "efs_all" {
  security_group_id = aws_security_group.efs.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_efs_file_system" "app" {
  creation_token = "${var.cluster_name}-app-shared"
  encrypted      = true

  # 不常存取的資料自動降轉到 IA，省成本
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-app-shared" })
}

# 每個 AZ 的 private subnet 各一個 mount target
resource "aws_efs_mount_target" "app" {
  for_each = toset(module.vpc.private_subnets)

  file_system_id  = aws_efs_file_system.app.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
