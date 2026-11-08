# MAIZEDOCTOR — Complete Oracle Cloud Infrastructure (OCI) Deployment Guide

**Document Version:** 1.0.0
**Target Platform:** Oracle Cloud Infrastructure (OCI) Compute Instance
**Target OS:** Ubuntu 22.04 LTS / 24.04 LTS (x86_64 / aarch64)
**System Version:** MAIZEDOCTOR v0.1.0
**Target Architecture:** Multi-tier decoupled architecture (Node.js REST API + Python FastAPI AI Service + PostgreSQL with pgvector + Redis + Nginx Reverse Proxy)

---

## Table of Contents

1. [Architectural Overview & Server Topology](#1-architectural-overview--server-topology)
2. [OCI Compute Sizing & Resource Planning](#2-oci-compute-sizing--resource-planning)
   - 2.1 Compute Shapes (x86_64 vs. ARM64 Ampere)
   - 2.2 Memory, Storage & CPU Budgets
   - 2.3 Network Bandwidth & Firewall Topology
3. [Oracle Cloud Infrastructure Setup (Console & CLI)](#3-oracle-cloud-infrastructure-setup-console--cli)
   - 3.1 VCN, Subnet, and Internet Gateway Creation
   - 3.2 OCI Security Lists & Ingress Rules
   - 3.3 Compute Instance Creation & SSH Setup
   - 3.4 Reserved Public IP Assignment
   - 3.5 Overcoming Default OCI Ubuntu `iptables` Traps
4. [Base Server Provisioning & OS Hardening](#4-base-server-provisioning--os-hardening)
   - 4.1 System Update and Essential Build Tooling
   - 4.2 Dedicated Service User Provisioning (`maizedoctor`)
   - 4.3 SSH Hardening & UFW Host Firewall
   - 4.4 Node.js 24 LTS Installation
   - 4.5 Python 3.11 & Build Dependencies Installation
5. [PostgreSQL 16 & pgvector Extension Deployment](#5-postgresql-16--pgvector-extension-deployment)
   - 5.1 Official PGDG Repository & Installation
   - 5.2 Building/Installing `pgvector` for Vector Similarity
   - 5.3 PostgreSQL Hardening (Local Loopback & Authentication)
   - 5.4 Database Provisioning & Least-Privilege Roles
   - 5.5 Extension Verification
6. [Redis 7/8 In-Memory Cache & Shared Quotas](#6-redis-78-in-memory-cache--shared-quotas)
   - 6.1 Installation & Configuration
   - 6.2 Password Authentication & Loopback Binding
   - 6.3 Service Verification
7. [Machine Learning Artifacts & Shared Preprocessing](#7-machine-learning-artifacts--shared-preprocessing)
   - 7.1 Model Weights Provenance (`epoch-008.pt`)
   - 7.2 Directory Structure & SHA-256 Checksum Validation
   - 7.3 Shared Preprocessing Package Installation (`maizedoctor_preprocessing v1.0.0`)
   - 7.4 Python Inference Environment & PyTorch CPU
8. [Python FastAPI AI Service Deployment](#8-python-fastapi-ai-service-deployment)
   - 8.1 Virtual Environment & Dependencies
   - 8.2 Environment Configuration (`ai-service/.env`)
   - 8.3 Systemd Service Unit (`maizedoctor-ai.service`)
   - 8.4 Verification of Health, Diagnostics, and Predict Contracts
9. [Node.js Orchestration Backend Deployment](#9-nodejs-orchestration-backend-deployment)
   - 9.1 Source Checkout & Production Dependency Installation
   - 9.2 Environment Configuration (`backend/.env`)
   - 9.3 Prisma Migrations Deployment & Client Generation
   - 9.4 TypeScript Compilation
   - 9.5 Headless Admin Seed Provisioning
   - 9.6 Systemd Service Unit (`maizedoctor-backend.service`)
   - 9.7 Periodic Scan Cleanup Worker (`maizedoctor-cleanup.service`)
10. [RAG Knowledge Corpus Ingestion & Gemini Setup](#10-rag-knowledge-corpus-ingestion--gemini-setup)
    - 10.1 Curated Extension Corpus Loading
    - 10.2 Embedding Generation (`text-embedding-004`)
    - 10.3 Vector Search Verification in PostgreSQL
11. [Nginx Reverse Proxy, Domain & Let's Encrypt HTTPS](#11-nginx-reverse-proxy-domain--lets-encrypt-https)
    - 11.1 Nginx Installation & Upload Buffer Tuning
    - 11.2 Site Configuration (Upstream Routing & Proxy Headers)
    - 11.3 Certbot SSL/TLS Provisioning & Auto-Renewal
12. [Complete Production Environment Variables Reference](#12-complete-production-environment-variables-reference)
13. [Production Architecture Diagrams](#13-production-architecture-diagrams)
14. [Step-by-Step Copy-Paste Deployment Runbook](#14-step-by-step-copy-paste-deployment-runbook)
15. [Operations, Log Management & Health Monitoring](#15-operations-log-management--health-monitoring)
16. [Backup, Restore, Update, and Rollback Runbooks](#16-backup-restore-update-and-rollback-runbooks)
17. [Production Verification Checklist & Troubleshooting Matrix](#17-production-verification-checklist--troubleshooting-matrix)

---

## 1. Architectural Overview & Server Topology

The MAIZEDOCTOR production stack runs as a collection of high-performance, isolated daemons managed by Linux `systemd`, fronted by Nginx as an SSL/TLS-terminating reverse proxy:

```
                      [ INTERNET / MOBILE CLIENTS ]
                                    │
                                    │ HTTPS (Port 443) / HTTP (Port 80)
                                    ▼
       ┌─────────────────────────────────────────────────────────────┐
       │             ORACLE CLOUD COMPUTE INSTANCE                   │
       │                                                             │
       │  [ Nginx Reverse Proxy (Port 80/443) ]                      │
       │        │                                                    │
       │        ├── /api/v1/ ──────────► [ Node.js Backend API ]      │
       │        └── /health  ──────────► (Port 3000, 127.0.0.1)      │
       │                                       │                     │
       │                   ┌───────────────────┼─────────────────┐   │
       │                   │                   │                 │   │
       │                   ▼                   ▼                 ▼   │
       │         [ PostgreSQL 16 ]     [ Redis 7/8 ]     [ AI Svc ]  │
       │         (Port 5432, loopback) (Port 6379)       (Port 8000) │
       │         • pgvector extension  • Rate limiting   • FastAPI   │
       │         • Business data       • Quota buckets   • PyTorch   │
       │         • Vector embeddings                     • MobileNet │
       │                                                             │
       └───────────────────────────────────────┬─────────────────────┘
                                               │
                        ┌──────────────────────┴─────────────────────┐
                        ▼                                            ▼
           [ Google Gemini API ]                       [ Cloudinary API ]
           • text-embedding-004 (768d)                 • Private authenticated
           • gemini-2.5-flash (grounded RAG)             leaf scan storage
```

### Core Separation Guarantees
- **Nginx** is the **only** process listening on public interfaces (`0.0.0.0:80`, `0.0.0.0:443`).
- **Node.js REST API** binds to `127.0.0.1:3000`.
- **FastAPI AI Service** binds to `127.0.0.1:8000`.
- **PostgreSQL 16** binds to `127.0.0.1:5432`.
- **Redis** binds to `127.0.0.1:6379`.
- **Cloudinary** credentials and **Google Gemini** API keys exist strictly in server-side configuration; they are never sent to mobile clients.

---

## 2. OCI Compute Sizing & Resource Planning

### 2.1 Compute Shapes (x86_64 vs. ARM64 Ampere)

Oracle Cloud Infrastructure offers two primary compute architectures suitable for this workload:

| Specification | Recommended Production (`VM.Standard.E4.Flex`) | OCI Always Free Compatible (`VM.Standard.A1.Flex`) | Low-Resource Testing (`VM.Standard.E2.1.Micro`) |
|---|---|---|---|
| **Architecture** | AMD EPYC x86_64 | Ampere Altra ARM64 (aarch64) | AMD EPYC x86_64 |
| **OCPU / vCPU** | 2 OCPU (4 vCPUs) | 4 OCPU (4 vCPUs) | 1/8 OCPU (1 vCPU burstable) |
| **RAM** | **12 GB – 16 GB** | **16 GB – 24 GB** | **1 GB** |
| **Boot Volume** | 100 GB Balanced NVMe | 100 GB – 200 GB NVMe | 50 GB NVMe |
| **Suitability** | **Recommended for production.** Full native wheel compatibility for PyTorch, OpenCV, Sharp, Node 24. | **High performance.** PyTorch CPU wheels exist for `linux_aarch64`. Excellent memory allocation in Always Free tier. | ❌ **NOT SUITABLE.** Will suffer fatal Out-Of-Memory (OOM) during PyTorch initialization and Node build. |

> [!WARNING]
> **Do not attempt to deploy on a 1 GB RAM instance (`VM.Standard.E2.1.Micro`).**
> PyTorch CPU runtime requires ~400 MB baseline resident memory; Node.js 24 with Prisma requires ~250 MB; PostgreSQL with pgvector requires ~300 MB; and TypeScript compilation requires ~800 MB. A minimum of **6 GB RAM** is required for reliable operation, with **12 GB+ RAM recommended**.

### 2.2 Memory, Storage & CPU Budgets

| Subsystem | Baseline RAM | Peak / Burst RAM | CPU Sizing | Storage Footprint |
|---|---|---|---|---|
| **Node.js 24 API** | 180 MB | 512 MB (sharp image processing) | 1.0 vCPU | ~500 MB (app + `node_modules`) |
| **Python FastAPI AI** | 450 MB | 1,200 MB (inference batch + RAG) | 1.5 vCPU | ~2.5 GB (PyTorch, Torchvision, Python libs) |
| **Model Artifacts** | N/A | Cached in memory (`epoch-008.pt`) | N/A | ~15 MB weights, metadata JSONs |
| **PostgreSQL 16 + pgvector**| 250 MB | 1,024 MB (shared buffers + work_mem)| 1.0 vCPU | ~5 GB initial (grows with scans & chunks) |
| **Redis Cache** | 30 MB | 128 MB | 0.2 vCPU | In-memory with append-only persistence |
| **Nginx & OS Buffers** | 60 MB | 256 MB | 0.3 vCPU | ~10 GB OS & system logs |
| **Total Recommended** | **~1.0 GB** | **~3.2 GB** | **4 vCPUs** | **Minimum 50 GB Boot Volume** |

### 2.3 Network Bandwidth & Firewall Topology

| Port | Protocol | Scope | Direction | Purpose |
|---|---|---|---|---|
| **22** | TCP | Public (Restricted CIDR recommended) | Ingress | Secure Shell (SSH) remote administrative access |
| **80** | TCP | Public (`0.0.0.0/0`) | Ingress | HTTP (Certbot ACME challenge & HTTP $\to$ HTTPS redirect) |
| **443** | TCP | Public (`0.0.0.0/0`) | Ingress | HTTPS (Encrypted client API and web traffic) |
| **3000** | TCP | **Internal Only (`127.0.0.1`)** | Loopback | Node.js Express REST API |
| **8000** | TCP | **Internal Only (`127.0.0.1`)** | Loopback | Python FastAPI AI microservice |
| **5432** | TCP | **Internal Only (`127.0.0.1`)** | Loopback | PostgreSQL database listener |
| **6379** | TCP | **Internal Only (`127.0.0.1`)** | Loopback | Redis cache & rate-limit listener |

---

## 3. Oracle Cloud Infrastructure Setup (Console & CLI)

### 3.1 VCN, Subnet, and Internet Gateway Creation

1. Log in to the [Oracle Cloud Console](https://cloud.oracle.com/).
2. Select your designated **Region** (e.g., `us-ashburn-1`, `eu-frankfurt-1`) and **Compartment**.
3. Navigate to **Networking** $\to$ **Virtual Cloud Networks (VCN)**.
4. Click **Start VCN Wizard** $\to$ Select **Create VCN with Internet Connectivity** $\to$ Click **Start VCN Wizard**.
5. Configure VCN Parameters:
   - **VCN Name:** `maizedoctor-vcn`
   - **IPv4 CIDR Block:** `10.0.0.0/16`
   - **Public Subnet CIDR Block:** `10.0.0.0/24`
   - **Private Subnet CIDR Block:** `10.0.1.0/24`
6. Click **Next** $\to$ Review resources $\to$ Click **Create**.
   *This automatically provisions the VCN, an Internet Gateway, a NAT Gateway, default Route Tables, and default Security Lists.*

### 3.2 OCI Security Lists & Ingress Rules

1. In the OCI Console, navigate to **Networking** $\to$ **Virtual Cloud Networks** $\to$ Click `maizedoctor-vcn`.
2. Click **Security Lists** under *Resources* $\to$ Click **Default Security List for maizedoctor-vcn**.
3. Under **Ingress Rules**, click **Add Ingress Rules**.
4. Add the following rules:

#### Rule 1: HTTP Traffic (Port 80)
- **Source Type:** CIDR
- **Source CIDR:** `0.0.0.0/0`
- **IP Protocol:** TCP
- **Destination Port Range:** `80`
- **Description:** Allow HTTP for Let's Encrypt validation and HTTPS redirects.

#### Rule 2: HTTPS Traffic (Port 443)
- **Source Type:** CIDR
- **Source CIDR:** `0.0.0.0/0`
- **IP Protocol:** TCP
- **Destination Port Range:** `443`
- **Description:** Allow secure production HTTPS traffic from mobile apps.

#### Rule 3: SSH Management (Port 22)
- **Source Type:** CIDR
- **Source CIDR:** `0.0.0.0/0` (or your static management IP/CIDR for enhanced security)
- **IP Protocol:** TCP
- **Destination Port Range:** `22`
- **Description:** Secure Shell administration.

> [!CAUTION]
> **Do not add ingress rules for ports 3000, 8000, 5432, or 6379.** Doing so exposes backend databases and microservices directly to the public internet.

### 3.3 Compute Instance Creation & SSH Setup

1. In OCI Console, navigate to **Compute** $\to$ **Instances** $\to$ Click **Create Instance**.
2. **Name:** `maizedoctor-production-01`
3. **Placement:** Select an Availability Domain (e.g., `AD-1`).
4. **Image and Shape:**
   - Click **Change Image** $\to$ Select **Canonical Ubuntu** $\to$ Choose **Ubuntu 22.04 LTS** or **Ubuntu 24.04 LTS**.
   - Click **Change Shape**:
     - *Option A (AMD x86_64):* Select **VM.Standard.E4.Flex** $\to$ 2 OCPU, 12 GB RAM.
     - *Option B (Ampere ARM64):* Select **VM.Standard.A1.Flex** $\to$ 4 OCPU, 16 GB RAM.
5. **Networking:**
   - Select **Primary Network:** Existing Virtual Cloud Network (`maizedoctor-vcn`).
   - Select **Subnet:** Public Subnet (`Public Subnet-maizedoctor-vcn`).
   - **Assign a public IPv4 address:** Select **Yes**.
6. **Add SSH Keys:**
   - Select **Generate a key pair for me** (and download private/public keys), OR select **Upload public key files (.pub)** and upload your existing SSH public key.
7. **Boot Volume:**
   - Check **Use in-transit encryption**.
   - Set **Custom boot volume size:** `100` GB.
8. Click **Create** and wait for the instance state to become **RUNNING**.

### 3.4 Reserved Public IP Assignment

A dynamic public IP will change if the VM is terminated or re-created. Assign a persistent Reserved Public IP:
1. In the Instance details page, click **Attached VNICs** under *Resources*.
2. Click the primary VNIC (`maizedoctor-production-01`).
3. Click **IPv4 Addresses** under *Resources*.
4. Click the three dots on the assigned Public IP $\to$ Select **Edit**.
5. Set **Public IP Type** to **No Public IP** $\to$ Click **Update**.
6. Edit the IP again $\to$ Select **Reserved Public IP** $\to$ Click **Create a new Reserved Public IP** named `maizedoctor-reserved-ip` $\to$ Click **Update**.
7. Note down your assigned IP (e.g., `150.136.x.x`).

### 3.5 Overcoming Default OCI Ubuntu `iptables` Traps

> [!IMPORTANT]
> **CRITICAL OCI UBUNTU BEHAVIOR:**
> Official Oracle Cloud Ubuntu images include aggressive default `iptables` rules that **reject all incoming traffic on ports 80 and 443**, even after you permit them in the OCI Console Security List! You must explicitly allow these ports in the OS firewall.

Connect to your instance over SSH:

```bash
ssh -i /path/to/private_key ubuntu@<YOUR_RESERVED_PUBLIC_IP>
```

Execute the following commands to permit HTTP and HTTPS in OS iptables:

```bash
# Allow HTTP and HTTPS in active iptables
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Persist iptables rules across system reboots
sudo apt-get update && sudo apt-get install -y iptables-persistent netfilter-persistent
sudo netfilter-persistent save
```

---

## 4. Base Server Provisioning & OS Hardening

### 4.1 System Update and Essential Build Tooling

```bash
# Upgrade all base system packages
sudo apt-get update && sudo apt-get dist-upgrade -y

# Install build utilities, compilers, security tools, and libraries
sudo apt-get install -y \
  build-essential \
  pkg-config \
  curl \
  wget \
  git \
  unzip \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  libssl-dev \
  libffi-dev \
  libvips-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  llvm \
  libncurses5-dev \
  libncursesw5-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  liblzma-dev \
  htop \
  ufw \
  fail2ban
```

### 4.2 Dedicated Service User Provisioning (`maizedoctor`)

Running web and AI services as `root` or default `ubuntu` is an unacceptable security hazard. Create an unprivileged system user with dedicated service home directory:

```bash
# Create service group and user
sudo adduser --system --group --shell /bin/bash --home /opt/maizedoctor maizedoctor

# Add your admin user to the maizedoctor group for deployment permissions
sudo usermod -aG maizedoctor ubuntu

# Set directory permissions
sudo chmod 775 /opt/maizedoctor
```

### 4.3 SSH Hardening & UFW Host Firewall

```bash
# Configure Uncomplicated Firewall (UFW)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Enable UFW (Confirm with 'y')
sudo ufw --force enable
sudo ufw status verbose
```

### 4.4 Node.js 24 LTS Installation

The MAIZEDOCTOR backend requires Node.js `24.22.0+` (`>=24.22.0 <25`). Install official NodeSource Node 24:

```bash
# Add NodeSource Node.js 24.x repository
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -

# Install Node.js runtime
sudo apt-get install -y nodejs

# Verify versions match project requirements
node -v   # Must report v24.22.0 or higher
npm -v    # Must report 10.x or higher
```

### 4.5 Python 3.11 & Build Dependencies Installation

The AI service requires Python `>=3.11,<3.12`. On Ubuntu 22.04 LTS, add the official deadsnakes PPA; Ubuntu 24.04 has Python 3.12 default so deadsnakes provides 3.11:

```bash
# Add deadsnakes PPA for strict Python 3.11 support
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update

# Install Python 3.11 runtime, dev headers, and venv module
sudo apt-get install -y \
  python3.11 \
  python3.11-venv \
  python3.11-dev \
  python3.11-distutils

# Verify Python 3.11 installation
python3.11 --version   # Must output Python 3.11.x
```

---

## 5. PostgreSQL 16 & pgvector Extension Deployment

### 5.1 Official PGDG Repository & Installation

Install PostgreSQL 16 directly from the official PostgreSQL Global Development Group (PGDG) apt repository:

```bash
# Add PostgreSQL PGDG apt repository key
sudo install -d /etc/apt/keyrings
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg

# Add repository entry
echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update package index and install PostgreSQL 16
sudo apt-get update
sudo apt-get install -y postgresql-16 postgresql-contrib-16 postgresql-server-dev-16
```

### 5.2 Building/Installing `pgvector` for Vector Similarity

The knowledge base uses dense vector search (768-dimensional embeddings) requiring the `pgvector` extension:

```bash
# Install pgvector from PostgreSQL package or build from official source
cd /tmp
git clone --branch v0.7.4 https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### 5.3 PostgreSQL Hardening (Local Loopback & Authentication)

Verify PostgreSQL listens **only** on the local loopback interface:

```bash
# Edit postgresql.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '127.0.0.1'/g" /etc/postgresql/16/main/postgresql.conf

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl enable postgresql
```

### 5.4 Database Provisioning & Least-Privilege Roles

In accordance with MAIZEDOCTOR security specifications, provision separate database identities:
1. `maizedoctor_owner`: Schema owner used for applying Prisma migrations.
2. `maizedoctor_app`: Runtime application user used by Node.js.
3. `maizedoctor_ai`: Read-only user for vector search queries.

Generate strong random passwords for each user and record them:

```bash
# Switch to postgres superuser
sudo -u postgres psql << 'EOF'
-- Create Database
CREATE DATABASE maizedoctor;

-- Connect to maizedoctor database
\c maizedoctor

-- Enable pgvector and uuid extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create Migration / Owner Role
CREATE USER maizedoctor_owner WITH PASSWORD 'REPLACE_WITH_STRONG_OWNER_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE maizedoctor TO maizedoctor_owner;
GRANT ALL ON SCHEMA public TO maizedoctor_owner;

-- 2. Create Application Runtime Role
CREATE USER maizedoctor_app WITH PASSWORD 'REPLACE_WITH_STRONG_APP_PASSWORD';
GRANT CONNECT ON DATABASE maizedoctor TO maizedoctor_app;
GRANT USAGE ON SCHEMA public TO maizedoctor_app;

-- 3. Create AI Microservice Role
CREATE USER maizedoctor_ai WITH PASSWORD 'REPLACE_WITH_STRONG_AI_PASSWORD';
GRANT CONNECT ON DATABASE maizedoctor TO maizedoctor_ai;
GRANT USAGE ON SCHEMA public TO maizedoctor_ai;

EOF
```

### 5.5 Extension Verification

Verify extensions are registered in PostgreSQL:

```bash
sudo -u postgres psql -d maizedoctor -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp');"
```

Expected output:
```text
  extname  | extversion
-----------+------------
 uuid-ossp | 1.1
 vector    | 0.7.4
(2 rows)
```

---

## 6. Redis 7/8 In-Memory Cache & Shared Quotas

The Node.js backend requires Redis in production for distributed rate limiting (`express-rate-limit` with Redis store) and atomic quota management.

### 6.1 Installation & Configuration

```bash
# Install Redis server
sudo apt-get install -y redis-server
```

### 6.2 Password Authentication & Loopback Binding

Edit `/etc/redis/redis.conf` to enforce strong password authentication and loopback binding:

```bash
# Generate a strong 32-byte hex password
REDIS_SEC_PASS=$(openssl rand -hex 32)
echo "Generated Redis Password: $REDIS_SEC_PASS"

# Enforce binding to localhost only
sudo sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/g' /etc/redis/redis.conf

# Set required authentication password
sudo sed -i "s/# requirepass foobared/requirepass $REDIS_SEC_PASS/g" /etc/redis/redis.conf

# Restart and enable Redis service
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

### 6.3 Service Verification

```bash
# Test authenticated ping
redis-cli -a "$REDIS_SEC_PASS" ping   # Must output PONG
```

---

## 7. Machine Learning Artifacts & Shared Preprocessing

### 7.1 Model Weights Provenance (`epoch-008.pt`)

The MAIZEDOCTOR deep-learning classifier is fine-tuned on the corrected `maize-research-20261008-v2` benchmark.
- **Model Architecture:** `MobileNetV3 Small` (`mobilenet_v3_small` in PyTorch torchvision)
- **Model Version String:** `mobilenet-v3-small-v2-20261009`
- **Trained Checkpoint Name:** `epoch-008.pt`
- **Model Weights SHA-256:** `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`
- **Metadata Spec SHA-256:** `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d`
- **Exact Class Index Mapping:**
  - `0`: `Common_Rust` (*Puccinia sorghi*)
  - `1`: `Gray_Leaf_Spot` (*Cercospora zeae-maydis*)
  - `2`: `Healthy` (*Healthy foliage*)
  - `3`: `Northern_Corn_Leaf_Blight` (*Exserohilum turcicum*)

### 7.2 Directory Structure & SHA-256 Checksum Validation

Create the immutable artifacts repository under `/opt/maizedoctor/artifacts`:

```bash
sudo mkdir -p /opt/maizedoctor/artifacts/calibration
sudo chown -R maizedoctor:maizedoctor /opt/maizedoctor/artifacts
```

Transfer the checkpoint and metadata from the repository or your secure artifact bucket:
- Source: `infrastructure/runtime/artifacts/epoch-008.pt` $\to$ Target: `/opt/maizedoctor/artifacts/epoch-008.pt`
- Source: `infrastructure/runtime/artifacts/model-artifact.json` $\to$ Target: `/opt/maizedoctor/artifacts/model-artifact.json`
- Source: `infrastructure/runtime/artifacts/calibration/calibration-config.json` $\to$ Target: `/opt/maizedoctor/artifacts/calibration/calibration-config.json`

Verify file integrity using SHA-256:

```bash
cd /opt/maizedoctor/artifacts
sha256sum epoch-008.pt model-artifact.json
```

Expected output:
```text
e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66  epoch-008.pt
a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d  model-artifact.json
```

> [!CAUTION]
> If the checksums do not match these exact hashes, the AI service will **fail startup validation** with `MODEL_METADATA_MISMATCH` or `INVALID_MODEL_WEIGHTS`.

---

## 8. Python FastAPI AI Service Deployment

### 8.1 Virtual Environment & Dependencies

Clone or transfer the application source into `/opt/maizedoctor/app`:

```bash
# Clone the repository as maizedoctor user
sudo -u maizedoctor git clone https://github.com/umerfarooq-sde/maize-disease-detection.git /opt/maizedoctor/app
cd /opt/maizedoctor/app/ai-service

# Create Python 3.11 virtual environment
sudo -u maizedoctor python3.11 -m venv .venv

# Upgrade pip and wheel tooling
sudo -u maizedoctor .venv/bin/pip install --upgrade pip setuptools wheel

# Install PyTorch and Torchvision CPU-only wheels (optimized for inference)
sudo -u maizedoctor .venv/bin/pip install torch==2.10.0 torchvision==0.25.0 --index-url https://download.pytorch.org/whl/cpu

# Install the shared preprocessing package in editable mode
sudo -u maizedoctor .venv/bin/pip install -e ../shared/preprocessing

# Install AI service requirements
sudo -u maizedoctor .venv/bin/pip install \
  "fastapi>=0.128.5,<1" \
  "uvicorn>=0.47.0,<1" \
  "pydantic>=2.13,<3" \
  "pydantic-settings>=2.12,<3" \
  "httpx>=0.28.1,<1" \
  "psycopg[binary]>=3.3,<4" \
  "google-genai>=1,<3" \
  "numpy>=2.4.2,<3" \
  "opencv-python-headless==4.13.0.92" \
  "pillow>=12.1.0,<13"
```

### 8.2 Environment Configuration (`ai-service/.env`)

Generate a 32-byte secret token for internal communication between Node.js and FastAPI:

```bash
AI_SERVICE_TOKEN=$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')
OPERATIONS_TOKEN=$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')
```

Create `/opt/maizedoctor/app/ai-service/.env` owned by `maizedoctor:maizedoctor` (permissions `600`):

```bash
sudo -u maizedoctor tee /opt/maizedoctor/app/ai-service/.env > /dev/null << EOF
ENVIRONMENT=production
HOST=127.0.0.1
PORT=8000
LOG_LEVEL=INFO
AI_SERVICE_TOKEN=${AI_SERVICE_TOKEN}
OPERATIONS_TOKEN=${OPERATIONS_TOKEN}

# Database connection for RAG vector search
DATABASE_URL=postgresql://maizedoctor_ai:REPLACE_WITH_STRONG_AI_PASSWORD@127.0.0.1:5432/maizedoctor?schema=public
DATABASE_CONNECT_DEADLINE_SECONDS=8

# ML Model Artifact Configuration
INFERENCE_ENABLED=true
MODEL_PATH=/opt/maizedoctor/artifacts/epoch-008.pt
MODEL_METADATA_PATH=/opt/maizedoctor/artifacts/model-artifact.json
MODEL_METADATA_SHA256=a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d
MODEL_VERSION=mobilenet-v3-small-v2-20261009
PREPROCESSING_VERSION=1.0.0
INFERENCE_THREADS=2
INFERENCE_MAX_CONCURRENCY=1
INFERENCE_UPLOAD_TIMEOUT_SECONDS=10
CONFIDENCE_POLICY_PATH=
CONFIDENCE_POLICY_SHA256=

# RAG & Gemini Configuration
RAG_ENABLED=true
GEMINI_API_KEY=REPLACE_WITH_ACTUAL_GOOGLE_GEMINI_KEY
EMBEDDING_MODEL=text-embedding-004
EMBEDDING_VERSION=2024-05-text-embedding-004
EMBEDDING_DIMENSIONS=768
EMBEDDING_TIMEOUT_SECONDS=8
RAG_CHUNK_CHARS=1000
RAG_CHUNK_OVERLAP=120
RAG_MAX_CONCURRENCY=4

GENERATION_ENABLED=true
GEMINI_MODEL=gemini-2.5-flash
GENERATION_TIMEOUT_SECONDS=12
GENERATION_MAX_CONCURRENCY=2
GENERATION_CONTEXT_CHARS=6000
GENERATION_MAX_CHUNKS=8
GENERATION_CORPUS_PATH=/opt/maizedoctor/app/backend/knowledge/maize-extension-20261012-v1.json
GENERATION_REVIEW_PATH=/opt/maizedoctor/app/backend/knowledge/maize-extension-20261012-v1.review.json
EOF

sudo chmod 600 /opt/maizedoctor/app/ai-service/.env
```

### 8.3 Systemd Service Unit (`maizedoctor-ai.service`)

Create the systemd daemon definition at `/etc/systemd/system/maizedoctor-ai.service`:

```ini
[Unit]
Description=MAIZEDOCTOR Python FastAPI AI Inference & RAG Service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=maizedoctor
Group=maizedoctor
WorkingDirectory=/opt/maizedoctor/app/ai-service
EnvironmentFile=/opt/maizedoctor/app/ai-service/.env
ExecStart=/opt/maizedoctor/app/ai-service/.venv/bin/uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --workers 1 --log-level info
Restart=always
RestartSec=5s
TimeoutStopSec=15s

# Security Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable maizedoctor-ai
sudo systemctl start maizedoctor-ai
```

### 8.4 Verification of Health, Diagnostics, and Predict Contracts

```bash
# Verify process status
sudo systemctl status maizedoctor-ai

# Probe the health endpoint
curl -s http://127.0.0.1:8000/health | jq .
```

Expected output:
```json
{
  "data": {
    "service": "maizedoctor-ai-service",
    "version": "0.1.0",
    "status": "ok",
    "capabilities": {
      "inference": "ready",
      "rag": "ready",
      "generation": "ready"
    },
    "model": {
      "status": "ready",
      "version": "mobilenet-v3-small-v2-20261009"
    }
  }
}
```

---

## 9. Node.js Orchestration Backend Deployment

### 9.1 Source Checkout & Production Dependency Installation

```bash
cd /opt/maizedoctor/app/backend

# Install exact production dependencies using clean-install
sudo -u maizedoctor npm ci
```

### 9.2 Environment Configuration (`backend/.env`)

Generate required cryptographic signing keys:

```bash
JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')
JWT_REFRESH_SECRET=$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')
```

Create `/opt/maizedoctor/app/backend/.env` owned by `maizedoctor:maizedoctor` (permissions `600`):

```bash
sudo -u maizedoctor tee /opt/maizedoctor/app/backend/.env > /dev/null << EOF
NODE_ENV=production
HOST=127.0.0.1
PORT=3000
LOG_LEVEL=info
SHUTDOWN_TIMEOUT_MS=10000

# Client Origins (Must be HTTPS in production)
CORS_ORIGINS=https://yourdomain.com,https://api.yourdomain.com

# Database Connection (maizedoctor_app for runtime, maizedoctor_owner for migrations)
DATABASE_URL=postgresql://maizedoctor_app:REPLACE_WITH_STRONG_APP_PASSWORD@127.0.0.1:5432/maizedoctor?schema=public
DIRECT_DATABASE_URL=postgresql://maizedoctor_owner:REPLACE_WITH_STRONG_OWNER_PASSWORD@127.0.0.1:5432/maizedoctor?schema=public

# Redis Connection
REDIS_URL=redis://:${REDIS_SEC_PASS}@127.0.0.1:6379
REDIS_NAMESPACE=maizedoctor

# Operations Token (Must match AI service OPERATIONS_TOKEN)
OPERATIONS_TOKEN=${OPERATIONS_TOKEN}

# JWT Authentication
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
JWT_ISSUER=maizedoctor
JWT_ACCESS_TTL_SECONDS=900
JWT_REFRESH_TTL_SECONDS=604800

# Cloudinary Storage Configuration
CLOUDINARY_CLOUD_NAME=REPLACE_WITH_CLOUDINARY_CLOUD_NAME
CLOUDINARY_API_KEY=REPLACE_WITH_CLOUDINARY_API_KEY
CLOUDINARY_API_SECRET=REPLACE_WITH_CLOUDINARY_API_SECRET

# AI Microservice Bridge
AI_SERVICE_URL=http://127.0.0.1:8000
AI_SERVICE_TOKEN=${AI_SERVICE_TOKEN}
AI_SERVICE_TIMEOUT_MS=10000
AI_MODEL_VERSION=mobilenet-v3-small-v2-20261009
AI_PREPROCESSING_VERSION=1.0.0

# Rate Limits (Per 60-second window per IP)
RATE_LIMIT_MAX=120
AUTH_RATE_LIMIT_MAX=10
SCAN_RATE_LIMIT_MAX=10
KNOWLEDGE_RATE_LIMIT_MAX=20
GENERATION_RATE_LIMIT_MAX=5
CALCULATOR_RATE_LIMIT_MAX=30
ANALYTICS_RATE_LIMIT_MAX=30
INFERENCE_MAX_CONCURRENCY=1

# Reverse Proxy Trust
TRUST_PROXY=127.0.0.1/32
EOF

sudo chmod 600 /opt/maizedoctor/app/backend/.env
```

### 9.3 Prisma Migrations Deployment & Client Generation

Run production migrations against the database using the schema owner identity:

```bash
cd /opt/maizedoctor/app/backend

# Apply all 15 migrations cleanly
sudo -u maizedoctor npx prisma migrate deploy

# Generate the typed Prisma client
sudo -u maizedoctor npx prisma generate
```

### 9.4 TypeScript Compilation

Compile TypeScript source into production JavaScript distribution (`dist/`):

```bash
cd /opt/maizedoctor/app/backend

# Compile project using TypeScript compiler
sudo -u maizedoctor npm run build

# Verify compiled entry point exists
ls -la dist/server.js
```

### 9.5 Headless Admin Seed Provisioning

Provision your initial administrator account using the secure interactive script:

```bash
cd /opt/maizedoctor/app/backend

# Execute the admin seeding CLI
sudo -u maizedoctor npm run admin:seed
```
*Enter the admin email and a strong, confirmed password when prompted. The account is created with `role = 'ADMIN'` and `status = 'ACTIVE'`.*

### 9.6 Systemd Service Unit (`maizedoctor-backend.service`)

Create `/etc/systemd/system/maizedoctor-backend.service`:

```ini
[Unit]
Description=MAIZEDOCTOR Node.js Orchestration API
After=network.target postgresql.service redis-server.service maizedoctor-ai.service
Wants=postgresql.service redis-server.service maizedoctor-ai.service

[Service]
Type=simple
User=maizedoctor
Group=maizedoctor
WorkingDirectory=/opt/maizedoctor/app/backend
EnvironmentFile=/opt/maizedoctor/app/backend/.env
ExecStart=/usr/bin/node dist/server.js
Restart=always
RestartSec=5s
TimeoutStopSec=15s

# Security Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Enable and start the backend:

```bash
sudo systemctl daemon-reload
sudo systemctl enable maizedoctor-backend
sudo systemctl start maizedoctor-backend
```

### 9.7 Periodic Scan Cleanup Worker (`maizedoctor-cleanup.service`)

MAIZEDOCTOR includes a background cleanup worker (`dist/cli/cleanup-worker.js`) to purge unreferenced Cloudinary uploads and expired guest scans:

Create `/etc/systemd/system/maizedoctor-cleanup.service`:

```ini
[Unit]
Description=MAIZEDOCTOR Cloudinary Asset & Expired Scan Cleaner
After=network.target maizedoctor-backend.service

[Service]
Type=simple
User=maizedoctor
Group=maizedoctor
WorkingDirectory=/opt/maizedoctor/app/backend
EnvironmentFile=/opt/maizedoctor/app/backend/.env
ExecStart=/usr/bin/node dist/cli/cleanup-worker.js
Restart=always
RestartSec=30s

[Install]
WantedBy=multi-user.target
```

Enable and start the cleanup daemon:

```bash
sudo systemctl daemon-reload
sudo systemctl enable maizedoctor-cleanup
sudo systemctl start maizedoctor-cleanup
```

---

## 10. RAG Knowledge Corpus Ingestion & Gemini Setup

To populate the vector database with peer-reviewed agronomic literature for the AI assistant:

### 10.1 Ingest Agricultural Knowledge & Compute Embeddings

```bash
cd /opt/maizedoctor/app/ai-service

# Run knowledge ingestion CLI using Python virtual environment
sudo -u maizedoctor .venv/bin/python -m app.rag.cli ingest \
  --corpus ../backend/knowledge/maize-extension-20261012-v1.json \
  --review ../backend/knowledge/maize-extension-20261012-v1.review.json
```

*This chunks the documentation into ~1000 character windows, queries Gemini for 768-dim embeddings, and persists chunks into the PostgreSQL `knowledge_chunks` table.*

### 10.2 Vector Search Verification in PostgreSQL

Verify that chunks and vectors are populated in PostgreSQL:

```bash
sudo -u postgres psql -d maizedoctor -c "SELECT count(*), embedding_dimensions, embedding_model FROM knowledge_chunks GROUP BY embedding_dimensions, embedding_model;"
```

---

## 11. Nginx Reverse Proxy, Domain & Let's Encrypt HTTPS

### 11.1 Nginx Installation & Upload Buffer Tuning

Install Nginx:

```bash
sudo apt-get install -y nginx
```

### 11.2 Site Configuration (Upstream Routing & Proxy Headers)

Create the site configuration at `/etc/nginx/sites-available/maizedoctor`:

```nginx
# Upstream definition for Node.js REST API
upstream backend_nodes {
    server 127.0.0.1:3000 max_fails=3 fail_timeout=10s;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name api.yourdomain.com yourdomain.com;

    # Allow Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.yourdomain.com yourdomain.com;

    # Temporary self-signed or Let's Encrypt SSL paths
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    # Hardened SSL Parameters
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Security Headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Upload size limit (Enforces maximum image payload of 10 MiB)
    client_max_body_size 10M;
    client_body_buffer_size 128k;

    # Timeouts
    proxy_connect_timeout 10s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Health check bypass
    location = /health {
        proxy_pass http://backend_nodes/health;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API Proxy Routing
    location /api/v1/ {
        proxy_pass http://backend_nodes/api/v1/;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Disable response buffering for fast streaming responses
        proxy_buffering off;
    }

    # Fallback / Error Page
    location / {
        return 404 '{"success": false, "error": {"code": "NOT_FOUND", "message": "Endpoint not found"}}';
        default_type application/json;
    }
}
```

Enable the site and verify configuration:

```bash
# Enable snakeoil certificates temporarily for config syntax testing
sudo apt-get install -y ssl-cert
sudo make-ssl-cert generate-default-snakeoil

# Link site and disable default
sudo ln -sf /etc/nginx/sites-available/maizedoctor /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx syntax
sudo nginx -t
sudo systemctl reload nginx
```

### 11.3 Certbot SSL/TLS Provisioning & Auto-Renewal

Point your domain's DNS `A` record (e.g. `api.yourdomain.com`) to your OCI Reserved Public IP. Once DNS propagation is complete:

```bash
# Install Certbot and the Nginx plugin
sudo apt-get install -y certbot python3-certbot-nginx

# Obtain and install SSL certificates
sudo certbot --nginx -d api.yourdomain.com -d yourdomain.com --non-interactive --agree-tos -m admin@yourdomain.com

# Test automated certificate renewal
sudo certbot renew --dry-run
```

---

## 12. Complete Production Environment Variables Reference

### Backend Orchestration API (`backend/.env`)

| Variable | Type | Required? | Purpose / Constraints | Production Example |
|---|---|---|---|---|
| `NODE_ENV` | String | **Yes** | Must be set to `production` | `production` |
| `HOST` | String | **Yes** | Internal bind interface | `127.0.0.1` |
| `PORT` | Integer | **Yes** | Internal HTTP port | `3000` |
| `DATABASE_URL` | String | **Yes** | PostgreSQL connection for app user | `postgresql://maizedoctor_app:<PASS>@127.0.0.1:5432/maizedoctor?schema=public` |
| `DIRECT_DATABASE_URL`| String | **Yes** | PostgreSQL connection for migration owner | `postgresql://maizedoctor_owner:<PASS>@127.0.0.1:5432/maizedoctor?schema=public` |
| `REDIS_URL` | String | **Yes** | Authenticated Redis connection URL | `redis://:<REDIS_PASS>@127.0.0.1:6379` |
| `REDIS_NAMESPACE` | String | **Yes** | Key prefix namespace | `maizedoctor` |
| `CORS_ORIGINS` | String | **Yes** | Comma-separated HTTPS client origins | `https://yourdomain.com,https://api.yourdomain.com` |
| `JWT_SECRET` | String | **Yes** | Base64URL string (min 32 bytes) for access tokens | `<32_BYTE_BASE64URL_STRING>` |
| `JWT_REFRESH_SECRET` | String | **Yes** | Base64URL string (must not match `JWT_SECRET`) | `<DIFFERENT_32_BYTE_BASE64URL_STRING>` |
| `JWT_ISSUER` | String | No | Token issuer header | `maizedoctor` |
| `JWT_ACCESS_TTL_SECONDS`| Integer | No | Access token expiration (max 900s) | `900` |
| `JWT_REFRESH_TTL_SECONDS`| Integer | No | Refresh token cookie expiration | `604800` |
| `CLOUDINARY_CLOUD_NAME` | String | **Yes** | Cloudinary cloud identifier | `<YOUR_CLOUD_NAME>` |
| `CLOUDINARY_API_KEY` | String | **Yes** | Cloudinary API Key | `<YOUR_API_KEY>` |
| `CLOUDINARY_API_SECRET` | String | **Yes** | Cloudinary API Secret | `<YOUR_API_SECRET>` |
| `AI_SERVICE_URL` | String | **Yes** | Internal origin of FastAPI microservice | `http://127.0.0.1:8000` |
| `AI_SERVICE_TOKEN` | String | **Yes** | Secret bearer token matching AI service | `<32_BYTE_BASE64URL_STRING>` |
| `AI_MODEL_VERSION` | String | **Yes** | Must match loaded PyTorch model version | `mobilenet-v3-small-v2-20261009` |
| `AI_PREPROCESSING_VERSION`| String| **Yes** | Must match shared preprocessing package | `1.0.0` |
| `OPERATIONS_TOKEN` | String | **Yes** | Independent token for metrics endpoint | `<INDEPENDENT_32_BYTE_BASE64URL>` |
| `TRUST_PROXY` | String | **Yes** | Explicit CIDR range of reverse proxy | `127.0.0.1/32` |

---

### Python AI Service (`ai-service/.env`)

| Variable | Type | Required? | Purpose / Constraints | Production Example |
|---|---|---|---|---|
| `ENVIRONMENT` | String | **Yes** | Set to `production` | `production` |
| `HOST` | String | **Yes** | Internal bind interface | `127.0.0.1` |
| `PORT` | Integer | **Yes** | Internal HTTP port | `8000` |
| `AI_SERVICE_TOKEN` | String | **Yes** | Bearer authentication token from Node.js | `<MATCHES_BACKEND_AI_SERVICE_TOKEN>` |
| `OPERATIONS_TOKEN` | String | **Yes** | Bearer token for `/internal/metrics` | `<MATCHES_BACKEND_OPERATIONS_TOKEN>` |
| `DATABASE_URL` | String | **Yes** | Read-only connection for `pgvector` search | `postgresql://maizedoctor_ai:<PASS>@127.0.0.1:5432/maizedoctor` |
| `INFERENCE_ENABLED` | Boolean | **Yes** | Enable PyTorch disease classification | `true` |
| `MODEL_PATH` | Path | **Yes** | Absolute path to PyTorch weights | `/opt/maizedoctor/artifacts/epoch-008.pt` |
| `MODEL_METADATA_PATH` | Path | **Yes** | Absolute path to model metadata JSON | `/opt/maizedoctor/artifacts/model-artifact.json` |
| `MODEL_METADATA_SHA256` | String | **Yes** | Expected SHA-256 hash of metadata | `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d` |
| `MODEL_VERSION` | String | **Yes** | Model version identifier | `mobilenet-v3-small-v2-20261009` |
| `PREPROCESSING_VERSION` | String | **Yes** | Pipeline version string | `1.0.0` |
| `INFERENCE_THREADS` | Integer | No | CPU thread count allocated to PyTorch | `2` |
| `INFERENCE_MAX_CONCURRENCY`| Integer| No | Max concurrent inference tasks | `1` |
| `RAG_ENABLED` | Boolean | **Yes** | Enable pgvector semantic search | `true` |
| `GEMINI_API_KEY` | String | **Yes** | Google Gemini API key | `<GEMINI_KEY>` |
| `EMBEDDING_MODEL` | String | **Yes** | Google text embedding model name | `text-embedding-004` |
| `EMBEDDING_VERSION` | String | **Yes** | Model version string | `2024-05-text-embedding-004` |
| `EMBEDDING_DIMENSIONS` | Integer | No | Vector dimension count | `768` |
| `GENERATION_ENABLED` | Boolean | **Yes** | Enable Gemini grounded generation | `true` |
| `GEMINI_MODEL` | String | **Yes** | Grounded chat model name | `gemini-2.5-flash` |
| `GENERATION_CORPUS_PATH`| Path | **Yes** | Path to curated knowledge JSON | `/opt/maizedoctor/app/backend/knowledge/maize-extension-20261012-v1.json` |
| `GENERATION_REVIEW_PATH`| Path | **Yes** | Path to knowledge review JSON | `/opt/maizedoctor/app/backend/knowledge/maize-extension-20261012-v1.review.json` |

---

## 13. Production Architecture Diagrams

### 13.1 OCI Deployment Architecture

```mermaid
flowchart TD
    subgraph OCI["Oracle Cloud Infrastructure (Region: Primary)"]
        subgraph VCN["Virtual Cloud Network (10.0.0.0/16)"]
            subgraph Subnet["Public Subnet (10.0.0.0/24)"]

                IGW["Internet Gateway"]
                SecList["Security List (Ingress: 22, 80, 443)"]

                subgraph VM["Compute Instance (Ubuntu LTS)"]
                    UFW["UFW Firewall (Port 80/443/22)"]
                    Nginx["Nginx Reverse Proxy & SSL"]

                    subgraph Daemons["Systemd Daemons (Internal Loopback Only)"]
                        Node["Node.js 24 API<br>(127.0.0.1:3000)"]
                        AI["FastAPI AI Service<br>(127.0.0.1:8000)"]
                        PG[("PostgreSQL 16 + pgvector<br>(127.0.0.1:5432)")]
                        Redis[("Redis 7/8 Cache<br>(127.0.0.1:6379)")]
                        Cleanup["Cleanup Worker"]
                    end
                end
            end
        end
    end

    Clients(("Mobile & Web Clients")) -->|"HTTPS :443"| IGW
    IGW --> SecList
    SecList --> UFW
    UFW --> Nginx
    Nginx --> Node
    Node --> Redis
    Node --> PG
    Node --> AI
    AI --> PG
    Cleanup --> PG
    Cleanup --> Redis
```

### 13.2 Startup & Service Dependency Flow

```mermaid
sequenceDiagram
    autonumber
    participant OS as Linux systemd
    participant PG as PostgreSQL 16
    participant RD as Redis
    participant AI as FastAPI AI Svc
    participant Node as Node.js API
    participant Nginx as Nginx Proxy

    OS->>PG: Start postgresql.service
    OS->>RD: Start redis-server.service
    OS->>AI: Start maizedoctor-ai.service
    Note over AI: 1. Validate SHA-256 of metadata<br/>2. Load PyTorch epoch-008.pt<br/>3. Initialize pgvector connection pool
    AI-->>OS: Health endpoint ready (127.0.0.1:8000)
    OS->>Node: Start maizedoctor-backend.service
    Note over Node: 1. Verify Prisma connection to PG<br/>2. Verify Redis connectivity<br/>3. Verify AI service token & model version
    Node-->>OS: Backend listening (127.0.0.1:3000)
    OS->>Nginx: Start nginx.service
    Note over Nginx: Reverse proxy traffic to 127.0.0.1:3000
```

---

## 14. Step-by-Step Copy-Paste Deployment Runbook

Follow these sequential commands on a newly provisioned Oracle Cloud Ubuntu instance:

### Step 1: Base System Initialization & Firewall
```bash
sudo apt-get update && sudo apt-get dist-upgrade -y
sudo apt-get install -y build-essential pkg-config curl wget git unzip iptables-persistent netfilter-persistent ufw

# Unblock OCI default iptables rules
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save

# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### Step 2: Install Node.js 24 & Python 3.11
```bash
# Node.js 24
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# Python 3.11
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
```

### Step 3: Install PostgreSQL 16, pgvector, and Redis
```bash
# PostgreSQL 16
sudo install -d /etc/apt/keyrings
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt-get update
sudo apt-get install -y postgresql-16 postgresql-contrib-16 postgresql-server-dev-16 redis-server

# Install pgvector
cd /tmp && git clone --branch v0.7.4 https://github.com/pgvector/pgvector.git && cd pgvector
make && sudo make install
```

### Step 4: Create User & Clone Repository
```bash
sudo adduser --system --group --shell /bin/bash --home /opt/maizedoctor maizedoctor
sudo usermod -aG maizedoctor ubuntu
sudo chmod 775 /opt/maizedoctor

# Clone repository
sudo -u maizedoctor git clone https://github.com/umerfarooq-sde/maize-disease-detection.git /opt/maizedoctor/app
```

### Step 5: Install Python Dependencies & Preprocessing
```bash
cd /opt/maizedoctor/app/ai-service
sudo -u maizedoctor python3.11 -m venv .venv
sudo -u maizedoctor .venv/bin/pip install --upgrade pip setuptools wheel
sudo -u maizedoctor .venv/bin/pip install torch==2.10.0 torchvision==0.25.0 --index-url https://download.pytorch.org/whl/cpu
sudo -u maizedoctor .venv/bin/pip install -e ../shared/preprocessing
sudo -u maizedoctor .venv/bin/pip install \
  "fastapi>=0.128.5,<1" "uvicorn>=0.47.0,<1" "pydantic>=2.13,<3" "pydantic-settings>=2.12,<3" \
  "httpx>=0.28.1,<1" "psycopg[binary]>=3.3,<4" "google-genai>=1,<3" "numpy>=2.4.2,<3" \
  "opencv-python-headless==4.13.0.92" "pillow>=12.1.0,<13"
```

### Step 6: Install Node Dependencies & Build Backend
```bash
cd /opt/maizedoctor/app/backend
sudo -u maizedoctor npm ci
sudo -u maizedoctor npm run build
```

---

## 15. Operations, Log Management & Health Monitoring

### Systemd Process Management Commands

```bash
# Check daemon statuses
sudo systemctl status maizedoctor-backend
sudo systemctl status maizedoctor-ai
sudo systemctl status maizedoctor-cleanup
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis-server

# Restart application services
sudo systemctl restart maizedoctor-ai
sudo systemctl restart maizedoctor-backend
```

### Viewing Live Journal Logs

```bash
# Stream Node.js backend logs
sudo journalctl -u maizedoctor-backend -f -o cat

# Stream FastAPI AI inference logs
sudo journalctl -u maizedoctor-ai -f -o cat

# Stream Nginx access and error logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Logrotate Configuration for Systemd Logs

Create `/etc/logrotate.d/maizedoctor`:

```text
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi \
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

---

## 16. Backup, Restore, Update, and Rollback Runbooks

### Automated Nightly Database Backup Script

Create `/opt/maizedoctor/scripts/backup-db.sh` (mode `700`):

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/opt/maizedoctor/backups/postgres"
DATE=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_DIR"

# Perform encrypted compressed SQL dump
sudo -u postgres pg_dump -Fc maizedoctor > "${BACKUP_DIR}/maizedoctor_${DATE}.dump"

# Delete backups older than 14 days
find "$BACKUP_DIR" -type f -name "maizedoctor_*.dump" -mtime +14 -delete
```

### Database Restore Procedure

```bash
# To restore a backup to the database:
sudo systemctl stop maizedoctor-backend maizedoctor-cleanup
sudo -u postgres pg_restore --clean --if-exists -d maizedoctor /opt/maizedoctor/backups/postgres/maizedoctor_TARGET.dump
sudo systemctl start maizedoctor-backend maizedoctor-cleanup
```

### Zero-Downtime Application Update Procedure

```bash
cd /opt/maizedoctor/app

# 1. Fetch latest changes
sudo -u maizedoctor git fetch origin main
sudo -u maizedoctor git checkout origin/main

# 2. Update backend dependencies & build
cd backend
sudo -u maizedoctor npm ci
sudo -u maizedoctor npx prisma migrate deploy
sudo -u maizedoctor npm run build

# 3. Update AI dependencies if needed
cd ../ai-service
sudo -u maizedoctor .venv/bin/pip install -e ../shared/preprocessing

# 4. Gracefully restart services
sudo systemctl restart maizedoctor-ai
sudo systemctl restart maizedoctor-backend
sudo systemctl restart maizedoctor-cleanup
```

### Rollback Procedure

```bash
# 1. Check out previous working commit hash
cd /opt/maizedoctor/app
sudo -u maizedoctor git checkout <PREVIOUS_COMMIT_SHA>

# 2. Rebuild backend
cd backend
sudo -u maizedoctor npm ci
sudo -u maizedoctor npm run build

# 3. Restart services
sudo systemctl restart maizedoctor-ai
sudo systemctl restart maizedoctor-backend
```

---

## 17. Production Verification Checklist & Troubleshooting Matrix

### Verification Checklist

- [ ] **Network & Ports:** Public ports 80/443 open in OCI Security List, OS `iptables`, and `ufw`.
- [ ] **Port Security:** Ports 3000, 8000, 5432, 6379 are bound exclusively to `127.0.0.1`.
- [ ] **SSL/TLS:** Valid Let's Encrypt certificate installed; HTTP redirects cleanly to HTTPS.
- [ ] **Health Probes:**
  - `curl -I https://api.yourdomain.com/health` returns `HTTP/1.1 200 OK`.
  - `curl http://127.0.0.1:8000/health` returns capability `inference: ready`, `rag: ready`.
- [ ] **Model Integrity:** Checksum of `epoch-008.pt` matches `e95a2e832626...`.
- [ ] **RAG Database:** `knowledge_chunks` contains 768-dimensional vector records.
- [ ] **Admin Authentication:** Able to log in with provisioned admin credentials at `/api/v1/auth/login`.
- [ ] **Live Prediction:** Submitting a test leaf image via `POST /api/v1/scans` returns classified label and probabilities without exceptions.
- [ ] **Daemons Surviving Reboot:** Executing `sudo reboot` brings all 5 daemons back to active status automatically.

### Troubleshooting Matrix

| Symptom | Likely Root Cause | Diagnostic Command | Resolution |
|---|---|---|---|
| **Site unreachable over port 80/443** | OCI default `iptables` rejecting traffic | `sudo iptables -L -n -v` | Run `iptables -I INPUT 6 ...` unblock command (Section 3.5). |
| **Backend fails on startup (`STARTUP_FAILED`)** | Node.js version mismatch or DB connection failure | `journalctl -u maizedoctor-backend -e` | Verify `node -v` is `>=24.22.0`. Verify PostgreSQL credentials in `.env`. |
| **FastAPI fails with `MODEL_STARTUP_FAILED`** | Weights file corrupted, missing, or SHA-256 mismatch | `journalctl -u maizedoctor-ai -e` | Run `sha256sum epoch-008.pt` and verify matching hash in `ai-service/.env`. |
| **Inference request returns HTTP 413** | Image exceeds 5 MiB or 16 MP limit | Check client response body | Pre-compress image on mobile client or ensure file is $<5$ MiB. |
| **RAG assistant returns `INSUFFICIENT_INFORMATION`** | Knowledge corpus has not been indexed into pgvector | `psql -d maizedoctor -c "SELECT count(*) FROM knowledge_chunks;"` | Run `python -m app.rag.cli ingest` (Section 10.1). |
| **Prisma migration fails with `extension vector does not exist`** | `pgvector` not installed in PostgreSQL 16 | `psql -d maizedoctor -c "\dx"` | Compile and install pgvector from source (Section 5.2). |
| **Image uploads fail with `IMAGE_UPLOAD_FAILED`** | Invalid or missing Cloudinary credentials | Check `backend/.env` Cloudinary keys | Ensure all three `CLOUDINARY_*` environment variables are populated. |

---

*End of MAIZEDOCTOR Oracle Cloud Infrastructure Production Deployment Manual.*
