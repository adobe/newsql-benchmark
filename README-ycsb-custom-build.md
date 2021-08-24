Steps to run custom YCSB build

 ## checkout the repo on local machine
 git clone https://github.com/brianfrankcooper/YCSB.git
 ## build package on local machine
 mvn -pl site.ycsb:foundationdb-binding -am clean package
 ## copy to control machine
 cd ~/repos/as-ops/; export CONTROL_MACHINE_IP=`cat ansible/inventory-cm.yaml| grep '\[control\]' -A 1| tail -n1`
 scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i terraform/out/id_rsa_tf /Users/arsriram/repos/YCSB/foundationdb/target/ycsb-foundationdb-binding-0.18.0-SNAPSHOT.tar.gz fdb@$CONTROL_MACHINE_IP:~/
 ## run loadgen_ycsb_install.yaml playbook on control machine
 cd /home/fdb/ansible ; export ANSIBLE_HOST_KEY_CHECKING=False ; ansible-playbook -i inventory.yaml -i inventory-cm.yaml --user fdb --private-key ../terraform/out/id_rsa_tf loadgen_ycsb_install.yaml
 ## run loadgen_ycsb_run.yaml playbook on control machine
 cd /home/fdb/ansible ; export ANSIBLE_HOST_KEY_CHECKING=False ; ansible-playbook -i inventory.yaml -i inventory-cm.yaml --user fdb --private-key ../terraform/out/id_rsa_tf loadgen_ycsb_run.yaml  -e "loadgen_workload_name=readmodifywrite ycsb_update_proportion=1.0 ycsb_read_proportion=0.0" -e "loadgen_db_name=fdb loadgen_threads_per_process=64 loadgen_process_per_host=4  ycsb_binding_name=foundationdb ycsb_op_count=35000000 ycsb_dir=/home/fdb/ycsb-foundationdb-binding-0.18.0-SNAPSHOT loadgen_batch_size=1 loadgen_num_keys=1000000000000"