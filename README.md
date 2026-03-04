# 🛡️ Trend Micro Agent Service - Automated Deployment

[![AWS](https://img.shields.io/badge/AWS-CloudFormation-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cloudformation/)
[![Python](https://img.shields.io/badge/Python-3.9-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

> Automated solution to install Trend Micro agents on ECS and EKS EC2 cluster instances using AWS Step Functions, Lambda, and EventBridge.

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## ✨ Features

### 🚀 **Two Operation Modes**

#### 1️⃣ **Initial Scan** - On deployment
- ✅ Scans **all** existing EC2 instances in the account
- ✅ Filters by customizable tags
- ✅ Automatically identifies **ECS** and **EKS** clusters
- ✅ Installs agent in **parallel** (max 20 concurrent)
- ✅ Automatic execution when deploying CloudFormation

#### 2️⃣ **Triggered Mode** - New instances
- ✅ Detects new EC2 instances via **EventBridge**
- ✅ Validates tags before proceeding
- ✅ Waits for **SSM** registration (up to 90s)
- ✅ Installs agent automatically

### 🎯 **Key Capabilities**

| Feature | Description |
|---------|-------------|
| **Intelligent Detection** | Automatically identifies ECS (`aws:ecs:clusterName`) and EKS (`kubernetes.io/cluster/*`) instances |
| **Tag Filtering** | Support for multiple tags: `key1:value1;key2:value2` or `NONE` for no filter |
| **Concurrency Control** | Maximum 20 instances processed in parallel |
| **Automatic Retries** | Configurable retries with exponential backoff |
| **Detailed Logs** | CloudWatch Logs with complete information for each step |
| **Multi-Platform** | Support for Linux (`.sh`) and Windows (`.ps1`) |
| **Fault Tolerance** | Continues processing even if some instances fail |

---

## 🏗️ Architecture

### Simple Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CloudFormation Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  INITIAL SCAN       │         │  TRIGGERED MODE     │       │
│  │  (On Deploy)        │         │  (EventBridge)      │       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           ▼                                  ▼                   │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  Step Function      │         │  Step Function      │       │
│  │  (Map State 5x)     │         │  (Wait + Verify)    │       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                                  │                   │
│           └──────────────┬───────────────────┘                  │
│                          ▼                                       │
│                 ┌─────────────────┐                             │
│                 │  Install Agent  │                             │
│                 │     Lambda      │                             │
│                 └─────────────────┘                             │
│                          │                                       │
│                          ▼                                       │
│                 ┌─────────────────┐                             │
│                 │  EC2 Instances  │                             │
│                 │                 │                             │
│                 └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

📖 **See complete documentation**: [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## 📦 Prerequisites

### AWS

- ✅ AWS Account with CloudFormation permissions
- ✅ Required **IAM Permissions**:
  - `cloudformation:*`
  - `lambda:*`
  - `states:*`
  - `events:*`
  - `iam:*` (to create roles)
  - `ec2:DescribeInstances`
  - `ssm:*`
  - `s3:GetObject`

### Required Resources

1. **S3 Bucket** with installation scripts:
   ```
   my-trend-micro-scripts/
   ├── install-agent.sh      # For Linux
   └── install-agent.ps1     # For Windows
   ```

2. **SSM Agent** installed on EC2 instances
   - Policy `AmazonSSMManagedInstanceCore` attached t EC2 instance

---

## 🚀 Installation

### Step 1: Clone repository

```bash
git clone https://github.com/your-user/trendmicro-agent-service.git
cd trendmicro-agent-service
```

### Step 2: Prepare installation scripts

Upload your scripts to S3 bucket:

```bash
aws s3 cp install-agent.sh s3://my-trend-micro-scripts/
aws s3 cp install-agent.ps1 s3://my-trend-micro-scripts/
```

### Step 3: Deploy CloudFormation

#### Option A: AWS Console

1. Go to **CloudFormation** → **Create Stack**
2. Upload file `cloudformation-template.yaml`
3. Configure parameters:
   - **S3Bucket**: `my-trend-micro-scripts`
   - **Tag**: `Project:IT-MODERNIZATION` or `NONE`
4. Click **Create Stack**

#### Option B: AWS CLI (ECS/EKS Only)

```bash
aws cloudformation create-stack \
  --stack-name trendmicro-agent-service \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=my-trend-micro-scripts \
    ParameterKey=Tag,ParameterValue="Project:IT-MODERNIZATION" \
    ParameterKey=InstanceScope,ParameterValue=ECS_EKS_ONLY \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Option C: All Instances

```bash
aws cloudformation create-stack \
  --stack-name trendmicro-agent-service \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=my-trend-micro-scripts \
    ParameterKey=Tag,ParameterValue=NONE \
    ParameterKey=InstanceScope,ParameterValue=ALL_INSTANCES \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Option D: All Instances with Tag Filter

```bash
aws cloudformation create-stack \
  --stack-name trendmicro-agent-service \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=my-trend-micro-scripts \
    ParameterKey=Tag,ParameterValue="Environment:Production;Team:DevOps" \
    ParameterKey=InstanceScope,ParameterValue=ALL_INSTANCES \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## ⚙️ Configuration

### CloudFormation Parameters

| Parameter | Description | Example | Required |
|-----------|-------------|---------|----------|
| `S3Bucket` | S3 bucket name with scripts | `my-trend-micro-scripts` | ✅ |
| `Tag` | Tag filter for instances | `Project:IT-MODERNIZATION` or `NONE` | ✅ |
| `InstanceScope` | Scope of instances to process | `ECS_EKS_ONLY` or `ALL_INSTANCES` | ✅ |

### Instance Scope Options

#### ECS_EKS_ONLY (Default)
```yaml
InstanceScope: "ECS_EKS_ONLY"
```
- Only processes instances that belong to ECS or EKS clusters
- Identifies instances by tags: `aws:ecs:clusterName` or `kubernetes.io/cluster/*`

#### ALL_INSTANCES
```yaml
InstanceScope: "ALL_INSTANCES"
```
- Processes **all** EC2 instances (regardless of ECS/EKS membership)
- Still respects tag filtering if configured

### Tag Format

#### No filter (process all ECS/EKS instances)
```yaml
Tag: "NONE"
```

#### Single tag
```yaml
Tag: "Environment:Production"
```

#### Multiple tags (logical AND)
```yaml
Tag: "Environment:Production;Team:DevOps;Project:Security"
```

### SSM Parameters (Auto-created)

The stack automatically creates these parameters:

- `/trend_micro/aws/automate/s3` → S3 bucket name
- `/trend_micro/aws/automate/ec2/tag` → Tag filter
- `/trend_micro/aws/automate/instance/scope` → Instance scope (ECS_EKS_ONLY or ALL_INSTANCES)

---

## 🎮 Usage

### Initial Scan (Automatic)

When deploying the stack, the **initial scan** runs automatically:

1. ✅ Scans all running EC2 instances
2. ✅ Filters by configured tags
3. ✅ Identifies ECS/EKS clusters
4. ✅ Installs agent in parallel (max 5)

**Track progress:**

```bash
# View Step Function execution
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:REGION:ACCOUNT:stateMachine:TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-WORKFLOW

# View scan logs
aws logs tail /aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-INSTANCES --follow
```

### Triggered Mode (Automatic)

When a **new EC2 instance** is created:

1. ✅ EventBridge detects state change to `running`
2. ✅ Step Function validates tags
3. ✅ Waits for SSM registration (up to 90s)
4. ✅ Installs agent automatically

**No manual intervention required** 🎉

### Run Manual Scan

If you want to re-scan instances:

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:REGION:ACCOUNT:stateMachine:TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-WORKFLOW \
  --input '{}'
```

---

## 📊 Monitoring

### CloudWatch Logs

Each Lambda generates detailed logs:

| Log Group | Content |
|-----------|---------|
| `/aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-INSTANCES` | Scan results, instances found |
| `/aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-CHECK-SSM` | SSM verification (no waiting) |
| `/aws/lambda/TRENDMICRO-AGENT-SERVICE-TRIGGERED-WAIT-SSM` | SSM registration wait (with retries) |
| `/aws/lambda/TRENDMICRO-AGENT-SERVICE-INSTALL-AGENT` | Installation process, Command ID |



## 🔧 Troubleshooting


### ❌ Problem: "Instance not registered in SSM"

**Symptoms:**
- Error in logs: `[ERROR] Instance i-xxxxx NOT registered in SSM`

**Solution:**
1. Verify SSM Agent installed:
   ```bash
   # On EC2 instance
   sudo systemctl status amazon-ssm-agent
   ```

2. Reinstall SSM Agent if necessary:
   ```bash
   # Amazon Linux 2
   sudo yum install -y amazon-ssm-agent
   sudo systemctl enable amazon-ssm-agent
   sudo systemctl start amazon-ssm-agent
   ```

3. Verify instance IAM role has `AmazonSSMManagedInstanceCore`


---

## 📝 Changelog

### v1.0.0 (2026-02-05)
- ✨ Initial release
- ✅ Initial Scan with Map State
- ✅ Triggered Mode with EventBridge
- ✅ Support for ECS and EKS
- ✅ Multiple tag filtering
- ✅ Detailed logs in CloudWatch

---

## 👥 Authors

- **Your Name** - *Initial Work* - [@alejogaci](https://github.com/alejogaci)

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- AWS for Step Functions and EventBridge
- Trend Micro for security agent
- CloudFormation community

---



<div align="center">

**⭐ If this project helped you, consider giving it a star ⭐**

Made with ❤️ using AWS

</div>
