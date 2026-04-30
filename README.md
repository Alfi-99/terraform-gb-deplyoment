# 🚀 AWS Blue/Green Deployment — Koperasi Merah Putih

> Arsitektur cloud modern dengan Blue/Green deployment, logging DynamoDB, dan optimalisasi AWS Free Tier.

---

## 📐 Topologi Arsitektur

```
Internet
   │
   ▼
[GitHub Repository] ──► [GitHub Actions] ──► [S3 Bucket Deploy]
       │                                            │
       │                                            ▼
       └──────────────────────────────► [AWS Amplify] (Frontend)
                                              │
                                              ▼
                              ┌─────── [Application Load Balancer] ───────┐
                              │            (Public Subnet)                 │
                              ▼                                            ▼
                    [EB Blue Env]                              [EB Green Env]
                    (Private Subnet)                          (Private Subnet)
                              │                                            │
                              └──────────────┬───────────────────────────┘
                                             │
                                    [S3 Storage] [EFS]
                                             │
                                             ▼
                                     [API Gateway]
                                    /             \
                                   ▼               ▼
                             [Lambda POST]    [Lambda GET]
                                   \               /
                                    ▼             ▼
                                       [RDS MySQL]
                                    [DynamoDB Logs]
```

---

## 📦 Semua Service yang Digunakan

| # | Service | Tier | Fungsi |
|---|---------|------|--------|
| 1 | VPC | Gratis | Jaringan isolasi utama |
| 2 | Application Load Balancer | Berbayar (low cost) | Switch Blue/Green traffic |
| 3 | Elastic Beanstalk | Free tier (t2.micro) | Backend aplikasi |
| 4 | API Gateway | Free tier (1M req/bln) | REST API endpoint |
| 5 | Lambda | Free tier (1M req/bln) | POST & GET handler |
| 6 | RDS MySQL | Free tier (db.t3.micro) | Database utama |
| 7 | DynamoDB | Free tier (25GB) | Logging semua service |
| 8 | S3 | Free tier (5GB) | Artifact & storage |
| 9 | EFS | Berbayar (low cost) | Shared file storage |
| 10 | AWS Amplify | Free tier | Frontend hosting |
| 11 | Secrets Manager | $0.40/secret/bln | Simpan kredensial (30H Trial) |

---

## 📖 Cerita Arsitektur (Story)

### Babak 1: Fondasi Jaringan — VPC

Dikisahkan sebuah tim developer ingin membangun aplikasi web modern bagi **Koperasi Merah Putih** di AWS. Langkah pertama yang mereka ambil adalah membangun **rumah** untuk semua komponen — sebuah **Virtual Private Cloud (VPC)**.

VPC ini ibarat sebuah gedung kantor privat yang terisolasi dari dunia luar. Di dalamnya terdapat dua zona:

- **Public Subnet** (lantai depan): Tempat Load Balancer berdiri, bisa diakses internet
- **Private Subnet** (lantai belakang): Tempat Elastic Beanstalk dan RDS berada, terlindung dari akses langsung

Yang perlu dikonfigurasi di VPC:
- CIDR Block: `10.0.0.0/16`
- 2 Public Subnet: `10.0.1.0/24` (AZ-1a) dan `10.0.2.0/24` (AZ-1b)
- 2 Private Subnet: `10.0.11.0/24` (AZ-1a) dan `10.0.12.0/24` (AZ-1b)
- Internet Gateway (pintu ke internet untuk public subnet)
- NAT Gateway (simulasi via NAT Instance t2.micro)
- Route Tables untuk masing-masing subnet
- VPC Endpoint untuk S3 dan DynamoDB (hemat biaya NAT)

---

### Babak 2: Keamanan Berlapis — Security Groups

Setelah gedung dibangun, tim memasang **sistem keamanan berlapis**. Setiap layer punya aturan siapa yang boleh masuk:

- **ALB Security Group**: Menerima HTTP/HTTPS dari internet (0.0.0.0/0)
- **EB Security Group**: Hanya menerima traffic dari ALB (port 80/8080)
- **RDS Security Group**: Hanya menerima MySQL (port 3306) dari EB dan Lambda
- **Lambda Security Group**: Hanya outbound (untuk akses RDS, DynamoDB)
- **EFS Security Group**: Hanya NFS (port 2049) dari EB

