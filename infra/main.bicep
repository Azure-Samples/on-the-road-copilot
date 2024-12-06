targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string
@description('Location for OpenAI resources (if empty uses primary location)')
param aiResourceLocation string
@description('Principal Id of the local user to assign application roles. Leave empty to skip.')
param principalId string
@description('Id of the user or app to assign application roles')
param resourceGroupName string = ''
param openaiName string = ''
param cosmosDbAccountName string = ''
param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param communicationServiceName string = ''
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName, 'app': 'audio-agents', 'tracing': 'yes' }

param logAnalyticsName string = ''
param applicationInsightsName string = ''
param cosmosDatabaseName string = 'mobile'
param cosmosContainerName string = 'reports'
param completionDeploymentModelName string = 'gpt-4o-realtime-preview'
param completionModelName string = 'gpt-4o-realtime-preview'
param completionModelVersion string = '2024-10-01'
param openaiApiVersion string = '2024-10-01-preview'
param modelDeployments array = [
  {
    name: completionDeploymentModelName
    skuName: 'GlobalStandard'
    capacity: 1
    model: {
      format: 'OpenAI'      
      name: completionModelName
      version: completionModelVersion
    }
  }
]

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Container apps host (including container registry)
module containerApps './core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}api-agents'
  }
}

module openai './ai/openai.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    location: !empty(aiResourceLocation) ? aiResourceLocation : location
    tags: tags
    customDomainName: !empty(openaiName) ? openaiName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    name: !empty(openaiName) ? openaiName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    deployments: modelDeployments
  }
}

module cosmodDb './core/data/cosmosdb.bicep' = {
  name: 'sql'
  scope: resourceGroup
  params: {
    location: location
    accountName: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbrs.cosmosDbAccount}${resourceToken}'
    databaseName: cosmosDatabaseName
    containerName: cosmosContainerName
    tags: tags
  }
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

module security 'core/security/security-main.bicep' = {
  name: 'security'
  scope: resourceGroup
  params: {
    openaiName: openai.outputs.openaiName
    containerRegistryName: containerApps.outputs.registryName
    databaseAccountName: cosmodDb.outputs.name
    principalIds: [
      containerApps.outputs.identityPrincipalId
      principalId
    ]
  }
}

module acs 'acs/acs.bicep' = {
  name: 'acs'
  scope: resourceGroup
  params: {
    name: !empty(communicationServiceName) ? communicationServiceName : '${abbrs.communicationService}${resourceToken}'
    location: 'global'
    tags: tags
  }
}

output AZURE_LOCATION string = location
output AZURE_AI_SERVICE_LOCATION string = openai.outputs.location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name
output OPENAI_API_TYPE string = 'azure'
output AZURE_OPENAI_VERSION string = openaiApiVersion
output AZURE_OPENAI_API_KEY string = openai.outputs.openaiKey
output AZURE_OPENAI_ENDPOINT string = openai.outputs.openaiEndpoint
output AZURE_OPENAI_COMPLETION_MODEL string = completionModelName
output AZURE_OPENAI_COMPLETION_DEPLOYMENT_NAME string = completionDeploymentModelName
output COSMOSDB_ACCOUNT_ENDPOINT string = cosmodDb.outputs.endpoint
output COSMOSDB_ACCOUNT_KEY string = cosmodDb.outputs.key
output COSMOSDB_DATABASE_NAME string = cosmosDatabaseName
output COSMOSDB_CONTAINER_NAME string = cosmosContainerName
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output PRINCIPAL_ID string = principalId
output ACS_CONNECTION_STRING string = acs.outputs.communicationConnectionString
output ACS_CALLBACK_PATH string = 'localhost:8000'
