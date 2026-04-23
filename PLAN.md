# Kế Hoạch Thực Hiện - Lab Day 16: Cloud AI Environment Setup

## Tổng Quan

**Mục tiêu**: Triển khai một LLM inference endpoint (vLLM + Gemma) trên cloud infrastructure sử dụng Infrastructure as Code (Terraform).

**Thời gian ước tính**: 2.5 giờ  
**Track**: AWS (có sẵn Terraform code) hoặc GCP (tự viết IaC)  
**Model**: `google/gemma-4-E2B-it` chạy trên NVIDIA T4 GPU  

---

## Kiến Trúc Hệ Thống

```
Internet
    │
    ▼
[Application Load Balancer] ← Public, port 80
    │
    ▼ (port 8000)
[GPU Node - g4dn.xlarge]    ← Private subnet, chạy vLLM
    │
    ▼ (SSH debug nếu cần)
[Bastion Host - t3.micro]   ← Public subnet
```

**VPC CIDR**: 10.0.0.0/16  
**Subnets**: 2 public + 2 private (multi-AZ)  
**Outbound**: NAT Gateway cho GPU node ra internet (pull model)  

---

## Các Giai Đoạn Thực Hiện

### Phase 1 — Chuẩn Bị Tài Khoản & Quyền Truy Cập (30 phút)

- [ ] **1.1 AWS IAM Setup**
  - Tạo IAM User mới với least-privilege permissions
  - Gán các policy cần thiết: EC2, VPC, ELB, IAM (đọc kỹ README_aws.md)
  - Tạo Access Key + Secret Key, lưu an toàn
  - Chạy `aws configure` với credentials vừa tạo

- [ ] **1.2 GPU Quota Request**
  - Vào AWS Console → Service Quotas → EC2
  - Tìm: "Running On-Demand G and VT instances"
  - Request tăng lên tối thiểu **4 vCPU** (g4dn.xlarge cần 4 vCPU)
  - **Lưu ý**: Quota approval có thể mất 15–30 phút

- [ ] **1.3 Hugging Face Token**
  - Đăng nhập tại huggingface.co
  - Vào Settings → Access Tokens → New token (Read permission)
  - Vào trang model `google/gemma-4-E2B-it` → Accept license agreement
  - Lưu token vào biến môi trường

---

### Phase 2 — Cấu Hình Môi Trường Local (15 phút)

- [ ] **2.1 Copy và điền file `.env`**
  ```bash
  cp .env.example .env
  # Điền vào:
  # TF_VAR_hf_token=hf_xxxxxxxxxxxx
  # AWS_ACCESS_KEY_ID=AKIA...
  # AWS_SECRET_ACCESS_KEY=...
  # AWS_DEFAULT_REGION=us-east-1
  ```

- [ ] **2.2 Load environment variables**
  ```bash
  source .env   # Linux/Mac
  # hoặc set từng biến trên Windows
  ```

- [ ] **2.3 Kiểm tra Terraform version**
  ```bash
  terraform version   # >= 1.3 khuyến nghị
  ```

- [ ] **2.4 Verify AWS credentials**
  ```bash
  aws sts get-caller-identity
  ```

---

### Phase 3 — Triển Khai Infrastructure với Terraform (45 phút)

- [ ] **3.1 Khởi tạo Terraform**
  ```bash
  cd terraform
  terraform init
  ```

- [ ] **3.2 Xem trước thay đổi**
  ```bash
  terraform plan
  ```
  - Kiểm tra output: ~20 resources sẽ được tạo
  - Đảm bảo không có lỗi về permissions hay quota

- [ ] **3.3 Triển khai**
  ```bash
  terraform apply
  # Nhập "yes" khi được hỏi
  # Thời gian: ~10–15 phút
  ```

- [ ] **3.4 Ghi lại các output quan trọng**
  ```
  bastion_public_ip   = xxx.xxx.xxx.xxx
  alb_dns_name        = xxxxxxxxx.us-east-1.elb.amazonaws.com
  endpoint_url        = http://xxxxxxxxx.us-east-1.elb.amazonaws.com/v1
  gpu_private_ip      = 10.0.x.x
  ```

---

### Phase 4 — Chờ Model Load & Kiểm Tra (30 phút)

- [ ] **4.1 Chờ vLLM khởi động**
  - Sau khi `terraform apply` thành công, GPU node cần thêm **5–10 phút** để:
    - Pull Docker image vLLM
    - Download model Gemma (~14 GB) từ Hugging Face
    - Load model vào VRAM (T4 có 16 GB)
  - Kiểm tra health endpoint:
    ```bash
    # Lặp lại cho đến khi trả về 200 OK
    curl http://<ALB_DNS>/health
    ```

