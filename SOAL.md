# Soal: Desain dan Implementasi Arsitektur Cloud AWS dengan Blue/Green Deployment — Koperasi Merah Putih

## Latar Belakang

Koperasi Merah Putih sedang melakukan transformasi digital besar-besaran dan membutuhkan infrastruktur web yang scalable, aman, dan tanpa downtime. Tim DevOps diminta untuk merancang solusi menggunakan strategi **Blue/Green Deployment** di atas AWS. Seluruh komponen harus diatur menggunakan Infrastructure as Code (IaC) dengan Terraform dan memanfaatkan batasan Free Tier secara optimal. Selain fungsionalitas aplikasi, setiap interaksi sistem harus dicatat secara otomatis ke dalam **Amazon DynamoDB** sebagai log terpusat untuk memudahkan pemantauan dan audit secara real-time.

## Cerita Arsitektur (Story)

### Babak 1: Fondasi Jaringan — VPC
Dikisahkan sebuah tim developer membangun gedung kantor privat berupa **Virtual Private Cloud (VPC)** sebagai fondasi utama bagi Koperasi Merah Putih. Konfigurasi yang diterapkan meliputi CIDR Block 10.0.0.0/16 dengan pembagian Public Subnet untuk Load Balancer yang dapat diakses internet, dan Private Subnet untuk tempat Elastic Beanstalk dan RDS berada agar terlindung dari akses langsung. Infrastruktur ini dilengkapi dengan Internet Gateway sebagai pintu akses publik, NAT Gateway sebagai pintu keluar satu arah untuk private subnet, Route Tables untuk masing-masing subnet, serta VPC Endpoint untuk S3 dan DynamoDB guna mengoptimalkan trafik internal.

### Babak 2: Keamanan Berlapis — Security Groups
Setelah gedung dibangun, tim memasang sistem keamanan berlapis di mana setiap lapisan memiliki aturan akses yang sangat ketat. Konfigurasi mencakup ALB Security Group yang menerima trafik HTTP/HTTPS dari internet publik (0.0.0.0/0), Elastic Beanstalk Security Group yang hanya menerima trafik dari ALB pada port 80/8080, serta RDS Security Group yang hanya menerima koneksi MySQL (port 3306) dari Elastic Beanstalk dan Lambda. Selain itu, terdapat Lambda Security Group dengan aturan outbound untuk akses database dan logging, serta EFS Security Group yang hanya mengizinkan koneksi NFS dari instance Elastic Beanstalk.

### Babak 3: Gudang Kode dan Media — S3 Buckets
Tim membutuhkan dua gudang penyimpanan utama berbasis S3. Gudang pertama adalah Deployment Bucket untuk menyimpan artefak ZIP hasil build dari GitHub Actions dengan konfigurasi Versioning enabled, enkripsi AES256, dan Lifecycle policy 30 hari. Gudang kedua adalah Application Storage Bucket untuk menyimpan file upload pengguna, gambar, dan dokumen dengan konfigurasi CORS enabled serta transisi lifecycle ke storage class Infrequent Access setelah 30 hari untuk efisiensi biaya.

### Babak 4: Storage Bersama — EFS
Untuk memastikan data tetap konsisten antar instance di Elastic Beanstalk, digunakan **EFS (Elastic File System)** sebagai hard disk jaringan yang dapat di-mount secara bersamaan. Konfigurasi menggunakan performance mode General Purpose dan throughput mode Bursting yang selaras dengan Free Tier. Mount target dibuat di setiap private subnet, lengkap dengan Access Point untuk direktori aplikasi dan unggahan, serta enkripsi at-rest yang diaktifkan untuk keamanan data.

