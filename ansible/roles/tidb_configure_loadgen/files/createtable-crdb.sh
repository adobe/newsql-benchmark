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

java -cp /home/crdb/ycsb-0.17.0/jdbc-binding/lib/jdbc-binding-0.17.0.jar:/home/crdb/ycsb-0.17.0/postgrenosql-binding/lib/postgresql-9.4.1212.jre7.jar site.ycsb.db.JdbcDBCreateTable -p fieldcount=20 -P /home/crdb/db.properties -n usertable
