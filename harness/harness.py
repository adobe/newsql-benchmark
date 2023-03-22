
# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

import json
import os.path
from os import path
import time
import subprocess
from string import Template
import requests
import datetime

# Get the DB eval prefix first 
dbeval_prefix  = os.getenv('DBEVAL_PREFIX', 'uis-dbeval-unknownuser')

# ------------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------------
base_path = '/home/fdb'
log_file = base_path + "/harness/harness.log"
input_spec_file = base_path + "/harness/harness-experiments.json"
clusters_file=base_path + "/harness/harness-clusters.json"
db_steps_file = base_path + "/harness/harness-db-steps.json"

tf_working_dir = base_path + '/terraform'
ansible_working_dir = base_path + '/ansible'

repl_factor=3
record_size_bytes=2000
operation_batch_size=100

ycsb_max_execution_time_seconds_default = 30*60
prometheus_host=subprocess.check_output(['sh', '-c', 'cat ../ansible/inventory-cm.yaml| grep control_private_ip -A 1| tail -n 1']).decode("utf-8").strip()#"localhost"
print(f"prometheus_host = {prometheus_host}")

cluster_stats_header_line='loadgen-cluster-avg-cpu-util(%), db-cluster-avg-cpu-util(%), db-cluster-avg-disk-read(MB/s), db-cluster-avg-disk-write(MB/s), db-cluster-avg-disk-free(%),	db-cluster-avg-network-rx(Mbps), db-cluster-avg-network-tx(Mbps)'
workload_details_header_line  = "loadgen-type, workload-name, workload-params, num-records, record-size(bytes), replication-factor, db-node-type, db-node-count, db-ssd-type, loadgen-node-type, loadgen-node-count, loadgen-processes-per-node, loadgen-threads-per-process, operation-count, operation-batch-size, start-time(UTC)"
ycsb_results_header_line      = "runtime(s), throughput(ops/s), insert-operations-error-count, insert-operations-success-count,insert-operations-unknown-count, insert-operation(avg-latency-us), read-operations-error-count, read-operations-success-count,read-operations-unknown-count, read-operation(avg-latency-us), read-operation(P95-latency-us), read-operation(P99-latency-us), update-operations-error-count, update-operations-success-count,update-operations-unknown-count, update-operation(avg-latency-us),update-operation(P95-latency-us),update-operation(P99-latency-us)"
cluster_stats_header_line     = "loadgen-cluster-avg-cpu-pct, db-cluster-avg-cpu-pct, db-cluster-avg-disk-read-MBps, db-cluster-avg-disk-write-MBps, db-cluster-min-free-disk-gbs-per-node, db-cluster-avg-network-rx-mbps, db-cluster-avg-network-tx-mbps"

final_results_header_line=f"{workload_details_header_line}, {ycsb_results_header_line}, {cluster_stats_header_line}"
# ------------------------------------------------------------------------------------
# Helper functions for running ansible/terraform/shell commands
# ------------------------------------------------------------------------------------
def build_tf_overrides_for_cluster(cluster):
	managed_ssd_count = 0 if cluster['ssdType'] == 'local' else 1
	tf_overrides = f""" -var "prefix={dbeval_prefix}" -var 'override_ascluster_map={{vm_type="{cluster['dbNodeType']}", vm_count="{cluster['dbNodeCount']}", disks_per_vm="{managed_ssd_count}"}}' -var 'override_loadgencluster_map={{vm_type="{cluster['loadgenNodeType']}", vm_count="{cluster['loadgenNodeCount']}"}}' """
	return tf_overrides

def build_tf_overrides_for_destroy_cluster(cluster):
	return f""" -var "prefix={dbeval_prefix}" -var 'override_ascluster_map={{vm_type="{cluster['dbNodeType']}", vm_count="0", disks_per_vm="0"}}' -var 'override_loadgencluster_map={{vm_type="{cluster['loadgenNodeType']}", vm_count="0"}}' """

