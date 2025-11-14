# Server and Workload Protection Auto-Installer (Lambda-based)

This project contains an AWS Lambda function designed to automatically install server and workload protection agents on your EC2 instances.

## 🛠 Prerequisites

- An AWS account with permissions to create:
  - S3 buckets
  - Lambda functions
  - IAM roles and policies
- A set of installation scripts for the server and workload protection agents (for both Windows and Linux).

## ⚙️ Arquitectura

<img width="764" height="418" alt="Diagrama sin título drawio" src="https://github.com/user-attachments/assets/0470dfa6-3e32-4560-8b9f-d0a65d9ce64e" />


## 🚀 Deployment Steps

1. **Create an S3 Bucket**  
   In your AWS account, create a new S3 bucket.  
   Upload the installation scripts for both Windows and Linux to this bucket.  
   - The file names **do not matter**.  
   - Make sure the scripts are executable.

2. **Configure the Lambda Function**  
   The Lambda function will:
   - Identify EC2 instances (Windows or Linux).
   - Determine whether to apply the installation based on EC2 tags.

3. **Input Parameters**  
   The Lambda function expects two parameters:
   - **S3 Bucket Name**: The bucket where your installation scripts are stored.
   - **Tag Filter**: A specific tag key-value pair used to filter which instances to target.  
     Example: `{"Key": "AutoProtect", "Value": "true"}`  
     If you set this parameter to `NONE`, the Lambda will run **on all EC2 instances** in the region.

## 💡 Example Use

- Run only on instances tagged with `Environment:Production` (This is the dormat to put the parameter).
- Automatically install the agent on all current and future instances by setting the tag parameter to `NONE`.

## 📦 Notes

- The Lambda function requires appropriate IAM permissions to:
  - Read from S3
  - Describe and interact with EC2 instances
  - Send logs to CloudWatch
- Remember, for this automation to work properly, all instances must have the AmazonSSMManagedInstanceCore role attached.

## 📄 License

MIT or your chosen license.

