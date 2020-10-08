#!/bin/bash

source ./demo-vars.sh

# Create a resource group to host an associated set of resources.  
# As resource group metadata has its primary (mutable) storage in a 
# single region co-locate resource groups and resources where possible
az group create --name $RESOURCE_GROUP --location $LOCATION_PRIMARY

# Does this resource group exist?
az group show --name $RESOURCE_GROUP

# Wait - doing this requires hammer polling on the Azure control plane.
# For large subscriptions and deployments this is inefficient.  Let's
# query the materialized inventory from Azure Resource Graph instead

# Add the Resource Graph extension to the Azure CLI environment
az extension add --name resource-graph

# Let's look at this resource group from the graph
az graph query -q "ResourceContainers | where name has '$RESOURCE_GROUP' | limit 5"

# Let's add a tag to this resource
az group update --name $RESOURCE_GROUP --tags "Context=Exploration"

# Resource Graph is very powerful, but not immediately consistent
az graph query -q "ResourceContainers | where name has '$RESOURCE_GROUP' | limit 5"
az group show --name $RESOURCE_GROUP