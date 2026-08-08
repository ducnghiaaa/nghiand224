# Thiết kế: Cá nhân hoá DevOps-Project-01

**Ngày:** 2026-08-08
**Trạng thái:** Đã thống nhất, chờ lập kế hoạch triển khai

---

## 1. Bối cảnh và mục tiêu

Repo hiện tại là bản sao của project DevOps-Project-01 do Harshhaa / NotHarshhaa (ProDevOpsGuy) viết: một ứng dụng Java Spring Boot (login/register, đóng gói WAR) kèm bộ Terraform dựng kiến trúc 3 tầng trên AWS.

**Mục tiêu của bản cá nhân hoá này (hai mục tiêu ngang nhau):**

1. **Portfolio xin việc DevOps/Cloud** — repo phải tự nó chứng minh năng lực, kể cả khi hạ tầng đã bị destroy.
2. **Luyện tay nghề AWS bám blueprint SAA-C03** — chạm tay thật vào VPC, ALB, ASG, RDS, IAM, KMS/Secrets Manager, CloudWatch.

**Ràng buộc đã chốt:**

| Ràng buộc | Giá trị |
| --- | --- |
| Ngân sách | ~$20-30/tháng, bắt buộc `destroy` sau mỗi buổi |
| Thời gian | 5-8 giờ/tuần, trong 4-6 tuần (≈25-45 giờ) |
| Ứng dụng | Giữ Java Spring Boot, dọn sạch — không viết app mới |
| CI/CD | GitHub Actions, xác thực bằng OIDC |
| Kiến trúc deploy | EC2 + ASG + AMI bất biến build bằng Packer |
| Vị trí repo | Không tách repo riêng. Nằm trong `ducnghiaaa/nghiand224`, trên nhánh `projects/devops`; `main` chỉ chứa README index (xem mục 3.2) |
| Vòng đời | **Không chạy 24/7.** Portfolio thể hiện qua repo, lịch sử CI, ảnh và video |

**Chi phí thực tế ước tính:** ~$0,10/giờ khi hạ tầng sống (ALB $0,0225 + 1 NAT Gateway $0,045 + RDS t3.micro $0,017 + 2× EC2 t3.micro $0,021). Với 8 giờ/tuần → **≈$3,5/tháng**. Ngân sách không phải là rủi ro; **quên `destroy` mới là rủi ro**.

---

## 2. Hiện trạng: các lỗi thật trong code gốc

Đây là danh sách đã kiểm chứng bằng cách đọc code, không phải phỏng đoán. Danh sách này chính là nguyên liệu cho phần "những gì tôi đã sửa" trong README cuối cùng.

### Lỗi chặn (khiến project không thể chạy)

| # | Lỗi | Vị trí |
| --- | --- | --- |
| B1 | **Trùng tên security group.** Cả module `alb` lẫn module `security` đều tạo SG tên `${environment}-alb-sg` → `terraform apply` thất bại với `InvalidGroup.Duplicate`. Suy ra project gốc chưa từng apply thành công | `modules/alb/main.tf:54`, `modules/security/main.tf:5` |
| B2 | **Ứng dụng không bao giờ được cài.** `user_data` cài Tomcat nhưng không deploy file WAR nào | `modules/asg/main.tf:11-19` |
| B3 | **Health check chắc chắn thất bại.** ALB kiểm tra `/` và chờ HTTP 200, nhưng app dùng Spring Security nên trả 302 redirect → mọi instance unhealthy vĩnh viễn | `modules/alb/main.tf:29` |
| B4 | `aws_eip.vpc = true` đã bị gỡ bỏ ở AWS provider 5.x (phải dùng `domain = "vpc"`) | `modules/vpc/main.tf:55` |

### Lỗi bảo mật

| # | Lỗi | Vị trí |
| --- | --- | --- |
| S1 | Endpoint RDS + username + password của người khác nằm plaintext trong repo | `Java-Login-App/src/main/resources/application.properties` |
| S2 | DB password truyền qua biến Terraform → lưu plaintext trong state file | `infrastructure/main.tf:54` |
| S3 | `allowed_ssh_cidr_blocks` mặc định `0.0.0.0/0` — SSH mở cho toàn Internet | `infrastructure/variables.tf:87` |
| S4 | Không có IAM instance profile → không dùng được SSM, CloudWatch agent không có quyền gửi log | `modules/asg/main.tf:3-32` |
| S5 | Tạo security group cho bastion nhưng **không tồn tại bastion instance nào** — code chết, mâu thuẫn với README | `modules/security/main.tf:96` |
| S6 | Backend S3 bị comment toàn bộ → state nằm ở máy local, không có lock, mất máy là mất quyền kiểm soát hạ tầng | `infrastructure/main.tf:12-17` |

