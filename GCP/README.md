# 🛡️ Trend Micro Agent Service - GCP (Google Cloud Platform)

[![GCP](https://img.shields.io/badge/GCP-Cloud_Functions-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/functions)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)

> Automated solution to install Trend Micro agents on **all GCE instances** using Cloud Functions, Cloud Scheduler, and Eventarc.

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Features

### 🚀 **Two Operation Modes**

#### 1️⃣ **Scheduled Scan** - Daily at 2 AM UTC
- ✅ Scans **all** GCE instances in the project
- ✅ Filters by customizable labels
- ✅ Processes instances in parallel
- ✅ Automatic execution via Cloud Scheduler

#### 2️⃣ **Event-Driven** - New instances
- ✅ Detects new GCE instances via **Eventarc**
- ✅ Validates labels before proceeding
- ✅ Installs agent automatically on creation

### 🎯 **Key Capabilities**

| Feature | Description |
|---------|-------------|
| **Label Filtering** | Support for multiple labels: `key1:value1;key2:value2` or `NONE` |
| **Multi-Platform** | Support for Linux and Windows |
| **Serverless** | Fully serverless using Cloud Functions Gen2 |
| **Scalable** | Automatic scaling with Cloud Functions |
| **Audit Logs** | Complete tracking in Cloud Logging |

---

## 🏗️ Architecture

### Simple Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Project                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  SCHEDULED SCAN     │         │  EVENT-DRIVEN       │       │
│  │  (Cloud Scheduler)  │         │  (Eventarc)         │       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           ▼                                  ▼                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  Scan Function      │         │  Install Function   │       │
│  │  (Cloud Function)   │         │  (Cloud Function)   │       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           └──────────────┬───────────────────┘                  │
│                          ▼                                       │
│                 ┌─────────────────┐                             │
│                 │  GCE Instances  │                             │
│                 │  (All VMs)      │                             │
│                 └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### GCP

- ✅ GCP Project with billing enabled
- ✅ Required **APIs enabled**:
  - Cloud Functions API
  - Cloud Scheduler API
  - Eventarc API
  - Compute Engine API
  - Cloud Storage API
  - Pub/Sub API

### Required Resources

1. **Cloud Storage Bucket** with installation scripts:
   ```
   my-trend-micro-scripts/
   ├── install-agent.sh      # For Linux
   └── install-agent.ps1     # For Windows
   ```

2. **Service Account** with permissions (auto-created by Terraform)

---

## 🚀 Installation

### Step 1: Clone repository

```bash
git clone https://github.com/your-user/trendmicro-agent-service.git
cd trendmicro-agent-service/gcp-terraform
```

### Step 2: Prepare installation scripts

Upload your scripts to GCS bucket:

```bash
gsutil cp install-agent.sh gs://my-trend-micro-scripts/
gsutil cp install-agent.ps1 gs://my-trend-micro-scripts/
```

### Step 3: Prepare function code

```bash
cd functions/scan-instances
zip -r ../scan-instances.zip .
cd ../install-agent
zip -r ../install-agent.zip .
cd ../..
```

### Step 4: Configure Terraform

Create `terraform.tfvars` in the same directory as `gcp-main.tf`:

```hcl
project_id     = "my-gcp-project"
region         = "us-central1"
storage_bucket = "my-trend-micro-scripts"
tag_filter     = "NONE"
```

### Step 5: Deploy with Terraform

```bash
terraform init
terraform plan
terraform apply
```

**Note**: Terraform will automatically use `gcp-main.tf` if it's the only `.tf` file in the directory, or you can rename it to `main.tf`.

---

## ⚙️ Configuration

### Terraform Variables

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | `my-project-123` | ✅ |
| `region` | GCP Region | `us-central1` | ✅ |
| `storage_bucket` | GCS bucket with scripts | `my-trend-micro-scripts` | ✅ |
| `tag_filter` | Label filter for instances | `environment:production` or `NONE` | ✅ |

### Label Format

#### No filter (process all instances)
```hcl
tag_filter = "NONE"
```

#### Single label
```hcl
tag_filter = "environment:production"
```

#### Multiple labels (logical AND)
```hcl
tag_filter = "environment:production;team:devops;project:security"
```

---

## 🎮 Usage

### Scheduled Scan (Automatic)

The scan runs **daily at 2 AM UTC** via Cloud Scheduler:

1. ✅ Scans all running GCE instances
2. ✅ Filters by configured labels
3. ✅ Triggers installation for matching instances

**Trigger manually:**

```bash
gcloud scheduler jobs run trendmicro-agent-service-scan-trigger \
  --location=us-central1
```

### Event-Driven Mode (Automatic)

When a **new GCE instance** is created:

1. ✅ Eventarc detects the instance creation
2. ✅ Install function is triggered
3. ✅ Agent is installed automatically

**No manual intervention required** 🎉

---

## 📊 Monitoring

### Cloud Logging

View logs in Cloud Logging:

```bash
# Scan function logs
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=trendmicro-agent-service-scan-instances" --limit 50

# Install function logs
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=trendmicro-agent-service-install-agent" --limit 50
```

### Log Examples

#### Successful Scan
```
[START] Scanning GCE instances in project: my-project
[INFO] Required labels: {"environment": "production"}
✓ Instance: web-server-1 (zone: us-central1-a)
✓ Instance: db-server-1 (zone: us-central1-b)
[SUMMARY] Total scanned: 25
[SUMMARY] Instances to process: 2
```

#### Successful Installation
```
[START] Installing agent on instance: web-server-1
[PLATFORM] Detected: Linux
[SCRIPT] Downloaded: install-agent.sh
[SUCCESS] Metadata set for instance web-server-1
[COMPLETED] Agent installation script deployed
```

---

## 🔧 Troubleshooting

### ❌ Problem: Function not triggering

**Solution:**
1. Verify Cloud Scheduler job:
   ```bash
   gcloud scheduler jobs describe trendmicro-agent-service-scan-trigger --location=us-central1
   ```

2. Check function permissions:
   ```bash
   gcloud functions describe trendmicro-agent-service-scan-instances --region=us-central1
   ```

### ❌ Problem: Script not found in GCS

**Solution:**
1. Verify bucket contents:
   ```bash
   gsutil ls gs://my-trend-micro-scripts/
   ```

2. Check function service account has Storage Object Viewer role

### ❌ Problem: Eventarc not triggering

**Solution:**
1. Verify Eventarc trigger:
   ```bash
   gcloud eventarc triggers describe trendmicro-agent-service-instance-created --location=us-central1
   ```

2. Ensure Audit Logs are enabled for Compute Engine

---

## 🧪 Testing

### Test Scan Function

```bash
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/trendmicro-agent-service-scan-instances \
  -H "Authorization: bearer $(gcloud auth print-identity-token)"
```

### Test with New Instance

```bash
gcloud compute instances create test-vm \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --labels=environment=test
```

---

## 🗑️ Cleanup

To remove all resources:

```bash
terraform destroy
```

---

## 📞 Support

Need help?

- 📧 Email: support@yourcompany.com
- 📚 GCP Docs: [Cloud Functions](https://cloud.google.com/functions/docs)

---

<div align="center">

**⭐ If this project helped you, consider giving it a star ⭐**

Made with ❤️ using GCP

</div>
