#!/bin/bash

source ./demo-vars.sh

# Create a static IP address reservation (if this IP address is ever 
# going to show up in any allow-list, create and reserve)
az network public-ip create --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --location $LOCATION_PRIMARY \
    --allocation-method Static \
    --dns-name mascontent \
    --idle-timeout 5 \
    --sku Standard 

PIP_ID=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query id -o tsv)
# Let's put a lock on this resource to protect against accidental deletion
az lock create --name ${PUBLIC_IP_NAME}-lock \
    --resource-group $RESOURCE_GROUP \
    --resource-name $PUBLIC_IP_NAME \
    --resource-type "Microsoft.Network/publicIPAddresses" \
    --notes "IP address reservation - do not delete" \
    --lock-type CanNotDelete

# Create a load balancer to expose this scale set to the internet
az network lb create --name $VMSS_LB_NAME \
    --resource-group $RESOURCE_GROUP \
    --backend-pool-name frontend \
    --location $LOCATION_PRIMARY \
    --sku Standard \
    --public-ip-address $PUBLIC_IP_NAME

    # Ok, that's just awesome.  Bug in the resource graph consistency logic and the associated
    # parsing
    # --public-ip-address $PIP_ID

VMSS_LB_ID=$(az network lb show --name $VMSS_LB_NAME --resource-group $RESOURCE_GROUP | jq -r .id)

# Create a VM scale set to host a simple static content web server
az vmss create --name $VMSS_CONTENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --computer-name-prefix $VMSS_CONTENT_NAME_PREFIX \
    --custom-data vmss-content.txt \
    --image $VMSS_IMAGE \
    --instance-count $VMSS_CONTENT_INSTANCE_COUNT \
    --location $LOCATION_PRIMARY \
    --orchestration-mode ScaleSetVM \
    --platform-fault-domain-count 5 \
    --scale-in-policy NewestVM \
    --vm-sku $VMSS_SIZE \
    --authentication-type ssh \
    --ssh-key-values id_rsa.pub \
    --accelerated-networking true \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_PRIMARY_NAME \
    --public-ip-address "" \
    --lb $VMSS_LB_ID 

   
# Since this is an exploration, let's do horribly insecure and inappropriate things
VM_IP_ADDRESS=$(az network public-ip show --resource-group $RESOURCE_GROUP --name solovmPublicIP | jq -r .ipAddress)
scp $HOME:/.ssh/id_rsa $VM_IP_ADDRESS:/home/masimms/.ssh/id_rsa


# But wait.. why aren't my cloud-init scripts working correctly?
ssh $VM_IP_ADDRESS
ssh 10.0.1.6

cat /var/log/cloud-init-output.log

# Whoops, we didn't create any path to the internet from the LB address pool 
# used by that VMSS, and we forgot to give an explicit name to the front end 
# configuration.  magic again.
az network lb outbound-rule create \
    --name internet-access \
    --address-pool frontend \
    --lb-name $VMSS_LB_NAME \
    --protocol All \
    --resource-group $RESOURCE_GROUP \
    --frontend-ip LoadBalancerFrontEnd

# Cloud init only runs on initial provisioning.  To re-trigger we'll reimage all of the 
# instances
az vmss reimage --resource-group $RESOURCE_GROUP \
    --name $VMSS_CONTENT_NAME \

# Wait, we also didn't create a route for the web servers in the content VMSS to
# receive traffic
VMSS_IP_ADDRESS=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME | jq -r .ipAddress)
curl http://$VMSS_IP_ADDRESS/ -v

# Set up a route for inbound http traffic, starting with the probe
# In a production system it is crucial that this probe accurately represent
# the ability of this instance/node to accept work. This requires that:
# - The probe endpoint capture the ability to accept work, including the transitive closure of dependencies
# - Not directly interrogate the transitive closure for dependencies (otherwise this is a DoS vector)
# - Have an interval/threshold appropriate for the error budget of the service
az network lb probe create --name content-probe \
    --resource-group $RESOURCE_GROUP \
    --lb-name $VMSS_LB_NAME --port 80 --protocol Http \
    --interval 15 \
    --threshold 3 \
    --path /

az network lb rule create --resource-group $RESOURCE_GROUP \
    --lb-name $VMSS_LB_NAME \
    --name HttpTrafficAllow \
    --protocol Tcp \
    --frontend-ip-name LoadBalancerFrontEnd --frontend-port 80 \
    --backend-pool-name frontend --backend-port 80 \
    --disable-outbound-snat true \
    --probe-name content-probe

az network lb rule delete  --resource-group $RESOURCE_GROUP \
    --lb-name $VMSS_LB_NAME 

# What, no connectivity, but my health probes show as awesomez?
# Oh, right.  I didn't explicitly allow traffic from the front 
# end to the VM instances.  
az network nsg create --resource-group $RESOURCE_GROUP \
    --name vmss-nsg

az network nsg rule create --resource-group $RESOURCE_GROUP \
    --nsg-name vmss-nsg \
    --name AllowHttpTraffic \
    --protocol '*' \
    --direction inbound \
    --source-address-prefix '*' \
    --source-port-range '*' \
    --destination-address-prefix '*' \
    --destination-port-range 80 \
    --access allow \
    --priority 200

# Now we need to update the VMSS' nsg settings per the nsg property path
# and reimage the nodes
az vmss show --name $VMSS_CONTENT_NAME --resource-group $RESOURCE_GROUP
NSG_ID=$(az network nsg show --name vmss-nsg --resource-group $RESOURCE_GROUP | jq -r .id)

az vmss update --name $VMSS_CONTENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --set virtualMachineProfile.networkProfile.networkSecurityGroup.id=${NSG_ID}

az vmss reimage --resource-group $RESOURCE_GROUP --name $VMSS_CONTENT_NAME

# Or we could simply rebuild the VMSS
az vmss delete --name $VMSS_CONTENT_NAME --resource-group $RESOURCE_GROUP

# Create a VM scale set to host a simple static content web server
az vmss create --name $VMSS_CONTENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --computer-name-prefix $VMSS_CONTENT_NAME_PREFIX \
    --custom-data vmss-content.txt \
    --image $VMSS_IMAGE \
    --instance-count $VMSS_CONTENT_INSTANCE_COUNT \
    --location $LOCATION_PRIMARY \
    --orchestration-mode ScaleSetVM \
    --platform-fault-domain-count 5 \
    --scale-in-policy NewestVM \
    --vm-sku $VMSS_SIZE \
    --authentication-type ssh \
    --ssh-key-values id_rsa.pub \
    --accelerated-networking true \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_PRIMARY_NAME \
    --public-ip-address "" \
    --lb $VMSS_LB_ID \
    --nsg vmss-nsg
