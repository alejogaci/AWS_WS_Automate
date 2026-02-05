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
- ✅ Installs agent in **parallel** (max 5 concurrent)
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
| **Concurrency Control** | Maximum 5 instances processed in parallel |
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
│                 │   (ECS / EKS)   │                             │
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

3. **Tags on instances** (optional):
   - ECS: `aws:ecs:clusterName`
   - EKS: `kubernetes.io/cluster/<name>` or `eks:cluster-name`

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

#### Option B: AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name trendmicro-agent-service \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=my-trend-micro-scripts \
    ParameterKey=Tag,ParameterValue="Project:IT-MODERNIZATION" \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Option C: With multiple tags

```bash
aws cloudformation create-stack \
  --stack-name trendmicro-agent-service \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=my-trend-micro-scripts \
    ParameterKey=Tag,ParameterValue="Environment:Production;Team:DevOps;Project:Security" \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## ⚙️ Configuration

### CloudFormation Parameters

| Parameter | Description | Example | Required |
|-----------|-------------|---------|----------|
| `S3Bucket` | S3 bucket name with scripts | `my-trend-micro-scripts` | ✅ |
| `Tag` | Tag filter for instances | `Project:IT-MODERNIZATION` or `NONE` | ✅ |

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

### Log Examples

#### Successful Scan
```
[START] Starting EC2 instance scan
✓ ECS - Instance: i-0abc123, Cluster: prod-ecs
✓ EKS - Instance: i-0def456, Cluster: k8s-prod
[SUMMARY] Total: 15, ECS: 8, EKS: 7
```

#### Successful Installation
```
[START] Processing installation for instance: i-0abc123
[S3] Bucket: my-trend-micro-scripts
[EC2] Platform: linux
[S3] Script: install-agent.sh
[SSM] Command sent
[SSM] Command ID: a1b2c3d4-e5f6-7890
[COMPLETED] Installation initiated
```

### Step Functions Console

Visualize flow in real-time:

1. AWS Console → **Step Functions**
2. Select:
   - `TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-WORKFLOW`
   - `TRENDMICRO-AGENT-SERVICE-TRIGGERED-INSTANCE-WORKFLOW`
3. View executions and states

---

## 🔧 Troubleshooting

### ❌ Problem: Instance not processed in Initial Scan

**Symptoms:**
- Instance doesn't appear in scan logs

**Solution:**
1. Verify instance tags:
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx --query 'Reservations[0].Instances[0].Tags'
   ```

2. Verify tag filter in SSM:
   ```bash
   aws ssm get-parameter --name /trend_micro/aws/automate/ec2/tag
   ```

3. Ensure it has ECS or EKS tag:
   - ECS: `aws:ecs:clusterName`
   - EKS: `kubernetes.io/cluster/<name>`

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

### ❌ Problem: Script not downloading from S3

**Symptoms:**
- Error: `Script .sh not found` or `No files in S3`

**Solution:**
1. Verify bucket and scripts:
   ```bash
   aws s3 ls s3://my-trend-micro-scripts/
   ```

2. Verify bucket permissions (must allow `s3:GetObject` to Lambda Role)

3. Ensure correct format:
   - Linux: `install-agent.sh`
   - Windows: `install-agent.ps1`

### ❌ Problem: EventBridge not triggering for new instances

**Solution:**
1. Verify rule is enabled:
   ```bash
   aws events describe-rule --name TRENDMICRO-AGENT-SERVICE-TRIGGERED-EC2-RUNNING-RULE
   ```

2. Check CloudWatch metrics for the rule:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Events \
     --metric-name TriggeredRules \
     --dimensions Name=RuleName,Value=TRENDMICRO-AGENT-SERVICE-TRIGGERED-EC2-RUNNING-RULE \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 3600 \
     --statistics Sum
   ```

---

## 🧪 Testing

### Test Manual - Initial Scan

```bash
# 1. Deploy stack
aws cloudformation create-stack \
  --stack-name test-trendmicro \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=S3Bucket,ParameterValue=test-bucket \
    ParameterKey=Tag,ParameterValue=NONE \
  --capabilities CAPABILITY_NAMED_IAM

# 2. Wait for completion
aws cloudformation wait stack-create-complete --stack-name test-trendmicro

# 3. Verify logs
aws logs tail /aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-INSTANCES --follow
```

### Test Manual - Triggered Mode

```bash
# Create test EC2 instance with tags
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --instance-type t3.micro \
  --iam-instance-profile Name=SSM-Role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Environment,Value=Test},{Key=aws:ecs:clusterName,Value=test-cluster}]'

# Monitor Step Function
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:REGION:ACCOUNT:stateMachine:TRENDMICRO-AGENT-SERVICE-TRIGGERED-INSTANCE-WORKFLOW \
  --max-results 1
```

---

## 🤝 Contributing

Contributions are welcome! 🎉

### Process

1. Fork the repository
2. Create a branch: `git checkout -b feature/my-improvement`
3. Commit changes: `git commit -m 'Add: new feature'`
4. Push: `git push origin feature/my-improvement`
5. Open a Pull Request

### Guidelines

- ✅ Follow naming convention: `TRENDMICRO-AGENT-SERVICE-*`
- ✅ Add detailed logs in new lambdas
- ✅ Document changes in `ARCHITECTURE.md`
- ✅ Include manual tests
- ✅ Update this README if necessary

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

- **Alejandro Garcia** - *Initial Work* - [@your-user](https://github.com/alejogaci)

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

