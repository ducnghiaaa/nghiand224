# Thiết kế: DevOps Project 01 — Java 3-Tier trên AWS

**Ngày:** 2026-08-08
**Trạng thái:** Đã thống nhất, đang triển khai

---

## 1. Mục tiêu

Xây dựng và vận hành một ứng dụng Java Spring Boot trên kiến trúc 3 tầng ở AWS, tự động hoá hoàn toàn bằng Terraform, Packer và GitHub Actions.

**Hai mục tiêu ngang nhau:**

1. **Portfolio xin việc DevOps/Cloud** — repo phải tự nó chứng minh năng lực, kể cả khi hạ tầng đã bị destroy.
2. **Luyện tay nghề AWS bám blueprint SAA-C03** — chạm tay thật vào VPC, ALB, ASG, RDS, IAM, Secrets Manager, CloudWatch.

**Ràng buộc đã chốt:**

| Ràng buộc | Giá trị |
| --- | --- |
| Region | **ap-southeast-1 (Singapore)** |
| Ngân sách | ~$20-30/tháng, bắt buộc `destroy` sau mỗi buổi |
| Thời gian | 5-8 giờ/tuần, trong 4-6 tuần (≈25-45 giờ) |
| Ứng dụng | Java Spring Boot 2.7, đóng gói WAR, chạy trên Tomcat 9 |
| CI/CD | GitHub Actions, xác thực bằng OIDC |
| Kiến trúc deploy | EC2 + ASG + AMI bất biến build bằng Packer |
| Vị trí repo | `ducnghiaaa/nghiand224`, nhánh `projects/devops`; `main` chứa README index (xem mục 3.2) |
| Vòng đời | **Không chạy 24/7.** Portfolio thể hiện qua repo, lịch sử CI, ảnh và video |

**Chi phí ước tính khi hạ tầng sống**, giá Singapore (Singapore đắt hơn us-east-1 khoảng 25-30%):

| Thành phần | ~USD/giờ |
| --- | --- |
| Application Load Balancer | 0,025 |
| NAT Gateway (một cái) | 0,059 |
| RDS db.t3.micro, Single-AZ | 0,026 |
| 2× EC2 t3.micro | 0,026 |
| **Tổng** | **≈ 0,14** |

Với 8 giờ/tuần → **≈$5/tháng**. Ngân sách không phải là rủi ro; **quên `destroy` mới là rủi ro**. Các con số trên là ước tính; Tuần 5 sẽ đo lại bằng Cost Explorer và đưa số thật vào README.

---

## 2. Tình trạng khởi điểm của codebase

Codebase nhận về ở trạng thái chưa từng chạy được: `terraform validate` thất bại ngay từ lệnh đầu tiên. Đây là danh sách công việc cần xử lý, đã kiểm chứng bằng cách đọc từng file.

### Lỗi chặn (khiến hạ tầng không thể dựng)

| # | Vấn đề | Vị trí |
| --- | --- | --- |
| B1 | **Trùng tên security group.** Cả module `alb` lẫn module `security` đều tạo SG tên `${environment}-alb-sg` → `terraform apply` thất bại với `InvalidGroup.Duplicate` | `modules/alb/main.tf:54`, `modules/security/main.tf:5` |
| B2 | **Ứng dụng không bao giờ được cài.** `user_data` cài Tomcat nhưng không deploy file WAR nào | `modules/asg/main.tf:11-19` |
| B3 | **Health check chắc chắn thất bại.** ALB kiểm tra `/` và chờ HTTP 200, nhưng app dùng Spring Security nên trả 302 redirect → mọi instance unhealthy vĩnh viễn | `modules/alb/main.tf:29` |
| B4 | `aws_eip.vpc = true` đã bị gỡ bỏ ở AWS provider 5.x (phải dùng `domain = "vpc"`) | `modules/vpc/main.tf:55` |
| B5 | **Khai báo output trùng lặp.** Ba file `variables.tf` chứa nguyên các khối `output` đã có trong `outputs.tf` cùng thư mục. Terraform gộp mọi file `.tf` trong một thư mục nên đây là lỗi `Duplicate output definition` | `modules/alb/variables.tf:23-36`, `modules/asg/variables.tf:53-56`, `modules/rds/variables.tf:41-56` |

