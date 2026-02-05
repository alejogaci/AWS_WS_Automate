# 🏗️ Architecture - Trend Micro Agent Service

## 📐 Simple Architecture Overview

```mermaid
graph TB
    subgraph Deploy["☁️ DEPLOYMENT (One Time)"]
        CFN[📦 CloudFormation<br/>Stack Deploy]
        CFN --> SCAN[🔍 Automatic Scan<br/>All EC2 Instances]
        SCAN --> INSTALL1[⚙️ Install Agent<br/>on existing instances]
    end

    subgraph Runtime["⚡ RUNTIME (Continuous)"]
        NEW[🆕 New EC2 Created]
        NEW --> DETECT[👀 EventBridge<br/>Detects]
        DETECT --> WAIT[⏱️ Wait for<br/>SSM Ready]
        WAIT --> INSTALL2[⚙️ Install Agent<br/>automatically]
    end

    style Deploy fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px
    style Runtime fill:#bbdefb,stroke:#1565c0,stroke-width:3px
    style INSTALL1 fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style INSTALL2 fill:#fff9c4,stroke:#f57f17,stroke-width:2px
```

## 🎯 How It Works

### **Scenario 1: First Time Deployment** 🚀

```mermaid
graph LR
    A[1️⃣ Deploy<br/>CloudFormation] --> B[2️⃣ Scan<br/>EC2 Instances]
    B --> C[3️⃣ Find<br/>ECS/EKS]
    C --> D[4️⃣ Install Agent<br/>5 at a time]
    D --> E[✅ Done!]

    style A fill:#e3f2fd
    style B fill:#e1f5fe
    style C fill:#b3e5fc
    style D fill:#81d4fa
    style E fill:#4fc3f7
```

### **Scenario 2: New Instance Created** ⚡

```mermaid
graph LR
    A[1️⃣ New EC2<br/>Starts] --> B[2️⃣ EventBridge<br/>Detects]
    B --> C[3️⃣ Wait<br/>70 seconds]
    C --> D[4️⃣ Check<br/>SSM Ready]
    D --> E[5️⃣ Install<br/>Agent]
    E --> F[✅ Done!]

    style A fill:#fff3e0
    style B fill:#ffe0b2
    style C fill:#ffcc80
    style D fill:#ffb74d
    style E fill:#ffa726
    style F fill:#ff9800
```

## 🔄 Detailed Flow - Initial Scan

```mermaid
sequenceDiagram
    participant User
    participant CF as ☁️ CloudFormation
    participant Scan as 🔍 Scan Lambda
    participant EC2 as 💻 EC2 API
    participant SF as ⚙️ Step Function
    participant Install as 📦 Install Lambda
    participant SSM as 🔧 SSM

    User->>CF: Deploy Stack
    CF->>Scan: Trigger Scan
    Scan->>EC2: List all instances
    EC2-->>Scan: Return 20 instances
    Scan->>Scan: Filter ECS/EKS
    Scan-->>SF: Send 8 instances
    
    loop 5 at a time
        SF->>Install: Install on instance
        Install->>SSM: Execute script
        SSM-->>Install: Success
    end
    
    SF-->>CF: All Done ✅
    CF-->>User: Stack Ready!
```

## 🔄 Detailed Flow - New Instance

```mermaid
sequenceDiagram
    participant EC2 as 💻 New Instance
    participant EB as 👀 EventBridge
    participant SF as ⚙️ Step Function
    participant Check as 🔍 Check Lambda
    participant SSM as 🔧 SSM
    participant Install as 📦 Install Lambda

    EC2->>EB: State: Running
    EB->>SF: New instance detected!
    SF->>SF: Wait 70 seconds
    SF->>Check: Is SSM ready?
    
    alt SSM Ready
        Check->>SSM: Check status
        SSM-->>Check: Online ✅
        Check-->>SF: Ready!
        SF->>Install: Install agent
        Install->>SSM: Execute script
        SSM->>EC2: Install agent
        EC2-->>SSM: Done ✅
    else Not Ready
        Check->>SSM: Check status
        SSM-->>Check: Not found ❌
        Check-->>SF: Skip instance
    end
```

## 🎯 Key Components

### **AWS Resources**

| Resource | Name | Purpose |
|----------|------|---------|
| 🔍 Lambda | INITIAL-SCAN-INSTANCES | Scans all EC2 instances |
| 🔍 Lambda | INITIAL-CHECK-SSM | Checks if SSM is ready (no wait) |
| ⏱️ Lambda | TRIGGERED-WAIT-SSM | Waits for SSM (up to 90s) |
| 📦 Lambda | INSTALL-AGENT | Installs the agent (shared) |
| ⚙️ Step Function | INITIAL-SCAN-WORKFLOW | Orchestrates initial scan |
| ⚙️ Step Function | TRIGGERED-INSTANCE-WORKFLOW | Orchestrates new instances |
| 👀 EventBridge | EC2-RUNNING-RULE | Detects new instances |

### **How Instances Are Detected**

```mermaid
graph TD
    A[EC2 Instance] --> B{Has Tags?}
    B -->|Yes| C{Which Tag?}
    B -->|No| D[Skip]
    
    C -->|aws:ecs:clusterName| E[✅ ECS Instance]
    C -->|kubernetes.io/cluster/*| F[✅ EKS Instance]
    C -->|Other| D
    
    E --> G[Install Agent]
    F --> G

    style E fill:#c8e6c9
    style F fill:#bbdefb
    style G fill:#fff9c4
```

## 📊 Monitoring

### **CloudWatch Logs Examples**

**Initial Scan:**
```
[START] Starting EC2 instance scan
✓ ECS - Instance: i-abc123, Cluster: prod-ecs
✓ EKS - Instance: i-def456, Cluster: k8s-prod
[SUMMARY] Total: 20, ECS: 12, EKS: 8
```

**Installation:**
```
[START] Processing installation for instance: i-abc123
[S3] Selected script: install-agent.sh
[SSM] Command sent successfully
[SSM] Command ID: a1b2c3d4-e5f6-7890
[COMPLETED] Installation initiated
```

## 🔐 Security

```mermaid
graph LR
    Lambda[🔧 Lambda] -->|Read| S3[📦 S3 Scripts]
    Lambda -->|Query| EC2[💻 EC2]
    Lambda -->|Execute| SSM[🔧 SSM]
    Lambda -->|Read| Params[⚙️ SSM Parameters]
    
    style Lambda fill:#fff9c4
    style S3 fill:#e1f5fe
    style EC2 fill:#f3e5f5
    style SSM fill:#e8f5e9
    style Params fill:#fce4ec
```

## 📈 Scalability

### **Parallel Processing**

```mermaid
graph TD
    Start[Start Scan] --> Map[Map State]
    Map --> P1[Instance 1]
    Map --> P2[Instance 2]
    Map --> P3[Instance 3]
    Map --> P4[Instance 4]
    Map --> P5[Instance 5]
    Map -.->|Wait| P6[Instance 6]
    
    P1 --> Done[All Done]
    P2 --> Done
    P3 --> Done
    P4 --> Done
    P5 --> Done
    P6 --> Done

    style Map fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style Done fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
```

**Why Max 5?**
- ✅ Prevents overwhelming AWS APIs
- ✅ Reduces costs
- ✅ Ensures reliability
- ✅ If 5 finish, next 5 start automatically

## 🎨 Color Legend

- 🟢 **Green**: Initial Scan (on deployment)
- 🔵 **Blue**: Triggered Mode (new instances)
- 🟡 **Yellow**: Shared components
- ⚪ **White**: AWS Services

