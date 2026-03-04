# 🛡️ Trend Micro Agent Service - Azure

[![Azure](https://img.shields.io/badge/Azure-Functions-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/en-us/services/functions/)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)

> Automated solution to install Trend Micro agents on **all Azure VMs** using Azure Functions and Event Grid.

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

#### 1️⃣ **HTTP Trigger** - On-demand scan
- ✅ Scans **all** VMs in the subscription
- ✅ Filters by customizable tags
- ✅ Processes VMs in parallel
- ✅ Can be triggered via HTTP or Timer

#### 2️⃣ **Event-Driven** - New VMs
- ✅ Detects new VMs via **Event Grid**
- ✅ Validates tags before proceeding
- ✅ Installs agent automatically on creation

### 🎯 **Key Capabilities**

| Feature | Description |
|---------|-------------|
| **Tag Filtering** | Support for multiple tags: `key1:value1;key2:value2` or `NONE` |
| **Multi-Platform** | Support for Windows and Linux |
| **Serverless** | Fully serverless using Azure Functions |
| **Scalable** | Automatic scaling with Consumption Plan |
| **Activity Logs** | Complete tracking in Azure Monitor |

---

## 🏗️ Architecture

### Simple Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Subscription                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  HTTP TRIGGER       │         │  EVENT-DRIVEN       │       │
│  │  (Function App)     │         │  (Event Grid)       │       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           ▼                                  ▼                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  Scan Function      │         │  Install Function   │       │
│  │  (HTTP Trigger)     │         │  (EventGrid Trigger)│       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           └──────────────┬───────────────────┘                  │
│                          ▼                                       │
│                 ┌─────────────────┐                             │
│                 │  Azure VMs      │                             │
│                 │  (All VMs)      │                             │
│                 └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### Azure

- ✅ Azure Subscription with Owner or Contributor role
- ✅ Azure CLI installed
- ✅ Terraform installed

### Required Resources

1. **Storage Account** with installation scripts:
   ```
   my-trend-micro-scripts/
   └── scripts/
       ├── install-agent.sh      # For Linux
       └── install-agent.ps1     # For Windows
   ```

2. **Resource Group** for deployment

---

## 🚀 Installation

### Step 1: Clone repository

```bash
git clone https://github.com/your-user/trendmicro-agent-service.git
cd trendmicro-agent-service/azure-terraform
```

### Step 2: Prepare installation scripts

Upload your scripts to Azure Storage:

```bash
az storage blob upload \
  --account-name mystorageaccount \
  --container-name scripts \
  --name install-agent.sh \
  --file install-agent.sh

az storage blob upload \
  --account-name mystorageaccount \
  --container-name scripts \
  --name install-agent.ps1 \
  --file install-agent.ps1
```

### Step 3: Configure Terraform

Create `terraform.tfvars` in the same directory as `azure-main.tf`:

```hcl
resource_group_name    = "rg-trendmicro-prod"
location               = "East US"
storage_account_name   = "mystorageaccount"
storage_container_name = "scripts"
tag_filter             = "NONE"
```

### Step 4: Deploy with Terraform

```bash
terraform init
terraform plan
terraform apply
```

**Note**: Terraform will automatically use `azure-main.tf` if it's the only `.tf` file in the directory, or you can rename it to `main.tf`.

---

## ⚙️ Configuration

### Terraform Variables

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Resource Group name | `rg-trendmicro-prod` | ✅ |
| `location` | Azure Region | `East US` | ✅ |
| `storage_account_name` | Storage account with scripts | `mystorageaccount` | ✅ |
| `storage_container_name` | Container name | `scripts` | ✅ |
| `tag_filter` | Tag filter for VMs | `environment:production` or `NONE` | ✅ |

### Tag Format

#### No filter (process all VMs)
```hcl
tag_filter = "NONE"
```

#### Single tag
```hcl
tag_filter = "environment:production"
```

#### Multiple tags (logical AND)
```hcl
tag_filter = "environment:production;team:devops;project:security"
```

---

## 🎮 Usage

### HTTP Trigger Scan (Manual)

Trigger the scan function via HTTP:

```bash
# Get function URL
FUNCTION_URL=$(az functionapp function show \
  --resource-group rg-trendmicro-prod \
  --name trendmicro-agent-service-scan \
  --function-name ScanInstances \
  --query invokeUrlTemplate -o tsv)

# Trigger scan
curl -X POST "$FUNCTION_URL"
```

### Event-Driven Mode (Automatic)

When a **new Azure VM** is created:

1. ✅ Event Grid detects the VM creation
2. ✅ Install function is triggered
3. ✅ Agent is installed automatically via VM Extension

**No manual intervention required** 🎉

---

## 📊 Monitoring

### Azure Monitor Logs

View logs in Azure Portal:

1. Go to **Function App** → **Logs**
2. Run queries:

```kusto
// Scan function logs
traces
| where cloud_RoleName == "trendmicro-agent-service-scan"
| where message contains "SUMMARY"
| project timestamp, message

// Install function logs
traces
| where cloud_RoleName == "trendmicro-agent-service-install"
| where message contains "COMPLETED"
| project timestamp, message
```

### Log Examples

#### Successful Scan
```
[START] Scanning Azure VMs
[INFO] Required tags: {"environment": "production"}
✓ VM: web-server-1 (RG: rg-web-prod)
✓ VM: db-server-1 (RG: rg-db-prod)
[SUMMARY] Total scanned: 30
[SUMMARY] VMs to process: 2
```

#### Successful Installation
```
[START] Processing EventGrid event
[VM] Location: eastus
[PLATFORM] OS Type: Linux
[SCRIPT] URL: https://...
[SUCCESS] Extension deployment started for VM web-server-1
[COMPLETED] Agent installation initiated
```

---

## 🔧 Troubleshooting

### ❌ Problem: Function not triggering

**Solution:**
1. Verify function app status:
   ```bash
   az functionapp show \
     --resource-group rg-trendmicro-prod \
     --name trendmicro-agent-service-scan
   ```

2. Check managed identity permissions:
   ```bash
   az role assignment list \
     --assignee <function-principal-id> \
     --all
   ```

### ❌ Problem: Script not found in Storage

**Solution:**
1. Verify blob exists:
   ```bash
   az storage blob list \
     --account-name mystorageaccount \
     --container-name scripts \
     --output table
   ```

2. Check Storage Blob Data Reader role is assigned

### ❌ Problem: Event Grid not triggering

**Solution:**
1. Verify Event Grid subscription:
   ```bash
   az eventgrid event-subscription show \
     --name trendmicro-agent-service-vm-created \
     --source-resource-id /subscriptions/.../resourceGroups/...
   ```

2. Check Activity Log for VM creation events

---

## 🧪 Testing

### Test Scan Function

```bash
az functionapp function invoke \
  --resource-group rg-trendmicro-prod \
  --name trendmicro-agent-service-scan \
  --function-name ScanInstances
```

### Test with New VM

```bash
az vm create \
  --resource-group rg-test \
  --name test-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --tags environment=test team=devops
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
- 📚 Azure Docs: [Azure Functions](https://docs.microsoft.com/en-us/azure/azure-functions/)

---

<div align="center">

**⭐ If this project helped you, consider giving it a star ⭐**

Made with ❤️ using Azure

</div>
