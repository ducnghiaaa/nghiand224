# Tuần 0 + Tuần 1 — Nền móng an toàn và Terraform chạy được

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đưa toàn bộ project vào git mà không rò rỉ một credential nào, rồi sửa 5 lỗi chặn để `terraform apply` chạy thành công từ đầu.

**Architecture:** Terraform root module nằm ở `infrastructure/`, dùng backend S3 với DynamoDB lock được tạo sẵn bởi một cấu hình `bootstrap/` riêng biệt. Giá trị theo môi trường nằm ở `infrastructure/envs/dev/` dưới dạng partial backend config (`backend.hcl`) và biến (`dev.tfvars`). Truy cập máy chủ hoàn toàn qua SSM Session Manager, không có bastion và không mở port 22.

**Tech Stack:** Terraform 1.9.8, AWS provider ~> 5.0, AWS CLI 2.34, GitHub CLI 2.92.

## Global Constraints

- **Region: `ap-southeast-1` (Singapore)** cho mọi tài nguyên hạ tầng.
  Ngoại lệ duy nhất: API **AWS Budgets chỉ có endpoint ở `us-east-1`**, nên lệnh `aws budgets` phải kèm `--region us-east-1`. Đây là giới hạn của AWS, không phải nhầm lẫn.
- **Availability zones:** `ap-southeast-1a`, `ap-southeast-1b`.
- **Nhánh làm việc:** `projects/devops`. Nhánh tính năng đặt tên `feat/<tên>`, PR nhắm vào `projects/devops`.
- **Thư mục gốc project trong repo:** `DevOps-Project-01/`. Mọi đường dẫn trong kế hoạch này là tương đối so với thư mục đó, trừ khi ghi rõ khác.
- **Terraform provider:** `hashicorp/aws` phiên bản `~> 5.0`. Không dùng `~> 4.0`.
- **Không có secret nào được commit.** Không có mật khẩu, access key, hay endpoint RDS thật trong bất kỳ file nào được git theo dõi.
- **`environment = "dev"`** là môi trường duy nhất trong phạm vi kế hoạch này.
- **Ngân sách:** luôn `terraform destroy` sau khi thu thập xong bằng chứng.
- **Đặt tên tài nguyên:** tiền tố `${var.environment}-`.
- **Mọi bằng chứng lưu vào** `docs/evidence/`.

---

## Cấu trúc file

**Tạo mới:**

| File | Trách nhiệm |
| --- | --- |
| `.gitignore` | Chặn state, tfvars có secret, artifact build, file OS |
| `README.md` | Tài liệu project — file GitHub render khi bấm link từ `main` |
| `docs/evidence/.gitkeep` | Giữ thư mục bằng chứng trong git |
| `infrastructure/bootstrap/main.tf` | S3 state bucket + DynamoDB lock table. Apply một lần, state để local |
| `infrastructure/bootstrap/outputs.tf` | In ra tên bucket và table để điền vào `backend.hcl` |
| `infrastructure/envs/dev/backend.hcl` | Partial backend config cho môi trường dev |
| `infrastructure/envs/dev/dev.tfvars` | Giá trị biến cho dev. **Không bao giờ chứa secret** |
| `infrastructure/outputs.tf` | Output ở root: DNS của ALB, endpoint RDS, tên ASG |

**Sửa:**

| File | Thay đổi |
| --- | --- |
| `Java-Login-App/src/main/resources/application.properties` | Thay credentials hardcode bằng placeholder biến môi trường |
| `Java-Login-App/settings.xml` | **Xoá file** — chứa credentials không thuộc dự án này |
| `infrastructure/README.md` | **Xoá file** — mô tả cấu trúc thư mục không tồn tại và hướng dẫn không khớp code (O8) |
| `infrastructure/main.tf` | Provider `~> 5.0`, `default_tags`, backend S3, nối lại các module |
| `infrastructure/variables.tf` | Bỏ `key_name`, `db_password`, `allowed_ssh_cidr_blocks`; thêm `nat_mode`, `db_instance_class`, `db_multi_az`, `health_check_path` |
| `infrastructure/modules/alb/variables.tf` | Xoá các khối `output` bị trùng; thêm `security_group_id`, `health_check_path` |
| `infrastructure/modules/alb/main.tf` | Xoá security group tự tạo; nhận SG từ biến |
| `infrastructure/modules/asg/variables.tf` | Xoá khối `output` bị trùng; bỏ `key_name` |
| `infrastructure/modules/asg/main.tf` | Bỏ `key_name` và AMI hardcode; `health_check_type = "EC2"` tạm thời |
| `infrastructure/modules/rds/variables.tf` | Xoá các khối `output` bị trùng; bỏ `db_password`; thêm `instance_class`, `multi_az` |
| `infrastructure/modules/rds/main.tf` | `manage_master_user_password = true`; `instance_class` và `multi_az` lấy từ biến |
| `infrastructure/modules/rds/outputs.tf` | Thêm `master_user_secret_arn` |
| `infrastructure/modules/security/main.tf` | Xoá security group bastion và rule port 22 |
| `infrastructure/modules/security/variables.tf` | Bỏ `allowed_ssh_cidr_blocks` |
| `infrastructure/modules/security/outputs.tf` | Bỏ output bastion |
| `infrastructure/modules/vpc/main.tf` | `aws_eip.domain`; một NAT Gateway; `nat_mode` |
| `infrastructure/modules/vpc/variables.tf` | Thêm `nat_mode`, `nat_instance_type` |
| `infrastructure/modules/vpc/outputs.tf` | Sửa output NAT cho khớp cả hai chế độ |

---

# TUẦN 0 — Nền móng an toàn

### Task 1: Đưa code vào git mà không rò rỉ credential

Đây là task quan trọng nhất trong toàn kế hoạch. Repo là **public**. Một khi credential đã vào lịch sử git, xoá ở commit sau vẫn không cứu được — phải viết lại toàn bộ lịch sử. Làm đúng thứ tự: **dọn trước, commit sau**.

**Files:**
- Create: `.gitignore`
- Create: `docs/evidence/.gitkeep`
- Modify: `Java-Login-App/src/main/resources/application.properties`
- Delete: `Java-Login-App/settings.xml`
- Delete: `README.md`, `infrastructure/README.md` (thay bằng tài liệu của Task 2)

**Interfaces:**
- Consumes: không có
- Produces: nhánh `projects/devops` chứa toàn bộ source, không có secret. Các task sau đều giả định code đã nằm trong git.