### Lỗi vận hành và chi phí

| # | Lỗi | Vị trí |
| --- | --- | --- |
| O1 | **Hai NAT Gateway** (mỗi public subnet một cái) = ~$64/tháng, gấp đôi ngân sách | `modules/vpc/main.tf:64-73` |
| O2 | **Không có scaling policy nào.** Mang tên "Auto Scaling" nhưng ASG không bao giờ scale | `modules/asg/main.tf` |
| O3 | Mọi alarm đều có `alarm_actions = []` → không thông báo cho ai | `modules/monitoring/main.tf:25,47,70` |
| O4 | AMI hardcode `ami-0c02fb55956c7d316` — chỉ đúng ở us-east-1 và sẽ mục theo thời gian | `modules/asg/main.tf:5` |
| O5 | Không có `outputs.tf` ở root → apply xong không biết DNS name của ALB | `infrastructure/` |
| O6 | AWS provider ghim `~> 4.0`, lạc hậu hai major version | `infrastructure/main.tf:8` |
| O7 | Không có khối `instance_refresh` → không có cơ chế rollout | `modules/asg/main.tf:34-61` |
| O8 | README mô tả thư mục `environments/dev,prod` không tồn tại; toàn bộ hướng dẫn là lệnh AWS CLI thủ công, không khớp với Terraform bên dưới | `README.md`, `infrastructure/README.md:43-45` |

---

## 3. Kiến trúc đích

Giữ nguyên mô hình 3 tầng (ALB công khai → EC2 trong private subnet → RDS trong private subnet), sửa toàn bộ lỗi ở mục 2, và thêm ba quyết định mang dấu ấn cá nhân.

### 3.1 Ba quyết định cá nhân hoá

**(a) Bỏ hẳn bastion host, thay bằng AWS Systems Manager Session Manager**

Xoá security group bastion (S5) và rule port 22 khỏi security group `app`. Truy cập instance qua Session Manager, dùng VPC interface endpoint (`ssm`, `ssmmessages`, `ec2messages`) để không cần đường ra Internet.

- *Bảo mật:* không mở port 22 ở bất kỳ đâu, không quản lý SSH key, mọi phiên truy cập được ghi log vào CloudWatch.
- *Chi phí:* bỏ được một EC2 bastion.
- *SAA-C03:* Domain 1 — IAM role, least privilege, VPC endpoint.

**(b) Biến `nat_mode`: chuyển giữa NAT Gateway và NAT instance**

Module `vpc` nhận biến `nat_mode` với hai giá trị:

- `"gateway"` — **một** NAT Gateway dùng chung (sửa O1, giảm từ $64 xuống $32/tháng)
- `"instance"` — một EC2 `t4g.nano` làm NAT (~$3/tháng)

README ghi bảng so sánh chi phí **đo bằng số thật từ Cost Explorer**, kèm phân tích đánh đổi (NAT instance là điểm chết đơn lẻ, băng thông giới hạn, phải tự vá lỗi; NAT Gateway được quản lý và HA trong một AZ).

- *SAA-C03:* Domain 4 — đây đúng là một task statement trong blueprint.

**(c) Bỏ DB password khỏi Terraform, dùng `manage_master_user_password`**

RDS tự sinh master password và lưu trong Secrets Manager, tự xoay vòng. Xoá hai biến `db_username`/`db_password` khỏi `variables.tf` (sửa S2). Ứng dụng đọc secret lúc khởi động qua IAM instance profile.

Kết quả: **không còn secret nào trong repo lẫn trong state file**.

- *SAA-C03:* Domain 1 — Secrets Manager so với Parameter Store, mã hoá at-rest.

### 3.2 Chiến lược repo và nhánh

Project này **không có repo GitHub riêng**. Nó nằm trong repo tổng hợp portfolio `ducnghiaaa/nghiand224`, theo mô hình **mỗi project một nhánh**:

| Nhánh | Nội dung |
| --- | --- |
| `main` (default) | Chỉ có `README.md` — trang portfolio liệt kê mọi project kèm link |
| `projects/devops` | Toàn bộ project này |
| *(sau này)* `projects/<tên>` | Các project khác |

