# CockroachDB : Single-Region on AWS

This repo provides you with the ability to launch a single-region(topology) CockroachDB(Self-hosted) cluster on AWS using terraform. 

We are going to use the following tools to launch this cluster.

- [CockroachDB](https://www.cockroachlabs.com/docs/stable/frequently-asked-questions.html#what-is-cockroachdb) - Scalable & Resilient Distributed SQL Database that can survive anything.
- [AWS Cloud](https://aws.amazon.com/) -  Cloud Infrastucture to host a single region of CRDB
- [Terraform](https://www.terraform.io/intro) - To automate infrasturture build on AWS
- [PSSH](https://linux.die.net/man/1/pssh) - Parallel SSH tool to install and setup cockroachDB on AWS EC2 Instance
- [AWS Client VPN](https://aws.amazon.com/vpn/client-vpn/) - create a secure remote access to AWS Cloud from client machines

# Deployment Modes 
- You can choose to start cockroachDB in [secure](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws) or [insecure](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws-insecure) mode. 
- You can choose to run this out over the internet gateways or via VPN tunnel using AWS Client VPN. 

# Secure Cluster Topology

 We recommend using the AWS VPN Client and using the secure mode to add extra layers of security as you connect from your local system. The below architecture is for a single-region secure CRDB cluster that the repo will help you build.

![Topology](Single-Region-AWS.drawio.png)

As per above architecture, we create 3 EC2 Instances, 1 VPC, 3 Subnets, 1 Network Load Balancer and AWS Client VPN for secure remote machine connection.

Note: Change variables as needed in `variables.tf`

# Housekeeping : 
- Last Updated on 03/10/2022
- Terraform version : 1.3.1

# Pre-requsites:

The following pre-reqs need to be setup in advance for using this repo: 

- [Install Terraform](https://www.terraform.io/downloads) on local machine
- [Install and configure](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) AWS CLI properly on local machine 
- [Create a SSH key-pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html), so the launched AWS EC2 instances can be connected through SSH.
- [Install PSSH]( https://formulae.brew.sh/formula/pssh) on local system
- [Install AWS Client VPN](https://aws.amazon.com/vpn/client-vpn-download/) for Desktop on local machine

# Terraform Intro

Terraform enables users to plan, create, and manage infrastructure as code. There are various providers available to cloud providers such as AWS,GCP, Azure and more. These providers provide methods that terraform users to provision and manage infrastructure. 


## Essential Terraform Commands

- `terraform init` - initialize terraform script
- `terraform fmt` - format the terraform configuration files
- `terraform validate` - validate the terraform configuration
- `terraform apply` - create infrastructure from the configuration
- `terraform show` - inspect build
- `terraform destroy` - destroy the infrastructure 
- `terraform apply -var 'instance_name=yetanothername'` - change variables from command line

# Deploying a CockroachDB Single Region Cluster 

This is divided into 5 parts
- Infrastucture build using terraform
- Setting up a VPN Tunnel for secure remote access
- Installing and setting up CockroachDB
- Starting CockroachDB
- Workload Testing

Read the below documentation for detailed understanding. 
https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html

## 1. Infrastucture Build

`main.tf` and `variables.tf` are the 2 essential files from this repo that will create the infrastructure. Check `main.tf` were  we create the resources to support this install. The below resources are created.

- [EC2 Instance](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-1-create-instances) 
- VPC 
- Subnets
- Internet gateway 
- Route tables
- [Security groups](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-2-configure-your-network)
- [Load Balancers](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-4-set-up-load-balancing) & Target groups

### Build steps

1. To check the terraform build plan, run the following command.

        terraform plan

2. To build the infrastructure, run the following command.

        terraform apply

2. Run the below to get public IP address for EC2 Instances that were just created by terraform. We will need these ip address in next steps.

        terraform output              

3. Go to `AWS Cloud Console` and verify all the infrastructure is build as expected. 

## 2. Setting up a VPN Tunnel for secure remote access
<br />
Note : `This step is only needed if you want to create a VPN Tunnel for secure access, if you do not want to then can continue with connecting through the Internet Gateway. The architecture for the same will look like below.`

<br />

 ![Topology](Single-Region-AWS.png)

<br />

###  Follow the [Detailed steps here ](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html) for AWS Client VPN Conncetion. The high level steps are as below for your understanding:


1. Generate server and client certificates and keys - [Detailed steps here](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-authentication.html#mutual)
2. Create a Client VPN endpoint, assocaite the target network you created in terraform and associate subnets.
3. Verify that your default security group and terraform created security groups are added.
4. Add Authorization rule for VPC
5. Download Client VPN end point configuration and setup a profile in client VPN.
5. Connect via the client VPN end point from local. 
6. Test connection by connecting via the internal IP for any EC2 Instance. 

## 2. Installing and setting up CockroachDB.

1. Go to `pssh_hosts_files.txt` and add Internal `host-ip-address` if connecting via AWS Client VPN as per your build that just completed. If connecting via internet gateway then add External `host-ip-address`.
2. Run the `setup.sh` script for AWS Time Sync Service and for installing CockroachDB. 

        `pssh -i -h pssh_hosts_files.txt -x "-oStrictHostKeyChecking=no -i add-your-key" -I < setup.sh`

3. Log into each node and test if setup ran as expected 

        `ssh -i add-ec2-key ec2-user@public-ip-of-host`

4. These step can vary depending on how you want to configure the cluster. You can setup the cluster either insecure or secure. Follow the [secure](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-5-generate-certificates 
) cluster creation steps. 

## 3. Starting CockroachDB

Follow the steps described [here](https://www.cockroachlabs.com/docs/v22.1/deploy-cockroachdb-on-aws.html#step-6-start-nodes). Below are some key things you need to do after you install cockroach binary on your local machine. 

`Note : if AWS VPN Client is used then add internal IPs, for connection through internet gateway use external IPs`

1. Modify and run the below command on `each node` of EC2 instance.

        cockroach start --certs-dir=certs --advertise-addr=node 1:26257 --join=node1:26257,node2:26257,node3:26257 --cache=.25 --max-sql-memory=.25 --background
2. Initialize the cluster from `your local machine`. 

        cockroach init --certs-dir=certs --host=<internal ip address of any node on --join list>

3. Test if the cluster has started by running the below command from local machine

        cockroach node status --certs-dir=certs --host=<internal address of any node on --join list>
    
    This should show all the nodes that are running in the cluster. If 3 then 3 nodes. 

4. You can also, go to https://ip-any-node:8080 - This should take you a db console. Also, to log into the db console you will need a user. Its recommended to create a new user with password, as below. 

         
        (In Local) 
        cockroach sql --certs-dir=certs --host=<address of any node on --join list>
        
      
        (In SQL) 
        CREATE USER with_password WITH LOGIN PASSWORD 'add_password';

        show users;

    Note : Since we have a self signed certificate the browser may show that its insecure connection .To solve this in production, you can use a separate ui.crt/ui.key that is signed by some known cert authority (Verisign or whatever) -- if you do this, the DB Console will use that key/cert pair for its TLS while the CRDB nodes will still use the node certs signed by your self-signed cert.

## 4. Workload testing

We will be running the workload against the aws load balancer that we created. For this we need the IP address or DNS of the load balancer. 

- For Application Load Balancers and Network Load Balancers, use the following command to find the load-balancer-id and DNS, alternatively you can get this info from details in console for load balancer:

        aws elbv2 describe-load-balancers --names load-balancer-name


- Initialize the tpcc workload

        cockroach workload init tpcc 'postgresql://root@ip-or-dns-name-of-network-load-balancer:26257/tpcc?sslmode=verify-full&sslrootcert=certs/ca.crt&sslcert=certs/client.root.crt&sslkey=certs/client.root.key'

- Run the workload against the aws load balancer

        cockroach workload run tpcc --duration=10m 'postgresql://root@ip-or-dns-name-of-network-load-balancer:26257/tpcc?sslmode=verify-full&sslrootcert=certs/ca.crt&sslcert=certs/client.root.crt&sslkey=certs/client.root.key'

<br />

You should now have a `running cluster` with test workload flowing into the DB. Go try some other things on this running cluster using these [tutorials/features](https://www.cockroachlabs.com/docs/stable/demo-replication-and-rebalancing.html) and have fun.

----


