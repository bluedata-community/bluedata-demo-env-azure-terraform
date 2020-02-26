# How to setup BlueData demo environment on Azure with Terraform

This aims to create a minimal demo environment in Microsoft Azure to run HPE Container Platform EPIC 5.0 installation.
Please check bluedata4 branch for EPIC v4 installation.

Taken from the work of https://github.com/bluedata-community/bluedata-demo-env-aws-terraform

Run terraform to deploy resources in Azure, and then ssh to controller & run `bluedata_install.sh` script to continue with the installation.


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