### Lỗi bảo mật

| # | Vấn đề | Vị trí |
| --- | --- | --- |
| S1 | Endpoint RDS, username và password nằm plaintext trong source | `Java-Login-App/src/main/resources/application.properties` |
| S2 | DB password truyền qua biến Terraform → lưu plaintext trong state file | `infrastructure/main.tf:54` |
| S3 | `allowed_ssh_cidr_blocks` mặc định `0.0.0.0/0` — SSH mở cho toàn Internet | `infrastructure/variables.tf:87` |
| S4 | Không có IAM instance profile → không dùng được SSM, CloudWatch agent không có quyền gửi log | `modules/asg/main.tf:3-32` |
| S5 | Tạo security group cho bastion nhưng **không tồn tại bastion instance nào** — code chết | `modules/security/main.tf:96` |
| S6 | Backend S3 bị comment toàn bộ → state nằm ở máy local, không có lock | `infrastructure/main.tf:12-17` |
| S7 | **SQL Injection.** Nối chuỗi thẳng vào câu SQL ở cả luồng đăng nhập lẫn đăng ký. Gõ `' OR '1'='1` là vào thẳng | `login.java:39`, `register.java:45` |
| S8 | **Mật khẩu người dùng lưu plaintext** trong bảng `Employee` — không băm, dù `spring-boot-starter-security` đã có sẵn trong `pom.xml` | `register.java:45` |
| S9 | **`settings.xml` chứa credentials Maven/JFrog** (email, mật khẩu, URL instance) — thông tin đăng nhập không thuộc về dự án này và tuyệt đối không được đẩy lên repo public | `Java-Login-App/settings.xml:6-13` |

### Lỗi vận hành và chi phí

| # | Vấn đề | Vị trí |
| --- | --- | --- |
| O1 | **Hai NAT Gateway** (mỗi public subnet một cái) — gấp đôi chi phí cần thiết | `modules/vpc/main.tf:64-73` |
| O2 | **Không có scaling policy nào.** Mang tên "Auto Scaling" nhưng ASG không bao giờ scale | `modules/asg/main.tf` |
| O3 | Mọi alarm đều có `alarm_actions = []` → không thông báo cho ai | `modules/monitoring/main.tf:25,47,70` |
| O4 | AMI hardcode `ami-0c02fb55956c7d316` — chỉ tồn tại ở us-east-1, không dùng được ở Singapore | `modules/asg/main.tf:5` |
| O5 | Không có `outputs.tf` ở root → apply xong không biết DNS name của ALB | `infrastructure/` |
| O6 | AWS provider ghim `~> 4.0`, lạc hậu hai major version | `infrastructure/main.tf:8` |
| O7 | Không có khối `instance_refresh` → không có cơ chế rollout | `modules/asg/main.tf:34-61` |
| O8 | Tài liệu mô tả thư mục `environments/dev,prod` không tồn tại; toàn bộ hướng dẫn là lệnh AWS CLI thủ công, không khớp với Terraform bên dưới | `infrastructure/README.md:43-45` |
| O9 | **Sai tên bảng.** Tài liệu hướng dẫn tạo bảng `users` với cột `id/username/password/email/created_at`, nhưng code truy vấn bảng `Employee` với cột `first_name/last_name/email/username/password/regdate` | `register.java:45` |

**Tổng: 23 vấn đề.** Sửa hết và ghi lại là một phần của tiêu chí hoàn thành.

---

## 3. Kiến trúc

Mô hình 3 tầng: ALB công khai → EC2 trong private subnet → RDS trong private subnet. Ba quyết định thiết kế đáng chú ý.

