# 🏗️ Architecture - Trend Micro Agent Service

## 📐 Complete Architecture Diagram

```mermaid
graph TB
    subgraph "🔷 CloudFormation Deployment"
        CFN[CloudFormation Stack]
        CFN --> SSM_S3[SSM Parameter: S3 Bucket]
        CFN --> SSM_TAG[SSM Parameter: EC2 Tags]
        CFN --> CUSTOM[Custom Resource Trigger]
    end

    subgraph "🟢 INITIAL SCAN WORKFLOW - On Deployment"
        CUSTOM -->|Invokes| LAMBDA_TRIGGER[Lambda: INITIAL-TRIGGER-SCAN]
        LAMBDA_TRIGGER -->|Starts| SF_INITIAL[Step Function: INITIAL-SCAN-WORKFLOW]
        
        SF_INITIAL -->|1. Scan| LAMBDA_SCAN[Lambda: INITIAL-SCAN-INSTANCES]
        LAMBDA_SCAN -->|Reads Tags| SSM_TAG
        LAMBDA_SCAN -->|Queries| EC2_API[AWS EC2 API]
        
        SF_INITIAL -->|2. Map State<br/>Max 5 parallel| MAP_INITIAL{Process Instances}
        
        MAP_INITIAL -->|For each instance| LAMBDA_CHECK[Lambda: INITIAL-CHECK-SSM]
        LAMBDA_CHECK -->|Verifies| SSM_API[AWS SSM API]
        
        LAMBDA_CHECK -->|If in SSM| LAMBDA_INSTALL
    end

    subgraph "🔵 TRIGGERED WORKFLOW - EventBridge"
        EB_RULE[EventBridge Rule:<br/>EC2 State = Running]
        EB_RULE -->|Detects new instance| SF_TRIGGERED[Step Function: TRIGGERED-INSTANCE-WORKFLOW]
        
        SF_TRIGGERED -->|1. Capture| LAMBDA_CAPTURE[Lambda: TRIGGERED-CAPTURE-INSTANCE]
        LAMBDA_CAPTURE -->|Validates Tags| SSM_TAG
        
        SF_TRIGGERED -->|2. Wait 70s| WAIT[Wait State]
        WAIT -->|3. Verify SSM| LAMBDA_WAIT[Lambda: TRIGGERED-WAIT-SSM]
        LAMBDA_WAIT -->|Waits registration<br/>Max 90s| SSM_API
        
        LAMBDA_WAIT -->|If registered| LAMBDA_INSTALL
    end

    subgraph "🟡 SHARED COMPONENT - Installation"
        LAMBDA_INSTALL[Lambda: INSTALL-AGENT<br/>Shared by both flows]
        LAMBDA_INSTALL -->|1. Reads bucket| SSM_S3
        LAMBDA_INSTALL -->|2. Downloads script| S3[S3 Bucket<br/>.sh or .ps1]
        LAMBDA_INSTALL -->|3. Executes via SSM| SSM_CMD[SSM Send Command]
        SSM_CMD -->|Installs agent| EC2_INSTANCE[EC2 Instance]
    end

    subgraph "🔍 Cluster Detection"
        LAMBDA_SCAN -->|Filters by tags| ECS_TAG[Tag: aws:ecs:clusterName]
        LAMBDA_SCAN -->|Filters by tags| EKS_TAG[Tag: kubernetes.io/cluster/*]
        ECS_TAG -.->|ECS Instances| MAP_INITIAL
        EKS_TAG -.->|EKS Instances| MAP_INITIAL
    end

    subgraph "📊 Observability"
        LAMBDA_SCAN --> CW_SCAN[CloudWatch Logs:<br/>Scan]
        LAMBDA_CHECK --> CW_CHECK[CloudWatch Logs:<br/>Check SSM]
        LAMBDA_WAIT --> CW_WAIT[CloudWatch Logs:<br/>Wait SSM]
        LAMBDA_INSTALL --> CW_INSTALL[CloudWatch Logs:<br/>Installation]
    end

    style CFN fill:#e1f5ff,stroke:#01579b,stroke-width:3px
    style SF_INITIAL fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px
    style SF_TRIGGERED fill:#bbdefb,stroke:#1565c0,stroke-width:3px
    style LAMBDA_INSTALL fill:#fff9c4,stroke:#f57f17,stroke-width:3px
    style MAP_INITIAL fill:#a5d6a7,stroke:#388e3c,stroke-width:2px
    style EC2_INSTANCE fill:#ffccbc,stroke:#d84315,stroke-width:2px
```

