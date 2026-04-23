# 🚀 Hướng dẫn Triển khai Hệ thống ML Đơn giản trên AWS (Simplified Lab 16)

Tài liệu này hướng dẫn bạn cách triển khai một ứng dụng Machine Learning (Iris Classifier) hoàn chỉnh trên AWS bằng Terraform. Hệ thống bao gồm:
- **FastAPI**: Cung cấp API dự đoán và Monitoring metrics.
- **Streamlit**: Giao diện người dùng (UI) để tương tác và xem biểu đồ giám sát.
- **Docker**: Đóng gói toàn bộ ứng dụng.
- **AWS Infrastructure**: VPC Private, NAT Gateway, Application Load Balancer (ALB), và EC2 Node.

---

## 1. Kiến trúc Hệ thống (Architecture)

Hệ thống được thiết kế theo mô hình chuẩn bảo mật trên AWS với VPC phân tầng. Ứng dụng chạy trong mạng riêng (Private Subnet) và chỉ có thể truy cập được thông qua Load Balancer.

```mermaid
graph TD
    User([Người dùng / Trình duyệt]) -->|HTTP Port 80| ALB[Application Load Balancer]
    User -->|HTTP Port 8000| ALB
    
    subgraph VPC [AWS VPC: 10.0.0.0/16]
        subgraph Public_Subnet [Public Subnets]
            ALB
            NAT[NAT Gateway]
            IGW[Internet Gateway]
        end
        
        subgraph Private_Subnet [Private Subnets]
            subgraph ML_Node [EC2: ML-App-Node - t3.medium]
                subgraph Docker_Container [Docker: ml-app]
                    Train[1. Training Job] -->|Lưu| Model[(model.joblib)]
                    Train -->|Lưu| Metrics[metrics.json]
                    API[2. FastAPI Backend :8000] -->|Load| Model
                    UI[3. Streamlit UI :8501] -->|Gọi| API
                    UI -->|Hiển thị| Metrics
                end
            end
        end
    end
    
    ALB -->|Forward to 8501| UI
    ALB -->|Forward to 8000| API
    ML_Node -->|Tải thư viện/Docker| NAT
    NAT --> IGW
    IGW -->|Internet| WWW((Internet))
```

### Các thành phần chính:
- **VPC & Networking**: Chia làm 2 lớp Public và Private. Các tài nguyên tính toán (EC2) nằm trong Private Subnet để đảm bảo an toàn.
- **ALB (Application Load Balancer)**: Đóng vai trò là cửa ngõ tiếp nhận request và phân phối vào ứng dụng.
- **NAT Gateway**: Cho phép máy chủ trong Private Subnet kết nối ra Internet để tải thư viện nhưng không cho phép chiều ngược lại.
- **Docker Container**: Đóng gói và chạy đồng thời quy trình Huấn luyện, API và UI.

---

## 2. Các thành phần Metrics được tích hợp
Hệ thống không chỉ dự đoán mà còn cung cấp các chỉ số quan trọng:
- **Model Metrics**: Accuracy, Precision, Recall, F1-Score (tính toán sau khi Training).
- **System Metrics**: CPU & Memory usage trong quá trình Training.
- **Inference Metrics**: Độ trễ (Latency) theo thời gian thực và biểu đồ lịch sử dự đoán trên giao diện Streamlit.
- **Prometheus Metrics**: Sẵn sàng cho việc giám sát chuyên sâu qua endpoint `/metrics` của API.

---

## 3. Các bước triển khai

### Bước 2.1: Chuẩn bị môi trường Local
Đảm bảo bạn đã cài đặt:
- **AWS CLI** (đã cấu hình `aws configure`)
- **Terraform**

### Bước 2.2: Khởi tạo Hạ tầng
Di chuyển vào thư mục `terraform` và thực hiện:

```bash
cd terraform
# Khởi tạo terraform
terraform init

# Kiểm tra tính hợp lệ
terraform validate

# Triển khai (mất khoảng 10-12 phút chủ yếu do NAT Gateway)
terraform apply -auto-approve
```

### Bước 2.3: Truy cập Ứng dụng
Sau khi `terraform apply` thành công, bạn sẽ nhận được các Outputs quan trọng:
- `ui_url`: Truy cập vào đây bằng trình duyệt để sử dụng giao diện Streamlit.
- `api_url`: Endpoint của FastAPI (dùng để test curl hoặc tích hợp hệ thống khác).

**Lưu ý:** Sau khi Terraform báo thành công, EC2 Node cần thêm khoảng 2-3 phút để cài đặt Docker, Build image và chạy Training lần đầu tiên. Hãy kiên nhẫn đợi một chút nếu chưa truy cập được ngay.

---

## 4. Kiểm tra Monitoring & Prediction

1. **Giao diện Streamlit (`ui_url`)**:
   - Bên thanh trái (Sidebar) hiển thị kết quả Training (Accuracy, CPU, RAM...).
   - Phần chính giữa cho phép bạn kéo thanh trượt để dự đoán loài hoa Iris.
   - Biểu đồ **Real-time Monitoring** sẽ hiển thị độ trễ của các lần dự đoán.

2. **Kiểm tra API (`api_url`)**:
   - Thử gọi API bằng cURL:
   ```bash
   curl -X POST <YOUR_API_URL>/predict \
     -H "Content-Type: application/json" \
     -d '{"sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2}'
   ```
   - Xem metrics hệ thống: `<YOUR_API_URL>/metrics`

---

## 5. Dọn dẹp tài nguyên (CỰC KỲ QUAN TRỌNG)
Để tránh phát sinh chi phí không đáng có (đặc biệt là NAT Gateway và ALB), bạn **BẮT BUỘC** phải xóa tài nguyên sau khi kết thúc:

```bash
terraform destroy -auto-approve
```

---
*Chúc bạn có buổi thực hành thành công!*
