# AWS Secrets Manager & Automated Rotation Lab

This lab demonstrates a mission-critical security automation pattern for the **AWS SysOps Administrator Associate**: using Secrets Manager and Lambda to securely manage and automatically rotate sensitive credentials.

## Architecture Overview

The system implements a proactive security lifecycle for sensitive data:

1.  **Dedicated Encryption:** A KMS Customer Managed Key (CMK) is used to encrypt the secret, ensuring only authorized entities can access the credential data.
2.  **Secret Storage:** AWS Secrets Manager acts as the secure vault for database credentials (simulated as a JSON object).
3.  **Rotation Automation:** An AWS Lambda function contains the logic to generate new random passwords, update the database (conceptual), and label the new secret version as current.
4.  **Scheduled Updates:** A rotation schedule automatically triggers the Lambda function every 30 days to ensure credentials are never stagnant.
5.  **Service Connectivity:** A Lambda permission explicitly allows the Secrets Manager service to invoke the rotation logic.

## Key Components

-   **KMS CMK & Alias:** The root of trust for secret encryption.
-   **Secrets Manager Secret:** The managed container for the credential.
-   **Rotation Lambda:** Python-based automation for the rotation workflow (`createSecret`, `setSecret`, `testSecret`, `finishSecret`).
-   **IAM Role & Policy:** Granular permissions for the rotation function to access Secrets Manager and KMS.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To observe the secret rotation in action:

1.  **Retrieve Initial Secret:**
    ```bash
    awslocal secretsmanager get-secret-value --secret-id sysops-lab-db-password
    aws secretsmanager get-secret-value --secret-id sysops-lab-db-password
    ```

2.  **Manually Trigger Rotation:**
    ```bash
    awslocal secretsmanager rotate-secret --secret-id sysops-lab-db-password
    aws secretsmanager rotate-secret --secret-id sysops-lab-db-password
    ```

3.  **Verify New Version:**
    After rotation, retrieve the secret again to confirm the password has changed:
    ```bash
    awslocal secretsmanager get-secret-value --secret-id sysops-lab-db-password
    aws secretsmanager get-secret-value --secret-id sysops-lab-db-password
    ```

4.  **Inspect Secret Metadata:**
    ```bash
    awslocal secretsmanager describe-secret --secret-id sysops-lab-db-password
    aws secretsmanager describe-secret --secret-id sysops-lab-db-password
    ```
    Confirm the `LastRotatedDate` and the `RotationEnabled` status.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
