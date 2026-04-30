# 🇮🇩 Koperasi Merah Putih - Blue/Green Infrastructure

![Status](https://img.shields.io/badge/Status-Production--Ready-success)
![Cloud](https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white)
![IAC](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)

Proyek ini adalah implementasi infrastruktur cloud skala enterprise untuk sistem **Koperasi Merah Putih**. Menggunakan arsitektur **Serverless** untuk API dan **Blue/Green Deployment** untuk aplikasi web guna menjamin *Zero Downtime*.

---

## 🏗️ Arsitektur High-Level

Sistem ini dirancang untuk ketahanan tinggi dan skalabilitas otomatis:

-   **Frontend (Amplify)**: Web dashboard responsif dengan fitur Live Testing Panel.
-   **Backend API (API Gateway)**: REST API yang aman dengan manajemen CORS penuh.
-   **Compute (Lambda)**: Fungsi backend yang berjalan hanya saat dipanggil (cost-efficient).
-   **Database (RDS MySQL)**: Penyimpanan data relasional yang stabil dan terenkripsi.
-   **Logging (DynamoDB)**: Audit trail otomatis untuk setiap request masuk.
-   **Traffic Management (ALB)**: Membagi beban antara environment `BLUE` (stabil) dan `GREEN` (testing/new version).

---

## 🛠️ Prasyarat (Prerequisites)

Sebelum memulai, pastikan Anda memiliki:
1.  **AWS Account** dengan akses Administrator.
2.  **Terraform CLI** terinstall (v1.5+).
3.  **AWS CLI** terkonfigurasi (`aws configure`).
4.  **Git** untuk kontrol versi.

---

## 🚀 Langkah-Langkah Instalasi (Step-by-Step)

### 1. Persiapan Environment
```bash
git clone https://github.com/Alfi-99/terraform-gb-deplyoment.git
cd terraform-gb-deplyoment
```

### 2. Konfigurasi Variabel
Buat file `terraform.tfvars` dari template yang tersedia:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit file tersebut dan masukkan nilai yang sesuai (Region, Kredensial, dll).

### 3. Inisialisasi & Deploy Awal
```bash
terraform init
terraform apply -auto-approve
```
*Tunggu sekitar 10-15 menit hingga RDS dan Elastic Beanstalk selesai dikonfigurasi.*

---

## 🧪 Cara Pengujian (Live Testing)

Setelah `terraform apply` selesai, Anda akan mendapatkan output berupa **`amplify_app_url`**. Buka URL tersebut di browser.

### Fitur Self-Healing Database
Anda **TIDAK PERLU** menjalankan script SQL secara manual. 
1.  Klik tombol **"Ambil Data dari Lambda GET"**.
2.  Lambda akan mendeteksi jika tabel belum ada, lalu otomatis menjalankan perintah:
    `CREATE DATABASE IF NOT EXISTS gbappdb;`
    `CREATE TABLE IF NOT EXISTS items (...);`
3.  Jika muncul pesan *"Berhasil mengambil 0 data"*, berarti database sudah siap digunakan.

---

## 🔄 Manajemen Blue/Green Deployment

Sistem ini mendukung transisi trafik yang mulus. Anda bisa mengatur persentase trafik di Application Load Balancer.

| Perintah | Efek |
| :--- | :--- |
| `terraform apply -var="active_color=green"` | Mengalihkan trafik 100% ke environment **GREEN**. |
| `terraform apply -var="active_color=blue"` | Mengalihkan trafik 100% ke environment **BLUE** (Default). |

---

## 📂 Struktur Repositori

-   `lambda/`: Kode sumber untuk fungsi GET dan POST.
-   `lambda/layer/`: Shared utilities (Database connection, Logging, Response helper).
-   `app-bundle/`: Kode untuk aplikasi Elastic Beanstalk (Node.js).
-   `index.html`: Dashboard utama yang di-host di Amplify.
-   `*.tf`: File konfigurasi infrastruktur Terraform.

---

## ⚠️ Troubleshooting

**1. Error: Failed to fetch (POST)**
-   Pastikan Anda sudah menjalankan Lambda GET minimal satu kali untuk inisialisasi tabel.
-   Cek apakah `API_URL` di `index.html` sudah sesuai dengan output API Gateway.

**2. Database Connection Timeout**
-   Lambda membutuhkan akses VPC. Pastikan Security Group RDS mengizinkan traffic dari Lambda Security Group. (Sudah dikonfigurasi otomatis oleh Terraform ini).

**3. Elastic Beanstalk "Busy"**
-   Tunggu 1-2 menit sebelum menjalankan `terraform apply` lagi. AWS sedang melakukan update environment.

## 🧹 Pembersihan (Cleanup / Destroy)

Untuk menghindari tagihan yang tidak diinginkan, Anda dapat menghapus seluruh infrastruktur dengan satu perintah:

```powershell
terraform destroy -auto-approve
```

> [!CAUTION]
> **Peringatan Data Hilang**: Perintah ini akan menghapus semua data di RDS, DynamoDB, dan seluruh file di S3 secara permanen.
> 
> **Catatan S3**: Jika perintah gagal karena bucket S3 tidak kosong, silakan kosongkan isi bucket secara manual melalui AWS Console terlebih dahulu, lalu ulangi perintah `destroy`.

---

## 📜 Lisensi & Kontributor
Proyek ini dikembangkan khusus untuk transformasi digital **Koperasi Merah Putih**.

**Lead Architect**: Alfi-99 & Antigravity AI
**Tahun**: 2026

---
*Membangun Negeri dengan Teknologi Digital.*
