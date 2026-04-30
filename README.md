# 🇮🇩 Koperasi Merah Putih - Blue/Green Infrastructure

![Status](https://img.shields.io/badge/Status-Production--Ready-success)
![Cloud](https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white)
![IAC](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)

Dokumentasi lengkap untuk setup, konfigurasi, dan operasional infrastruktur Blue/Green Deployment Koperasi Merah Putih.

---

## 🏗️ 1. Persiapan Awal (Prerequisites)

Sebelum menyentuh Terraform, pastikan tool dasar ini sudah terpasang di komputer Anda:

### A. Install AWS CLI & Konfigurasi
1.  **Download & Install**: [AWS CLI Installer](https://aws.amazon.com/cli/).
2.  **Buka Terminal/PowerShell**, jalankan perintah:
    ```powershell
    aws configure
    ```
3.  **Masukkan Kredensial**:
    - `AWS Access Key ID`: (Dapatkan dari IAM User di AWS Console)
    - `AWS Secret Access Key`: (Dapatkan dari IAM User di AWS Console)
    - `Default region name`: `ap-southeast-1`
    - `Default output format`: `json`

### B. Persiapan Git
Pastikan Git sudah terinstall, lalu clone repositori ini:
```powershell
git clone https://github.com/Alfi-99/terraform-gb-deplyoment.git
cd terraform-gb-deplyoment
```

### C. Install Terraform
Download dari [terraform.io](https://www.terraform.io/downloads) dan pastikan path-nya terdaftar di Environment Variables Anda. Cek dengan: `terraform version`.

---

## 🚀 2. Cara Deploy Infrastruktur

### Langkah 1: Inisialisasi
```powershell
terraform init
```

### Langkah 2: Konfigurasi Variabel
Salin file template variabel:
```powershell
cp terraform.tfvars.example terraform.tfvars
```
Buka file `terraform.tfvars` dan isi sesuai kebutuhan (Project Name, Environment, dll).

### Langkah 3: Eksekusi
```powershell
terraform apply -auto-approve
```
*Tunggu proses 10-15 menit. Output akan menampilkan `amplify_app_url` dan `api_gateway_url`.*

---

## 🧪 3. Verifikasi & Testing Database

Sistem ini memiliki fitur **Self-Healing Database**. Anda tidak perlu menjalankan script SQL manual.

1.  Buka **`amplify_app_url`** di browser.
2.  Klik tombol **"Ambil Data dari Lambda GET"**.
3.  Lambda akan otomatis:
    - Membuat database `gbappdb`.
    - Membuat tabel `items`.
4.  Coba masukkan data via form **POST** untuk memastikan RDS & DynamoDB berjalan.

---

## 🔄 4. Operasional Blue/Green

| Kebutuhan | Perintah |
| :--- | :--- |
| **Switch ke GREEN** | `terraform apply -var="active_color=green"` |
| **Rollback ke BLUE** | `terraform apply -var="active_color=blue"` |

---

## 🧹 5. Cara Menghapus (Cleanup)

Untuk menghapus semua resource agar tidak kena tagihan:

1.  **Kosongkan S3 (Jika diperlukan manual)**:
    - Buka S3 Console, pilih bucket, klik **Empty**.
2.  **Jalankan Destroy**:
    ```powershell
    terraform destroy -auto-approve
    ```

---

## 📂 Struktur Repositori
- `lambda/`: Logika backend (Node.js).
- `lambda/layer/`: Koneksi DB & Logging (Shared).
- `app-bundle/`: Aplikasi Elastic Beanstalk.
- `*.tf`: Definisi infrastruktur AWS.

---
*Lead Architect: Alfi-99 | Digital Transformation 2026*
