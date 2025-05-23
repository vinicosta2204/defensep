param location string = resourceGroup().location
param appName string = 'my-linux-app-${uniqueString(resourceGroup().id)}'
param dbName string = 'mydb${uniqueString(resourceGroup().id)}'
param redisName string = 'redis${uniqueString(resourceGroup().id)}'
param cdnProfileName string = 'cdnProfile${uniqueString(resourceGroup().id)}'
param cdnEndpointName string = 'cdnEndpoint${uniqueString(resourceGroup().id)}'
param storageName string = 'staticweb${uniqueString(resourceGroup().id)}'

@secure()
param dbAdminPassword string

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${appName}-plan'
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
    size: 'P1v2'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// App Service (Linux)
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
    }
    publicNetworkAccess: 'Enabled'
  }
}

// PostgreSQL Flexible Server
resource dbServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: dbName
  location: location
  properties: {
    administratorLogin: 'pgadmin'
    administratorLoginPassword: dbAdminPassword
    version: '13'
    storage: {
      storageSizeGB: 32
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    authentication: {
      passwordAuthentication: {
        passwordEnabled: true
      }
    }
  }
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
    capacity: 1
  }
}

// Azure Cache for Redis
resource redis 'Microsoft.Cache/Redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    enableNonSslPort: false
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
  }
}

// Static Website Storage Account
resource staticSiteStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    staticWebsite: {
      enabled: true
      indexDocument: 'index.html'
      error404Document: '404.html'
    }
  }
}

// CDN Profile
resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
}

// CDN Endpoint pointing to static website
resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: '${cdnProfile.name}/${cdnEndpointName}'
  location: 'global'
  properties: {
    origins: [
      {
        name: 'staticWebOrigin'
        properties: {
          hostName: '${staticSiteStorage.name}.z13.web.core.windows.net'
        }
      }
    ]
    isHttpAllowed: false
    isHttpsAllowed: true
  }
  dependsOn: [
    cdnProfile
    staticSiteStorage
  ]
}

// App Service Access - open
resource accessRestriction 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${webApp.name}/web'
  properties: {
    ipSecurityRestrictionsDefaultAction: 'Allow'
  }
  dependsOn: [
    webApp
  ]
}
