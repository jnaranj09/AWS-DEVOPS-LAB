#!/bin/bash

export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY

echo -e "YOUR_PASSWORD\nYOUR_PASSWORD" | sudo passwd ec2-user
sudo hostnamectl set-hostname foreman.semicloud.dev
echo "10.100.1.11 $(hostname)" | sudo tee -a /etc/hosts
echo "10.100.1.10 ldap.semicloud.dev" | sudo tee -a /etc/hosts
sudo dnf -y install https://yum.puppet.com/puppet7-release-el-8.noarch.rpm
sudo dnf -y install https://yum.theforeman.org/releases/3.8/el8/x86_64/foreman-release.rpm
sudo dnf module -y enable foreman:el8
sudo dnf -y install foreman-installer ipa-client sshpass git

##########   Wait until LDAP is installed to enroll  ##################
sleep 300
max_retries=100
retry_interval=15
# Initialize variables
retry_count=0
success=false
# Loop until the maximum number of retries is reached
while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
    # Execute the SSH command and capture the exit status
    sshpass -p "YOUR_PASSWORD" ssh ec2-user@ldap.semicloud.dev -o "StrictHostKeyChecking no" 'cat /tmp/ldapdeployed.txt'
    exit_status=$?

    # Check the exit status to determine success
    if [ $exit_status -eq 0 ]; then
        success=true
        sudo ipa-client-install -U -N -w YOUR_PASSWORD -p admin --enable-dns-updates --server=ldap.semicloud.dev --domain=semicloud.dev --mkhomedir
    else
        echo "SSH command failed with exit status $exit_status. Retrying in $retry_interval seconds..."
        sleep $retry_interval
        ((retry_count++))
    fi
done
# Check if the maximum number of retries was reached
if [ "$success" = false ]; then
    echo "Maximum number of retries reached. SSH command failed."
fi

######### Add LDAP service for Foreman IPA Authentication #############
sshpass -p "YOUR_PASSWORD" ssh ec2-user@ldap.semicloud.dev -o "StrictHostKeyChecking no" 'sudo kinit admin <<<"YOUR_PASSWORD" && sudo ipa service-add HTTP/foreman.semicloud.dev'


######## Wildcard certs for Foreman HTTPS ###############
sudo mkdir -p /etc/httpd/certs
cd /etc/httpd/certs
cat << 'EOF' > cert.pem
-----BEGIN CERTIFICATE-----
YOUR_CERTIFICATE_CONTENT
-----END CERTIFICATE-----
EOF
cat << 'EOF' > privkey.pem
-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT
-----END PRIVATE KEY-----
EOF
cat << 'EOF' > chain.pem
-----BEGIN CERTIFICATE-----
YOUR_CHAIN_CERTIFICATE_CONTENT
-----END CERTIFICATE-----
EOF

########   Running Foreman Installer  ##############

sudo foreman-installer \
    --foreman-server-ssl-cert /etc/httpd/certs/cert.pem \
    --foreman-server-ssl-chain /etc/httpd/certs/chain.pem \
    --foreman-server-ssl-key /etc/httpd/certs/privkey.pem \
    --foreman-proxy-foreman-ssl-ca /etc/ssl/certs/ca-bundle.crt \
    --puppet-server-foreman-ssl-ca /etc/ssl/certs/ca-bundle.crt \
    --enable-foreman-compute-ec2 \
    --foreman-initial-admin-password YOUR_PASSWORD \
    --foreman-cli-foreman-url https://foreman.semicloud.dev \
    --foreman-cli-password YOUR_PASSWORD \
    --foreman-cli-username admin \
    --foreman-initial-location dev \
    --foreman-initial-organization semicloud \
    --foreman-ipa-authentication=true \
    --foreman-ipa-authentication-api=true


######### Adding FreeIPA Realm Support  ##########
cd /etc/foreman-proxy/
sudo foreman-prepare-realm admin realm-smart-proxy <<<"YOUR_PASSWORD"
sudo chown foreman-proxy:foreman-proxy /etc/foreman-proxy/freeipa.keytab

sudo foreman-installer \
    --foreman-proxy-realm true \
    --foreman-proxy-realm-keytab /etc/foreman-proxy/freeipa.keytab \
    --foreman-proxy-realm-principal realm-smart-proxy@SEMICLOUD.DEV \
    --foreman-proxy-realm-provider freeipa


########  Removing Hammer SSL Verification  #######
sudo sed -i 's/:ssl:/#:ssl:/' /etc/hammer/cli.modules.d/foreman.yml

########   Downloading Puppet Modules     #########
cd /etc/puppetlabs/code/environments/production/modules
sudo git clone https://github.com/jnaranj09/AWS-DEVOPS-LAB-PUPPET.git .
sudo hammer proxy import-classes --id 1 --organization "semicloud" --location "dev" --puppet-environment "production"
cd -

########  Creating AWS Compute Resource    ########
sudo hammer compute-resource create \
    --organization semicloud \
    --location dev \
    --name EC2_AWS \
    --user $AWS_ACCESS_KEY_ID \
    --password $AWS_SECRET_ACCESS_KEY \
    --region us-east-1 \
    --provider EC2


######### Creating OS Image  ############
sudo hammer compute-resource image create \
    --compute-resource EC2_AWS \
    --name "RHEL 8.8" \
    --operatingsystem "RHEL 8.8" \
    --architecture x86_64 \
    --username ec2-user \
    --uuid ami-033d3612433d4049b \
    --user-data=true 


######## Creating Realm ##########
sudo hammer realm create --name "SEMICLOUD.DEV" --realm-type "FreeIPA" --realm-proxy-id 1 --organization "semicloud" --location "dev"


######### Creating pub1a Host Group  ############
sudo hammer hostgroup create \
    --name pub1a \
    --compute-resource EC2_AWS \
    --organization semicloud  \
    --location dev \
    --domain semicloud.dev \
    --architecture x86_64 \
    --operatingsystem "RHEL 8.8" \
    --puppet-proxy foreman.semicloud.dev \
    --puppet-ca-proxy foreman.semicloud.dev \
    --puppet-environment production \
    --puppet-classes haproxy \
    --root-password YOUR_PASSWORD \
    --realm SEMICLOUD.DEV

######### Associating Template with OS  ########
sudo hammer template update --name "Kickstart default user data" --operatingsystems "RHEL 8.8"
sudo hammer template update --name "Linux host_init_config default" --operatingsystems "RHEL 8.8"
sudo hammer os update --id "1-RHEL 8-8" --provisioning-templates '"Linux host_init_config default","Kickstart default user data"'
sudo hammer os set-default-template --id "1-RHEL 8-8" --provisioning-template-id "120-Kickstart default user data"


######### Enabling Puppet ###########
sudo hammer global-parameter set --name 'enable-official-puppet7-repo' --parameter-type 'boolean' --value=true


#########    HAProxy   ################
sudo hammer host create \
   --compute-attributes="flavor_id=t3.medium,security_group_ids=["${secgroup}"],subnet_id="${subnet}",managed_ip=Public" \
   --name "lb-pub1a" \
   --organization "semicloud" \
   --location "dev" \
   --hostgroup "pub1a" \
   --operatingsystem "RHEL 8.8" \
   --image "RHEL 8.8" \
   --interface="type=interface,name=hammer,domain_id=1,ip=10.100.200.200,managed=true,primary=true,provision=true,virtual=false"


########  Finished deploy   ############
sudo echo "foreman deployed" > /tmp/foremandeployed.txt