- [ ] **4.2 Test API call**
  ```bash
  curl -X POST http://<ALB_DNS>/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "google/gemma-4-E2B-it",
      "messages": [{"role": "user", "content": "Hello, what is AI?"}],
      "max_tokens": 150
    }'
  ```
  - Kết quả thành công: HTTP 200 với JSON response chứa text generated

- [ ] **4.3 Đo Cold Start Time**
  - Ghi lại thời gian từ `terraform apply` xong → API call đầu tiên trả về 200
  - Mục tiêu: **< 15 phút**

---

### Phase 5 — Thu Thập Deliverables (15 phút)

- [ ] **5.1 Chụp màn hình API call thành công**
  - Screenshot terminal với curl command và response JSON

- [ ] **5.2 Chụp màn hình AWS Billing Dashboard**
  - AWS Console → Billing → Bills hoặc Cost Explorer
  - Hiển thị các charges phát sinh

- [ ] **5.3 Ghi lại Cold Start Time benchmark**
  - Thời gian từ lúc instance start đến API sẵn sàng

- [ ] **5.4 Nén source code**
  ```bash
  zip -r terraform_code.zip terraform/
  ```

---

### Phase 6 — Dọn Dẹp Tài Nguyên (QUAN TRỌNG) (10 phút)

> **CẢNH BÁO**: g4dn.xlarge tốn ~$0.526/giờ. Phải destroy ngay sau khi hoàn thành để tránh phí.

- [ ] **6.1 Destroy toàn bộ infrastructure**
  ```bash
  cd terraform
  terraform destroy
  # Nhập "yes" để xác nhận
  ```

- [ ] **6.2 Verify trên AWS Console**
  - Kiểm tra EC2 → Instances: không còn instance nào running
  - Kiểm tra VPC: đã xóa VPC lab
  - Kiểm tra EC2 → Load Balancers: đã xóa ALB

---

## Xử Lý Sự Cố Thường Gặp

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|-------------|-----------|
| `terraform apply` lỗi quota | Chưa được duyệt GPU quota | Chờ thêm, hoặc thử region khác (us-west-2) |
| `/health` trả về 502/503 | vLLM chưa khởi động xong | Chờ thêm 5 phút, thử lại |
| API lỗi 401 hoặc model not found | HF token sai hoặc chưa accept license | Kiểm tra token, accept license model |
| SSH vào GPU node | Debug cần thiết | `ssh -J ubuntu@<bastion_ip> ubuntu@<gpu_private_ip>` |
| `terraform destroy` không xóa được | Dependency lock | Chạy lại, hoặc xóa thủ công trên console |

---

## Checklist Nộp Bài

- [ ] Screenshot API call thành công (HTTP 200 + JSON response)
- [ ] Screenshot AWS Billing Dashboard
- [ ] Cold Start Time benchmark (giây/phút)
- [ ] File `terraform_code.zip` chứa toàn bộ Terraform code
- [ ] `terraform destroy` đã chạy thành công

---

## Ghi Chú Chi Phí

| Resource | Type | Chi phí ước tính |
|----------|------|-----------------|
| GPU Node | g4dn.xlarge | ~$0.526/giờ |
| Bastion Host | t3.micro | ~$0.01/giờ |
| NAT Gateway | - | ~$0.045/giờ + data |
| Load Balancer | ALB | ~$0.008/giờ |
| **Tổng (2.5 giờ)** | | **~$1.50–2.00** |

> Nếu có AWS Free Tier hoặc credit từ chương trình training, chi phí có thể được bù đắp.

---

## Files Quan Trọng Trong Repo

| File | Mục đích |
|------|----------|
| [terraform/main.tf](terraform/main.tf) | Toàn bộ infrastructure resources |
| [terraform/variables.tf](terraform/variables.tf) | Input variables (region, HF token, model) |
| [terraform/outputs.tf](terraform/outputs.tf) | Output sau khi deploy (IPs, URLs) |
| [terraform/providers.tf](terraform/providers.tf) | AWS provider config |
| [terraform/user_data.sh](terraform/user_data.sh) | Bootstrap script chạy Docker + vLLM |
| [.env.example](.env.example) | Template biến môi trường |
| [README_aws.md](README_aws.md) | Hướng dẫn chi tiết AWS track |
| [README_gcp.md](README_gcp.md) | Hướng dẫn chi tiết GCP track |
