# DevOps Project 01 — Java 3-Tier trên AWS

Ứng dụng Java Spring Boot chạy trên kiến trúc 3 tầng ở AWS, dựng và triển khai
hoàn toàn tự động bằng Terraform, Packer và GitHub Actions.

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
Manager. Không mở port 22 ở bất kỳ security group nào, không quản lý SSH key,
và mọi phiên truy cập được ghi log.

Tôi đã cân nhắc dùng VPC interface endpoint cho SSM rồi loại bỏ: hạ tầng đã có
NAT Gateway nên SSM agent kết nối ra ngoài được rồi. Ba endpoint × 2 AZ tốn
khoảng $0,078/giờ, còn NAT Gateway chỉ $0,059/giờ — cắm thêm endpoint là trả
tiền hai lần cho cùng một đường ra Internet. Endpoint chỉ đáng tiền khi bỏ hẳn
NAT, nhưng khi đó lại phải thêm endpoint cho Secrets Manager và CloudWatch
Logs, tổng còn cao hơn nữa.

**Không có mật khẩu database ở bất kỳ đâu.** RDS bật
`manage_master_user_password`, tự sinh và tự xoay vòng mật khẩu trong Secrets
Manager. Không có biến `db_password` trong Terraform, không có mật khẩu trong
state file, không có gì trong repo.

**Biến `nat_mode`.** Cùng một cấu hình chạy được với NAT Gateway (được quản lý
sẵn) hoặc NAT instance `t4g.nano` (rẻ hơn khoảng 10 lần). 🚧 *Bảng so sánh chi
phí đo thật sẽ bổ sung ở Tuần 5*

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
$5/tháng. 🚧 *Số đo thật từ Cost Explorer sẽ bổ sung ở Tuần 5*

## Cách chạy

🚧 *Sẽ bổ sung ở Tuần 1*

## Tài liệu

- [Thiết kế hệ thống](docs/superpowers/specs/2026-08-08-devops-project-01-personalization-design.md)
- [Kế hoạch triển khai Tuần 0 + Tuần 1](docs/superpowers/plans/2026-08-08-tuan-0-1-nen-mong-va-terraform.md)