## 🔄 Detailed Workflow

### **Flow 1: Initial Scan (On CloudFormation Deployment)**

```mermaid
sequenceDiagram
    participant CFN as CloudFormation
    participant CR as Custom Resource
    participant LT as Lambda Trigger
    participant SF as Step Function Initial
    participant LS as Lambda Scan
    participant SSM_P as SSM Parameters
    participant EC2 as EC2 API
    participant Map as Map State
    participant LC as Lambda Check SSM
    participant SSM_A as SSM API
    participant LI as Lambda Install
    participant S3 as S3 Bucket
    participant Inst as EC2 Instance

    CFN->>CR: CREATE Stack
    CR->>LT: Invoke
    LT->>SF: Start Execution
    SF->>LS: Scan Instances
    LS->>SSM_P: Read Tag Filter
    LS->>EC2: describe_instances()
    EC2-->>LS: Instance list
    LS->>LS: Filter ECS/EKS
    LS-->>SF: Filtered list
    SF->>Map: Process (Max 5 parallel)
    
    loop For each instance
        Map->>LC: Verify SSM
        LC->>SSM_A: describe_instance_information()
        alt Registered in SSM
            SSM_A-->>LC: ✅ Online
            LC-->>Map: OK
            Map->>LI: Install Agent
            LI->>SSM_P: Read S3 Bucket
            LI->>S3: Download Script
            LI->>SSM_A: send_command()
            SSM_A->>Inst: Execute Script
            Inst-->>SSM_A: ✅ Installed
        else Not registered
            SSM_A-->>LC: ❌ Not found
            LC-->>Map: Error (Skip)
        end
    end
    
    Map-->>SF: Completed
    SF-->>LT: Success
    LT-->>CR: SUCCESS
    CR-->>CFN: Stack CREATE_COMPLETE
```

### **Flow 2: Triggered (New EC2 Instance)**

```mermaid
sequenceDiagram
    participant EC2 as New EC2 Instance
    participant EB as EventBridge
    participant SF as Step Function Triggered
    participant LC as Lambda Capture
    participant SSM_P as SSM Parameters
    participant W as Wait 70s
    participant LW as Lambda Wait SSM
    participant SSM_A as SSM API
    participant LI as Lambda Install
    participant S3 as S3 Bucket
    participant Inst as EC2 Instance

    EC2->>EB: State Change: Running
    EB->>SF: Trigger Step Function
    SF->>LC: Capture Instance ID
    LC->>SSM_P: Validate Tags
    alt Valid Tags
        LC-->>SF: ✅ Instance ID
        SF->>W: Wait 70 seconds
        W-->>SF: Continue
        SF->>LW: Verify SSM
        LW->>LW: Loop (Max 90s)
        loop Every 5 seconds
            LW->>SSM_A: describe_instance_information()
            alt Registered
                SSM_A-->>LW: ✅ Online
                LW-->>SF: Ready
            else Not registered yet
                SSM_A-->>LW: ❌ Waiting...
                LW->>LW: Sleep 5s
            end
        end
        SF->>LI: Install Agent
        LI->>SSM_P: Read S3 Bucket
        LI->>S3: Download Script
        LI->>SSM_A: send_command()
        SSM_A->>Inst: Execute Script
        Inst-->>SSM_A: ✅ Installed
    else Invalid Tags
        LC-->>SF: ❌ Error
        SF->>SF: End (Failed)
    end
```

## 🎯 Key Components

### **Lambdas by Purpose**

| Lambda | Purpose | Timeout | Memory | Process |
|--------|---------|---------|--------|---------|
| **INITIAL-SCAN-INSTANCES** | Scans all EC2 instances and filters ECS/EKS | 300s | 512MB | Initial |
| **INITIAL-CHECK-SSM** | Verifies SSM registration without waiting | 30s | 256MB | Initial |
| **INITIAL-TRIGGER-SCAN** | Starts Step Function on deployment | 120s | 128MB | Initial |
| **TRIGGERED-CAPTURE-INSTANCE** | Captures and validates tags of new instance | 90s | 300MB | Triggered |
| **TRIGGERED-WAIT-SSM** | Waits up to 90s for instance to register in SSM | 120s | 300MB | Triggered |
| **INSTALL-AGENT** | Installs Trend Micro agent via SSM | 90s | 300MB | Shared |