### 3.1 Ba quyết định thiết kế

**(a) Không có bastion host — truy cập qua AWS Systems Manager Session Manager**

Không mở port 22 ở bất kỳ đâu, không quản lý SSH key, không tốn một EC2 bastion. Instance nhận IAM instance profile có quyền SSM; agent kết nối ra ngoài qua NAT Gateway.

*Đã cân nhắc và loại bỏ phương án VPC interface endpoint cho SSM.* Endpoint chỉ đáng tiền khi bỏ hẳn NAT Gateway, nhưng khi đó lại phải thêm endpoint cho Secrets Manager và CloudWatch Logs — tổng chi phí cao hơn. Cụ thể ở Singapore: 3 endpoint × 2 AZ ≈ $0,078/giờ so với NAT Gateway $0,059/giờ. Đã có NAT rồi thì cắm thêm endpoint là trả tiền hai lần cho cùng một đường ra Internet.

- *Bảo mật:* không có cổng vào nào từ Internet ngoài ALB; mọi phiên truy cập ghi log vào CloudWatch.
- *SAA-C03:* Domain 1 — IAM role, least privilege.

**(b) Biến `nat_mode`: chuyển giữa NAT Gateway và NAT instance**

Module `vpc` nhận biến `nat_mode` với hai giá trị:

- `"gateway"` — **một** NAT Gateway dùng chung (≈$43/tháng ở Singapore nếu chạy 24/7)
- `"instance"` — một EC2 `t4g.nano` làm NAT (≈$4/tháng)

README ghi bảng so sánh chi phí **đo bằng số thật từ Cost Explorer**, kèm phân tích đánh đổi: NAT instance là điểm chết đơn lẻ, băng thông giới hạn theo loại instance, và phải tự vá lỗi hệ điều hành; NAT Gateway được quản lý sẵn và có sẵn dự phòng trong một AZ.

- *SAA-C03:* Domain 4 — đây đúng là một task statement trong blueprint.

**(c) Không có mật khẩu database ở bất kỳ đâu**

RDS bật `manage_master_user_password`: tự sinh master password, lưu trong Secrets Manager và tự xoay vòng. Không có biến `db_password` trong Terraform, không có mật khẩu trong state file, không có gì trong repo. Ứng dụng đọc secret lúc khởi động qua IAM instance profile.

- *SAA-C03:* Domain 1 — Secrets Manager so với Parameter Store, mã hoá at-rest.

### 3.2 Chiến lược repo và nhánh

Project nằm trong repo tổng hợp portfolio `ducnghiaaa/nghiand224`, theo mô hình **mỗi project một nhánh**:

| Nhánh | Nội dung |
| --- | --- |
| `main` (default) | Chỉ có `README.md` — trang portfolio liệt kê mọi project kèm link |
| `projects/devops` | Toàn bộ project này |
| *(sau này)* `projects/<tên>` | Các project khác |

Link từ README ở `main`:

```markdown
- [DevOps Project 01 — Java 3-Tier trên AWS](https://github.com/ducnghiaaa/nghiand224/tree/projects/devops/DevOps-Project-01)
```

GitHub sẽ render `README.md` nằm trong thư mục đó ngay khi bấm vào.

**Hệ quả cần xử lý (đã cân nhắc và chấp nhận):**

1. **Badge CI phải chỉ định nhánh:**
   `![CI](https://github.com/ducnghiaaa/nghiand224/actions/workflows/ci.yml/badge.svg?branch=projects/devops)`
2. **Luồng PR nhắm vào `projects/devops`, không phải `main`.** Làm việc trên nhánh `feat/<tên>`, mở PR vào `projects/devops`.
3. **`workflow_dispatch` chỉ hiện nút bấm nếu file workflow tồn tại ở default branch.** Vì file nằm ở `projects/devops`, kích hoạt bằng `gh workflow run --ref projects/devops` từ dòng lệnh.
4. **Thống kê ngôn ngữ và code search của repo chỉ tính `main`** → repo sẽ hiện "Markdown 100%". Đánh đổi đã biết và chấp nhận.

