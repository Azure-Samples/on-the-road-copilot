param name string
param location string 
param tags object = {}

resource communcationService 'Microsoft.Communication/CommunicationServices@2023-04-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dataLocation: 'germany'
  }
}

output communicationConnectionString string = communcationService.listKeys().primaryConnectionString
