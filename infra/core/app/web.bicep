param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param applicationInsightsName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'web'
param imageName string
param openaiName string
param databaseAccountName string
param acsconnectionName string = ''
param acssourceNumber string = ''

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource app 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${userIdentity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: userIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: imageName
          name: serviceName
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: userIdentity.properties.clientId
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: account.properties.endpoint
            }
            {
              name: 'AZURE_OPENAI_COMPLETION_DEPLOYMENT_NAME'
              value: 'gpt-4o-realtime-preview'
            }
            {
              name: 'AZURE_OPENAI_VERSION'
              value: '2024-10-01'
            }
            {
              name: 'OPENAI_API_TYPE'
              value: 'azure'
            }
            {
              name: 'COSMOSDB_ACCOUNT_ENDPOINT'
              value: database.properties.documentEndpoint
            }
            {
              name: 'COSMOSDB_CONTAINER_NAME'
              value: 'reports'
            }
            {
              name: 'COSMOSDB_DATABASE_NAME'
              value: 'mobile'
            }
            {
              name: 'COSMOSDB_DATABASE_NAME'
              value: 'mobile'
            }            
            {
              name: 'ACS_CONNECTION_STRING'
              value: acsconnectionName
            }
            {
              name: 'ACS_SOURCE_NUMBER'
              value: acssourceNumber
            }
          ]
          resources: {
            cpu: json('1')
            memory: '2.0Gi'
          }
        }
      ]
    }
  }
}

resource account 'Microsoft.CognitiveServices/accounts@2022-10-01' existing = {
  name: openaiName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: containerAppsEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource database 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: databaseAccountName
}

output uri string = 'https://${app.properties.configuration.ingress.fqdn}'
