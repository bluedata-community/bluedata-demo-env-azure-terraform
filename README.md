# How to setup HPE Container Platform demo environment on Azure with Terraform

This aims to create a minimal demo environment in Microsoft Azure to run HPE Container Platform (EPIC 5.0) installation.
Please check bluedata4 branch for EPIC v4 installation.

Taken from the work of https://github.com/bluedata-community/bluedata-demo-env-aws-terraform

Run terraform to deploy resources in Azure, and then ssh to controller & run `bluek8s_install.sh` script to continue with the installation.

Similar process should be followed as explained in aws template;
- `git clone https://github.hpe.com/erdinc-kaya/bluedata-demo-env-azure-terraform && cd bluedata-demo-env-azure-terraform`
- `terraform init`
- `cp cloud-init-ctr.yaml.template cloud-init-ctr.yaml`
- `cp cloud-init.yaml.template cloud-init.yaml`
- Edit cloud-init*.yaml files
  - Paste your ssh private key so you can use for initial paswordless login (this will be removed as part of setup script later on)
  - Paste your ssh public key signature to be able to connect to controller & gateway from your machine
  - Paste your bluedata install file url
  - change default username and folders if you wish
- Edit terraform.tfvars file to add your Azure subscription details (detailed steps below)

After successful deployment of Azure resources, you can manually update NSG settings to secure access to nodes (only controller and gateway have public IP addresses but all ports are exposed by default).
Once connected with bluedata user (default user by cloud-init, you can choose your own), run installation script to prepare nodes & setup EPIC in controller. 

## Before start, you should setup your Azure subscription & crendetials following these steps:

Query subscription ID

`az account list --query "[].{name:name, subscriptionId:id, tenantId:tenantId}"`

Set environment variable to the subscription you want to use (following line works with a single subscription only)

`SUBSCRIPTION_ID=az account list --query "[].{sub:id}" -o tsv`

Set subscription to use

`az account set --subscription="${SUBSCRIPTION_ID}"`

Create a service principle to be used for this deployment

`az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}"`

The output should be used to fill in provider details in terraform.tfvars
Save appId, password, sp_name & tenant from response


<pre>
AppId                                 DisplayName                    Name                                  Password                              Tenant
------------------------------------  -----------------------------  ------------------------------------  ------------------------------------  ------------------------------------
3dbee582-0000-0000-0000-06e44d93dd63  azure-cli-2019-12-10-07-12-40  http://azure-cli-2019-12-10-07-12-40  bf3f0384-0000-0000-0000-6c39aecaaa21  105b2061-0000-0000-0000-24d304d195dc
</pre>

## TODO:

- Use variables/templates inside cloud-init files to replace username/IP addresses and paths
- Add AzureAD and NFS server options
- Disable firewall ports except for gateway (https) and controller (ssh)
- Enable adding worker nodes
