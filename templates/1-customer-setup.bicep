@description('The deployment location')
param location string = resourceGroup().location

@description('The name of the user-assigned managed identity')
param identityName string

@description('The issuer URL')
param issuerUrl string

@description('The subject name')
param sub string

@description('The audience')
param aud string

@description('A user-assigned managed identity to emit usage.')
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: {
    usage: 'Used to remotely sign-in from the ISV'
  }
  resource federatedCred 'federatedIdentityCredentials' = {
    name: 'fed'
    properties: {
      issuer: issuerUrl
      subject: sub
      audiences: [
        aud
      ]
      description: 'The ISV/publisher will sign in via a federated credential'
    }
  }
}

output uami object = {
  federated: {
    iss: issuerUrl
    aud: aud
    sub: sub
  }
  tenant_id: subscription().tenantId    
  client_id: identity.properties.clientId
  object_id: identity.properties.principalId
}