Link từ README ở `main`:

```markdown
- [DevOps Project 01 — 3-Tier Java trên AWS](https://github.com/ducnghiaaa/nghiand224/tree/projects/devops/DevOps-Project-01)
```

GitHub sẽ render `README.md` nằm trong thư mục đó ngay khi bấm vào.

**Hệ quả cần xử lý (đã cân nhắc và chấp nhận):**

1. **Badge CI phải chỉ định nhánh.** Cú pháp:
   `![CI](https://github.com/ducnghiaaa/nghiand224/actions/workflows/ci.yml/badge.svg?branch=projects/devops)`
2. **Luồng PR nhắm vào `projects/devops`, không phải `main`.** Làm việc trên nhánh `feat/<tên>`, mở PR vào `projects/devops`. `terraform-plan.yml` cấu hình `pull_request: branches: [projects/devops]`.
3. **Workflow phải nằm ở `.github/workflows/` trên chính nhánh `projects/devops`.** Sự kiện `push` và `pull_request` đọc định nghĩa workflow từ nhánh liên quan, nên cách này chạy đúng. Riêng `workflow_dispatch` chỉ hiện trên giao diện Actions nếu file workflow tồn tại ở **default branch**, do đó `infra-apply.yml` và `deploy.yml` sẽ dùng cách kích hoạt bằng `gh workflow run --ref projects/devops` từ dòng lệnh, hoặc đồng bộ một bản copy của hai file này sang `main`. **Chốt: dùng `gh workflow run --ref`**, đơn giản hơn và không phải giữ hai bản đồng bộ.
4. **Thống kê ngôn ngữ và code search của repo chỉ tính `main`** → repo sẽ hiện "Markdown 100%". Đây là đánh đổi đã biết và chấp nhận; bù lại bằng README index viết kỹ.

### 3.3 Cấu trúc thư mục đích

Bên trong nhánh `projects/devops`:

```
DevOps-Project-01/
├── ATTRIBUTION.md              # Ghi nhận nguồn gốc + danh sách việc tự làm
├── README.md                   # Viết lại hoàn toàn
├── docs/
│   ├── architecture.png        # Sơ đồ tự vẽ
│   └── evidence/               # Ảnh chụp, số liệu chi phí, video demo
├── Java-Login-App/             # Giữ nguyên, dọn sạch
├── packer/
│   ├── app.pkr.hcl             # Bake AMI: Corretto + Tomcat + WAR + CW agent
│   └── scripts/
├── infrastructure/
│   ├── bootstrap/              # S3 state bucket + DynamoDB lock (apply một lần)
│   ├── envs/dev/               # backend.tf + terraform.tfvars
│   ├── main.tf, variables.tf, outputs.tf
│   └── modules/
│       ├── vpc/                # + nat_mode, + VPC endpoints, - 1 NAT GW
│       ├── security/           # - bastion SG, - rule 22, - SG trùng tên
│       ├── alb/                # + health check /actuator/health
│       ├── asg/                # + instance profile, + instance_refresh, + scaling policy
│       ├── rds/                # + manage_master_user_password
│       ├── monitoring/         # + SNS topic, + dashboard
│       └── iam/                # MỚI: instance profile + GitHub OIDC role
└── .github/workflows/
    ├── ci.yml
    ├── terraform-plan.yml
    ├── infra-apply.yml         # input: action = apply | destroy
    └── deploy.yml
```

### 3.4 Thay đổi ở tầng ứng dụng

Giữ nguyên chức năng login/register. Ba thay đổi:

1. **Xoá credentials hardcode** (S1). Cấu hình DB đọc từ biến môi trường do user-data bơm vào sau khi lấy secret từ Secrets Manager.
2. **Thêm Spring Boot Actuator**, mở đúng endpoint `/actuator/health`, cấu hình Spring Security cho phép truy cập ẩn danh endpoint này. ALB health check trỏ vào đây (sửa B3).
3. **Thêm Flyway migration** tạo bảng `users` và các index, thay cho việc chạy SQL bằng tay như README gốc hướng dẫn.

---

## 4. CI/CD

Bốn workflow, tách bạch trách nhiệm. Tất cả nằm ở `.github/workflows/` **trên nhánh `projects/devops`**, và mọi trigger đều nhắm vào nhánh đó chứ không phải `main` (xem mục 3.2).

