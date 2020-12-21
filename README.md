# dotnet-oidc-webapp
Simple OpenID Connect test application

## Pre-requisites

1.	App Gateway VNET peered with AKS VNET
2.	A user assigned managed identity with contributor role on the AKS cluster resource group. The least permission would be “Network Contributor” but needs further testing to confirm.
3.	SP with reply URL as below and "id_token" enabled,
    a.	https://<appGWFQDN>
    b.	https://<appGWFQDN>/signin-oidc/
 
4.	Self-signed root certificate and server certificate (Root- ```www.contoso.com```, server - ```www.fabrikam.com```)

## Steps to implement

### Deploy the code as a container to ACR from a local machine (Linux, preferably) with git and az CLI,

1.	Clone the code locally,

```git clone https://github.com/joergjo/dotnet-oidc-webapp.git```

2.	Login to azure account with the context of the subscription in which ACR resides,

```az login```

```az account set -s <SUB_ID>```

3.	Modify the acr-build.sh file

```
#!/bin/bash
version=${1:-3.1}
repo=dotnet-samples/openidconnect
az acr login -n <YOUR_ACR> -g <YOUR_ACR_RG>
az acr build --registry <YOUR_ACR> -t ${repo}:latest -t ${repo}:${version}-{{.Run.ID}} -f ./src/OpenIdConnect.WebApp/Dockerfile .
```

4.	Change the permissions of the file to execute,

```chmod +x acr-build.sh```

5.	Execute the script,

```./acr-build.sh```


