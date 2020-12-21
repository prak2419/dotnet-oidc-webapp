### Variables
$RGName = "ram-aks-demo4"
$AppGWRGName = "ram-appgw-rg4"
$StorageAccountName = "prak249001sac3"
$SubscriptionID = "a8e9ab67-8191-4af3-a97f-788849f3832a"
$Tags = @{"Project" = "AKS_Demo_4"}
$Location = "SouthEastAsia"
$ACRName = "prakazacr5"
$MIName = "ramaskmi4"

##$SqlServerName = "ramk8sqlsvr"
#$SqlDatabaseName = "ramk8sqldb"
#$SQLServerVnetRuleName = "Allow_AksSubnet"
#$SqlAdminCreds = Get-Credential


$AKSClusterName = "ramazaksdemod"
$AKSVersion = "1.18.8"
$AKSNodeSKU = "Standard_B2MS"
$AKSNodeCount = 2
$AKSNodePoolName = "praknp04"
$AKSNetworkPlugin = "kubenet"
$PodCIDRRange = "172.29.0.0/16"
$ServiceCIDRRange = "172.30.0.0/22"
$ServiceDNSIP = "172.30.0.10"

$VnetName = "ram-aks-demo4-vnet"
$SubnetName = "aks4-subnet"
$VMSubnetName = "vm4-subnet"
$AppGWVnetName = "appgw4-vnet"
$AppGWSubnetName = "appgw4-subnet"
$VnetIPAddressRange = "10.82.0.0/16"
$SubnetAddresRange = "10.82.2.0/24"
$VMSubnetAddressRange = "10.82.1.0/24"
$AppGwVnetIPAddressRange = "10.83.0.0/16"
$AppGWSubnetAddressRange = "10.83.240.0/27"

$PvtDNSZoneName = "fabrikam.com"
$AppGWVNetLink = "appgwlink"
$AksVnetLink = "akslink"


#$null = Set-AzContext -SubscriptionId $SubscriptionID

### Create a resource group in SEA
New-AzResourceGroup -Name $RGName -Location $Location -Tag $Tags

New-AzResourceGroup -Name $AppGWRGName -Location $Location -Tag $Tags

### Create a vnet and associated subnets
$VirtualNetwork = New-AzVirtualNetwork -Name $VnetName -ResourceGroupName $RGName -AddressPrefix $VnetIPAddressRange -Location $Location -Tag $Tags

Add-AzVirtualNetworkSubnetConfig -AddressPrefix $SubnetAddresRange -Name $SubnetName -VirtualNetwork $VirtualNetwork -ServiceEndpoint Microsoft.Sql

Add-AzVirtualNetworkSubnetConfig -AddressPrefix $VMSubnetAddressRange -Name $VMSubnetName -VirtualNetwork $VirtualNetwork

$AppGWVirtualNetwork = New-AzVirtualNetwork -Name $AppGWVnetName -ResourceGroupName $AppGWRGName -AddressPrefix $AppGWVnetIPAddressRange -Location $Location -Tag $Tags

Add-AzVirtualNetworkSubnetConfig -AddressPrefix $AppGWSubnetAddressRange -Name $AppGWSubnetName -VirtualNetwork $AppGWVirtualNetwork

$VirtualNetwork | Set-AzVirtualNetwork

$AppGWVirtualNetwork | Set-AzVirtualNetwork

Add-AzVirtualNetworkPeering -Name "aks-appgw" -VirtualNetwork $VirtualNetwork -RemoteVirtualNetworkId $AppGWVirtualNetwork.Id

Add-AzVirtualNetworkPeering -Name "appgw-aks" -VirtualNetwork $AppGWVirtualNetwork -RemoteVirtualNetworkId $VirtualNetwork.id

$Subnets = (Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VnetName).Subnets.ID

$AKSSubnet = $Subnets | where {$_ -match $SubnetName}

### Create a storage account
$StorageAccount = New-AzStorageAccount -ResourceGroupName $RGName -Name $StorageAccountName -Location $Location -SkuName Standard_ZRS -Tag $Tags

### Create a User MI
$MIObj = New-AzUserAssignedIdentity -Name $MIName -ResourceGroupName $RGName

### Create an ACR
$ACR = New-AzContainerRegistry -ResourceGroupName $RGName -Name $ACRName -Sku Standard -EnableAdminUser -Tag $Tags

New-AzRoleAssignment -Scope $acr.Id -ApplicationId $MIObj.ClientId -RoleDefinitionName acrpull

### Create an AKS Cluster
$AKS = az aks create -n $AKSClusterName -g $RGName -s Standard_B2S -c 2 --network-plugin kubenet --service-cidr $ServiceCIDRRange --dns-service-ip $ServiceDNSIP --nodepool-name $AKSNodePoolName --vnet-subnet-id $AKSSubnet --docker-bridge-address 172.17.3.1/16 -l $Location --attach-acr $ACRName --enable-managed-identity --assign-identity $MIObj.Id --generate-ssh-keys | ConvertFrom-Json

az aks get-credentials -n $AKSClusterName -g $RGName

$val = kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-basic -o jsonpath='{.spec.loadBalancerIP}'

### Create a Private DNS Zone
$PvtDNS = New-AzPrivateDnsZone -Name $PvtDNSZoneName -ResourceGroupName $AppGWRGName -Tag $Tags

New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $AppGWRGName -Name $AksVnetLink -ZoneName $PvtDNS.Name -VirtualNetworkId $VirtualNetwork.Id