### 4.1 `ci.yml` — chạy trên mọi push và pull request

Trigger: `push: branches: [projects/devops, 'feat/**']` và `pull_request: branches: [projects/devops]`.

Không đụng tới AWS, không tốn tiền, luôn nhìn thấy được:

1. `mvn verify` (biên dịch + unit test)
2. Quét SonarCloud
3. `tflint` + `checkov` trên thư mục `infrastructure/`
4. Upload file WAR làm build artifact

Đây là workflow tạo badge xanh và lịch sử chạy — tài sản portfolio tồn tại vĩnh viễn.

### 4.2 `terraform-plan.yml` — chạy trên pull request

Trigger: `pull_request: branches: [projects/devops]`.

Chạy `terraform plan` rồi **bot comment kết quả plan vào PR**. Đây là quy trình thật ở doanh nghiệp và là chi tiết gây ấn tượng mạnh.

### 4.3 `infra-apply.yml` — kích hoạt bằng tay

`workflow_dispatch` với input `action: apply | destroy`, gắn `environment: dev` yêu cầu phê duyệt thủ công. **Không bao giờ auto-apply hạ tầng.**

Vì file nằm ngoài default branch, kích hoạt bằng:
`gh workflow run infra-apply.yml --ref projects/devops -f action=apply`

### 4.4 `deploy.yml` — kích hoạt bằng tay

1. Tải WAR artifact
2. Packer bake AMI, gắn tag `app=java-login-app`, `version=<git-sha>`
3. Cập nhật Launch Template trỏ tới AMI mới
4. Gọi `aws autoscaling start-instance-refresh`
5. Chờ và kiểm tra ALB target health, in kết quả

### 4.5 Xác thực: OIDC, không dùng access key

GitHub Actions assume một IAM role qua OpenID Connect. **Không có access key nào trong GitHub Secrets.**

**Hai role, hai mức quyền** — vì `terraform plan` chạy từ PR của nhánh `feat/**` cũng cần đọc AWS, nhưng tuyệt đối không được có quyền ghi:

| Role | Điều kiện `sub` trong trust policy | Quyền |
| --- | --- | --- |
| `gha-terraform-plan` | `repo:ducnghiaaa/nghiand224:pull_request` | Chỉ đọc (`ReadOnlyAccess` + ghi state lock) |
| `gha-terraform-apply` | `repo:ducnghiaaa/nghiand224:ref:refs/heads/projects/devops` | Quyền tạo/sửa/xoá hạ tầng |

Điểm mấu chốt: token của sự kiện `pull_request` mang `sub` là `...:pull_request`, **không** phải `...:ref:refs/heads/<nhánh>`. Nếu chỉ khai báo một role theo `ref:` thì `terraform-plan.yml` sẽ thất bại với lỗi `AssumeRoleWithWebIdentity` — đây là lỗi rất hay gặp khi mới dùng OIDC.

`ci.yml` không assume role nào cả vì nó không đụng tới AWS.

Đây là điểm bảo mật đáng nói nhất trong toàn project và trùng khớp SAA-C03 Domain 1 (IAM, STS, trust policy).

### 4.6 Luồng đầy đủ

```
nhánh feat/<tên>  →  ci.yml (test, quét, đóng gói WAR)
                        ↓
PR vào projects/devops  →  terraform-plan.yml (bot comment plan)
                        ↓ merge vào projects/devops
gh workflow run   →  infra-apply.yml (action=apply)  →  hạ tầng lên
                        ↓
gh workflow run   →  deploy.yml  →  Packer bake  →  instance refresh  →  health check
                        ↓
                     THU THẬP BẰNG CHỨNG (ảnh / video / số liệu chi phí)
                        ↓
gh workflow run   →  infra-apply.yml (action=destroy)  →  về $0
```

---

## 5. Chiến lược bằng chứng

Vì hạ tầng không chạy lâu dài, thứ nhà tuyển dụng thực sự xem là **repo**, không phải link demo. Ba tài sản tồn tại vĩnh viễn và miễn phí:

1. **Lịch sử chạy GitHub Actions** — badge xanh, log build/test/scan/deploy thật
2. **README tự viết** — sơ đồ kiến trúc, bảng chi phí có số thật, mục "những gì tôi đã sửa so với bản gốc"
3. **Chất lượng code Terraform** — module sạch, có tflint và checkov chạy trong CI