def run_step(stepname, steptype, stepargs, failonerror, expname):
	print(f"Running {steptype} step: {stepname} for sub-experiment {expname}...")
	rc = -1
	if(steptype == 'harness-terraform'):
		cmd = f"cd {tf_working_dir}; {stepargs}"
		rc = run_shell_command_with_retries(f"{steptype}:CreateCluster", cmd, 10, 5)
	elif(steptype == 'harness-ansible'):
		cmd = f"cd {ansible_working_dir} ; export ANSIBLE_HOST_KEY_CHECKING=False ; ansible-playbook -i inventory.yaml -i inventory-cm.yaml --user fdb --private-key ../terraform/out/id_rsa_tf {stepargs} -e  \"loadgen_exp_name={expname}\" "
		rc = run_shell_command_with_retries(f"{stepname}:{steptype}", cmd, 10, 2)
	elif(steptype == 'shell'):
		cmd = f"sh {stepargs}"
		rc = run_shell_command_with_retries(f"{stepname}:{steptype}", cmd, 10, 5)
	else:
		exit("Unsupported step type - " + steptype)

	if(failonerror and (rc != 0)):
			exit(f"FATAL: Running {steptype} step: {stepname} for sub-experiment {expname}...FAILED with rc {rc}!")
	else:
		return rc

def run_shell_command_with_retries(cmd_name, cmd, timeout_mins, retry_attempts):
	total_attempts = retry_attempts #5
	remaining_attempts = total_attempts
	timeout_value = f"{timeout_mins}m"
	exit_code = -1

	while remaining_attempts > 0:
		exit_code = run_shell_command(cmd)
		remaining_attempts -= 1
		if exit_code != 0 :
			if remaining_attempts <= 0:
				print(f"ERROR: Command {cmd_name} returned a non-zero exit code = {exit_code}. All {total_attempts} retries failed!")
			else:
				print(f"Running {cmd_name} ...FAILED with RC({exit_code})..RETRYING..")
		else:
			break
	return exit_code

def run_shell_command(cmd):
	new_cmd = f"{cmd}>> {log_file} 2>&1"
	with open(log_file, 'a') as log: 
		log.write(f"\n\nRunning command - {new_cmd}")
		log.flush()
		process = subprocess.Popen(new_cmd, shell=True, stdout=subprocess.PIPE)
		process.wait()
		log.write(f"Shell command returned exit code = {process.returncode}")
		log.flush()
	return process.returncode

def create_markerfile(file_path):
	if not os.path.exists(file_path):
		basedir = os.path.dirname(file_path)
		if not os.path.exists(basedir):
			os.makedirs(basedir)
	open(file_path, 'w').close()

def markerfile_exists(file_path):
	if path.exists(file_path):
		#print(f"MarkerFile {file_path} already exists!")
		return True
	#print(f"MarkerFile {file_path} doesn't exists!")
	return False

def get_workload_param(workload_name):
	workload_name_param_map = {
		'insertWorkload':           '(read_proportion=0.0|update_proportion=0.0|request-distribution=constant)',
		'readOnlyWorkload':         '(read_proportion=1.0|update_proportion=0.0|request-distribution=constant)',
		'readModifyWriteWorkload':  '(read_proportion=0.0|update_proportion=1.0|request-distribution=constant)',
		'read90Update10Workload':   '(read_proportion=0.9|update_proportion=0.1|request-distribution=constant)'
	}
	return workload_name_param_map.get(workload_name, "n/a")

def get_cluster_details_for_results(cluster,loadgen_threads_per_process, loadgen_processes_per_node):
	res = f"{cluster['dbNodeType']}, {cluster['dbNodeCount']}, {cluster['ssdType']}, {cluster['loadgenNodeType']}, {cluster['loadgenNodeCount']}, {loadgen_processes_per_node}, {loadgen_threads_per_process}"
	return res