---

### Babak 3: Gudang Kode — S3 Buckets

Tim membutuhkan **dua gudang**:

**S3 Bucket #1 — Deployment Artifacts**
Tempat GitHub Actions menyimpan ZIP file hasil build. Setiap versi baru disimpan di sini sebelum di-deploy ke Elastic Beanstalk.
- Konfigurasi: Versioning enabled, enkripsi AES256, lifecycle 30 hari
- Path: `s3://koperasi-merah-putih-prod-deploy-xxxx/deployments/v1.0.0-blue/app.zip`

**S3 Bucket #2 — Application Storage**
Tempat aplikasi menyimpan file upload user, gambar, dokumen, dll.
- Konfigurasi: CORS enabled, lifecycle transition ke IA setelah 30 hari
- Dilindungi dari akses publik langsung

---

### Babak 4: Storage Bersama — EFS

Bayangkan Elastic Beanstalk memiliki lebih dari satu EC2 instance. Jika user upload file ke instance A, instance B tidak tahu. Solusinya adalah **EFS (Elastic File System)** — seperti hard disk jaringan yang bisa di-mount ke semua instance sekaligus.

Yang dikonfigurasi:
- Performance mode: `generalPurpose` (hemat biaya)
- Throughput mode: `bursting` (free tier friendly)
- Mount target di setiap private subnet
- Access Point untuk `/app-data` dan `/uploads`
- Enkripsi at rest enabled

---

### Babak 5: Otak Backend — Elastic Beanstalk Blue/Green

Inilah inti dari arsitektur kita. **Blue/Green Deployment** bekerja seperti ini:

**Analogi**: Bayangkan Anda punya dua restoran identik. Restoran BIRU sedang melayani pelanggan. Anda mempersiapkan menu baru di restoran HIJAU. Setelah siap dan teruji, Anda memindahkan semua pelanggan ke restoran HIJAU dalam sekejap. Jika ada masalah, tinggal pindah balik ke BIRU.

**Implementasi**:
- **Environment BLUE**: Menjalankan versi stabil (production saat ini)
- **Environment GREEN**: Menerima deployment versi baru
- **ALB**: Bertindak sebagai "kasir" yang mengarahkan pelanggan

Yang dikonfigurasi per environment:
- Instance type: `t2.micro` (free tier)
- VPC: Private subnet
- Platform: Node.js 20 on Amazon Linux 2023
- Health check path: `/health`
- Environment variables: DB credentials, S3 bucket, DynamoDB table
- EFS mount: `/mnt/efs`
- CloudWatch Logs: Stream logs 7 hari

---

### Babak 6: Pintu API — API Gateway

**API Gateway** adalah resepsionis yang menerima semua request API dari client dan meneruskannya ke Lambda yang tepat.

Endpoint yang tersedia:
- `GET /items` — Ambil daftar items (→ Lambda GET)
- `GET /items/{id}` — Ambil item by ID (→ Lambda GET)
- `POST /items` — Buat item baru (→ Lambda POST)
- `PUT /items/{id}` — Update item (→ Lambda POST)
- `DELETE /items/{id}` — Hapus item (→ Lambda POST)
- `GET /health` — Health check (→ Mock response)

Yang dikonfigurasi:
- Type: REST API, REGIONAL endpoint
- Stage: `prod` dengan access logging ke CloudWatch
- X-Ray tracing enabled
- Usage plan: 1 juta request/bulan (free tier)
- Throttling: 1000 req/detik, burst 500

---

### Babak 7: Eksekutor — Lambda Functions

Lambda adalah **karyawan on-demand** — mereka hanya bekerja ketika ada request, dan tidur ketika tidak ada. Ini yang membuat biayanya sangat hemat.