Do đó **mỗi giai đoạn phải kết thúc bằng bằng chứng lưu được**, thu thập khi hạ tầng còn sống, trước khi `destroy`. Tất cả lưu vào `docs/evidence/`.

---

## 6. Lộ trình

Mỗi tuần là một giai đoạn **độc lập, dừng lại được**, và sẽ có kế hoạch triển khai chi tiết riêng. Không cố gộp cả sáu tuần vào một kế hoạch duy nhất.

### Tuần 0 — Nền móng an toàn (1-2 giờ)

**Đưa code vào git.** Hiện toàn bộ `DevOps-Project-01/` đang untracked; nhánh `projects/devops` mới chỉ có tài liệu thiết kế này. Thứ tự bắt buộc:

1. Viết `.gitignore` **trước** (`*.tfstate*`, `*.tfvars`, `.terraform/`, `target/`, `.DS_Store`).
2. Xoá credentials khỏi `application.properties` (S1) **trước khi commit lần đầu** — commit rồi mới xoá thì secret vẫn nằm vĩnh viễn trong lịch sử git.
3. Commit toàn bộ project vào `projects/devops`, push lên origin.

**Viết README index ở nhánh `main`.** Một file duy nhất, liệt kê các project kèm link theo mục 3.2. Đây là trang đầu tiên nhà tuyển dụng nhìn thấy nên viết cẩn thận: mỗi project một dòng mô tả một câu về vấn đề đã giải quyết, không phải liệt kê tên công nghệ.

**Viết `ATTRIBUTION.md`** trong `DevOps-Project-01/`: ghi rõ project bắt nguồn từ repo của NotHarshhaa (ProDevOpsGuy), liệt kê phần bạn tự làm. *Trung thực về nguồn gốc là điểm cộng; giấu đi mà bị phát hiện là điểm trừ chí mạng.*

**Tài khoản AWS:** bật MFA, tạo IAM user riêng thay cho root, đặt AWS Budget alert ở mức $20 và $30.

**Bằng chứng:** ảnh chụp cấu hình Budget alert.

### Tuần 1 — Nền tảng Terraform (6-8 giờ)

- `bootstrap/`: S3 state bucket (bật versioning, mã hoá, chặn public access) + DynamoDB lock table.
- `envs/dev/`: `backend.tf` + `terraform.tfvars`.
- Nâng AWS provider lên `~> 5.x` (O6), sửa `aws_eip.domain` (B4), thêm `default_tags` cho toàn provider.
- Viết `outputs.tf` ở root (O5).
- Sửa trùng tên security group (B1) — module `alb` dùng SG do module `security` cấp, không tự tạo.
- Xoá bastion SG và rule port 22 (S5, S3); thêm VPC interface endpoint cho SSM.
- Giảm còn một NAT Gateway và thêm biến `nat_mode` (O1).

**Điều kiện hoàn thành:** `terraform apply` thành công từ đầu — điều mà project gốc chưa từng làm được.
**Bằng chứng:** ảnh VPC Resource Map, output của lần apply đầu tiên.

### Tuần 2 — Dọn app, IAM, RDS an toàn (6-8 giờ)

- Spring Boot đọc DB credentials từ biến môi trường; thêm Actuator và mở `/actuator/health` (B3); thêm Flyway migration.
- RDS: bật `manage_master_user_password` (S2), đưa `instance_class` thành biến, thêm cờ `multi_az` tuỳ chọn.
- Module `iam` mới: instance profile với quyền SSM, CloudWatch agent, đọc secret RDS (S4).
- Chạy thử app ở local với MySQL trong Docker.

**Bằng chứng:** ảnh phiên SSM Session Manager kết nối thành công, ảnh secret trong Secrets Manager, ảnh app chạy local.

### Tuần 3 — Packer và deploy thật (6-8 giờ)

- `packer/app.pkr.hcl`: Amazon Linux 2023 + Amazon Corretto 11 + **Tomcat 9** + WAR + CloudWatch agent (B2).
  - Bắt buộc Tomcat 9, không phải Tomcat 10: Spring Boot 2.7 dùng `javax.servlet`, còn Tomcat 10 đã chuyển sang `jakarta.servlet`.
  - AL2023 không có sẵn gói `tomcat` trong repo `dnf`, nên script provisioner sẽ tải bản Tomcat 9 từ Apache và tạo systemd unit.
