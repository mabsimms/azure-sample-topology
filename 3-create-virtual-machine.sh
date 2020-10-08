#!/bin/bash

source ./demo-vars.sh

# Let the platform do some magic and create the enclosed resources
# (NICs and disks) for us.  Better to be explicit when doing this
# for "real".
az vm create --name $VM_NAME --resource-group $RESOURCE_GROUP \
    --enable-agent true \
    --image $VM_IMAGE \
    --location $LOCATION_PRIMARY \
    --patch-mode manual \
    --size $VM_SIZE \
    --authentication-type ssh \
     --ssh-key-values id_rsa.pub \
    --accelerated-networking \
    --private-ip-address $VM_IP     