- [ ] **Bước 1: Xác nhận chưa có gì được commit (kiểm chứng trước khi sửa)**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git ls-files DevOps-Project-01/ | grep -v '^DevOps-Project-01/docs/' | head
```

Kỳ vọng: **không in ra dòng nào**. Nếu có dòng nào hiện ra nghĩa là code đã bị commit từ trước và credential đã nằm trong lịch sử — dừng lại, báo lại để xử lý bằng `git filter-repo`.

- [ ] **Bước 2: Viết `.gitignore`**

Tạo `DevOps-Project-01/.gitignore`:

```gitignore
# ---- Terraform ----
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# Chặn mọi tfvars theo mặc định, chỉ mở ngoại lệ cho file môi trường
# (các file này đã được rà soát và KHÔNG được phép chứa secret)
*.tfvars
*.tfvars.json
!infrastructure/envs/*/*.tfvars

# ---- Packer ----
packer_cache/
*.pkrvars.hcl

# ---- Java / Maven ----
target/
*.class
*.war
*.jar

# ---- Maven settings (có thể chứa credential) ----
settings.xml

# ---- IDE ----
.idea/
*.iml
.vscode/

# ---- OS ----
.DS_Store
Thumbs.db
```

Lưu ý: **không** ignore `.terraform.lock.hcl`. File lock đó cần được commit để mọi lần chạy dùng đúng một phiên bản provider.

- [ ] **Bước 3: Xoá các file chứa credential và tài liệu không dùng được**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01
rm Java-Login-App/settings.xml
rm README.md
rm infrastructure/README.md
```

- `settings.xml` chứa email và mật khẩu Maven/JFrog không thuộc dự án này. Project dùng GitHub Actions chứ không dùng JFrog nên không cần file này. Nó cũng đã nằm trong `.gitignore` để phòng trường hợp Maven sinh lại.
- Hai file README bị xoá vì mô tả cấu trúc thư mục không tồn tại và hướng dẫn bằng lệnh AWS CLI thủ công không khớp với Terraform (O8). Task 2 viết lại từ đầu.

- [ ] **Bước 4: Thay credentials trong `application.properties`**

Ghi đè toàn bộ `Java-Login-App/src/main/resources/application.properties`:

```properties
spring.mvc.view.prefix=/pages/
spring.mvc.view.suffix=.jsp

# Cau hinh DB duoc bom vao luc chay bang bien moi truong.
# Khong bao gio hardcode credential trong source control.
# Gia tri mac dinh chi phuc vu chay local voi MySQL trong Docker.
spring.datasource.url=${DB_URL:jdbc:mysql://localhost:3306/UserDB}
spring.datasource.username=${DB_USERNAME:root}
spring.datasource.password=${DB_PASSWORD:}
```

Cú pháp `${BIEN:giá-trị-mặc-định}` của Spring cho phép chạy local mà không cần khai báo gì, đồng thời trên AWS thì user-data sẽ bơm giá trị thật vào.

- [ ] **Bước 5: Tạo thư mục bằng chứng**

```bash
mkdir -p docs/evidence && touch docs/evidence/.gitkeep
```

- [ ] **Bước 6: Chạy kiểm tra rò rỉ — đây là "test" của task này**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01
grep -rniE "Admin123|prdevop26|edshopdpt8|cdgiiabcm6en|rds\.amazonaws\.com" . \
  --exclude-dir=.git --exclude-dir=target --exclude-dir=docs 2>/dev/null
```

Kỳ vọng: **không in ra dòng nào.** Nếu còn dòng nào, sửa file đó rồi chạy lại. Không được sang bước tiếp theo khi lệnh này còn output.

(Loại trừ `docs/` vì tài liệu thiết kế có trích dẫn các chuỗi này để mô tả vấn đề cần sửa — đó là văn bản mô tả, không phải credential đang hoạt động.)

- [ ] **Bước 7: Xem trước danh sách file sẽ được commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add --dry-run DevOps-Project-01/ | grep -iE "settings\.xml|\.tfstate|\.tfvars|target/"
```

Kỳ vọng: **không in ra dòng nào.** Đây là lưới an toàn thứ hai, xác nhận `.gitignore` thực sự có tác dụng.

- [ ] **Bước 8: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add -A DevOps-Project-01/
git commit -m "Add application source and Terraform modules

Brings the Java login app and the infrastructure modules under version
control. Removes settings.xml, which held Maven credentials unrelated to
this project, and replaces the hardcoded database endpoint and password in
application.properties with environment variable placeholders so nothing
sensitive enters git history on this public repo."
git push origin projects/devops
```

- [ ] **Bước 9: Xác minh trên GitHub**

```bash
gh api repos/ducnghiaaa/nghiand224/contents/DevOps-Project-01/Java-Login-App/settings.xml?ref=projects/devops 2>&1 | head -3
```

Kỳ vọng: lỗi `Not Found`. Nghĩa là file không tồn tại trên remote.

---

### Task 2: README của project

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: không có
- Produces: `README.md` ở gốc `DevOps-Project-01/` — file GitHub render khi bấm link từ README index ở nhánh `main`

- [ ] **Bước 1: Viết `README.md`**

Đây là khung; các mục đánh dấu 🚧 điền dần ở các tuần sau. Không để trống mục nào đã làm được.

````markdown
# DevOps Project 01 — Java 3-Tier trên AWS

Ứng dụng Java Spring Boot chạy trên kiến trúc 3 tầng ở AWS, dựng và
triển khai hoàn toàn tự động bằng Terraform, Packer và GitHub Actions.

**Region:** ap-southeast-1 (Singapore)

## Kiến trúc

Ba tầng, mỗi tầng một ranh giới bảo mật:

| Tầng | Thành phần | Vị trí mạng |
| --- | --- | --- |
| Presentation | Application Load Balancer | Public subnet, 2 AZ |
| Application | EC2 trong Auto Scaling Group, Tomcat 9 | Private subnet, 2 AZ |
| Data | RDS MySQL 8.0 | Private subnet, 2 AZ |

🚧 *Sơ đồ kiến trúc sẽ bổ sung ở Tuần 5*

## Quyết định thiết kế

**Không có bastion host.** Truy cập máy chủ qua AWS Systems Manager Session
Manager. Không mở port 22 ở bất kỳ security group nào, không quản lý SSH
key, và mọi phiên truy cập được ghi log.

Tôi đã cân nhắc dùng VPC interface endpoint cho SSM rồi loại bỏ: hạ tầng
đã có NAT Gateway nên SSM agent kết nối ra ngoài được rồi. Ba endpoint ×
2 AZ tốn khoảng \$0,078/giờ, còn NAT Gateway chỉ \$0,059/giờ — cắm thêm
endpoint là trả tiền hai lần cho cùng một đường ra Internet. Endpoint chỉ
đáng tiền khi bỏ hẳn NAT, nhưng khi đó lại phải thêm endpoint cho Secrets
Manager và CloudWatch Logs, tổng còn cao hơn nữa.

**Không có mật khẩu database ở bất kỳ đâu.** RDS bật
`manage_master_user_password`, tự sinh và tự xoay vòng mật khẩu trong
Secrets Manager. Không có biến `db_password` trong Terraform, không có mật
khẩu trong state file, không có gì trong repo.

**Biến `nat_mode`.** Cùng một cấu hình chạy được với NAT Gateway (được
quản lý sẵn) hoặc NAT instance `t4g.nano` (rẻ hơn khoảng 10 lần). 🚧 *Bảng
so sánh chi phí đo thật sẽ bổ sung ở Tuần 5*

## Chi phí

Chi phí khi hạ tầng đang chạy, giá ap-southeast-1:

| Thành phần | ~USD/giờ |
| --- | --- |
| Application Load Balancer | 0,025 |
| NAT Gateway | 0,059 |
| RDS db.t3.micro Single-AZ | 0,026 |
| 2× EC2 t3.micro | 0,026 |
| **Tổng** | **≈ 0,14** |

Hạ tầng được `destroy` sau mỗi buổi làm việc, nên chi phí thực tế khoảng
\$5/tháng. 🚧 *Số đo thật từ Cost Explorer sẽ bổ sung ở Tuần 5*

## Cách chạy

🚧 *Sẽ bổ sung ở Tuần 1*
````

- [ ] **Bước 2: Kiểm tra file tồn tại và không còn README cũ**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01
test -f README.md && echo "OK   README.md"
test -f infrastructure/README.md && echo "LOI  infrastructure/README.md van con" || echo "OK   infrastructure/README.md da xoa"
```

Kỳ vọng: `OK README.md` và `OK infrastructure/README.md da xoa`.

- [ ] **Bước 3: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add -A DevOps-Project-01/
git commit -m "Add project README

Documents the three-tier architecture, the design decisions behind it, and
the running cost in ap-southeast-1. Records why VPC interface endpoints
for SSM were considered and rejected on cost grounds."
git push origin projects/devops
```

- [ ] **Bước 4: Xác minh link từ nhánh `main` render đúng**

Mở trong trình duyệt:
`https://github.com/ducnghiaaa/nghiand224/tree/projects/devops/DevOps-Project-01`

Kỳ vọng: GitHub render `README.md` mới ngay bên dưới danh sách file.

---

### Task 3: Công cụ, AWS credentials và Budget alert

**Files:** không sửa file nào trong repo. Task này cấu hình máy local và tài khoản AWS.

**Interfaces:**
- Consumes: không có
- Produces: `aws sts get-caller-identity` chạy được với region `ap-southeast-1` — mọi task Terraform sau đó phụ thuộc vào điều này.

- [ ] **Bước 1: Xác nhận trạng thái hiện tại**

```bash
aws sts get-caller-identity
```

Hiện tại lệnh này báo lỗi `InvalidClientTokenId` — credentials không hợp lệ. Đây là "test đang fail" của task.

- [ ] **Bước 2: Tạo IAM user riêng cho việc phát triển (làm trên AWS Console)**

Không dùng root account để chạy Terraform. Trên Console:

1. Bật MFA cho root account nếu chưa bật: **IAM → Security credentials → Multi-factor authentication**.
2. **IAM → Users → Create user**, tên `terraform-dev`.
3. Gắn policy `AdministratorAccess`. *(Hẹp lại quyền là việc đáng làm, nhưng làm ngay từ đầu sẽ khiến bạn mất hàng giờ debug lỗi thiếu quyền. Tuần 4 sẽ thay bằng OIDC role có quyền tối thiểu.)*
4. **Security credentials → Create access key**, chọn mục đích **Command Line Interface (CLI)**.

IAM là dịch vụ toàn cầu nên không cần chọn region ở bước này.

- [ ] **Bước 3: Cấu hình AWS CLI với region Singapore**

```bash
aws configure --profile nghia-dev
```

Điền: access key, secret key, **region `ap-southeast-1`**, output `json`.

Rồi đặt profile mặc định cho phiên làm việc:

```bash
export AWS_PROFILE=nghia-dev
```

Thêm dòng đó vào `~/.zshrc` để không phải gõ lại mỗi lần mở terminal mới.

- [ ] **Bước 4: Chạy lại kiểm tra**

```bash
aws sts get-caller-identity
aws configure get region
```

Kỳ vọng: JSON có `UserId`, `Account`, `Arn` kết thúc bằng `:user/terraform-dev`; và region in ra `ap-southeast-1`.

**Ghi lại số `Account` — các task sau cần dùng để đặt tên bucket.**

- [ ] **Bước 5: Xác nhận Singapore đủ AZ như kế hoạch giả định**

```bash
aws ec2 describe-availability-zones --region ap-southeast-1 \
  --query 'AvailabilityZones[?State==`available`].ZoneName' --output text
```

Kỳ vọng: có ít nhất `ap-southeast-1a` và `ap-southeast-1b`. Nếu tài khoản của bạn được ánh xạ sang bộ AZ khác, ghi lại tên thật để điền vào `dev.tfvars` ở Task 6.

- [ ] **Bước 6: Đặt Budget alert**

**Lưu ý quan trọng:** API AWS Budgets chỉ có endpoint ở `us-east-1`. Phải chỉ định `--region us-east-1` dù toàn bộ hạ tầng nằm ở Singapore. Budget vẫn theo dõi chi phí của cả tài khoản trên mọi region.

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > /tmp/budget.json <<EOF
{
  "BudgetName": "monthly-30-usd",
  "BudgetLimit": { "Amount": "30", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF

cat > /tmp/budget-notifications.json <<'EOF'
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 66.7,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      { "SubscriptionType": "EMAIL", "Address": "nguyenducnghiaa21@gmail.com" }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      { "SubscriptionType": "EMAIL", "Address": "nguyenducnghiaa21@gmail.com" }
    ]
  }
]
EOF

aws budgets create-budget \
  --region us-east-1 \
  --account-id "$ACCOUNT_ID" \
  --budget file:///tmp/budget.json \
  --notifications-with-subscribers file:///tmp/budget-notifications.json
```

Ngưỡng 66,7% của $30 là $20, và 100% là $30 — đúng hai mốc trong spec.

- [ ] **Bước 7: Xác minh budget đã tạo**

```bash
aws budgets describe-budgets --region us-east-1 \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount}' --output table
```

Kỳ vọng: một dòng `monthly-30-usd` với limit `30`.

- [ ] **Bước 8: Cài các công cụ còn thiếu**

**Cài từng gói một, không gộp.** `brew install a b c` là all-or-nothing ở khâu phân giải tên: một gói không tìm thấy thì cả lệnh dừng và những gói sau không được thử.

Ba gói có sẵn trong homebrew-core:

```bash
for f in checkov openjdk@11 maven; do
  brew install "$f" && echo "$f: OK" || echo "$f: THAT BAI"
done
```

`packer` và `tflint` **không có trong homebrew-core** — chỉ có trong tap của chính nhà phát hành, và Homebrew bản mới bắt buộc `brew trust` trước khi cài, vì formula trong tap là mã Ruby chạy được lệnh tuỳ ý lúc cài:

```bash
brew tap hashicorp/tap
brew tap terraform-linters/tap
brew trust hashicorp/tap
brew trust terraform-linters/tap

brew install hashicorp/tap/packer
brew install terraform-linters/tap/tflint
```

**Ghim Java 11 — bước bắt buộc, không phải tuỳ chọn.**

`brew install maven` kéo theo `openjdk` bản mới nhất (hiện là 26) làm phụ thuộc. Không ghim thì Maven sẽ dùng Java 26 để build một project nhắm Java 11, và lỗi sinh ra rất khó lần.

Thêm khối này vào `~/.zshrc` (không cần `sudo`, và dễ gỡ hơn symlink vào `/Library/Java/JavaVirtualMachines`):

```bash
cp ~/.zshrc ~/.zshrc.bak-$(date +%Y%m%d-%H%M%S)

cat >> ~/.zshrc <<'EOF'

# ===== DevOps-Project-01 =====
export JAVA_HOME="/opt/homebrew/opt/openjdk@11"
export PATH="$JAVA_HOME/bin:$PATH"
export AWS_PROFILE=nghia-dev
# ===== het DevOps-Project-01 =====
EOF
```

**Cẩn thận khi đọc kết quả:** đừng nối `brew install` qua `| tail` hay kết thúc script bằng `echo`. Exit code của pipeline là exit code của lệnh cuối, nên brew hỏng vẫn báo thành công. Dùng `set -o pipefail` hoặc kiểm tra `$?` ngay sau lệnh.

- [ ] **Bước 9: Xác minh toàn bộ công cụ**

**Phải chạy trong shell tương tác.** Zsh chỉ nạp `~/.zshrc` cho shell tương tác, nên `zsh -lc` (login nhưng không tương tác) sẽ báo `JAVA_HOME` và `AWS_PROFILE` rỗng dù cấu hình hoàn toàn đúng. Dùng `zsh -ic`, hoặc mở terminal mới rồi gõ tay:

```bash
zsh -ic '
for c in terraform aws packer java mvn gh tflint checkov docker; do
  printf "%-11s " "$c"
  command -v "$c" >/dev/null 2>&1 && ($c --version 2>&1 | head -1) || echo "CHUA CAI"
done
echo "JAVA_HOME   = $JAVA_HOME"
echo "AWS_PROFILE = $AWS_PROFILE"
mvn -version 2>&1 | grep -i "Java version"
aws sts get-caller-identity --query "[Account,Arn]" --output text
'
```

Kỳ vọng:
- Cả chín công cụ in ra phiên bản, không dòng nào `CHUA CAI`
- `JAVA_HOME` trỏ tới `openjdk@11`
- **`mvn -version` báo `Java version: 11.x`** — nếu ra 26 thì khối `~/.zshrc` chưa có tác dụng, đừng build gì cho tới khi sửa xong
- `aws sts get-caller-identity` trả về ARN của `terraform-dev`

**Dọn profile `[default]` nếu nó chứa credential cũ.** `AWS_PROFILE` trong `~/.zshrc` chỉ có tác dụng ở shell tương tác; script chạy qua cron, CI hay một số IDE sẽ rơi về `[default]` và lỗi `InvalidClientTokenId`. Kiểm tra bằng `aws sts get-caller-identity --profile default`.

- [ ] **Bước 10: Lưu bằng chứng**

Chụp màn hình trang **AWS Budgets** hiển thị budget vừa tạo, lưu vào `docs/evidence/00-budget-alert.png`.

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/docs/evidence/
git commit -m "Add budget alert evidence"
git push origin projects/devops
```

---

# TUẦN 1 — Terraform chạy được

### Task 4: Remote state trên S3 với DynamoDB lock

`bootstrap/` là một cấu hình Terraform tách biệt, state của nó để local. Đây là cách giải bài toán "con gà quả trứng": không thể lưu state trên S3 khi bucket S3 chưa tồn tại.

**Files:**
- Create: `infrastructure/bootstrap/main.tf`
- Create: `infrastructure/bootstrap/outputs.tf`

**Interfaces:**
- Consumes: AWS credentials từ Task 3
- Produces: bucket tên `nghiand224-tfstate-<account_id>` và DynamoDB table `nghiand224-tfstate-lock`, cả hai ở `ap-southeast-1`. Task 6 dùng hai tên này trong `backend.hcl`.

- [ ] **Bước 1: Viết `infrastructure/bootstrap/main.tf`**

```hcl
# Tao noi luu Terraform state. Cau hinh nay tu no dung local state
# (bai toan con ga qua trung: chua co bucket thi khong the luu state len S3).
# Chi can apply MOT LAN, sau do gan nhu khong bao gio dong toi nua.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project   = "DevOps-Project-01"
      ManagedBy = "Terraform"
      Component = "tfstate-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "nghiand224-tfstate-${data.aws_caller_identity.current.account_id}"

  # Chan xoa nham. Muon xoa that thi phai sua dong nay truoc.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning cho phep khoi phuc state neu apply hong giua chung.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State file chua ID tai nguyen va cau hinh ha tang. Khong bao gio duoc public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bang lock chan hai lan apply chay dong thoi lam hong state.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "nghiand224-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

`PAY_PER_REQUEST` nghĩa là chỉ trả tiền theo số lần đọc/ghi. Với vài chục lần `terraform apply` mỗi tháng, chi phí thực tế là **$0,00**.

- [ ] **Bước 2: Viết `infrastructure/bootstrap/outputs.tf`**

```hcl
output "state_bucket_name" {
  description = "Ten S3 bucket luu Terraform state - dien vao envs/*/backend.hcl"
  value       = aws_s3_bucket.tfstate.id
}

