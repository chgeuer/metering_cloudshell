@description('The deployment location')
param location string = resourceGroup().location

param currentUserId string 

param storageAccountName string = ''

param keyVaultName string = ''

param containerName string = ''

var roles = {
  KeyVaultCryptoOfficer: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
}

var names = {
  storageAccount: !empty(storageAccountName) ? storageAccountName : 'k${uniqueString(resourceGroup().id)}'
  keyVault: !empty(keyVaultName) ? keyVaultName : 'k${uniqueString(resourceGroup().id)}'
  container: !empty(containerName) ? toLower(containerName) : 'public'
}

@description('Publicly hosts key material for our IdP.')
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: names.storageAccount
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  tags: {
    usage: 'Fake identity provider key material'
  }
  properties: {
    accessTier: 'Cool'
    allowSharedKeyAccess: true
    allowBlobPublicAccess: true
  }
  resource blobServices 'blobServices' = {
    name: 'default'
    resource containers 'containers' = {
      name: names.container
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: names.keyVault
  location: location
  tags: {
    usage: 'Fake identity provider key material'
  }
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
       bypass: 'AzureServices'
       defaultAction: 'Allow'
    }
  }
}

resource tokenSigningKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  parent: keyVault, name: 'idpkey'
  properties: {
    keyOps: [ 'sign' ]
    kty: 'RSA'
    keySize: 4096
  }
}

resource currentUserIsKeyVaultCryptoOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(currentUserId, roles.KeyVaultCryptoOfficer, keyVault.id)
  scope: keyVault
  properties: {
    principalType: 'User'
    principalId: currentUserId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.KeyVaultCryptoOfficer)    
  }
}

output storage object = {
  url: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}/${names.container}'
  storageAccountName: storageAccount.name
  containerName: names.container
}

output keyvault object = {
  name: names.keyVault
  vaultUri: keyVault.properties.vaultUri
  keyUri: tokenSigningKey.properties.keyUri
}
