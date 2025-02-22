#!/bin/bash
#Configure Server

echo -e "YOUR_PASSWORD\nYOUR_PASSWORD" | sudo passwd ec2-user
sudo hostnamectl set-hostname ldap.semicloud.dev
echo "10.100.1.10 $(hostname)" | sudo tee -a /etc/hosts
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

##Install LDAP
sudo dnf module reset idm && sudo dnf -y install @idm:DL1 && sudo dnf -y install freeipa-server ipa-server-dns bind-dyndb-ldap
sudo ipa-server-install \
   -U \
   --setup-dns \
   --hostname=$(hostname) \
   --domain=semicloud.dev \
   --realm=SEMICLOUD.DEV \
   --ds-password=YOUR_PASSWORD \
   --admin-password=YOUR_PASSWORD \
   --allow-zone-overlap \
   --auto-reverse \
   --netbios-name=SEMICLOUD \
   --mkhomedir \
   --no-ntp \
   --forwarder=10.100.0.2

##Change Cert for Lets Encrypt Wildcard
cd /tmp
mkdir freeipa-certs
cd freeipa-certs
CERTS=("isrgrootx1.pem" "isrg-root-x2.pem" "lets-encrypt-r3.pem" "lets-encrypt-e1.pem" "lets-encrypt-r4.pem" "lets-encrypt-e2.pem")

for CERT in "${CERTS[@]}"
do
  curl -o $CERT "https://letsencrypt.org/certs/$CERT"
done

for CERT in "${CERTS[@]}"
do
  sudo ipa-cacert-manage install $CERT
done

sudo ipa-certupdate

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

sudo ipa-server-certinstall -w -d /tmp/freeipa-certs/privkey.pem /tmp/freeipa-certs/cert.pem --pin='' -p YOUR_PASSWORD
sudo ipactl restart

#### Foreman Requirement for Realm Integration ######
sudo cp /etc/ipa/ca.crt /etc/pki/ca-trust/source/anchors/ipa.crt
sudo update-ca-trust enable
sudo update-ca-trust

sudo echo "ldap deployed" > /tmp/ldapdeployed.txt
