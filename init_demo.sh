#!/bin/bash
if [ $# -eq 0 ] || [ $# -gt 1 ]
then
 echo "no or too many arguments provided, please provide apply or destroy"
 exit 1
elif [[ $1 != "apply" ]] && [[ $1 != "destroy" ]]
then
 echo "wrong argument, please provide apply or destroy"
 exit 1
else

 #Setting AWS Authentication INFO

 export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
 export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY


 if [[ $1 == "apply" ]]
 then
  #Terraform init, format, validate and apply
  echo -e "\nRunning terraform fmt"
  terraform fmt
  echo -e "\nRunning terraform validate"
  terraform validate
  echo -e "\nRunning terraform apply"
  terraform apply -auto-approve
  

  #### Getting HAProxy Public IP address  ####
  echo "Sleeping for 5 minutes"
  sleep 300
  max_retries=50
  retry_interval=60
  # Initialize variables
  retry_count=0
  success=false
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
      # Execute the SSH command and capture the exit status
      aws ec2 describe-instances --region us-east-1 --filters Name=private-ip-address,Values=10.100.200.200 --query 'Reservations[*].Instances[*].[PublicIpAddress]' --output text > lb-pub1a-ip.txt
      grep -q -E -i -o "([0-9]{1,3}\.){3}[0-9]{1,3}" lb-pub1a-ip.txt
      exit_status=$?

      # Check the exit status to determine success
      if [ $exit_status -eq 0 ]; then
          success=true
          echo ""
          echo "######"
          echo "HAproxy Public IP Obtained!!, IP: $(cat lb-pub1a-ip.txt)"
          echo "######"
          echo ""
          rm -f lb-pub1a-ip.txt
      else
          echo "HAproxy Public IP not available yet..... Retrying in $retry_interval seconds..."
          sleep $retry_interval
          ((retry_count++))
      fi
  done

  ##### Updating GoDaddy DNS #######
  sleep 5
  GODADDYKEY=YOUR_GODADDY_KEY
  GODADDYSEC=YOUR_GODADDY_SECRET
  lB_PUB1A_IP=$(aws ec2 describe-instances --region us-east-1 --filters Name=private-ip-address,Values=10.100.200.200 --query 'Reservations[*].Instances[*].[PublicIpAddress]' --output text)
  curl -X 'PUT' 'https://api.godaddy.com/v1/domains/semicloud.dev/records/A/*' -H 'accept: application/json' -H 'Content-Type: application/json' -H "Authorization: sso-key $GODADDYKEY:$GODADDYSEC" -d '[
  {
    "data": '"\"$lB_PUB1A_IP\""',
    "port": 1,
    "priority": 0,
    "protocol": "string",
    "service": "string",
    "ttl": 600,
    "weight": 1
  }
]'


  ####### Checking if HAproxy is fully deployed #########
  max_retries=50
  retry_interval=60
  # Initialize variables
  retry_count=0
  success=false
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
      # Execute the SSH command and capture the exit status
      sshpass -p "YOUR_SSH_PASSWORD" ssh -q root@$lB_PUB1A_IP -o "StrictHostKeyChecking no" 'cat /tmp/deployed.txt'
      exit_status=$?

      # Check the exit status to determine success
      if [ $exit_status -eq 0 ]; then
          success=true
          echo ""
          echo "######"
          echo "HAproxy has been fully deployed"
          echo "######"
          echo ""
      else
          echo "HAproxy not deployed yet. Retrying in $retry_interval seconds..."
          sleep $retry_interval
          ((retry_count++))
      fi
  done




 elif [[ $1 == "destroy" ]]
 then
  echo -e "\nRunning terraform destroy"
  terraform destroy
 fi
fi