### 3.3 Cấu trúc thư mục đích

Bên trong nhánh `projects/devops`:

```
DevOps-Project-01/
├── README.md
├── docs/
│   ├── architecture.png        # Sơ đồ kiến trúc
│   └── evidence/               # Ảnh chụp, số liệu chi phí, video demo
├── Java-Login-App/
├── packer/
│   ├── app.pkr.hcl             # Bake AMI: Corretto 11 + Tomcat 9 + WAR + CW agent
│   └── scripts/
├── infrastructure/
│   ├── bootstrap/              # S3 state bucket + DynamoDB lock (apply một lần)
│   ├── envs/dev/               # backend.hcl + dev.tfvars
│   ├── main.tf, variables.tf, outputs.tf
│   └── modules/
│       ├── vpc/                # + nat_mode, một NAT Gateway
│       ├── security/           # không bastion, không port 22
│       ├── alb/                # health check /actuator/health
│       ├── asg/                # + instance profile, + instance_refresh, + scaling policy
│       ├── rds/                # manage_master_user_password
│       ├── monitoring/         # + SNS topic, + dashboard
│       └── iam/                # instance profile + GitHub OIDC role
└── .github/workflows/
    ├── ci.yml
    ├── terraform-plan.yml
    ├── infra-apply.yml         # input: action = apply | destroy
    └── deploy.yml
```

### 3.4 Công việc ở tầng ứng dụng

Giữ nguyên chức năng login/register. Bốn thay đổi:

1. **Xoá credentials khỏi source** (S1) và **xoá `settings.xml`** (S9) — dự án dùng GitHub Actions chứ không dùng JFrog. Cấu hình DB đọc từ biến môi trường do user-data bơm vào sau khi lấy secret từ Secrets Manager.
2. **Sửa SQL Injection** (S7): thay nối chuỗi bằng `PreparedStatement` với tham số ràng buộc. **Băm mật khẩu** bằng `BCryptPasswordEncoder` (S8) — `spring-boot-starter-security` đã có sẵn trong `pom.xml`.
3. **Thêm Spring Boot Actuator**, mở đúng endpoint `/actuator/health`, cấu hình Spring Security cho phép truy cập ẩn danh endpoint này. ALB health check trỏ vào đây (sửa B3).
4. **Thêm Flyway migration** tạo bảng **`Employee`** đúng theo cột mà code thực sự dùng — `first_name`, `last_name`, `email`, `username`, `password`, `regdate` (O9).

SonarCloud bắt được SQLi ở lần quét đầu tiên, bạn sửa rồi quét lại thấy sạch — đó là một bằng chứng DevSecOps đáng chụp ảnh trước và sau.

---

## 4. CI/CD

Bốn workflow, tách bạch trách nhiệm. Tất cả nằm ở `.github/workflows/` trên nhánh `projects/devops`, mọi trigger nhắm vào nhánh đó.

### 4.1 `ci.yml` — chạy trên mọi push và pull request

Trigger: `push: branches: [projects/devops, 'feat/**']` và `pull_request: branches: [projects/devops]`.

Không đụng tới AWS, không tốn tiền:

1. `mvn verify` (biên dịch + unit test)
2. Quét SonarCloud
3. `tflint` + `checkov` trên thư mục `infrastructure/`
4. Upload file WAR làm build artifact

Đây là workflow tạo badge xanh và lịch sử chạy — tài sản portfolio tồn tại vĩnh viễn.

### 4.2 `terraform-plan.yml` — chạy trên pull request

Trigger: `pull_request: branches: [projects/devops]`.

Chạy `terraform plan` rồi **bot comment kết quả plan vào PR**.

### 4.3 `infra-apply.yml` — kích hoạt bằng tay

