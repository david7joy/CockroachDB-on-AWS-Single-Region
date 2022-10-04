#!/bin/bash
echo "Starting CockcrochDB Setup Script"
echo "=============================="
echo "."
echo "."
echo "."
echo "."
echo "Setting up Time Sync service on Amazon"
echo "."
echo "."
sudo yum erase 'ntp*'
sudo yum install chrony
echo 'server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4' | sudo tee -a /etc/chrony.conf
sudo service chronyd restart
sudo chkconfig chronyd on
echo "."
echo "."
echo "---- Installing CockroachDB on Hosts ----"
echo "."
echo "."
sudo curl https://binaries.cockroachdb.com/cockroach-v22.1.8.linux-amd64.tgz | tar -xz
sudo cp -i cockroach-v22.1.8.linux-amd64/cockroach /usr/local/bin/
sudo mkdir -p /usr/local/lib/cockroach
sudo cp -i cockroach-v22.1.8.linux-amd64/lib/libgeos.so /usr/local/lib/cockroach/
sudo cp -i cockroach-v22.1.8.linux-amd64/lib/libgeos_c.so /usr/local/lib/cockroach/
echo "."
echo "."
echo "---- Setup Completed----"