New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $AppGWRGName -Name $AppGWVNetLink -ZoneName $PvtDNS.Name -VirtualNetworkId $AppGWVirtualNetwork.Id

$records = New-AzPrivateDnsRecordConfig -Ipv4Address 10.15.20.100

New-AzPrivateDnsRecordSet -Name "www" -RecordType A -ZoneName $PvtDNSZoneName -ResourceGroupName $AppGWRGName -Ttl 3600 -PrivateDnsRecord $records

### Create an application gateway

function New-AppGw {
    param(
[Parameter(Mandatory=$true)]
[string] $rgname
,[Parameter(Mandatory=$true)]
[string] $gwName
,[Parameter(Mandatory=$true)]
[string] $vnetname
,[Parameter(Mandatory=$true)]
[string] $myAGSubnetName
,[Parameter(Mandatory=$true)]
[string] $backendPoolName
,[Parameter(Mandatory=$true)]
[string] $backendFQDN
,[Parameter(Mandatory=$true)]
[string] $frontendIPconfigName
,[Parameter(Mandatory=$true)]
[string] $fePort
,[Parameter(Mandatory=$true)]
[string] $BepPort
,[Parameter(Mandatory=$true)]
[string] $BeProtocol
,[Parameter(Mandatory=$true)]
[string] $probeName
,[Parameter(Mandatory=$true)]
[string] $frontendportName
,[Parameter(Mandatory=$true)]
[string] $poolSettingsName
,[Parameter(Mandatory=$true)]
[string] $defaultlistenerName
,[Parameter(Mandatory=$true)]
[string] $frontendRuleName
,[Parameter(Mandatory=$true)]
[ValidateSet("Standard_V2", "WAF-V2")]
[string] $skuType
)

$rg = Get-AzReSourceGroup -Name $rgName

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rg.ResourceGroupName

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $myAGSubnetName -VirtualNetwork $vnet

$bep = New-AzApplicationGatewayBackendAddressPool -Name $backendPoolName -BackendFqdns $backendFQDN

$gwIpConfiguration = New-AzApplicationGatewayIPConfiguration -Name "$($gwName)_IPConfig" -SubnetId $subnet.Id

$frontendport = New-AzApplicationGatewayFrontendPort -Name $frontendportName -Port $fePort

$pip = New-AzPublicIpAddress -Name "$($gwName)_PIP" -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -Sku Standard -AllocationMethod Static -DomainNameLabel "appgwram4"

$frontendipconfig = New-AzApplicationGatewayFrontendIPConfig -Name $frontendIPconfigName -PublicIPAddressId $pip.Id

$rootCert = New-AzApplicationGatewayTrustedRootCertificate -Name "trustedroot" -CertificateFile "c:\customers\daimler\demo\aks\day-2\certs\contoso.cer"

$beSettings = New-AzApplicationGatewayBackendHttpSetting -Name AGWBEPSetting -Port $BepPort -Protocol $BeProtocol -CookieBasedAffinity Enabled -RequestTimeout 30 -TrustedRootCertificate $rootCert -HostName "www.fabrikam.com"

$pwd = ConvertTo-SecureString `
  -String "test1234" `
  -Force `
  -AsPlainText

$cert = New-AzApplicationGatewaySslCertificate -Name "sslcert1" -CertificateFile "c:\customers\daimler\demo\aks\day-2\certs\fabrikam.pfx" -Password $pwd

$httplistener = New-AzApplicationGatewayHttpListener -Name $defaultlistenerName -FrontendIPConfigurationId $frontendipconfig.Id -FrontendPortId $frontendport.Id -Protocol $BeProtocol -HostName $pip.DnsSettings.Fqdn -SslCertificateId $cert.Id

$gatewayRule = New-AzApplicationGatewayRequestRoutingRule -Name $frontendRuleName -RuleType Basic -BackendHttpSettingsId $beSettings.id -HttpListenerId $httplistener.id -BackendAddressPoolId $bep.Id

$sku = New-AzApplicationGatewaySku -Name $skuType -Tier $skuType

$autoscalesettings = New-AzApplicationGatewayAutoscaleConfiguration -MinCapacity 2 -MaxCapacity 4

#$probesettings = New-AzApplicationGatewayProbeConfig -Name $probeName -Protocol Http -HostName "contoso.com" -Path "/path/custompath.htm" -Interval 30 -Timeout 120 -UnhealthyThreshold 8

$agw = New-AzApplicationGateway -Name $gwName -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -Sku $sku -GatewayIPConfigurations $gwIpConfiguration -FrontendIPConfigurations $frontendipconfig -FrontendPorts $frontendport -BackendAddressPools $bep -HttpListeners $httplistener -RequestRoutingRules $gatewayRule -BackendHttpSettingsCollection $beSettings -AutoscaleConfiguration $autoscalesettings -Tag $tags -TrustedRootCertificate $rootCert -SslCertificates $cert

}

New-AppGw -rgname $AppGWRGName -vnetname $AppGWVnetName -myAGSubnetName $AppGWSubnetName -backendPoolName "mybep" -backendFQDN "www.fabrikam.com" -frontendIPconfigName "appgwfip" -gwName "demoramgw" -fePort 443 -BepPort 443 -BeProtocol Https -frontendportName "gwfeport" -poolSettingsName "httpsettings" -defaultlistenerName "httpslistener" -frontendRuleName "ferule1" -skuType Standard_V2 -probe "natest"