### **Step Functions**

| Step Function | States | Concurrency | Purpose |
|---------------|--------|-------------|---------|
| **INITIAL-SCAN-WORKFLOW** | 6 states | Max 5 parallel | Initial scan on deployment |
| **TRIGGERED-INSTANCE-WORKFLOW** | 4 states | 1 per instance | New instance via EventBridge |

### **IAM Resources**

- **LAMBDA-ROLE**: Permissions for EC2, SSM, S3, Lambda invoke, Step Functions
- **STEP-FUNCTIONS-ROLE**: Permissions to invoke Lambdas
- **EVENTBRIDGE-ROLE**: Permissions to start Step Function

## 🔐 Security

```mermaid
graph LR
    subgraph "IAM Permissions"
        LR[Lambda Role]
        SFR[Step Functions Role]
        EBR[EventBridge Role]
    end
    
    subgraph "AWS Services"
        LR -->|ec2:DescribeInstances| EC2[EC2 API]
        LR -->|ssm:*| SSM[SSM API]
        LR -->|s3:GetObject| S3[S3 Bucket]
        LR -->|lambda:InvokeFunction| LAMBDA[Lambdas]
        LR -->|states:StartExecution| SF[Step Functions]
        
        SFR -->|lambda:InvokeFunction| LAMBDA
        EBR -->|states:StartExecution| SF
    end
    
    subgraph "Parameters"
        SSM_P[SSM Parameters]
        LR -->|ssm:GetParameter| SSM_P
    end

    style LR fill:#fff9c4,stroke:#f57f17
    style SFR fill:#e1bee7,stroke:#7b1fa2
    style EBR fill:#c5e1a5,stroke:#558b2f
```

## 📈 Scalability and Performance

### **Concurrency Control**

```yaml
Initial Scan Workflow:
  - Map State MaxConcurrency: 5
  - Controlled parallel processing
  - Prevents API saturation
  - Optimizes costs

Triggered Workflow:
  - 1 instance at a time
  - No limit on total instances
  - EventBridge handles queue
```

### **Retries and Fault Tolerance**

| Component | Retries | Interval | BackoffRate |
|-----------|---------|----------|-------------|
| Check SSM (Initial) | 2 | 10s | 2x |
| Install Agent | 2 | 5s | 1.5x |
| Wait SSM (Triggered) | 3 | 10s | 2x |

## 📊 Monitoring

### **CloudWatch Logs - Structure**

```
/aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-SCAN-INSTANCES
├── [START] Scan initiated
├── [INFO] Required tags: {...}
├── ✓ ECS - Instance: i-xxx, Cluster: prod
├── ✓ EKS - Instance: i-yyy, Cluster: k8s
└── [SUMMARY] Total: 10, ECS: 5, EKS: 5

/aws/lambda/TRENDMICRO-AGENT-SERVICE-INITIAL-CHECK-SSM
├── [START] Checking i-xxx
├── [SUCCESS] Registered in SSM
├── [SSM INFO] Platform: Linux
└── [COMPLETED] Ready for installation

/aws/lambda/TRENDMICRO-AGENT-SERVICE-INSTALL-AGENT
├── [START] Processing i-xxx
├── [S3] Script: install-agent.sh
├── [SSM] Command sent
└── [COMPLETED] Command ID: abc-123
```

## 💰 Cost Estimation

**Example: 20 ECS/EKS instances in initial scan**

| Service | Quantity | Unit Cost | Total |
|---------|----------|-----------|-------|
| Lambda Invocations | ~45 | $0.0000002 | $0.000009 |
| Lambda Duration (GB-s) | ~30 GB-s | $0.0000166667 | $0.0005 |
| Step Functions Transitions | ~50 | $0.000025 | $0.00125 |
| **TOTAL per deployment** | | | **~$0.002** |

**Estimated monthly cost** (1 deployment + 50 new instances):
- Initial Scan: $0.002
- Triggered (50 instances): $0.002
- **Total: ~$0.004/month** ✨

---

## 🎨 Color Legend

- 🔷 **Light Blue**: CloudFormation / Deployment
- 🟢 **Green**: Initial Scan Workflow
- 🔵 **Blue**: Triggered Workflow (EventBridge)
- 🟡 **Yellow**: Shared Components
- 🔴 **Red/Orange**: EC2 Instances (Target)
