# AsiaYo Case2 — EKS 上的高可用應用 + MySQL 一寫多讀

用 Terraform 開一座跨 3 AZ 的 EKS，並以 K8s manifests 部署「對外應用（ALB Ingress → Service → Deployment）」與「MySQL 一主多從 StatefulSet」，整體以高可用（HA）為設計主軸。

## 架構概觀

```
                 Internet
                    │
            ALB (跨 3 AZ, internet-facing)        ← AWS LB Controller 依 Ingress 建立
                    │
        Ingress(asiayo.com) → Service(asiayo-app) → Deployment(3 副本, 跨 AZ)
                                                          │  讀/寫分流
                                   ┌──────────────────────┴───────────────────┐
                              mysql-writer                                mysql-reader
                              (→ mysql-0 primary)                  (→ 所有 mysql pod, 負載平衡)
                                   └──────────── StatefulSet mysql (GTID 一主多從) ─────────┘
                                         mysql-0(primary) / mysql-1,2(replica)
   儲存：MySQL 每 pod 各一顆 EBS(gp3, RWO)；App 多副本共享 EFS(RWX)
```

## 前置需求

- AWS CLI（已設定有權限的憑證）、Terraform `>= 1.5`、kubectl
- Terraform 會自動安裝 AWS Load Balancer Controller（透過 helm provider），不需手動裝。

## 一、部署 EKS 與基礎設施（Terraform）

版本：EKS module `~> 21.0`、AWS provider `~> 6.0`、Kubernetes `1.33`（皆為 2026-06 現行版本）。

此步驟會一次建立：VPC（跨 3 AZ、每 AZ 一個 NAT）、EKS cluster + managed node group、核心 addon（CoreDNS / kube-proxy / VPC CNI / metrics-server）、**EBS CSI + EFS CSI driver（含 Pod Identity 授權）**、**App 共享儲存用的 EFS**、以及 **AWS Load Balancer Controller**。

```bash
cd terraform
terraform init
terraform plan
terraform apply

# 完成後設定 kubectl
aws eks update-kubeconfig --region ap-northeast-1 --name asiayo-eks
```

> 安全提醒：`var.api_allowed_cidrs` 預設 `0.0.0.0/0` 僅為示範，正式環境請收斂到辦公室/VPN/跳板 IP，或改走 private endpoint。

## 二、把 EFS id 寫進 efs-sc StorageClass

`efs-sc` 需要實際的 EFS 檔案系統 id（Terraform 建立後才知道），套用前先填入：

```bash
# 仍在 terraform/ 目錄
terraform output -raw efs_file_system_id          # 看 id
# 直接用內建指令把 id 寫進 k8s/02-efs-storageclass.yaml（macOS/BSD sed）：
eval "$(terraform output -raw patch_efs_storageclass_cmd)"
# Linux 請改用： sed -i "s/fs-REPLACE_WITH_TERRAFORM_OUTPUT/$(terraform output -raw efs_file_system_id)/" ../k8s/02-efs-storageclass.yaml
```

## 三、部署應用（kubectl）

檔名前綴有編號，依序套用即可：

```bash
cd ../k8s
kubectl apply -f .
```

| 檔案 | 對應架構圖 | 說明 |
| --- | --- | --- |
| `00-namespace.yaml` | Namespace: asiayo | 隔離環境 |
| `01-storageclass.yaml` | pv | gp3，PVC 動態建立 EBS（MySQL 用） |
| `02-efs-storageclass.yaml` | pv | efs-sc，PVC 動態建立 EFS（App 共享用，RWX） |
| `10~14-mysql-*.yaml` | sts(mysql) / writer / reader | MySQL 一寫多讀 StatefulSet + 複寫 bootstrap |
| `20-app-pvc.yaml` | pvc → pv | 多副本共享儲存（EFS RWX） |
| `21-app-deployment.yaml` | deploy → pod | 應用程式本體（DB 用最小權限 app 帳號） |
| `22-app-service.yaml` | svc | 內部負載平衡 |
| `23-app-ingress.yaml` | ing（asiayo.com） | 對外入口（ALB，預設 HTTP） |
| `24-app-hpa-pdb.yaml` | — | 自動擴縮 + 中斷預算 |