output "state_lock_table_name" {
  description = "Ten DynamoDB table dung de lock state"
  value       = aws_dynamodb_table.tfstate_lock.name
}
```

- [ ] **Bước 3: Chạy validate — kỳ vọng PASS**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure/bootstrap
terraform init
terraform validate
```

Kỳ vọng: `Success! The configuration is valid.`

- [ ] **Bước 4: Apply**

```bash
terraform apply
```

Xem kỹ plan trước khi gõ `yes`. Kỳ vọng: tạo 5 tài nguyên (bucket, versioning, encryption, public access block, dynamodb table).

- [ ] **Bước 5: Xác minh tài nguyên đã tồn tại thật và nằm đúng region**

```bash
BUCKET=$(terraform output -raw state_bucket_name)
aws s3api head-bucket --bucket "$BUCKET" && echo "BUCKET OK"
aws s3api get-bucket-location --bucket "$BUCKET" --query LocationConstraint --output text
aws dynamodb describe-table --table-name nghiand224-tfstate-lock \
  --query 'Table.TableStatus' --output text
```

Kỳ vọng: `BUCKET OK`, location `ap-southeast-1`, và table status `ACTIVE`.

- [ ] **Bước 6: Commit**

`.gitignore` đang chặn `*.tfstate`, nên state local của bootstrap sẽ không bị commit. Điều đó chấp nhận được: cấu hình này gần như không bao giờ chạy lại, và nếu cần thì `terraform import` lại được.

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/bootstrap/
git commit -m "Add bootstrap config for Terraform remote state

