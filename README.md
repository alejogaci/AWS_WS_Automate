# 🛡️ Trend Micro Workload Security - Multi-Cloud Automated Deployment

[![AWS](https://img.shields.io/badge/AWS-CloudFormation-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![GCP](https://img.shields.io/badge/GCP-Terraform-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![Azure](https://img.shields.io/badge/Azure-Terraform-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

> **Automated solution to deploy Trend Micro Workload Security agents across AWS, GCP, and Azure cloud instances using Infrastructure as Code (IaC).**

---


## 🎯 Overview

This project provides **fully automated Infrastructure as Code (IaC)** solutions to deploy **Trend Micro Workload Security** agents on cloud instances across multiple cloud providers. It eliminates manual agent installation and ensures consistent security posture across your multi-cloud infrastructure.


### **What This Project Does**

- ✅ **Automatically scans** all cloud instances in your environment
- ✅ **Deploys agents** on new instances as they are created
- ✅ **Filters by tags/labels** to target specific instances
- ✅ **Supports multiple OS** (Windows and Linux)
- ✅ **Serverless architecture** with minimal operational overhead
- ✅ **Multi-cloud ready** - Works on AWS, GCP, and Azure

---

## ✨ Features

### 🚀 **Two Operation Modes**

#### 1️⃣ **Initial Deployment Scan**
Automatically scans and installs agents on existing instances when you deploy the solution.

#### 2️⃣ **Event-Driven Installation**
Automatically detects and installs agents on new instances as they are created.

### 🎯 **Key Capabilities**

| Feature | AWS | GCP | Azure |
|---------|:---:|:---:|:-----:|
| **Initial Scan** | ✅ | ✅ | ✅ |
| **Event-Driven** | ✅ | ✅ | ✅ |
| **Tag/Label Filtering** | ✅ | ✅ | ✅ |
| **Windows Support** | ✅ | ✅ | ✅ |
| **Linux Support** | ✅ | ✅ | ✅ |
| **Parallel Processing** | ✅ (5 max) | ✅ (10 max) | ✅ (Auto) |
| **Serverless** | ✅ | ✅ | ✅ |

---

## 🏗️ Architecture

### **High-Level Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Multi-Cloud Infrastructure                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │     AWS     │    │     GCP     │    │    Azure    │        │
│   │  (EC2)      │    │   (GCE)     │    │    (VMs)    │        │
│   └─────────────┘    └─────────────┘    └─────────────┘        │
│          │                  │                    │               │
│          ▼                  ▼                    ▼               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │Step Function│    │Cloud Function│   │Azure Function│       │
│   │+ EventBridge│    │+ Eventarc   │    │+ Event Grid  │       │
│   └─────────────┘    └─────────────┘    └─────────────┘        │
│          │                  │                    │               │
│          └──────────────────┴────────────────────┘              │
│                             │                                    │
│                             ▼                                    │
│                  ┌─────────────────────┐                        │
│                  │  Trend Micro Agent  │                        │
│                  │   Installed on VM   │                        │
│                  └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---


### **Deployment Method**

| Feature | AWS | GCP | Azure |
|---------|-----|-----|-------|
| **IaC Tool** | CloudFormation | Terraform | Terraform |
| **Language** | YAML | HCL | HCL |
| **One-Click Deploy** | ✅ Console | ❌ CLI only | ❌ CLI only |



---

## 🎯 Configuration

### **Tag/Label Filtering**

#### No Filter
```
AWS:    Tag: "NONE"
GCP:    tag_filter: "NONE"
Azure:  tag_filter: "NONE"
```

#### Single Tag
```
AWS:    Tag: "Environment:Production"
GCP:    tag_filter: "environment:production"
Azure:  tag_filter: "environment:production"
```

#### Multiple Tags
```
AWS:    Tag: "Environment:Production;Team:DevOps"
GCP:    tag_filter: "environment:production;team:devops"
Azure:  tag_filter: "environment:production;team:devops"
```




## 📄 License

This project is licensed under the MIT License.

---


<div align="center">

**⭐ If this project helped you, consider giving it a star ⭐**

Made with ❤️ for Multi-Cloud Security

</div>
