# Install terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt install -y terraform

# Install ansible
sudo apt -y update
sudo apt install -y software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Setup the control machine - Install monitoring (Grafana/Prometheus)
cd ~
tar xfvz archive.tgz
cd terraform
terraform init

sudo chmod -R 755 /home/fdb/.ansible/
sudo chmod -R 755 /home/fdb/
sudo chown -R fdb:fdb ~/*
sudo chmod 600 ~/terraform/out/id_rsa*

mkdir ~/results

cd ~/ansible
ansible-galaxy role install -r roles/requirements.yaml
pip install jmespath