Creates the versioned, encrypted S3 bucket and DynamoDB lock table that
the main configuration stores its state in. Kept as a separate root module
with local state because the bucket must exist before any backend can use it."
git push origin projects/devops
```

---

### Task 5: Sửa 3 lỗi chặn để `terraform validate` chạy được

**Files:**
- Modify: `infrastructure/modules/alb/variables.tf` — xoá 3 khối `output` bị lặp, thêm 2 biến
- Modify: `infrastructure/modules/asg/variables.tf` — xoá 1 khối `output` bị lặp
- Modify: `infrastructure/modules/rds/variables.tf` — xoá 3 khối `output` bị lặp
- Modify: `infrastructure/modules/alb/main.tf` — bỏ security group tự tạo
- Modify: `infrastructure/main.tf` — truyền SG vào module `alb`
- Modify: `infrastructure/variables.tf` — thêm `health_check_path`
- Modify: `infrastructure/modules/vpc/main.tf` — `aws_eip` dùng `domain`

**Interfaces:**
- Consumes: không có
- Produces: module `alb` nhận thêm hai biến `security_group_id` (string) và `health_check_path` (string). Task 8 và Tuần 2 sẽ dùng `health_check_path`.

- [ ] **Bước 1: Chạy validate để thấy lỗi đầu tiên — đây là test đang fail**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform init -backend=false
terraform validate
```

Kỳ vọng: **FAIL** với thông báo dạng `Duplicate output definition` trỏ vào `modules/alb/variables.tf`.

- [ ] **Bước 2: Ghi đè `modules/alb/variables.tf`**

Xoá toàn bộ phần từ `output "alb_arn" {` tới hết file, và thêm hai biến mới. File sau khi sửa **phải là chính xác** như sau:

```hcl
# ALB Module

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID cua security group cho ALB, do module security cung cap"
  type        = string
}

variable "health_check_path" {
  description = "Duong dan ALB dung de kiem tra suc khoe target"
  type        = string
  default     = "/"
}
```

- [ ] **Bước 3: Xoá khối `output` khỏi `modules/asg/variables.tf`**

Xoá phần này ở cuối file:

```hcl
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.main.name
}
```

Nó đã có sẵn trong `modules/asg/outputs.tf`.

- [ ] **Bước 4: Xoá các khối `output` khỏi `modules/rds/variables.tf`**

Xoá ba khối `output "rds_instance_id"`, `output "rds_instance_endpoint"`, `output "rds_instance_port"` ở cuối file. Cả ba đã có trong `modules/rds/outputs.tf`.

- [ ] **Bước 5: Chạy lại validate — kỳ vọng lỗi output biến mất**

```bash
terraform validate
```

Kỳ vọng: `Success! The configuration is valid.`

`validate` không phát hiện được lỗi trùng tên security group vì đó là lỗi phát sinh lúc gọi API AWS, không phải lỗi cú pháp. Các bước tiếp theo sửa lỗi đó trước khi nó kịp làm hỏng lần `apply` đầu tiên.

