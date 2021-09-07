#
# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

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