# ------------------------------------------------------------------------------------
# Helper functions for scraping metrics from prometheus
# ------------------------------------------------------------------------------------
def get_cluster_stats_for_time_range(start_ts, end_ts, interval_seconds, hostname, node_count):
	avg_cpu_db_query = "http://" + hostname + ":9090/api/v1/query_range?start=" +start_ts+ "&end="+end_ts+"&step=24h&query=avg%20by%20(nodeType)(100%20-%20((rate(node_cpu_seconds_total{mode=%22idle%22}[" + str(interval_seconds) +"s]))%20*%20100))"
	min_disk_bytes_util_query = "http://" + hostname + ":9090/api/v1/query_range?start="+start_ts+"&end="+end_ts+'&step=24h&query=min(node_filesystem_avail_bytes{mountpoint=~"/mount/.*",nodeType="db"})by(nodeType)'
	generic_sum_query_templ_with_filter = Template("http://" + hostname + ":9090/api/v1/query_range?start="+start_ts+"&end="+end_ts+"&step=24h&query=sum%20by%20(nodeType)(rate($metric_name{$filter_name=\"$filter_value\"}[" + str(interval_seconds) +"s]))")
	generic_sum_query_templ = Template("http://" + hostname + ":9090/api/v1/query_range?start="+start_ts+"&end="+end_ts+"&step=24h&query=sum%20by%20(nodeType)(rate($metric_name[" + str(interval_seconds) +"s]))")

	avg_cpu_db_result = get_metric(avg_cpu_db_query)
	disk_write_result = get_metric(generic_sum_query_templ.substitute(metric_name='node_disk_written_bytes_total'))
	disk_read_result = get_metric(generic_sum_query_templ.substitute(metric_name='node_disk_read_bytes_total'))
	min_disk_bytes_result = get_metric(min_disk_bytes_util_query)

	net_rx_result = get_metric(generic_sum_query_templ_with_filter.substitute(metric_name='node_network_receive_bytes_total', filter_name='device', filter_value='eth0'))
	net_tx_result = get_metric(generic_sum_query_templ_with_filter.substitute(metric_name='node_network_transmit_bytes_total', filter_name='device', filter_value='eth0'))

	result_csv_line = str(avg_cpu_db_result['loadgen']) + "," 
	result_csv_line += str(avg_cpu_db_result['db']) + ","
	result_csv_line += str(int(float(disk_read_result['db'])/(node_count * 1000000))) + ","
	result_csv_line += str(int(float(disk_write_result['db'])/(node_count * 1000000))) + ","
	result_csv_line += str(int(float(min_disk_bytes_result['db'])/(1000000000))) + ","
	result_csv_line += str(int(8*float(net_rx_result['db'])/(node_count * 1000000))) + ","
	result_csv_line += str(int(8*float(net_tx_result['db'])/(node_count * 1000000)))
	print(cluster_stats_header_line + "\n" + result_csv_line)
	return result_csv_line

def get_metric(url):
				#print("Querying url " + url)
				r = requests.get(url)
				raw_json = r.json()
				#print("Json response = ")
				#print(raw_json)

				t1 = map(lambda x: (x['metric']['nodeType'], int(float(x['values'][0][1]))), raw_json['data']['result'])
				result = dict((x, y) for x, y in t1)
				#print("Json response parsed = ")
				#print(result)
				return result


# ------------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------------

# Read the harness-db-steps.json file 
loaded_steps = []
with open(db_steps_file) as f:
	loaded_steps = json.load(f)

# Read the harness-clusters.json file 
cluster_defns=[]
with open(clusters_file) as f:
	cluster_defns = json.load(f)

