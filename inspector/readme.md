# Amazon Inspector

### Plan:

1. Create Amazon EC2 instance (Amazon Linux instance which already has installed smm agent). Provide tag Inspector=true


2. Assign to instance role with AmazonSSMManagedInstanceCore policy \
	This will allow SSM to install inspector agent. However be aware which role and permissions to provide (check out this [article](https://cloudonaut.io/aws-ssm-is-a-trojan-horse-fix-it-now/))

3. Create Inspector: 
	* assessment set-up
	* assessment target
	* assessment template with [rules specific for your region](https://docs.aws.amazon.com/inspector/latest/userguide/inspector_rules-arns.html)

---
## Deploy

Create key pair for EC2 instance
```bash
aws ec2 create-key-pair \
    --region us-east-2 \
    --key-name key-pair-instance-inspector \
    --query "KeyMaterial" \
    --output text > my-key-pair.pem
```
Create stack
```bash
aws cloudformation deploy --stack-name enable-aws-inspector \
	--template-file template.yaml \
	--parameter-overrides KeyPairName=key-pair-instance-inspector \
	--capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
	--region us-east-2
```

## Clean up
```bash
aws cloudformation delete-stack \
	--region us-east-2 \
	--stack-name enable-aws-inspector
```