**Lambda POST Handler** — Menangani perubahan data:
- Menerima request POST, PUT, DELETE dari API Gateway
- Memvalidasi input
- Berinteraksi dengan RDS (create/update/delete)
- **Mencatat SETIAP request ke DynamoDB** (log_level, timestamp, duration, IP)
- Mengembalikan response standar

**Lambda GET Handler** — Menangani pembacaan data:
- Menerima request GET dari API Gateway
- Query ke RDS dengan pagination
- **Mencatat SETIAP request ke DynamoDB**
- Health check dengan tes koneksi DB

Yang dikonfigurasi:
- Runtime: Node.js 20.x
- Memory: 128MB (free tier optimal)
- Timeout: 30 detik
- VPC: Private subnet (agar bisa akses RDS)
- Lambda Layer: Shared utils (DB connection, DynamoDB logger)
- X-Ray tracing: Active

---

### Babak 8: Database — RDS MySQL

**RDS** adalah database managed service yang menyimpan data aplikasi. Tim memilih MySQL karena familiar dan masuk free tier.

Yang dikonfigurasi:
- Engine: MySQL 8.0
- Instance: `db.t3.micro` (free tier)
- Storage: 20GB gp2 (free tier maximum)
- Multi-AZ: **Disabled** (free tier — single AZ)
- Backup retention: 1 hari
- Performance Insights: 7 hari (gratis)
- Enkripsi at rest: Enabled
- Tidak publicly accessible (hanya dari dalam VPC)
- Credentials disimpan di **Secrets Manager**

---

### Babak 9: Buku Log — DynamoDB

**DynamoDB** adalah buku besar yang mencatat semua aktivitas sistem. Setiap request yang masuk, setiap error yang terjadi, setiap deployment yang dilakukan — semuanya tercatat.

Tiga tabel yang dibuat:

**1. `koperasi-merah-putih-prod-app-logs`** — Log semua service
- Partition key: `service_id` (lambda-post, lambda-get, eb-blue, dll)
- Sort key: `timestamp` (ISO 8601)
- GSI: `log-level-index` (query ERROR logs)
- GSI: `request-id-index` (distributed tracing)
- TTL: 30 hari (auto-delete log lama)

**2. `koperasi-merah-putih-prod-api-requests`** — Log setiap API request
- Partition key: `request_id`
- Sort key: `timestamp`
- GSI: `endpoint-index` (analisis per endpoint)
- GSI: `status-code-index` (analisis error rate)

**3. `koperasi-merah-putih-prod-deployments`** — Riwayat deployment
- Partition key: `deployment_id`
- Sort key: `timestamp`
- GSI: `color-index` (lihat history blue/green)

---

### Babak 10: Frontend — AWS Amplify

**Amplify** menghubungkan GitHub repository frontend ke AWS. Setiap kali ada push ke branch `main`, Amplify otomatis build dan deploy.

Yang dikonfigurasi:
- Repository: GitHub (menggunakan Personal Access Token)
- Build spec: `npm ci && npm run build`
- Output directory: `dist/`
- SPA routing: Semua path ke `index.html`
- Environment variables: `VITE_API_URL`, `VITE_APP_NAME`
- Pull Request Preview: Enabled

---

### Babak 11: CI/CD Pipeline — GitHub Actions

GitHub Actions adalah **robot deployment** yang bekerja otomatis:

1. Developer push code ke branch `main`
2. GitHub Actions menjalankan tests
3. Build application → ZIP package
4. Upload ZIP ke S3 deployment bucket
5. Buat Elastic Beanstalk Application Version
6. Deploy ke environment **GREEN** (standby)
7. Jalankan health check
8. Catat deployment ke DynamoDB
9. Jika semua OK, switch traffic di ALB (100% ke GREEN)
10. Environment BLUE menjadi standby

Untuk **rollback**: cukup switch traffic kembali ke BLUE.

---

## 🛠️ Cara Deploy Step-by-Step

### Prasyarat

```bash
# Install tools yang dibutuhkan
# 1. Terraform v1.5+
winget install HashiCorp.Terraform

# 2. AWS CLI v2
winget install Amazon.AWSCLI

# 3. Node.js v20
winget install OpenJS.NodeJS.LTS
```

### Step 1: Clone dan Persiapkan