- [ ] **Bước 6: Bỏ security group tự tạo trong `modules/alb/main.tf`**

Xoá toàn bộ khối `resource "aws_security_group" "alb"` (dòng 53 tới hết file), và sửa `aws_lb.main`:

```hcl
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
  }
}
```

Đồng thời sửa health check trong `aws_lb_target_group.main` để dùng biến:

```hcl
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
```

Lý do: module `security` đã tạo một SG tên `${var.environment}-alb-sg` rồi. Hai security group trùng tên trong cùng một VPC là không hợp lệ. Giữ lại bản trong module `security` vì `aws_security_group.app` tham chiếu tới nó để cho phép traffic từ ALB.

- [ ] **Bước 7: Truyền security group vào module `alb` trong `infrastructure/main.tf`**

```hcl
# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  health_check_path = var.health_check_path
}
```

- [ ] **Bước 8: Thêm biến `health_check_path` vào `infrastructure/variables.tf`**

```hcl
variable "health_check_path" {
  description = "Duong dan ALB kiem tra suc khoe. Doi thanh /actuator/health o Tuan 2 khi app co Actuator."
  type        = string
  default     = "/"
}
```

- [ ] **Bước 9: Sửa `aws_eip` trong `modules/vpc/main.tf`**

Đổi `vpc = true` thành `domain = "vpc"`:

```hcl
# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = length(var.public_subnets)
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}
```

Đối số `vpc` đã bị gỡ bỏ ở AWS provider 5.x. Chưa sửa dòng này thì không nâng được provider ở Task 6.

- [ ] **Bước 10: Chạy lại validate và fmt**

```bash
terraform fmt -recursive
terraform validate
```

Kỳ vọng: `Success! The configuration is valid.`

- [ ] **Bước 11: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/
git commit -m "Fix three defects that made terraform validate fail

Removes output blocks duplicated between variables.tf and outputs.tf in
the alb, asg, and rds modules, which made validate abort with Duplicate
output definition. Drops the ALB module's own security group, which
collided by name with the one the security module already creates, and has
the module take the group as an input instead. Replaces the aws_eip vpc
argument, removed in provider 5.x, with domain."
git push origin projects/devops
```

---

### Task 6: Nâng provider, thêm default_tags, remote backend, outputs ở root

**Files:**
- Modify: `infrastructure/main.tf`
- Create: `infrastructure/outputs.tf`
- Create: `infrastructure/envs/dev/backend.hcl`
- Create: `infrastructure/envs/dev/dev.tfvars`

**Interfaces:**
- Consumes: tên bucket và table từ Task 4
- Produces: output ở root tên `alb_dns_name`, `rds_endpoint`, `asg_name`, `vpc_id`. Task 9 dùng để xác minh.

- [ ] **Bước 1: Sửa khối `terraform` và `provider` trong `infrastructure/main.tf`**

Thay 22 dòng đầu bằng:

```hcl
# Main Terraform configuration for AWS infrastructure

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Cau hinh backend dang partial. Gia tri thuc nam o envs/<env>/backend.hcl
  # va duoc truyen vao bang:
  #   terraform init -backend-config=envs/dev/backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  # Gan tag cho MOI tai nguyen ma provider nay tao ra.
  # Nho vay loc chi phi theo Project trong Cost Explorer moi chinh xac.
  default_tags {
    tags = {
      Project     = "DevOps-Project-01"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "nghiand224"
    }
  }
}
```

- [ ] **Bước 2: Đổi mặc định region và AZ trong `infrastructure/variables.tf`**

```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}
```

- [ ] **Bước 3: Viết `infrastructure/outputs.tf`**

```hcl
output "alb_dns_name" {
  description = "DNS name cua ALB - mo trinh duyet vao dia chi nay de xem app"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint cua RDS (host:port)"
  value       = module.rds.rds_instance_endpoint
}

output "asg_name" {
  description = "Ten Auto Scaling Group - dung cho lenh start-instance-refresh"
  value       = module.asg.asg_name
}

output "vpc_id" {
  description = "ID cua VPC"
  value       = module.vpc.vpc_id
}
```

Bốn output này là thứ cấu hình ban đầu thiếu hoàn toàn: apply xong không có cách nào biết địa chỉ để mở app.

- [ ] **Bước 4: Sinh `infrastructure/envs/dev/backend.hcl`**

Sinh bằng lệnh để không phải chép tay số account (chép tay là nguồn lỗi phổ biến):

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
mkdir -p envs/dev

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > envs/dev/backend.hcl <<EOF
bucket         = "nghiand224-tfstate-${ACCOUNT_ID}"
key            = "devops-project-01/dev/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "nghiand224-tfstate-lock"
encrypt        = true
EOF

cat envs/dev/backend.hcl
```

Kỳ vọng: in ra file với tên bucket đã có số account thật, khớp với giá trị `state_bucket_name` mà Task 4 xuất ra.

- [ ] **Bước 5: Viết `infrastructure/envs/dev/dev.tfvars`**

**File này được commit, nên tuyệt đối không chứa secret.**

```hcl
# Cau hinh moi truong dev.
# File nay DUOC commit - khong bao gio dat secret vao day.

aws_region  = "ap-southeast-1"
environment = "dev"

vpc_cidr           = "192.168.0.0/16"
public_subnets     = ["192.168.1.0/24", "192.168.2.0/24"]
private_subnets    = ["192.168.3.0/24", "192.168.4.0/24"]
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

instance_type        = "t3.micro"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

db_name           = "UserDB"
db_username       = "dbadmin"
db_instance_class = "db.t3.micro"
db_multi_az       = false

health_check_path = "/"
```

`db_name = "UserDB"` khớp với chuỗi kết nối mà code Java thực sự dùng.

Nếu Task 3 bước 5 cho ra bộ AZ khác `ap-southeast-1a`/`1b`, sửa dòng `availability_zones` cho khớp.

- [ ] **Bước 6: Khởi tạo lại Terraform với backend từ xa**

```bash
terraform init -backend-config=envs/dev/backend.hcl -reconfigure
```

Kỳ vọng: `Successfully configured the backend "s3"!` và provider tải về phiên bản 5.x.

- [ ] **Bước 7: Xác minh provider đúng phiên bản**

```bash
terraform version
```

Kỳ vọng: dòng `+ provider registry.terraform.io/hashicorp/aws v5.x.x`.

- [ ] **Bước 8: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/
git commit -m "Move state to S3, upgrade provider to 5.x, add root outputs

Wires the partial S3 backend to envs/dev/backend.hcl, defaults the region
to ap-southeast-1, applies default_tags so cost filtering by project works,
and adds root outputs - without alb_dns_name there was no way to find the
application after an apply."
git push origin projects/devops
```

---

### Task 7: Bỏ bastion và SSH, giảm còn một NAT Gateway

**Files:**
- Modify: `infrastructure/modules/security/main.tf`
- Modify: `infrastructure/modules/security/variables.tf`
- Modify: `infrastructure/modules/security/outputs.tf`
- Modify: `infrastructure/modules/vpc/main.tf`
- Modify: `infrastructure/modules/vpc/outputs.tf`
- Modify: `infrastructure/modules/asg/variables.tf`
- Modify: `infrastructure/modules/asg/main.tf`
- Modify: `infrastructure/main.tf`
- Modify: `infrastructure/variables.tf`

**Interfaces:**
- Consumes: `module.vpc.vpc_id`
- Produces: module `security` không còn output `bastion_security_group_id`, không còn biến `allowed_ssh_cidr_blocks`.

- [ ] **Bước 1: Xoá security group bastion và rule SSH trong `modules/security/main.tf`**

Xoá toàn bộ khối `resource "aws_security_group" "bastion"` (dòng 95 tới hết file), và xoá khối `ingress` port 22 trong `aws_security_group.app`. Sau khi sửa, `aws_security_group.app` phải là:

```hcl
# Application Security Group
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Khong co rule port 22. Truy cap may chu qua SSM Session Manager:
  # agent tren may tu ket noi ra ngoai qua NAT Gateway, khong co ket noi
  # nao di vao tu Internet.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}
