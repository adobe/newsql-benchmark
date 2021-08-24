#!/usr/bin/env bash

cd ~
if [ ! -d "ycsb-0.17.0" ]
then
  wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz
  tar xfvz ycsb-0.17.0.tar.gz
else
   echo "YCSB is already installed"
fi

rm -rf ycsb-foundationdb-binding-0.18.0-SNAPSHOT
tar -xvf ycsb-foundationdb-binding-0.18.0-SNAPSHOT.tar.gz
echo "Completed"