```bash
git clone <repo-url>
cd terraform-gb-deplyoment
```

### Step 2: Konfigurasi AWS Credentials

```bash
aws configure
# Masukkan:
# AWS Access Key ID: [dari IAM Console]
# AWS Secret Access Key: [dari IAM Console]
# Default region: ap-southeast-1
# Default output: json
```

> [!IMPORTANT]
> **Izin IAM yang Diperlukan:** User IAM yang digunakan harus memiliki akses untuk membuat resource. Untuk keperluan Lab, disarankan menggunakan policy **`AdministratorAccess`**. Jika ingin lebih spesifik, pastikan user memiliki akses ke: *VPC, IAM (Create Role), S3, RDS, DynamoDB, Lambda, API Gateway, Elastic Beanstalk, Amplify, dan EFS.*

### Step 3: Buat file terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit file terraform.tfvars dengan nilai yang sesuai
```

Isi minimal yang wajib diubah:
```hcl
db_password         = "PasswordKuat123!"
github_repo_url     = "https://github.com/user/repositori"
github_access_token = "ghp_xxxxxxxxxxxx"
```

### Step 4: Install Lambda Layer Dependencies

```bash
cd lambda/layer/nodejs
npm install
cd ../../..
```

### Step 5: Buat Deployment Bundle Awal

> [!NOTE]
> Elastic Beanstalk membutuhkan file ZIP di S3 sebelum environment bisa dibuat. Kita perlu membuat placeholder dulu.

### Step 5: Buat Deployment Bundle Awal

> [!NOTE]
> Elastic Beanstalk membutuhkan file ZIP di S3 sebelum environment bisa dibuat. Kita perlu membuat placeholder dulu.

#### A. Untuk Windows (PowerShell) - **Gunakan ini jika Anda di Windows**
```powershell
# 1. Buat folder dan file app.js
mkdir -Force app-bundle
@'
const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
  } else {
    res.writeHead(200);
    res.end('Hello from Blue/Green App!');
  }
});
server.listen(process.env.PORT || 8080);
console.log('Server running on port', process.env.PORT || 8080);
'@ | Out-File -FilePath "app-bundle/app.js" -Encoding utf8

# 2. Buat file package.json
@'
{
  "name": "koperasi-merah-putih",
  "version": "1.0.0",
  "scripts": { "start": "node app.js" },
  "engines": { "node": ">=20" }
}
'@ | Out-File -FilePath "app-bundle/package.json" -Encoding utf8

# 3. Buat file ZIP
Compress-Archive -Path "app-bundle/*" -DestinationPath "app-placeholder.zip" -Force
```

#### B. Untuk Linux / macOS / Git Bash
```bash
# Buat folder dan app.js
mkdir -p app-bundle
cat > app-bundle/app.js << 'EOF'
const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
  } else {
    res.writeHead(200);
    res.end('Hello from Blue/Green App!');
  }
});
server.listen(process.env.PORT || 8080);
console.log('Server running on port', process.env.PORT || 8080);
EOF

# Buat package.json
cat > app-bundle/package.json << 'EOF'
{
  "name": "koperasi-merah-putih",
  "version": "1.0.0",
  "scripts": { "start": "node app.js" },
  "engines": { "node": ">=20" }
}
EOF

# ZIP bundle
cd app-bundle && zip -r ../app-placeholder.zip . && cd ..
```

### Step 6: Terraform Init

```bash
terraform init
```

Output yang diharapkan:
```
Initializing provider plugins...
- Installing hashicorp/aws v5.x.x
- Installing hashicorp/archive v2.x.x
- Installing hashicorp/random v3.x.x

Terraform has been successfully initialized!
```

### Step 7: Terraform Plan

```bash
terraform plan -out=tfplan
```

Review output. Pastikan tidak ada resource berbayar yang tidak diinginkan.

### Step 8: Upload Placeholder ke S3 (Sebelum Apply)

> [!NOTE]
> Karena Elastic Beanstalk membutuhkan file di S3, kita perlu strategi dua-tahap.

**Pilih perintah sesuai OS Anda:**

<details>
<summary><b>Linux / macOS / Git Bash</b></summary>

```bash
# Tahap 1: Buat hanya S3 bucket dulu
terraform apply -target="aws_s3_bucket.deployment" -target="random_id.bucket_suffix" -auto-approve

