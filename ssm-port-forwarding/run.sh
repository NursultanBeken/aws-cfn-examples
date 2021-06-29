#working version
echo -e 'y\n' | ssh-keygen -t rsa -f /tmp/temp -N '' >/dev/null 2>&1

echo ">>> push your SSH Key to the target instance"
aws ec2-instance-connect send-ssh-public-key \
  --region us-west-2 \
  --instance-id `terraform output -raw instance_id` \
  --availability-zone `terraform output -raw az` \
  --instance-os-user ubuntu \
  --ssh-public-key file:///tmp/temp.pub >/dev/null 2>&1

echo ">>> start an AWS System Manager session and enable port forwarding ..."
nohup aws ssm start-session --target `terraform output -raw instance_id` \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["22"], "localPortNumber":["9999"]}' \
  --region us-west-2 &

sleep 5 

echo ">>> opening a tunnel to RDS instance via the AWS System Manager session ..."
ssh -i /tmp/temp  \
-p 9999 \
-Nf -M  \
-L 5432:`terraform output -raw rds_endpoint` \
-o "UserKnownHostsFile=/dev/null" \
-o "StrictHostKeyChecking=no" \
ubuntu@localhost

export PGPASSWORD=codelab_password
echo ">>> connect to DataBase"
psql -d codelab_db -p 5432 \
  -h localhost \
  -U codelab_user \
  -c "SELECT * FROM codelab_table"