# Lab: Quy trình triển khai ML Job trên AWS EKS bằng Terraform

Bài lab này tập trung vào việc build Docker image cho ứng dụng ML, đẩy lên Amazon ECR và triển khai chạy Job trên cụm EKS sử dụng hạ tầng được định nghĩa bằng Terraform.

---

## Bước 1: Khởi tạo hạ tầng (Terraform)

Di chuyển vào thư mục terraform:
```bash
cd terraform-eks
terraform init
terraform apply
```
*Lưu ý: Quá trình tạo EKS Cluster sẽ mất khoảng **15-20 phút**.*

Sau khi chạy xong, hãy ghi lại giá trị **`ecr_repository_url`** và **`cluster_name`** từ output.

---

## Bước 2: Build và Push Docker Image

1. **Xác thực Docker với ECR:**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <YOUR_ECR_REPOSITORY_URL>
   ```

2. **Build Image:**
   Di chuyển vào thư mục `ml-app` (hoặc đứng ở root):
   ```bash
   docker build -t ml-lab-repo ../ml-app
   ```

3. **Tag và Push Image:**
   ```bash
   docker tag ml-lab-repo:latest <YOUR_ECR_REPOSITORY_URL>:latest
   docker push <YOUR_ECR_REPOSITORY_URL>:latest
   ```

---

## Bước 3: Triển khai Job lên EKS

1. **Cập nhật Kubeconfig:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name ml-lab-eks
   ```

2. **Cập nhật file Manifest:**
   Mở file `ml-job.yaml` và thay thế `<YOUR_ECR_REPOSITORY_URL>` bằng địa chỉ ECR bạn đã copy ở Bước 1.

3. **Chạy Job:**
   ```bash
   kubectl apply -f ml-job.yaml
   ```

4. **Kiểm tra kết quả:**
   ```bash
   # Xem danh sách các pod
   kubectl get pods

   # Xem logs của training job (thay <pod_name> bằng tên pod thật)
   kubectl logs <pod_name>
   ```

---

## Bước 4: Giám sát và Kiểm tra

1. **Kiểm tra Latency:** Xem logs của Pod để thấy thời gian thực thi (Execution Latency) của mô hình Scikit-learn.
2. **Kiểm tra Cost:** Truy cập AWS Billing Dashboard sau 1-2 tiếng để xem chi tiết chi phí của EKS, EC2 và NAT Gateway.

---

## Bước 5: Dọn dẹp tài nguyên (QUAN TRỌNG)

Để tránh phát sinh chi phí không mong muốn, hãy xóa toàn bộ tài nguyên ngay sau khi hoàn thành:

```bash
kubectl delete -f ml-job.yaml
terraform destroy
```
*Lưu ý: Luôn đợi đến khi `terraform destroy` hoàn tất báo `Destroy complete!`.*
