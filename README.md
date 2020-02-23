## How to setup BlueData demo environment on Azure with Terraform

This aims to create a minimal demo environment in Microsoft Azure to run BlueData 4.0 installation.

Taken from the work of https://github.com/bluedata-community/bluedata-demo-env-aws-terraform

Run terraform to deploy resources in Azure, and then ssh to controller & run "bluedata_install.sh" script to continue with the installation.


Before start, you should setup your Azure subscription & crendetials following these steps:

Query subscription ID
[code] az account list --query "[].{name:name, subscriptionId:id, tenantId:tenantId}" [/code]

Set environment variable to the subscription you want to use (following line works with a single subscription only)
[code] SUBSCRIPTION_ID=`az account list --query "[].{sub:id}" -o tsv` [/code]

Set subscription to use
[code] az account set --subscription="${SUBSCRIPTION_ID}" [/code]

Create a service principle to be used for this deployment
[code] az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" [/code]

The output should be used to fill in provider details in terraform.tfvars
Save appId, password, sp_name & tenant from response

[code]

AppId                                 DisplayName                    Name                                  Password                              Tenant
------------------------------------  -----------------------------  ------------------------------------  ------------------------------------  ------------------------------------
3dbee582-0000-0000-0000-06e44d93dd63  azure-cli-2019-12-10-07-12-40  http://azure-cli-2019-12-10-07-12-40  bf3f0384-0000-0000-0000-6c39aecaaa21  105b2061-0000-0000-0000-24d304d195dc

[/code]

TODO:

Disable firewall ports except for gateway (https) and controller (ssh)