### Babak 5: Otak Backend — Elastic Beanstalk Blue/Green
Inti dari arsitektur ini adalah mekanisme Blue/Green Deployment menggunakan Elastic Beanstalk. Konfigurasi mencakup satu Environment **BLUE** yang menjalankan versi stabil dan satu Environment **GREEN** yang menerima deployment versi baru bagi Koperasi Merah Putih. Application Load Balancer bertindak sebagai pengatur trafik utama yang memindahkan beban antar environment melalui weighted listener rules. Setiap environment menggunakan instance t2.micro, platform Node.js 20, dan health check pada endpoint /health untuk memastikan aplikasi berjalan dengan benar.

### Babak 6: Pintu API — API Gateway
**API Gateway** berfungsi sebagai resepsionis yang menerima semua request API dari klien dan meneruskannya ke fungsi Lambda yang tepat. Konfigurasi menggunakan tipe REST API dengan Regional endpoint dan stage bernama 'prod'. Sistem dilengkapi dengan access logging ke CloudWatch, X-Ray tracing, serta usage plan yang membatasi kuota hingga 1 juta request per bulan dengan throttling 1000 request per detik sesuai batas Free Tier AWS.

### Babak 7: Eksekutor Serverless — Lambda Functions
Fungsi Lambda bertindak sebagai karyawan on-demand yang hanya bekerja saat ada permintaan. Terdiri dari **Lambda POST Handler** untuk menangani perubahan data (POST, PUT, DELETE) dan **Lambda GET Handler** untuk pembacaan data. Konfigurasi menggunakan runtime Node.js 20.x, memori 128MB, dan timeout 30 detik. Setiap fungsi berjalan di dalam VPC agar dapat mengakses RDS dan wajib mencatat setiap aktivitas request secara otomatis ke tabel DynamoDB sebagai log sistem Koperasi Merah Putih.

### Babak 8: Database Utama — RDS MySQL
Penyimpanan data relasional dikelola oleh **RDS MySQL 8.0** menggunakan instance db.t3.micro. Konfigurasi mencakup storage 20GB gp2 tanpa fitur Multi-AZ untuk menjaga efisiensi Free Tier. Database tidak dapat diakses secara publik dan hanya menerima koneksi dari dalam VPC. Kredensial database tidak disimpan dalam kode, melainkan diamankan di dalam Secrets Manager dan diambil secara programatik oleh aplikasi saat runtime.

### Babak 9: Buku Log Terpusat — DynamoDB
**DynamoDB** digunakan sebagai buku besar yang mencatat seluruh aktivitas sistem Koperasi Merah Putih. Konfigurasi mencakup tiga tabel utama dengan partition key dan sort key (timestamp) yang optimal. Digunakan pula Global Secondary Index (GSI) untuk pencarian log berdasarkan level (ERROR/INFO) dan fitur Time-to-Live (TTL) untuk menghapus log lama secara otomatis tanpa biaya tambahan.

### Babak 10: Otomasi CI/CD — GitHub Actions & Amplify
Seluruh proses deployment diatur secara otomatis oleh **GitHub Actions** dan **AWS Amplify**. Amplify menangani hosting frontend dengan koneksi langsung ke repositori GitHub, sementara GitHub Actions menjalankan pipeline yang mencakup pengujian unit, pembangunan artefak ZIP, unggah ke S3, hingga eksekusi switch traffic pada ALB untuk strategi Blue/Green. Mekanisme ini memungkinkan tim untuk melakukan rollback instan dengan hanya mengubah variabel warna aktif di konfigurasi Terraform.

## Persyaratan Pengerjaan

Mahasiswa diminta untuk mengimplementasikan seluruh arsitektur yang telah dijelaskan di atas menggunakan Terraform. Seluruh konfigurasi harus terorganisir dalam file `.tf` berdasarkan fungsinya. Kode Lambda harus mencakup integrasi pencatatan log ke DynamoDB. Workflow GitHub Actions wajib memiliki tahap pengetesan, deployment, dan swap traffic. Dokumentasi akhir harus menyertakan README.md yang menjelaskan langkah deployment dan prosedur operasional Blue/Green switching secara detail.