`workflow_dispatch` với input `action: apply | destroy`, gắn `environment: dev` yêu cầu phê duyệt thủ công. **Không bao giờ auto-apply hạ tầng.**

Kích hoạt: `gh workflow run infra-apply.yml --ref projects/devops -f action=apply`

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
| `gha-terraform-plan` | `repo:ducnghiaaa/nghiand224:pull_request` | Chỉ đọc |
| `gha-terraform-apply` | `repo:ducnghiaaa/nghiand224:ref:refs/heads/projects/devops` | Tạo/sửa/xoá hạ tầng |

Điểm mấu chốt: token của sự kiện `pull_request` mang `sub` là `...:pull_request`, **không** phải `...:ref:refs/heads/<nhánh>`. Khai báo một role duy nhất theo `ref:` sẽ khiến `terraform-plan.yml` thất bại với lỗi `AssumeRoleWithWebIdentity`.

`ci.yml` không assume role nào vì không đụng tới AWS.

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
2. **README** — sơ đồ kiến trúc, bảng chi phí có số thật, quyết định thiết kế và lý do
3. **Chất lượng code Terraform** — module sạch, có tflint và checkov chạy trong CI

Do đó **mỗi giai đoạn phải kết thúc bằng bằng chứng lưu được**, thu thập khi hạ tầng còn sống, trước khi `destroy`. Tất cả lưu vào `docs/evidence/`.

---

## 6. Lộ trình

Mỗi tuần là một giai đoạn **độc lập, dừng lại được**, có kế hoạch triển khai chi tiết riêng.

### Tuần 0 — Nền móng an toàn (1-2 giờ)

Đưa code vào git đúng thứ tự: viết `.gitignore` và xoá mọi credential **trước** commit đầu tiên (commit rồi mới xoá thì secret nằm vĩnh viễn trong lịch sử git). Viết README index ở nhánh `main` và README của project. Bật MFA, tạo IAM user riêng thay root, đặt AWS Budget alert ở mức $20 và $30.

**Bằng chứng:** ảnh chụp cấu hình Budget alert.

### Tuần 1 — Nền tảng Terraform (6-8 giờ)

`bootstrap/` tạo S3 state bucket (versioning, mã hoá, chặn public access) + DynamoDB lock table. Nâng AWS provider lên `~> 5.x`, thêm `default_tags`. Viết `outputs.tf` ở root. Sửa 5 lỗi chặn. Bỏ bastion và mọi tham chiếu SSH. Giảm còn một NAT Gateway và thêm biến `nat_mode`.

**Điều kiện hoàn thành:** `terraform apply` thành công từ đầu.
**Bằng chứng:** ảnh VPC Resource Map, log của lần apply đầu tiên.

### Tuần 2 — Dọn app, IAM, RDS an toàn (6-8 giờ)

Sửa SQL Injection và băm mật khẩu. Spring Boot đọc DB credentials từ biến môi trường; thêm Actuator và mở `/actuator/health`; thêm Flyway migration tạo bảng `Employee`. RDS bật `manage_master_user_password`. Module `iam` cấp instance profile: SSM + CloudWatch + đọc secret.

**Bằng chứng:** ảnh phiên SSM Session Manager, ảnh secret trong Secrets Manager, ảnh SonarCloud trước và sau khi sửa SQLi.

### Tuần 3 — Packer và deploy thật (6-8 giờ)

`packer/app.pkr.hcl`: Amazon Linux 2023 + Amazon Corretto 11 + **Tomcat 9** + WAR + CloudWatch agent (B2).

- Bắt buộc Tomcat 9, không phải Tomcat 10: Spring Boot 2.7 dùng `javax.servlet`, còn Tomcat 10 đã chuyển sang `jakarta.servlet`.
- AL2023 không có sẵn gói `tomcat` trong repo `dnf`, nên script provisioner tải bản Tomcat 9 từ Apache và tạo systemd unit.