## 四、驗證

```bash
kubectl -n asiayo get pods -o wide                 # 3 個 app + 3 個 mysql，跨節點/AZ
kubectl -n asiayo get ingress asiayo-ingress       # 等 ADDRESS 出現 ALB DNS
# 確認複寫已接上（任一 replica 應為 Replica_IO_Running: Yes）
kubectl -n asiayo exec mysql-1 -c mysql -- \
  bash -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "SHOW REPLICA STATUS\G"' | grep Running
```

## 五、高可用（HA）設計總覽

| 層級 | 做法 |
| --- | --- |
| 區域 | VPC 與節點跨 **3 個 AZ**；每 AZ 一個 NAT Gateway，避免單點 |
| Control Plane | EKS 託管，本身跨多 AZ（SLA 99.95%） |
| 運算節點 | Managed node group `min=3`，每 AZ 至少一台，可擴至 6 |
| 應用層 | Deployment 3 副本 + `podAntiAffinity` + `topologySpread` 分散到不同節點/AZ；HPA 依 CPU 擴縮（3→20） |
| 資料層 | MySQL StatefulSet GTID 一主多從，writer/reader Service 分流；PVC 各自獨立 EBS |
| 入口 | ALB 跨 AZ + 健康檢查，只導流到健康的 pod |
| 共享儲存 | EFS 跨 AZ（每 AZ 一個 mount target），App 多副本可 RWX 共寫 |
| 滾動更新 | `maxUnavailable: 0`，更新零中斷 |
| 維運保護 | PDB（app/mysql 各保最低 2 副本）；節點 drain 不會打掛服務 |

## 六、MySQL 複寫怎麼運作

- `init-mysql`（init container）依 Pod 序號套設定：`mysql-0` 用 primary.cnf（可寫），其餘用 replica.cnf（`super_read_only`），並寫入唯一 `server-id`。
- `replication-bootstrap`（sidecar，腳本見 `11-configmap`）：
  - **primary**：建立複寫帳號 `repl`、應用資料庫與最小權限的 `app` 帳號。
  - **replica**：等 primary 就緒後，先用 MySQL **CLONE plugin** 從 primary 完整複製資料（含 GTID 狀態），再以 **GTID auto-position** 持續同步。腳本 idempotent，可重跑。
- 讀寫分流：應用寫入連 `mysql-writer`（指向 mysql-0），讀取連 `mysql-reader`（負載平衡到所有 pod）。

## 七、限制與正式環境建議（誠實揭露）

1. **無自動 failover**：`mysql-writer` 靜態指向 `mysql-0`，primary 故障需人工把 writer 切到新 primary。本方案展示的是「一主多從的編排與複寫機制」，不是自癒叢集。
2. **複寫 bootstrap 假設全新叢集**：CLONE + GTID 流程針對乾淨初始化情境；replica 首次 clone 會讓該 pod 的 mysqld 重啟一次（屬預期）。
3. **正式環境建議**：
   - 自管 MySQL 想要真 HA，請用 **MySQL Operator**（如 Oracle MySQL Operator / Percona / Moco）接管複寫、備援與自動 failover；
   - 或直接用 **RDS / Aurora MySQL（Multi-AZ）**，由 AWS 提供寫入 HA 與自動 failover，維運成本最低（OTA 場景多半更划算）。
4. **機密管理**：`10-mysql-secret.yaml` 為明碼佔位，正式請改用 External Secrets Operator 或 AWS Secrets Manager + Pod Identity，切勿把真密碼 commit。
5. **TLS / HTTPS**：Ingress 預設只開 HTTP，需提供 ACM 憑證 ARN 後才開 443（見 `23-app-ingress.yaml` 註解）。
6. **App 若為無狀態**：其實可不掛 EFS，靜態檔交給 S3/CDN 更單純；此處依需求保留共享儲存示範 RWX。

> 註：以上 Terraform / manifests 已就語法與邏輯自審，但未在真實 AWS 帳號 `apply` 驗證；實際佈署時請以 `terraform plan` 與叢集回饋為準。