# Ambil nama bucket yang dibuat
BUCKET=$(terraform output -raw s3_deployment_bucket)
echo "Bucket: $BUCKET"

# Upload placeholder untuk Blue dan Green
aws s3 cp app-placeholder.zip "s3://${BUCKET}/deployments/v100blue/app.zip"
aws s3 cp app-placeholder.zip "s3://${BUCKET}/deployments/v101green/app.zip"
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
# Tahap 1: Buat hanya S3 bucket dulu (Gunakan tanda kutip untuk target)
terraform apply -target="aws_s3_bucket.deployment" -target="random_id.bucket_suffix" -auto-approve

# Ambil nama bucket yang dibuat
$BUCKET = terraform output -raw s3_deployment_bucket
echo "Bucket: $BUCKET"

# Upload placeholder untuk Blue dan Green
aws s3 cp app-placeholder.zip "s3://${BUCKET}/deployments/v100blue/app.zip"
aws s3 cp app-placeholder.zip "s3://${BUCKET}/deployments/v101green/app.zip"
```
</details>

### Step 9: Terraform Apply Penuh

> [!IMPORTANT]
> Karena kita baru saja melakukan `apply` untuk S3 di Step 8, file `tfplan` lama Anda sekarang sudah kedaluwarsa (*stale*). Anda **wajib** membuat ulang plan sebelum apply penuh.

```powershell
# 1. Buat ulang plan yang segar
terraform plan -out=tfplan

# 2. Jalankan apply penuh
terraform apply tfplan
```

⏳ Proses ini membutuhkan **15-25 menit** karena:
- RDS butuh ~10 menit untuk provisioning
- Elastic Beanstalk butuh ~5 menit per environment
- NAT Gateway butuh ~2 menit

### Step 10: Verifikasi Deployment

```bash
# Lihat semua output
terraform output

# Test API Gateway
API_URL=$(terraform output -raw api_gateway_url)
curl "${API_URL}/health"

# Test ALB
ALB_URL=$(terraform output -raw alb_dns_name)
curl "http://${ALB_URL}/health"

# Test Langsung ke EB (Jika ALB bermasalah)
EB_URL=$(terraform output -raw eb_blue_env_url)
curl "http://${EB_URL}/health"
```

---

## 🔄 Cara Blue/Green Deployment

### Deploy versi baru ke Green (standby)

```bash
# 1. Update aplikasi di folder `app-bundle/`
# 2. Push ke branch main → GitHub Actions otomatis deploy ke GREEN

# 3. Cek status environment GREEN
aws elasticbeanstalk describe-environments \
  --environment-names "koperasi-green" \
  --query 'Environments[0].{Status:Status,Health:Health,HealthStatus:HealthStatus}'
```

### Switch traffic ke Green

```bash
# Via Terraform (recommended)
terraform apply -var="active_color=green"

# Atau via GitHub Actions workflow_dispatch dengan swap_traffic=true
```

### Rollback ke Blue

```bash
# Jika ada masalah, kembali ke Blue dalam hitungan detik
terraform apply -var="active_color=blue"
```

---

## 📊 Melihat Logs di DynamoDB

```bash
# Lihat ERROR logs terbaru
aws dynamodb query \
  --table-name "koperasi-merah-putih-prod-app-logs" \
  --index-name "log-level-index" \
  --key-condition-expression "log_level = :level" \
  --expression-attribute-values '{":level":{"S":"ERROR"}}' \
  --scan-index-forward false \
  --limit 10

# Lihat log per service (Lambda POST)
aws dynamodb query \
  --table-name "koperasi-merah-putih-prod-app-logs" \
  --key-condition-expression "service_id = :sid" \
  --expression-attribute-values '{":sid":{"S":"lambda-post-ap-southeast-1"}}' \
  --scan-index-forward false \
  --limit 20