ASG chuyển sang `data source` lọc AMI theo tag (O4), thêm `instance_refresh` (O7), thêm target-tracking scaling policy ở mức CPU 50% (O2). Đổi `health_check_type` về `"ELB"`.

**Bằng chứng:** **video app login/register chạy qua ALB** — tài sản portfolio quan trọng nhất. Kèm ảnh target group toàn bộ healthy.

### Tuần 4 — Tự động hoá CI/CD (6-8 giờ)

OIDC provider + hai IAM role. Bốn workflow ở mục 4. Kết nối SonarCloud, tflint, checkov.

**Bằng chứng:** ảnh PR có bot comment `terraform plan`; lịch sử Actions xanh.

### Tuần 5 — Monitoring, kiểm chứng chịu lỗi, tài liệu (6-8 giờ)

CloudWatch: log group nhận `catalina.out`, dashboard, alarm (CPU, RDS connections, ALB 5xx, unhealthy host) nối vào SNS topic gửi email (O3).

**Thử nghiệm chịu lỗi:** tự tay terminate một instance, đo thời gian ASG phục hồi. Đưa con số thật vào README.

**Đo chi phí:** chạy `nat_mode=gateway` và `nat_mode=instance`, lấy số thật từ Cost Explorer, lập bảng so sánh.

Viết lại README hoàn chỉnh, vẽ sơ đồ kiến trúc, dựng video demo.

**Bằng chứng:** ảnh dashboard, biểu đồ phục hồi kèm mốc thời gian, bảng chi phí có số thật.

### Tuần 6 — Tuỳ chọn: ACM và Route 53 HTTPS

Mua domain rẻ trên Route 53 (`.click` ~$3/năm, `.link` ~$5/năm), tạo hosted zone ($0,50/tháng), xin ACM cert (miễn phí, xác thực qua DNS), thêm listener HTTPS và chuyển hướng HTTP sang HTTPS.

Lý do đáng làm: trong video demo, thanh địa chỉ hiện `https://app.<domain>` kèm ổ khoá xanh, thay vì `dev-alb-1234.ap-southeast-1.elb.amazonaws.com` kèm chữ "Not secure".

Bỏ giai đoạn này không ảnh hưởng gì tới các giai đoạn trước.

---

## 7. Tiêu chí hoàn thành

1. Từ repo sạch, chạy `terraform apply` rồi `deploy.yml` → ứng dụng hoạt động trong **dưới 20 phút**, **không một thao tác thủ công nào**.
2. **Không có secret nào** trong repo lẫn trong state file.
3. Toàn bộ 23 vấn đề ở mục 2 đã được xử lý và ghi lại trong README.
4. CI xanh; `tflint` và `checkov` chạy trong pipeline.
5. Thu đủ năm loại bằng chứng trong `docs/evidence/`: video demo, ảnh dashboard, ảnh phiên SSM, ảnh PR có plan comment, bảng chi phí.
6. `main` có README index, link dẫn thẳng vào project và **đã bấm thử thấy README project hiện ra đúng**.

---

## 8. Rủi ro

| Rủi ro | Cách giảm thiểu |
| --- | --- |
| Quên `destroy` → cháy tiền | Budget alert $20/$30 từ tuần 0; `infra-apply.yml` có input `destroy` bấm một lệnh |
| Packer bake chậm (8-12 phút mỗi lần) làm nản | Tuần 3 bake bằng tay trước để nắm quy trình, tự động hoá ở tuần 4 |
| AMI cũ tích tụ gây tốn phí lưu trữ | Gắn tag `version` và dọn thủ công ở cuối mỗi tuần |
| Hết thời gian ở tuần 5 | Tuần 6 vốn đã tuỳ chọn; nếu thiếu nữa thì cắt phần thử nghiệm chịu lỗi, giữ phần tài liệu |
| Spring Boot 2.7 đã hết hỗ trợ chính thức | Giữ nguyên phiên bản — nâng cấp Spring Boot nằm ngoài phạm vi và không phục vụ mục tiêu DevOps |
