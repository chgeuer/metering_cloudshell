# metering_cloudshell

Walkthrough video here: https://www.youtube.com/watch?v=2vKbkPnW6Rg

This repository contains a mechanism to emit one-time charges against an Azure Marketplace managed application, running in the customer tenant, **from the ISV tenant**. There is no need to have a compute resource (like a virtual machine) running in the customer subscription.

The ISV user running the scripts must be an Owner on the managed apps, i.e. be listed in the managed app's marketplace configuration, or member of a group which is authorized to manage the managed app.

## Install the solution

1. Sign-in to https://shell.azure.com/, and open a `bash` session (**not** Powershell)
2. `git clone https://github.com/chgeuer/metering_cloudshell`
3. Setup the ISV side
   - `./metering_cloudshell/0-isv-setup.sh`
   - `./metering_cloudshell/0-add-defaults.sh`
   - Edit the `clouddrive/metering-data/config.json` if you like to change the defaults
   - `./metering_cloudshell/0-isv-setup.sh`

## Submit usage

1. List the current customers `./metering_cloudshell/1-list-customers.sh`
2. Connect to a customer deployment: `./metering_cloudshell/1-connect-customer-deployment.sh <<subscription-id-from-previous-step>> <<managed-resource-group-name-from-previous-step>>`
3. Submit the usage you want to emit: `./metering_cloudshell/2-emit-meter.sh <<subscription-id-from-previous-step>> <<managed-resource-group-name-from-previous-step>> hour-delta dimension amount`


> If you get warnings like `Warning BCP081: Resource type "..." does not have types available.`, ignore them.


The ISV resource group with the KeyVault containing the issuance key for workload identity federation, as well as the storage account containing the IdP metadata



![image-20230202225144003](pictures/image-20230202225144003.png)

https://k53rhogdavblgg.blob.core.windows.net/public/jwks_uri/keys

The token signing key in KeyVault

![image-20230202225351235](pictures/image-20230202225351235.png)



## The customer side

![image-20230202225554925](pictures/image-20230202225554925.png)

![image-20230202225640362](pictures/image-20230202225640362.png)



