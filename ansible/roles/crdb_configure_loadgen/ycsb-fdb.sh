#!/usr/bin/env bash

if [ ! -d "~/ycsb-0.17.0" ]
then
  cd ~
  wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz
  tar xfvz ycsb-0.17.0.tar.gz
  cd ycsb-0.17.0
else
   echo "YCSB is already installed"
fi