```

- [ ] **Bước 2: Bỏ biến `allowed_ssh_cidr_blocks` khỏi `modules/security/variables.tf`**

File sau khi sửa chỉ còn:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
```

- [ ] **Bước 3: Bỏ output bastion khỏi `modules/security/outputs.tf`**

Xoá khối `output "bastion_security_group_id"`. Ba output còn lại giữ nguyên.

- [ ] **Bước 4: Bỏ tham chiếu bastion khỏi `infrastructure/main.tf` và `variables.tf`**

Trong `main.tf`, khối `module "security"` thành:

```hcl
# Security Module
module "security" {
  source = "./modules/security"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}
```

Trong `variables.tf`, xoá hẳn hai biến `allowed_ssh_cidr_blocks` và `key_name`.

- [ ] **Bước 5: Bỏ `key_name` khỏi module ASG**

Trong `modules/asg/variables.tf`, xoá khối `variable "key_name"`.
Trong `modules/asg/main.tf`, xoá dòng `key_name = var.key_name` khỏi `aws_launch_template.main`.
Trong `infrastructure/main.tf`, xoá dòng `key_name = var.key_name` khỏi khối `module "asg"`.

Không còn SSH thì SSH key cũng không còn ý nghĩa.

- [ ] **Bước 6: Giảm còn một NAT Gateway trong `modules/vpc/main.tf`**

`aws_eip.nat` và `aws_nat_gateway.main` bỏ `count`:

```hcl
# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
  }
}

# MOT NAT Gateway dung chung cho moi private subnet.
# Cau hinh ban dau tao mot cai moi public subnet, tuc gap doi chi phi.
# Voi moi truong dev thi mot cai la du: danh doi la neu AZ chua no chet
# thi private subnet mat duong ra Internet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}
```

Và `aws_route_table.private` trỏ tới NAT Gateway duy nhất:

```hcl
# Private Route Tables
resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}
```

- [ ] **Bước 7: Sửa output NAT trong `modules/vpc/outputs.tf`**

Thay hai khối `nat_gateway_ids` và `nat_gateway_elastic_ips`:

```hcl
output "nat_gateway_id" {
  description = "ID cua NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_elastic_ip" {
  description = "Dia chi Elastic IP gan voi NAT Gateway"
  value       = aws_eip.nat.public_ip
}
```

- [ ] **Bước 8: Validate**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform fmt -recursive
terraform validate
```

Kỳ vọng: `Success! The configuration is valid.`

- [ ] **Bước 9: Xác minh không còn dấu vết SSH nào**

```bash
grep -rn "key_name\|allowed_ssh\|bastion\|from_port *= *22" . || echo "SACH - khong con tham chieu SSH"
```

Kỳ vọng: `SACH - khong con tham chieu SSH`.

- [ ] **Bước 10: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/
git commit -m "Drop bastion host and SSH, halve NAT Gateway cost

Removes the bastion security group, which had no instance behind it, and
the port 22 ingress rule. Instances are reached through SSM Session
Manager, whose agent dials out via the NAT Gateway, so no inbound path
from the Internet is needed. Also goes from two NAT Gateways to one, which
a dev environment does not need per-AZ redundancy for."
git push origin projects/devops
```

---

### Task 8: RDS không secret, AMI động, ASG không tự huỷ hoại

**Files:**
- Modify: `infrastructure/modules/rds/main.tf`
- Modify: `infrastructure/modules/rds/variables.tf`
- Modify: `infrastructure/modules/rds/outputs.tf`
- Modify: `infrastructure/modules/asg/main.tf`
- Modify: `infrastructure/main.tf`
- Modify: `infrastructure/variables.tf`

**Interfaces:**
- Consumes: `module.vpc.private_subnet_ids`, `module.security.db_security_group_id`
- Produces: module `rds` có thêm output `master_user_secret_arn` (string) — Tuần 2 dùng để cấp quyền đọc secret cho instance profile.

- [ ] **Bước 1: Sửa `modules/rds/main.tf` để RDS tự quản lý mật khẩu**

Trong `aws_db_instance.main`, thay dòng `password = var.db_password` bằng:

```hcl
  db_name  = var.db_name
  username = var.db_username

  # RDS tu sinh mat khau, luu vao Secrets Manager va tu xoay vong.
  # Nho vay khong co mat khau nao trong tfvars, trong state, hay trong repo.
  manage_master_user_password = true
```

Và đưa hai giá trị đang hardcode thành biến:

```hcl
  instance_class = var.instance_class
  multi_az       = var.multi_az
```

- [ ] **Bước 2: Sửa `modules/rds/variables.tf`**

Xoá khối `variable "db_password"`. Thêm hai biến mới:

```hcl
variable "instance_class" {
  description = "Loai instance cho RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Bat Multi-AZ. Tang gap doi chi phi, chi bat khi can chung minh HA."
  type        = bool
  default     = false
}
```

Biến `db_username` **giữ lại** — `aws_db_instance` bắt buộc phải có master username, và username không phải là secret.

- [ ] **Bước 3: Thêm output ARN của secret vào `modules/rds/outputs.tf`**

```hcl
output "master_user_secret_arn" {
  description = "ARN cua secret chua mat khau master do RDS tu quan ly"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
```

- [ ] **Bước 4: Thay AMI hardcode bằng data source trong `modules/asg/main.tf`**

Thêm vào đầu file:

```hcl
# ASG Module

# Lay AMI Amazon Linux 2023 moi nhat thay vi ghi cung mot ID.
# ID cu ami-0c02fb55956c7d316 chi ton tai o us-east-1 nen khong dung duoc
# o ap-southeast-1. O Tuan 3, data source nay se doi sang loc theo tag cua
# AMI do Packer bake ra.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

Và sửa `aws_launch_template.main` thành:

```hcl
resource "aws_launch_template" "main" {
  name_prefix   = "${var.environment}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_group_ids

  # Chua cai gi ca. O Tuan 3, Packer se bake san Tomcat va file WAR vao AMI,
  # nen instance khoi dong len la chay duoc ngay - khong con user_data cai dat.

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web-instance"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

- [ ] **Bước 5: Đổi `health_check_type` sang `EC2` trong `modules/asg/main.tf`**

```hcl
resource "aws_autoscaling_group" "main" {
  name                = "${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = var.target_group_arns

  # Tam thoi dung EC2 thay vi ELB. Den Tuan 3, khi AMI da co san app va
  # endpoint /actuator/health hoat dong, se doi lai thanh ELB.
  #
  # Neu de ELB ngay bay gio: instance chua co app -> ALB danh dau unhealthy
  # -> ASG terminate va tao lai -> lap vo han, vua khong bao gio on dinh
  # vua dot tien.
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
```

Đây là chi tiết dễ bỏ sót nhất trong cả tuần. Không sửa thì lần apply đầu tiên sẽ tạo ra một vòng lặp tự huỷ: instance khởi động, ALB thấy không có app nên báo unhealthy, ASG giết instance đó và tạo cái mới, lặp mãi.

- [ ] **Bước 6: Nối biến mới vào `infrastructure/main.tf`**

```hcl
# RDS Module
module "rds" {
  source = "./modules/rds"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.db_security_group_id]
  db_name            = var.db_name
  db_username        = var.db_username
  instance_class     = var.db_instance_class
  multi_az           = var.db_multi_az
}
```

- [ ] **Bước 7: Cập nhật `infrastructure/variables.tf`**

Xoá khối `variable "db_password"`. Sửa `db_username` bỏ `sensitive` và thêm hai biến mới:

```hcl
variable "db_username" {
  description = "Master username cua RDS. Khong phai secret - mat khau do RDS tu quan ly qua Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "Loai instance cho RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Bat Multi-AZ cho RDS"
  type        = bool
  default     = false
}
```

- [ ] **Bước 8: Validate và kiểm tra không còn biến mật khẩu nào**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform fmt -recursive
terraform validate
grep -rn "db_password\|var.db_password" . || echo "SACH - khong con bien mat khau"
```

Kỳ vọng: `Success! The configuration is valid.` và `SACH - khong con bien mat khau`.

- [ ] **Bước 9: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/
git commit -m "Let RDS manage its own password, resolve AMI dynamically

Switches RDS to manage_master_user_password so the master credential is
generated and rotated in Secrets Manager and never appears in tfvars or
state. Replaces the hardcoded us-east-1 AMI id, which does not exist in
ap-southeast-1, with a data source. Sets the ASG health check to EC2 until
the app exists - leaving it on ELB would make the group terminate and
replace every instance forever, since nothing answers the health check yet."
git push origin projects/devops
```

---

### Task 9: Lần `apply` đầu tiên thành công và thu thập bằng chứng

**Files:**
- Create: `docs/evidence/01-terraform-apply-output.txt`
- Create: `docs/evidence/02-vpc-resource-map.png`
- Modify: `README.md` — điền mục "Cách chạy"

**Interfaces:**
- Consumes: toàn bộ cấu hình từ Task 5 tới Task 8
- Produces: bằng chứng cho portfolio; xác nhận hạ tầng đúng đắn trước khi sang Tuần 2

- [ ] **Bước 1: Chạy plan và đọc kỹ**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform plan -var-file=envs/dev/dev.tfvars -out=dev.tfplan
```

Kỳ vọng: kế hoạch tạo mới khoảng 30-35 tài nguyên, **không có tài nguyên nào bị destroy**. Đọc qua danh sách và xác nhận:
- Đúng **một** `aws_nat_gateway`
- **Không có** tài nguyên nào tên chứa `bastion`
- `aws_db_instance.main` **không** có thuộc tính `password`
- Subnet nằm ở `ap-southeast-1a` và `ap-southeast-1b`

- [ ] **Bước 2: Apply**

```bash
terraform apply dev.tfplan 2>&1 | tee ../docs/evidence/01-terraform-apply-output.txt
```

Mất khoảng 10-15 phút, phần lớn là chờ RDS. Ghi lại giờ bắt đầu để biết chính xác thời gian dựng hạ tầng — con số này đưa vào README.

- [ ] **Bước 3: Xác minh output**

```bash
terraform output
```

Kỳ vọng: in ra bốn giá trị `alb_dns_name`, `asg_name`, `rds_endpoint`, `vpc_id`, không giá trị nào rỗng. `alb_dns_name` phải chứa `ap-southeast-1`.

- [ ] **Bước 4: Xác minh mật khẩu RDS thật sự nằm trong Secrets Manager**

```bash
aws rds describe-db-instances \
  --db-instance-identifier dev-database \
  --query 'DBInstances[0].MasterUserSecret.[SecretArn,SecretStatus]' \
  --output table
```

Kỳ vọng: có ARN của secret và trạng thái `active`.

- [ ] **Bước 5: Xác minh không có mật khẩu trong state**

```bash
terraform show -json | grep -io '"password":"[^"]*"' || echo "SACH - khong co mat khau trong state"
```

Kỳ vọng: `SACH - khong co mat khau trong state`. Đây là bằng chứng mạnh nhất rằng S2 đã được xử lý.

- [ ] **Bước 6: Xác minh ASG không rơi vào vòng lặp thay thế**

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dev-asg \
  --query 'AutoScalingGroups[0].Instances[].[InstanceId,LifecycleState,HealthStatus]' \
  --output table
```

Kỳ vọng: đúng hai instance, cả hai `InService` và `Healthy`. Chờ thêm 5 phút rồi chạy lại — **instance ID phải không đổi**. Nếu ID đổi nghĩa là vòng lặp thay thế vẫn đang xảy ra, quay lại Task 8 bước 5.

- [ ] **Bước 7: Chụp bằng chứng**

Trên AWS Console (nhớ chọn region **Singapore** ở góc trên bên phải), vào **VPC → Your VPCs → dev-vpc → Resource map**, chụp toàn màn hình lưu thành `docs/evidence/02-vpc-resource-map.png`.

- [ ] **Bước 8: Điền mục "Cách chạy" trong `README.md`**

Thay khối `🚧 *Sẽ bổ sung ở Tuần 1*` dưới mục "Cách chạy" bằng:

````markdown
## Cách chạy

Yêu cầu: Terraform >= 1.5, AWS CLI đã cấu hình credentials với region
`ap-southeast-1`.

```bash
# Lan dau tien: tao noi luu state
cd infrastructure/bootstrap
terraform init && terraform apply

# Backend config da tro san toi bucket do bootstrap tao ra
cd ..
terraform init -backend-config=envs/dev/backend.hcl
terraform apply -var-file=envs/dev/dev.tfvars

# Mo app
terraform output alb_dns_name

# Xoa sach de khong ton tien
terraform destroy -var-file=envs/dev/dev.tfvars
```

Không cần khai báo mật khẩu database ở bất kỳ đâu — RDS tự sinh và tự
xoay vòng qua Secrets Manager.
````

- [ ] **Bước 9: Huỷ hạ tầng**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform destroy -var-file=envs/dev/dev.tfvars
```

- [ ] **Bước 10: Xác minh đã sạch, không còn gì tính tiền**

```bash
aws ec2 describe-nat-gateways --filter "Name=state,Values=available" \
  --query 'NatGateways[].NatGatewayId' --output text
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text
```

Kỳ vọng: cả ba lệnh không in ra gì. Nếu còn sót, xoá thủ công trước khi kết thúc buổi.

- [ ] **Bước 11: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/
git commit -m "Record first successful terraform apply

Captures the apply log and VPC resource map from the first end-to-end run
in ap-southeast-1, and documents the run commands in the README. Verified
that no password appears in state and that the ASG holds its instances
instead of cycling them."
git push origin projects/devops
```

---

### Task 10: Biến `nat_mode` — chuyển giữa NAT Gateway và NAT instance

Để cuối tuần vì đây là phần rủi ro nhất và bỏ được mà không ảnh hưởng gì phía trước.

**Files:**
- Modify: `infrastructure/modules/vpc/main.tf`
- Modify: `infrastructure/modules/vpc/variables.tf`
- Modify: `infrastructure/modules/vpc/outputs.tf`
- Modify: `infrastructure/main.tf`
- Modify: `infrastructure/variables.tf`
- Modify: `infrastructure/envs/dev/dev.tfvars`

**Interfaces:**
- Consumes: `var.vpc_cidr`, `aws_subnet.public`
- Produces: biến `nat_mode` nhận `"gateway"` hoặc `"instance"`

- [ ] **Bước 1: Thêm biến vào `modules/vpc/variables.tf`**

```hcl
variable "nat_mode" {
  description = "Cach cap duong ra Internet cho private subnet: gateway (~43 USD/thang) hoac instance (~4 USD/thang)"
  type        = string
  default     = "gateway"

  validation {
    condition     = contains(["gateway", "instance"], var.nat_mode)
    error_message = "nat_mode phai la \"gateway\" hoac \"instance\"."
  }
}

variable "nat_instance_type" {
  description = "Loai instance dung lam NAT khi nat_mode = instance"
  type        = string
  default     = "t4g.nano"
}
```

- [ ] **Bước 2: Đặt `count` theo chế độ cho các tài nguyên NAT Gateway**

Sửa trong `modules/vpc/main.tf`:

```hcl
locals {
  use_nat_gateway  = var.nat_mode == "gateway"
  use_nat_instance = var.nat_mode == "instance"
}

resource "aws_eip" "nat" {
  count  = local.use_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = local.use_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}
```

- [ ] **Bước 3: Thêm tài nguyên NAT instance**

```hcl
# ---------------------------------------------------------------------------
# NAT instance - lua chon re tien thay cho NAT Gateway
#
# Danh doi so voi NAT Gateway:
#   - Re hon khoang 10 lan
#   - Nhung: la diem chet don le, bang thong gioi han boi loai instance,
#     va ban phai tu va loi he dieu hanh cho no
#
# Chi nen dung cho moi truong dev. Moi truong that thi dung NAT Gateway.
# ---------------------------------------------------------------------------

data "aws_ami" "nat_instance" {
  count       = local.use_nat_instance ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
}

resource "aws_security_group" "nat_instance" {
  count       = local.use_nat_instance ? 1 : 0
  name        = "${var.environment}-nat-instance-sg"
  description = "Cho phep private subnet di ra ngoai qua NAT instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-nat-instance-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "nat" {
  count         = local.use_nat_instance ? 1 : 0
  ami           = data.aws_ami.nat_instance[0].id
  instance_type = var.nat_instance_type
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.nat_instance[0].id]

  # Bat buoc: mac dinh EC2 vut bo goi tin khong phai gui cho chinh no.
  # Tat kiem tra nay thi may moi lam duoc viec chuyen tiep.
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Bat chuyen tiep IP, giu lai sau khi reboot
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf

    # Che dia chi nguon: moi goi tin di ra deu mang IP cua may nay
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE

    # Giu lai rule sau khi reboot
    dnf install -y iptables-services
    service iptables save
    systemctl enable iptables
  EOF

  tags = {
    Name        = "${var.environment}-nat-instance"
    Environment = var.environment
  }
}
```

- [ ] **Bước 4: Cho private route table trỏ đúng đích theo chế độ**

**Xoá khối `route { ... }` nằm trong `aws_route_table.private`** (đã viết ở Task 7 bước 6) và thay bằng ba tài nguyên dưới đây. Không thể để route inline vì mỗi chế độ cần một đích khác nhau, mà một route table chỉ được có đúng một route `0.0.0.0/0`.

```hcl
resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

# Tach route ra khoi route table de moi che do co the dat route rieng
# ma khong xung dot voi nhau.
resource "aws_route" "private_nat_gateway" {
  count                  = local.use_nat_gateway ? length(var.private_subnets) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route" "private_nat_instance" {
  count                  = local.use_nat_instance ? length(var.private_subnets) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}
```

- [ ] **Bước 5: Sửa output NAT cho khớp cả hai chế độ**

**Phải xoá hai output đã tạo ở Task 7** — `nat_gateway_id` và `nat_gateway_elastic_ip` — rồi thay bằng hai output dưới đây. Bỏ qua bước xoá thì `validate` sẽ chết: Task 10 vừa biến `aws_eip.nat` và `aws_nat_gateway.main` thành tài nguyên có `count`, nên tham chiếu `aws_eip.nat.public_ip` không còn hợp lệ (phải là `aws_eip.nat[0].public_ip`).

Trong `modules/vpc/outputs.tf`:

```hcl
output "nat_mode" {
  description = "Che do NAT dang dung"
  value       = var.nat_mode
}

output "nat_public_ip" {
  description = "Dia chi IP cong khai ma private subnet di ra Internet qua do"
  value       = local.use_nat_gateway ? aws_eip.nat[0].public_ip : aws_instance.nat[0].public_ip
}
```

- [ ] **Bước 6: Nối biến lên root**

Trong `infrastructure/variables.tf`:

```hcl
variable "nat_mode" {
  description = "gateway (duoc quan ly, dat hon) hoac instance (tu quan ly, re hon)"
  type        = string
  default     = "gateway"
}
```

Trong `infrastructure/main.tf`, khối `module "vpc"` thêm dòng:

```hcl
  nat_mode = var.nat_mode
```

Trong `infrastructure/envs/dev/dev.tfvars` thêm:

```hcl
# Doi thanh "instance" de tiet kiem khoang 39 USD/thang,
# danh doi la mat tinh san sang cao
nat_mode = "gateway"
```

- [ ] **Bước 7: Validate cả hai chế độ**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224/DevOps-Project-01/infrastructure
terraform fmt -recursive
terraform validate

terraform plan -var-file=envs/dev/dev.tfvars \
  | grep -cE "aws_nat_gateway.main\[0\] will be created"

terraform plan -var-file=envs/dev/dev.tfvars -var="nat_mode=instance" \
  | grep -cE "aws_instance.nat\[0\] will be created"
```

Kỳ vọng: `validate` thành công, lệnh thứ hai in `1`, lệnh thứ ba in `1`.

- [ ] **Bước 8: Kiểm tra giá trị sai bị chặn**

```bash
terraform plan -var-file=envs/dev/dev.tfvars -var="nat_mode=banana" 2>&1 | grep -i "nat_mode phai la"
```

Kỳ vọng: in ra thông báo lỗi validation. Điều này chứng minh khối `validation` hoạt động.

- [ ] **Bước 9: Commit**

```bash
cd /Users/mac/PERSONAL_Projects/nghiand224
git add DevOps-Project-01/infrastructure/
git commit -m "Add nat_mode to switch between NAT Gateway and NAT instance

Lets the same configuration run either a managed NAT Gateway or a t4g.nano
NAT instance roughly ten times cheaper, so the cost tradeoff can be
measured with real numbers rather than quoted from a blog post. Routes are
split out of the route table so each mode owns its own route resource."
git push origin projects/devops
```

---

## Điều kiện hoàn thành Tuần 0 + Tuần 1

- [ ] `git ls-files` không chứa `settings.xml`, không chứa mật khẩu nào
- [ ] Nhánh `main` có README index, bấm link vào hiện đúng README của project
- [ ] `aws sts get-caller-identity` chạy được, region `ap-southeast-1`
- [ ] Budget alert $20/$30 đã bật
- [ ] `terraform validate` thành công
- [ ] `terraform apply` tạo hạ tầng thành công từ đầu ở Singapore
- [ ] Không có mật khẩu trong state, xác minh bằng `terraform show -json`
- [ ] ASG giữ nguyên instance sau 5 phút, không rơi vào vòng lặp thay thế
- [ ] `nat_mode` chuyển được cả hai chiều, `plan` sạch ở cả hai
- [ ] `terraform destroy` chạy xong, ba lệnh kiểm tra không còn tài nguyên nào
- [ ] `docs/evidence/` có 3 file: budget alert, apply log, VPC resource map

## Sang Tuần 2

Các việc dưới đây vẫn đang mở và là nội dung Tuần 2:

- SQL Injection ở `login.java:39` và `register.java:45` (S7)
- Mật khẩu người dùng lưu plaintext (S8)
- Ứng dụng chưa có Actuator, `health_check_path` vẫn là `/` (B3)
- Chưa có IAM instance profile nên SSM Session Manager chưa dùng được (S4)
- Chưa có Flyway migration tạo bảng `Employee` (O9)
- ASG vẫn để `health_check_type = "EC2"`, đổi lại thành `"ELB"` ở Tuần 3
