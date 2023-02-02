# metering_cloudshell

This repository contains a mechanism to emit one-time charges against an Azure Marketplace managed application, running in the customer tenant, **from the ISV tenant**. There is no need to have a compute resource (like a virtual machine) running in the customer subscription.

The ISV user running the scripts must be an Owner on the managed apps, i.e. be listed in the managed app's marketplace configuration, or member of a group which is authorized to manage the managed app.

## Install the solution

1. Sign-in to https://shell.azure.com/, and open a `bash` session (**not** Powershell)

2. run `git clone https://github.com/chgeuer/metering_cloudshell`

   



 



The ISV resource group with the KeyVault containing the issuance key for workload identity federation, as well as the storage account containing the IdP metadata



![image-20230202225144003](pictures/image-20230202225144003.png)

https://k53rhogdavblgg.blob.core.windows.net/public/jwks_uri/keys

The token signing key in KeyVault

![image-20230202225351235](pictures/image-20230202225351235.png)



## The customer side

![image-20230202225554925](pictures/image-20230202225554925.png)

![image-20230202225640362](pictures/image-20230202225640362.png)