# Lihat riwayat deployment
aws dynamodb scan \
  --table-name "koperasi-merah-putih-prod-deployments" \
  --limit 10
```

---

## 🧹 Cara Menghapus Semua Resource

```bash
# PERINGATAN: Ini akan menghapus SEMUA resource!
terraform destroy

# Jika ada resource yang stuck, hapus manual dulu di Console AWS
# lalu jalankan terraform destroy lagi
```

---

## 💰 Estimasi Biaya (Free Tier)

| Service | Free Tier | Estimasi Biaya |
|---------|-----------|----------------|
| EC2 (EB) | 750 jam t2.micro/bln | **Gratis** |
| RDS | 750 jam db.t3.micro/bln | **Gratis** |
| Lambda | 1 juta request/bln | **Gratis** |
| API Gateway | 1 juta request/bln | **Gratis** |
| S3 | 5GB + 20K GET/bln | **Gratis** |
| DynamoDB | 25GB + 25WCU/25RCU | **Gratis** |
| Amplify | 1000 build menit/bln | **Gratis** |
| ALB | 750 jam/bln (12 bln pertama) | **Gratis** |
| NAT Gateway | **Tidak ada free tier** | ~$32/bln |
| EFS | **Tidak ada free tier** | ~$0.30/GB/bln |

> **💡 Tips Hemat**: Untuk development, matikan NAT Gateway saat tidak digunakan, atau ganti dengan NAT Instance (t2.micro - free tier).

---

## 🔐 GitHub Actions Secrets yang Diperlukan

Tambahkan secrets berikut di repository GitHub Anda:
(`Settings → Secrets and variables → Actions → New repository secret`)

| Secret Name | Nilai |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Access key dari IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret key dari IAM user |
| `AWS_DEPLOYMENT_BUCKET` | Nama S3 deployment bucket (dari `terraform output`) |

---

## 📁 Struktur Project

```
terraform-gb-deplyoment/
├── providers.tf          # Provider AWS & Terraform version
├── variables.tf          # Semua input variable
├── locals.tf             # Computed values & random ID
├── outputs.tf            # Output setelah terraform apply
├── vpc.tf                # VPC, Subnet, IGW, NAT, Routes
├── security_groups.tf    # Security groups semua service
├── iam.tf                # IAM roles, policies, Secrets Manager
├── s3.tf                 # S3 buckets (deploy + storage)
├── efs.tf                # EFS file system
├── alb.tf                # Application Load Balancer
├── elastic_beanstalk.tf  # EB Application + Blue/Green envs
├── rds.tf                # RDS MySQL
├── dynamodb.tf           # DynamoDB tables (logging)
├── lambda.tf             # Lambda functions (POST + GET)
├── api_gateway.tf        # API Gateway REST API
├── amplify.tf            # AWS Amplify frontend
├── terraform.tfvars.example  # Template konfigurasi
├── .gitignore
├── lambda/
│   ├── layer/nodejs/     # Shared utilities (logger, DB, response)
│   ├── post-handler/     # Lambda POST source code
│   └── get-handler/      # Lambda GET source code
└── .github/workflows/
    └── blue-green-deploy.yml  # CI/CD pipeline
```

---

## ❓ FAQ

**Q: Mengapa dua environment EB berjalan bersamaan jika free tier hanya 750 jam?**
A: Free tier 750 jam = 1 instance selama sebulan penuh. Dua instance = ~375 jam masing-masing, atau Anda menanggung biaya ringan untuk 1 instance tambahan. Untuk pure free tier, matikan environment standby saat tidak diperlukan.

**Q: Bagaimana cara melihat environment mana yang aktif?**
A: `terraform output active_environment` atau lihat ALB listener rules di console.

**Q: Apakah bisa deploy tanpa NAT Gateway?**
A: Bisa, tapi Lambda dan EB tidak bisa akses internet (download packages, dll). Alternatifnya: buat Lambda di luar VPC (tapi tidak bisa akses RDS), atau gunakan NAT Instance (t2.micro free tier).

---

*Dibuat dengan ❤️ menggunakan Terraform & AWS Free Tier*
