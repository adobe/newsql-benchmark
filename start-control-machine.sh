#!/bin/bash

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

if [ -z "$DBEVAL_PREFIX" ]
  then
    echo "Please set the \$DBEVAL_PREFIX environment variable first! Recommended value = uis-dbeval-<username>-<dbname>"
    exit 1
fi

# Create control machine
echo "Creating control machine ..."
cd terraform
terraform init -var "prefix=$DBEVAL_PREFIX"
terraform apply --auto-approve -var "prefix=$DBEVAL_PREFIX"

# Copy the repo to the control machine
echo "Copying all files(tracked by git) from local machine to control machine ..."
cd ..
git ls-files | tar Tzcf - archive.tgz
export CONTROL_MACHINE_IP=`cat ansible/inventory-cm.yaml| grep '\[control\]' -A 1| tail -n1`
echo $CONTROL_MACHINE_IP
scp -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf archive.tgz fdb@$CONTROL_MACHINE_IP:~/archive.tgz

# copy the tfstate file to the control-machine and place it in the root dir
echo "Copying terraform state file from local machine to control machine ..."
ssh -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf fdb@$CONTROL_MACHINE_IP "mkdir -p ~/terraform/; echo 'export DBEVAL_PREFIX=$DBEVAL_PREFIX' >> ~/.bashrc ; source ~/.bashrc"
scp -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf terraform/terraform.tfstate fdb@$CONTROL_MACHINE_IP:~/terraform/terraform.tfstate

echo "Running Ansible to provision the control machine ..."
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ansible/inventory-cm.yaml --user fdb --private-key terraform/out/id_rsa_tf ansible/control_machine_install.yaml
echo "Control Machine Ready!"

# Steps to login to control machine and run benchmarks
echo ""
echo "****************************************************************************************************"
echo "************************************** SSH to Control Machine **************************************"
echo "[on local machine] To SSH to control machine use the following command : "
echo "    export CONTROL_MACHINE_IP=\`cat ansible/inventory-cm.yaml| grep '\[control\]' -A 1| tail -n1\` ; ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf fdb@\$CONTROL_MACHINE_IP"
echo "****************************************************************************************************"
echo "************************************ Run Harness on Control Machine ********************************"
echo "[on control machine] To login into Azure run :"
echo "    az login"
echo "[on control machine] To select the R&D subscription run :"
echo "    az account set --subscription <subscription-id>"
echo "[on control machine] To start harness, run the following command on the control machine."
echo "    # this command will produce logs and results in ~/harness/workingDir/ directory"
echo "    tmux"
echo "    cd ~/harness ; python3 harness.py"
echo "    echo \"hit ctrl+b,c to create a new window in tmux\""
echo "    tail -f harness.log"
echo "    # we tar the results to the home directory. use ctrl+b followed by c to create new window in tmux)"
echo "    tar -cvf ~/harness/workingDir ~/workingDir.tar"
echo "[on local machine] To SCP the results from the control machine to your local machine use the following command : "
echo "    export CONTROL_MACHINE_IP=\`cat ansible/inventory-cm.yaml| grep '\[control\]' -A 1| tail -n1\` ; scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf fdb@\$CONTROL_MACHINE_IP:./workingDir.tar ."
echo "    mkdir results; cd results; tar -xvf ../workingDir.tar"
echo "****************************************************************************************************"
echo "************************************* Destroy all resources **********************************"
echo "[on control machine] To destroy all provisioned resources"
echo "    cd ~/terraform; terraform apply -auto-approve -var \"prefix=$DBEVAL_PREFIX\" -var \'override_ascluster_map={vm_type=\"Standard_L8s_v3\", vm_count=\"0\", disks_per_vm=\"0\"}\' -var \'override_loadgencluster_map={vm_type=\"Standard_F8s_v2\", vm_count=\"0\"}\' "
echo "[on local machine] To destroy all provisioned resources"
echo "    cd terraform; terraform destroy -auto-approve -var \"prefix=$DBEVAL_PREFIX\""
echo "****************************************************************************************************"
echo "****************************************************************************************************"


