#!/bin/bash

set -e

SERVICE_NAME="$1"

if [ "$SERVICE_NAME" == "" ]; then
echo "No phase name provided - aborting"
exit 0;
fi

AZURE_ENV_NAME="$2"

SOURCENUMBER="$3"

if [ "$AZURE_ENV_NAME" == "" ]; then
echo "No environment name provided - aborting"
exit 0;
fi

if [[ $SERVICE_NAME =~ ^[a-z0-9]{3,12}$ ]]; then
    echo "service name $SERVICE_NAME is valid"
else
    echo "service name $SERVICE_NAME is invalid - only numbers and lower case min 5 and max 12 characters allowed - aborting"
    exit 0;
fi

RESOURCE_GROUP="rg-$AZURE_ENV_NAME"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    echo "resource group $RESOURCE_GROUP does not exist"
    error=1
else   
    echo "resource group $RESOURCE_GROUP already exists"
    LOCATION=$(az group show -n $RESOURCE_GROUP --query location -o tsv)
fi

APPINSIGHTS_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.Insights/components" --query "[0].name" -o tsv)
AZURE_CONTAINER_REGISTRY_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.ContainerRegistry/registries" --query "[0].name" -o tsv)
OPENAI_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.CognitiveServices/accounts" --query "[0].name" -o tsv)
ENVIRONMENT_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.App/managedEnvironments" --query "[0].name" -o tsv)
IDENTITY_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.ManagedIdentity/userAssignedIdentities" --query "[0].name" -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
COSMOSDB_NAME=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.DocumentDB/databaseAccounts" --query "[0].name" -o tsv)

echo "container registry name: $AZURE_CONTAINER_REGISTRY_NAME"
echo "application insights name: $APPINSIGHTS_NAME"
echo "openai name: $OPENAI_NAME"
echo "cosmosdb name: $COSMOSDB_NAME"
echo "identity name: $IDENTITY_NAME"
echo "service name: $SERVICE_NAME"

CONTAINER_APP_EXISTS=$(az resource list -g $RESOURCE_GROUP --resource-type "Microsoft.App/containerApps" --query "[?contains(name, '$SERVICE_NAME')].id" -o tsv)
EXISTS="false"

if [ "$CONTAINER_APP_EXISTS" == "" ]; then
    echo "container app $SERVICE_NAME does not exist"
else
    echo "container app $SERVICE_NAME already exists"
    EXISTS="true"
fi

IMAGE_TAG=$(date '+%m%d%H%M%S')

az acr build --subscription ${AZURE_SUBSCRIPTION_ID} --registry ${AZURE_CONTAINER_REGISTRY_NAME} --image $SERVICE_NAME:$IMAGE_TAG ./src/$SERVICE_NAME
IMAGE_NAME="${AZURE_CONTAINER_REGISTRY_NAME}.azurecr.io/$SERVICE_NAME:$IMAGE_TAG"

echo "deploying image: $IMAGE_NAME"

ACA_NAME=roadcopilot$SERVICE_NAME

URI=$(az deployment group create -g $RESOURCE_GROUP -f ./infra/core/app/web.bicep \
          -p name=$ACA_NAME -p location=$LOCATION -p containerAppsEnvironmentName=$ENVIRONMENT_NAME \
          -p containerRegistryName=$AZURE_CONTAINER_REGISTRY_NAME -p applicationInsightsName=$APPINSIGHTS_NAME -p serviceName=$SERVICE_NAME -p acssourceNumber=$SOURCENUMBER \
          -p openaiName=$OPENAI_NAME -p identityName=$IDENTITY_NAME -p imageName=$IMAGE_NAME -p databaseAccountName=$COSMOSDB_NAME --query properties.outputs.uri.value)

echo "deployment uri: $URI"