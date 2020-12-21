# dotnet-oidc-webapp
Simple OpenID Connect test application

## Pre-requisites

1.	App Gateway VNET peered with AKS VNET
2.	A user assigned managed identity with contributor role on the AKS cluster resource group. The least permission would be “Network Contributor” but needs further testing to confirm.
3.	SP with reply URL as below and "id_token" enabled,  
    a. `https://<appGWFQDN>`  
    b. `https://<appGWFQDN>/signin-oidc/`  
 
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

### Generate self-signed root and server certificates or use the certificates available in the certs folder.

    https://docs.microsoft.com/en-us/azure/application-gateway/self-signed-certificates

   Create a PFX certificate to use for the backend servers

    openssl pkcs12 -export -out .\certs\fabrikam.pfx -in .\certs\fabrikam.crt -inkey .\certs\fabrikam.key -certfile .\certs\contoso_original.crt

### Deploy the network, ACR, MI, AKS, Private DNS Zone using the powershell script ```Deploy-AksAadApp.ps1```.

### Authenticate to the AKS cluster,

    az aks get-credentials -n <aks_cluster_name> -g <aks_cluster_RG>
    
### Deploy a private ingress controller in a namespace "ingress-basic"

   #### > Create a namespace for ingress controller
   
         kubectl create namespace ingress-basic

   #### > Create a file ingress_internal.yaml with the below specs
    
            controller:
              service:
                loadBalancerIP: 10.58.1.70 #IP address from the subnet
                annotations:
                  service.beta.kubernetes.io/azure-load-balancer-internal: "true"
          
   #### > Deploy the helm repo for ```nginx``` ingress controller
        
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
 
        helm install nginx-ingress ingress-nginx/ingress-nginx \
             --namespace ingress-basic \
             -f ingress_internal.yaml \
             --set controller.replicaCount=2 \
             --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
             --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
 
### Create a namespace for the application
 
    kubectl create ns dotnetapp
 
### Create a secret with the self-signed cert
 
    kubectl create secret tls fabrikam-tls --key fabrikam.key --cert fabrikam.crt -n dotnetapp
 
### Deploy the application after modifying the parameters in the app.yaml file

   AzureAd__Domain: <YOUR-AAD-DOMAIN>  
   AzureAd__TenantId: <YOUR-AAD-TENANT-ID>  
   AzureAd__ClientId: <YOUR-AAD-CLIENT-ID>  

    kubectl apply -f app.yaml -n dotnetapp
    
### Change the IP address of the A record created for ```www.fabrikam.com``` with nginx ingress controller external IP.

    kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-basic -o jsonpath='{.spec.loadBalancerIP}'
    
### Create a rewrite rule in the app gateway to rewrite the header ```Location```

   1. Condition
    
        ```(.*)redirect_uri=https%3A%2F%2Fwww.fabrikam\.com(.*)$```
        
     
   2. Action
    
        ```{http_resp_Location_1}redirect_uri=https%3A%2F%2F<GW_FQDN>{http_resp_Location_2}```