with open(input_spec_file) as f:
	# Read the harness-experiements.json file
	cfg = json.load(f)

	cwd = cfg['workingDirectory'] + "/" + cfg['runId']
	keepalive = cfg['keepLastClusterAlive']
	runid = cfg['runId'] 
	workload_lists = cfg['workloadLists']

	for exp in cfg['experiments']:
		print(f"Running experiment {exp['experimentName']}..")
		exp_marker_file_path = f"{cwd}/markers/{exp['experimentName']}.EXPERIMENT.DONE"
		if markerfile_exists(exp_marker_file_path):
			print(f"Running experiment {exp['experimentName']}...SKIPPED")
			continue

		dbname = exp['dbName']
		default_steps = loaded_steps['default']
		custom_steps = loaded_steps[dbname]
		steps = {}
		steps.update(default_steps)
		steps.update(custom_steps)
		ycsb_binding_name = steps['ycsb_binding_name']
		loadgen_custom_ansible_args = steps.get('ansible_params',"")

		for i in range(len(exp['testClusters'])):
			cluster_name = exp['testClusters'][i]
			cluster = cluster_defns[cluster_name]
			# provision the cluster
			exp_cluster_marker = f"{exp['experimentName']}-{cluster_name}"
			exp_cluster_exp_completed_marker_file_path = f"{cwd}/markers/{exp_cluster_marker}.CLUSTER.DONE"
			if markerfile_exists(exp_cluster_exp_completed_marker_file_path):
				print(f"All sub-experiments have already been run for this cluster {cluster_name}.")
				continue

			print(f"Provisioning cluster {cluster_name}...")
			exp_cluster_provisioned_marker_file_path = f"{cwd}/markers/{exp_cluster_marker}.CLUSTER.PROVISIONED"

			if not markerfile_exists(exp_cluster_provisioned_marker_file_path):
				run_step('createCluster', 'harness-terraform', "terraform apply --auto-approve " + build_tf_overrides_for_cluster(cluster), True, exp_cluster_marker)
				run_step('provisionDb', steps['provisionDb'][0], steps['provisionDb'][1], True, exp_cluster_marker)
				run_step('provisionLoadgen', steps['provisionLoadgen'][0], steps['provisionLoadgen'][1], True, exp_cluster_marker)

				run_shell_command(f"rm -f {cwd}/markers/*.CLUSTER.PROVISIONED")
				create_markerfile(exp_cluster_provisioned_marker_file_path)
				print(f"Provisioning cluster {cluster_name} ...DONE")
			else:	
				print("Requested cluster has aleady been provisioned")
				print(f"Provisioning cluster {cluster_name}...SKIPPED")


			# for each run = (experiment, cluster, number-of-test-records)
			for num_test_record in exp['numberOfTestRecords']:
				exp_cluster_recordcount_marker = f"{exp['experimentName']}-{cluster_name}-{num_test_record}"
				exp_cluster_recordcount_marker_file_path = f"{cwd}/markers/{exp_cluster_recordcount_marker}.RUN.DONE"
				print(f"Running sub-experiment {exp_cluster_recordcount_marker} using {num_test_record} records against cluster {cluster_name}...")
				if markerfile_exists(exp_cluster_recordcount_marker_file_path):
					print(f"Running sub-experiment {exp_cluster_recordcount_marker} using {num_test_record} records against cluster {cluster_name}...SKIPPED")
					continue

				# run all the specified workloads for the current run
				workload_list = workload_lists[exp['workloadList']]
				for workload in workload_list :
					workload_name = workload['workloadName']
					worker_parallelism_arr = workload['workerParallelism']
					operations_per_worker_process_thread = workload['operationsPerWorkerProcessThread']
					doResetDb = workload.get('resetDbBeforeEachIteration',"false")
					skipWorkload = workload.get('ignore',"false")

					if skipWorkload == True:
						print(f"Workload {workload_name} has ignore flag set. SKIPPED.")
						continue

					for num, parallelism in enumerate(worker_parallelism_arr, start=0):
					#for parallelism in worker_parallelism_arr:
						loadgen_processes_per_node = parallelism[0]
						loadgen_threads_per_process = parallelism[1]
						operations_per_worker_process = loadgen_threads_per_process * operations_per_worker_process_thread
						operations_count_per_cluster = operations_per_worker_process * loadgen_processes_per_node * cluster['dbNodeCount']

						print(f"Running {workload_name} workload with {num_test_record} records against a {cluster['dbNodeCount']}-node {dbname} cluster using a {cluster['loadgenNodeCount']}-node loadgen cluster with {loadgen_processes_per_node} loadgen processes per node and {loadgen_threads_per_process} threads per loadgen process...")
						exp_cluster_recordcount_workload_marker = f"{exp_cluster_recordcount_marker}-{workload_name}-{loadgen_processes_per_node}-{loadgen_threads_per_process}"
						exp_cluster_recordcount_workload_marker_file_path = f"{cwd}/markers/{exp_cluster_recordcount_workload_marker}.WORKLOAD.DONE"
						if markerfile_exists(exp_cluster_recordcount_workload_marker_file_path) :
							print(f"Running {workload_name} workload with {num_test_record} records against a {cluster['dbNodeCount']}-node {dbname} cluster using a {cluster['loadgenNodeCount']}-node loadgen cluster with {loadgen_processes_per_node} loadgen processes per node and {loadgen_threads_per_process} threads per loadgen process...SKIPPED")
							continue	          

						# Run the workload
						ycsb_max_execution_time_seconds = exp.get('maxRuntimePerIterationInSeconds', ycsb_max_execution_time_seconds_default)
						if workload_name == "insertWorkload":
							if doResetDb == True:
								print("Resetting the DB before running insertWorkload ...")
								run_step('resetDb', steps['resetDb'][0], steps['resetDb'][1], True, exp_cluster_recordcount_marker)
							else:
								print("Resetting the DB before running insertWorkload ...SKIPPED")
							# Don't limit runtime for the last iteration of insertWorkload. Subsequent workloads expect all records to be inserted.
							if(num == len(worker_parallelism_arr)-1):
								ycsb_max_execution_time_seconds = 60 * 60 * 24 * 14
								operations_per_worker_process = int(num_test_record/(int(cluster['dbNodeCount']) * operation_batch_size))
						# YCSB uses Integer type for this param, so guard against overflow
						if(operations_per_worker_process >= 2147483646):
							print(f"WARN: Number of operations/loadgen process ({operations_per_worker_process}) cannot exceed 2147483646.")
							operations_per_worker_process = min(2147483646, operations_per_worker_process)

						loadgen_args = f" -e \"loadgen_db_name={dbname} loadgen_num_keys={num_test_record} loadgen_threads_per_process={loadgen_threads_per_process} loadgen_process_per_host={loadgen_processes_per_node}  ycsb_binding_name={ycsb_binding_name} ycsb_op_count={operations_per_worker_process} ycsb_max_execution_time_seconds={ycsb_max_execution_time_seconds} loadgen_batch_size={operation_batch_size} {loadgen_custom_ansible_args}\""
						start_ts_str = datetime.datetime.utcnow().isoformat() + 'Z'
						start_ts = time.time()

						run_step(workload_name, steps[workload_name][0], steps[workload_name][1] + loadgen_args, True, exp_cluster_recordcount_workload_marker)

						# Wait for workload completion
						while True:
							rc = run_step('loadgenStatusCheck', steps['loadgenStatusCheck'][0], steps['loadgenStatusCheck'][1], False, exp_cluster_recordcount_workload_marker)
							if rc == 0:
								print(f"Running harness-ansible step: loadgenStatusCheck ...DONE")
								break
							else :
								print(f"Running workload {workload_name} ...got exit code = {rc}. RETRYING in 5s...")
								time.sleep(10)

						end_ts_str = datetime.datetime.utcnow().isoformat() + 'Z'
						end_ts = time.time() 
						elapsed_seconds = max(60,int(end_ts - start_ts)) #TODO: use the Runtime from the ansible step since scraping results can take a minute

						# Get results
						result_dir = f"{cwd}/results"
						run_shell_command(f"mkdir -p {result_dir}")
						current_result_file = f"{result_dir}/{exp_cluster_recordcount_workload_marker}.results.csv"
						final_results_file = f"{result_dir}/{exp['experimentName']}.results.csv"
						new_args = steps['loadgenResults'][1] + " -e \"loadgen_combined_results_path=" + current_result_file + "\""
						rc = run_step('loadgenResults', steps['loadgenResults'][0], new_args, True, exp_cluster_recordcount_workload_marker)
						if(rc != 0):
							exit("Running harness-ansible step: loadgenResults...FAILED")

						# Get stats from prometheus
						cluster_stats_csv_line = get_cluster_stats_for_time_range(start_ts_str, end_ts_str, elapsed_seconds, prometheus_host, int(cluster['dbNodeCount']))

						#append to results file
						with open(current_result_file, 'r') as f:
							current_result_file_contents = f.read().splitlines()
							if(len(current_result_file_contents) != 2):
								exit("Expected results file to have 2 lines, but found " + str(len(current_result_file_contents)))
							cluster_details_headers = get_cluster_details_for_results(cluster, loadgen_threads_per_process, loadgen_processes_per_node)
							new_entry = f"{cluster['loadgenType']}, {workload_name}, {get_workload_param(workload_name)}, {num_test_record}, {record_size_bytes}, {repl_factor}, {cluster_details_headers}, {operations_count_per_cluster}, {operation_batch_size}, {start_ts_str}, {current_result_file_contents[1]}, {cluster_stats_csv_line}"
							print(f"Results: \n${final_results_header_line}\n{new_entry}")
							file_exists = path.exists(final_results_file)
							with open(final_results_file, 'a+') as f2:
								if file_exists != True:
									f2.write(final_results_header_line + "\n")
								f2.write(new_entry + "\n")
								f2.flush()

						create_markerfile(exp_cluster_recordcount_workload_marker_file_path)
						print(f"Completed {workload_name} workload.")
				print(f"Completed experiment run {exp_cluster_recordcount_marker} using {num_test_record} records.")
				create_markerfile(exp_cluster_recordcount_marker_file_path) #here
			print(f"Completed experiment runs {exp_cluster_marker} using cluster {cluster_name}.")
			print(f"Copy results from the cluster {cluster_name} to the control machine...")
			run_step("ArchiveResults", "harness-ansible", "control_machine_archive_results.yaml", True, exp_cluster_marker)
			create_markerfile(exp_cluster_exp_completed_marker_file_path)
			print(f"Destroying cluster {cluster_name}...")
			if(i == (len(exp['testClusters']) - 1) and keepalive == True):
				print("Destroying cluster {cluster_name}...SKIPPED due to keepAlive flag")
			else:
				run_step('DestroyCluster', 'harness-terraform', "terraform apply --auto-approve " + build_tf_overrides_for_destroy_cluster(cluster), True, exp_cluster_marker)
				run_shell_command(f"rm {exp_cluster_provisioned_marker_file_path}")

		print(f"Completed experiment {exp['experimentName']}.")
		create_markerfile(exp_marker_file_path)
	print(f"Completed all experiments. Exiting.")
