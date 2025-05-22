param location string = resourceGroup().location
param appName string = 'my-linux-app-${uniqueString(resourceGroup().id)}'
param dbName string = 'mydb${uniqueString(resourceGroup().id)}'
param redisName string = 'redis${uniqueString(resourceGroup().id)}'
param linuxFxVersion string = 'node|20-lts' 
param cdnProfileName string = 'cdnProfile${uniqueString(resourceGroup().id)}'
param cdnEndpointName string = 'cdnEndpoint${uniqueString(resourceGroup().id)}'

@secure()
param dbAdminPassword string

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${appName}-plan'
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: 'F1'
  }
  kind: 'linux'
}

// Web App (Linux)
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
    }
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

// Redis Cache
resource redis 'Microsoft.Cache/Redis@2023-08-01' = {
  name: redisName
  location: location
  sku: {
    name: 'Basic'
    family: 'C'
    capacity: 0
  }
  properties: {
    enableNonSslPort: false
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

// CDN Endpoint
resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: '${cdnProfile.name}/${cdnEndpointName}'
  location: 'global'
  properties: {
    origins: [
      {
        name: 'appOrigin'
        properties: {
          hostName: webApp.properties.defaultHostName
        }
      }
    ]
    isHttpAllowed: false
    isHttpsAllowed: true
  }
  dependsOn: [
    cdnProfile
    webApp
  ]
}

// App Service access restriction to only allow CDN
resource accessRestrictions 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${webApp.name}/web'
  properties: {
    ipSecurityRestrictionsDefaultAction: 'Deny'
    ipSecurityRestrictions: [
      {
        name: 'AllowCDN'
        action: 'Allow'
        priority: 100
        tag: 'ServiceTag'
        ipAddress: 'AzureFrontDoor.Backend'
      }
    ]
  }
  dependsOn: [
    webApp
  ]
}
