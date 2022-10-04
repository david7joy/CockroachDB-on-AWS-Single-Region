# CockroachDB - Single Region on AWS

This repo provides you with the ability to launch a single region(topology) CockroachDB(Self-hosted) cluster on AWS using terraform. We are going to use the following tools to launch this cluster. 

- CockroachDB - Distributed Database
- AWS Cloud -  Infrastucture to host a single region of CRDB
- Terraform - To automate infrasturture build on AWS
- PSSH - To setup AWS EC2 Instance that will be part of CRDB cluster

### Cluster Topology

![Topology](Single-Region-AWS.png)

As per above, we have created 
- 3 EC2 Instances 
- 1 VPC 
- 3 Subnets 
- 1 Network Load Balancer

Note : Change variables as needed in `variables.tf`

# Housekeeping : 
- Last Updated on 03/10/2022
- Terraform version : 1.3.1

# Terraform Intro

Terraform enables users to plan, create, and manage infrastructure as code. There are various providers available to cloud providers such as AWS,GCP, Azure and more. These providers provide methods that terraform users to provision and manage infrastructure. 

## Pre-requsites:

To run the terraform sucessfully, the following pre-reqs need to be setup in advance: 

- Install Terraform on local system
- Install and configure AWS CLI properly. 
- Create a SSH key-pair, so the launched AWS EC2 instances can be connected through SSH. 

## Essential Terraform Commands

- `terraform init` - initialize terraform script
- `terraform fmt` - format the terraform configuration files
- `terraform validate` - validate the terraform configuration
- `terraform apply` - create infrastructure from the configuration
- `terraform show` - inspect build
- `terraform destroy` - destroy the infrastructure 
- `terraform apply -var 'instance_name=yetanothername'` - change variables from command line

# Deploying a CockroachDB Single Region Cluster 

This is divided into 3 parts
- Infrastucture build
- Installing and setting up CockroachDB
- Starting CockroachDB
- Workload Testing

Read the below documentation for detailed understanding. 
https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html

## 1. Infrastucture Build

`main.tf` and `variables.tf` are the 2 essential files from this repo that will create the infrastructure. Check `main.tf` reach of the resources that are created to support this install. We create 
- EC2 Instance 
- VPC 
- Subnets
- Internet gateway 
- Route tables
- Security groups
- Load Balancers & Target groups

To build the infrastructure, run the following command
`terraform apply` 

Run `terraform output` to get public IP address for EC2 Instances that were just created by terraform. We will need these ip address for next steps.

## 2. Installing and setting up CockroachDB.

1. Go to `pssh_hosts_files.txt` and add `host-ip-address` as per your build that just completed.
2. Run the `setup.sh` script for AWS Time Sync Service and for installing CockroachDB. 

        `pssh -i -h pssh_hosts_files.txt -x "-oStrictHostKeyChecking=no -i add-your-key" -I < setup.sh`

3. Log into each node and test if setup ran as expected 

        `ssh -i add-ec2-key ec2-user@public-ip-of-host`

4. These step can vary depending on how you want to configure the cluster. You can setup the cluster either insecure or secure. 

    Follow the secure cluster creation steps as provider here - https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-5-generate-certificates 

## 3. Starting CockroachDB

Follow the steps describer here - https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-6-start-nodes

Below are some key things you need to do after you install cockroach binary on your local machine. 

1. Modify and run the below command on each node or EC2 instance.

        cockroach start --certs-dir=certs --advertise-addr=node 1:26257 --join=node1:26257,node2:26257,node3:26257 --cache=.25 --max-sql-memory=.25 --background

2. Initialize the cluster from your local machine. 

        cockroach init --certs-dir=certs --host=<address of any node on --join list>

3. Test if the cluster has started by running the below command.

        cockroach node status --certs-dir=certs --host=<address of any node on --join list>
    
    This should show all the nodes that are running in the cluster. If 3 then 3 nodes. 

4. You can also, go to https://public-ip-any-node:8080 - This should take you a db console. Also, to log into the db console you will need a user. Its recommended to create a new user with password, as below. 

        cockroach sql --certs-dir=certs --host=<address of any node on --join list>
        
        CREATE USER with_password WITH LOGIN PASSWORD '$tr0nGpassW0rD'

        show users;

    Since we have a self signed certificate the browser may show that its insecure.To solve this in production, you can use a separate ui.crt/ui.key that is signed by some known cert authority (Verisign or whatever) -- if you do this, the DB Console will use that key/cert pair for its TLS while the CRDB nodes will still use the node certs signed by your self-signed cert

## 4. Workload testing

We will be running the workload against the aws load balancer that we created. For this we need the Ip address or dns of the load balancer. 

For Application Load Balancers and Network Load Balancers, use the following command to find the load-balancer-id:

`aws elbv2 describe-load-balancers --names load-balancer-name`


- Initialize the tpcc workload

        cockroach workload init tpcc 'postgresql://root@my-nlb-demo-eedb484ae82f55bd.elb.us-east-1.amazonaws.com:26257/tpcc?sslmode=verify-full&sslrootcert=certs/ca.crt&sslcert=certs/client.root.crt&sslkey=certs/client.root.key'

- Run the workload against the aws load balancer

        cockroach workload run tpcc --duration=10m 'postgresql://root@my-nlb-demo-eedb484ae82f55bd.elb.us-east-1.amazonaws.com:26257/tpcc?sslmode=verify-full&sslrootcert=certs/ca.crt&sslcert=certs/client.root.crt&sslkey=certs/client.root.key'