- ASG: thay AMI hardcode bằng `data source` lọc theo tag (O4); thêm `instance_refresh` (O7); thêm target-tracking scaling policy ở mức CPU 50% (O2).
- Bake và deploy bằng tay lần đầu, xác nhận app chạy qua DNS của ALB.

**Bằng chứng:** **video app login/register chạy qua ALB** — tài sản portfolio quan trọng nhất. Kèm ảnh target group toàn bộ healthy.

### Tuần 4 — Tự động hoá CI/CD (6-8 giờ)

- OIDC provider + IAM role với trust policy khoá đúng repo và branch.
- Bốn workflow ở mục 4.
- Kết nối SonarCloud, tflint, checkov.

**Bằng chứng:** ảnh PR có bot comment `terraform plan`; lịch sử Actions xanh (tồn tại vĩnh viễn).

### Tuần 5 — Monitoring, kiểm chứng chịu lỗi, tài liệu (6-8 giờ)

- CloudWatch: log group nhận `catalina.out`, dashboard, alarm (CPU, RDS connections, ALB 5xx, unhealthy host) nối vào SNS topic gửi email (O3).
- **Thử nghiệm chịu lỗi:** tự tay terminate một instance, đo thời gian ASG phục hồi. Đưa con số thật vào README.
- **Đo chi phí:** chạy `nat_mode=gateway` và `nat_mode=instance`, lấy số thật từ Cost Explorer, lập bảng so sánh.
- Viết lại README hoàn toàn, vẽ sơ đồ kiến trúc, dựng video demo.

**Bằng chứng:** ảnh dashboard, biểu đồ phục hồi kèm mốc thời gian, bảng chi phí có số thật.

### Tuần 6 — Tuỳ chọn: ACM và Route 53 HTTPS

Nếu còn thời gian: mua domain rẻ trên Route 53 (`.click` ~$3/năm, `.link` ~$5/năm), tạo hosted zone ($0,50/tháng), xin ACM cert (miễn phí, xác thực qua DNS), thêm listener HTTPS và chuyển hướng HTTP sang HTTPS.

Lý do đáng làm: trong video demo, thanh địa chỉ hiện `https://app.<domain>` kèm ổ khoá xanh, thay vì `dev-alb-1234.us-east-1.elb.amazonaws.com` kèm chữ "Not secure".

Bỏ giai đoạn này không ảnh hưởng gì tới các giai đoạn trước.

---

## 7. Tiêu chí hoàn thành

Project được coi là xong khi thoả **toàn bộ** các điều kiện sau:

1. Từ repo sạch, chạy `terraform apply` rồi `deploy.yml` → ứng dụng hoạt động trong **dưới 20 phút**, **không một thao tác thủ công nào**.
2. **Không có secret nào** trong repo lẫn trong state file.
3. Toàn bộ 18 lỗi ở mục 2 đã được sửa và ghi lại trong README.
4. CI xanh; `tflint` và `checkov` chạy trong pipeline.
5. Thu đủ năm loại bằng chứng trong `docs/evidence/`: video demo, ảnh dashboard, ảnh phiên SSM, ảnh PR có plan comment, bảng chi phí.
6. `ATTRIBUTION.md` ghi rõ nguồn gốc và ranh giới đóng góp.
7. `main` có README index, link dẫn thẳng vào project và **đã bấm thử thấy README project hiện ra đúng**.

---

## 8. Rủi ro

| Rủi ro | Cách giảm thiểu |
| --- | --- |
| Quên `destroy` → cháy tiền | Budget alert $20/$30 từ tuần 0; `infra-apply.yml` có input `destroy` bấm một nút |
| Packer bake chậm (8-12 phút mỗi lần) làm nản | Tuần 3 bake bằng tay trước để nắm quy trình, tự động hoá ở tuần 4 |
| AMI cũ tích tụ gây tốn phí lưu trữ | Gắn tag `version` và dọn thủ công ở cuối mỗi tuần; ghi vào checklist |
| Hết thời gian ở tuần 5 | Tuần 6 vốn đã là tuỳ chọn; nếu thiếu nữa thì cắt phần thử nghiệm chịu lỗi, giữ phần tài liệu |
| Ứng dụng Java cũ (Spring Boot 2.7 đã hết hỗ trợ) gây khó khi build | Giữ nguyên phiên bản, không nâng cấp — nâng Spring Boot nằm ngoài phạm vi và không phục vụ mục tiêu DevOps |
