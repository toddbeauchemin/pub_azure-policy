// Private Endpoint DNS Management Initiative
// This template creates a comprehensive policy initiative for managing DNS zones and records for Private Endpoints

metadata name = 'Private Link and Private Endpoint DNS Management'
metadata description = 'This template creates a comprehensive policy initiative for managing DNS zones, records, and configurations for Private Link and Private Endpoints. It includes policies for controlling Private Link DNS zone creation, enabling failback mechanisms, and automatically configuring DNS zone groups.'
metadata owner = 'Azure Platform Team'

targetScope = 'managementGroup'

@description('Organization identifier')
param org string

@description('Whether to deploy new policy definitions or reference existing ones')
param deployPolicyDefinitions bool = true

@description('Custom names for policy definitions (used when deployPolicyDefinitions = true)')
param policyDefinitionNames object = {
  denyPrivateLinkZones: '${org}-net-privatednszone-deny-v1'
  enableInternetFailback: '${org}-net-internetfailback-deploy-v1'
  requireInternetFailback: '${org}-net-internetfailback-require-v1'
  deployDnsZoneGroup: '${org}-net-privateendpoint-deploy-v1'
}

@description('Existing policy definition IDs (used when deployPolicyDefinitions = false)')
param existingPolicyDefinitionIds object = {
  denyPrivateLinkZones: ''
  enableInternetFailback: ''
  requireInternetFailback: ''
  deployDnsZoneGroup: ''
}

// Variables
var initiativeName = '${org}-net-privateendpoint-dnsmanagement-v1'

// DNS Zone mappings - calculated at template time to avoid environment() function issues in policy definitions
var defaultDnsZoneMappings = {
  blob: 'privatelink.blob.${environment().suffixes.storage}'
  file: 'privatelink.file.${environment().suffixes.storage}'
  table: 'privatelink.table.${environment().suffixes.storage}'
  queue: 'privatelink.queue.${environment().suffixes.storage}'
  web: 'privatelink.web.${environment().suffixes.storage}'
  dfs: 'privatelink.dfs.${environment().suffixes.storage}'
  sqlServer: 'privatelink${environment().suffixes.sqlServerHostname}'
  vault: 'privatelink.vaultcore.azure.net'
  registry: 'privatelink.azurecr.io'
  sites: 'privatelink.azurewebsites.net'
  redisCache: 'privatelink.redis.cache.windows.net'
  namespace: 'privatelink.servicebus.windows.net'
  eventhub: 'privatelink.servicebus.windows.net'
  cosmosdb: 'privatelink.documents.azure.com'
  cassandra: 'privatelink.cassandra.cosmos.azure.com'
  gremlin: 'privatelink.gremlin.cosmos.azure.com'
  cosmosTable: 'privatelink.table.cosmos.azure.com'
  mongo: 'privatelink.mongo.cosmos.azure.com'
}

// Deploy policy definitions using modules when deployPolicyDefinitions = true
module policyDenyPrivateLinkZones '../../policies/net/privateDnsZone-DenyPrivateLinkZones.bicep' = if (deployPolicyDefinitions) {
  name: 'deploy-deny-private-link-zones'
  params: {
    org: org
    policyDefinitionName: policyDefinitionNames.denyPrivateLinkZones
  }
}

module policyEnableInternetFailback '../../policies/net/privateDnsZone-EnableInternetFailback.bicep' = if (deployPolicyDefinitions) {
  name: 'deploy-enable-internet-failback'
  params: {
    org: org
    policyDefinitionName: policyDefinitionNames.enableInternetFailback
  }
}

module policyRequireInternetFailback '../../policies/net/privateDnsZone-RequireInternetFailback.bicep' = if (deployPolicyDefinitions) {
  name: 'deploy-require-internet-failback'
  params: {
    org: org
    policyDefinitionName: policyDefinitionNames.requireInternetFailback
  }
}

module policyDeployDnsZoneGroup '../../policies/net/privateEndpoint-DeployDnsZoneGroup.bicep' = if (deployPolicyDefinitions) {
  name: 'deploy-dns-zone-group'
  params: {
    org: org
    policyDefinitionName: policyDefinitionNames.deployDnsZoneGroup
  }
}

// Policy Initiative (Policy Set Definition)
resource policyInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: guid(initiativeName, managementGroup().id)
  properties: {
    displayName: 'Private Link and Private Endpoint DNS Management'
    description: 'Comprehensive policy initiative for managing DNS zones, records, and configurations for Private Link and Private Endpoints. Includes policies for controlling Private Link DNS zone creation, enabling failback mechanisms, and automatically configuring DNS zone groups.'
    policyType: 'Custom'
    metadata: {
      category: 'Network'
      version: '1.0.0'
      author: 'Azure Network Team'
    }
    parameters: {
      // Parameters for Deny Private Link Zones policy
      denyPrivateLinkZonesEffect: {
        type: 'String'
        metadata: {
          displayName: 'Effect for denying Private Link DNS zones'
          description: 'Enable or disable the execution of the deny Private Link DNS zones policy'
        }
        allowedValues: [
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Deny'
      }
      excludedResourceGroupIds: {
        type: 'Array'
        metadata: {
          displayName: 'Excluded Resource Groups'
          description: 'List of Resource Group IDs that are excluded from the deny Private Link DNS zones policy'
        }
        defaultValue: []
      }
      excludedPrivateDnsZones: {
        type: 'Array'
        metadata: {
          displayName: 'Excluded Private DNS Zones'
          description: 'List of Private DNS Zones that are excluded from this policy and which can be created'
        }
        defaultValue: []
      }
      // Parameters for Enable Internet Failback policy
      enableInternetFailbackEffect: {
        type: 'String'
        metadata: {
          displayName: 'Effect for enabling Internet failback'
          description: 'Enable or disable the execution of the enable Internet failback policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      vnetLinkName: {
        type: 'String'
        metadata: {
          displayName: 'Virtual Network Link Name'
          description: 'The name of the Virtual Network Link to which the private DNS zone is linked'
        }
        defaultValue: 'setByPolicy-PrivateLink-InternetFailbackEnabled'
      }
      vnetResourceId: {
        type: 'String'
        metadata: {
          displayName: 'Virtual Network Resource ID'
          description: 'The resource ID of the virtual network to which the private DNS zone is linked'
          strongType: 'Microsoft.Network/virtualNetworks'
          assignPermissions: true
        }
      }
      // Parameters for Require Internet Failback policy
      requireInternetFailbackEffect: {
        type: 'String'
        metadata: {
          displayName: 'Effect for requiring Internet failback'
          description: 'Enable or disable the execution of the require Internet failback policy'
        }
        allowedValues: [
          'Deny'
          'Audit'
          'Disabled'
        ]
        defaultValue: 'Deny'
      }
      privateDnsZonesList: {
        type: 'Array'
        metadata: {
          displayName: 'Private DNS Zones List'
          description: 'List of Private DNS zones to apply policies to. A single entry "*" applies to all Private Link DNS zones'
        }
        defaultValue: ['*']
      }
      // Parameters for Deploy DNS Zone Group policy
      deployDnsZoneGroupEffect: {
        type: 'String'
        metadata: {
          displayName: 'Effect for deploying DNS zone groups'
          description: 'Enable or disable the execution of the deploy DNS zone groups policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      privateDnsZoneResourceGroupName: {
        type: 'String'
        metadata: {
          displayName: 'Private DNS Zone Resource Group'
          description: 'The resource group name where the Private DNS zones are located'
        }
      }
      privateDnsZoneSubscriptionId: {
        type: 'String'
        metadata: {
          displayName: 'Subscription Id'
          description: 'The subscription Id where the Private DNS zones are located. If empty, uses the same subscription as the Private Endpoint.'
        }
        defaultValue: ''
      }
      dnsZoneMappings: {
        type: 'Object'
        metadata: {
          displayName: 'DNS Zone Mappings'
          description: 'Object mapping private endpoint group IDs to their corresponding Private DNS zone names'
        }
        defaultValue: defaultDnsZoneMappings
      }
    }
    policyDefinitions: [
      // Deny Private Link Zones Policy
      {
        policyDefinitionId: deployPolicyDefinitions ? policyDenyPrivateLinkZones!.outputs.policyDefinitionId : existingPolicyDefinitionIds.denyPrivateLinkZones
        policyDefinitionReferenceId: 'deny-private-link-zones'
        parameters: {
          effect: {
            value: '[parameters(\'denyPrivateLinkZonesEffect\')]'
          }
          excludedResourceGroupIds: {
            value: '[parameters(\'excludedResourceGroupIds\')]'
          }
          excludedPrivateDnsZones: {
            value: '[parameters(\'excludedPrivateDnsZones\')]'
          }
          privateDnsZonesList: {
            value: '[parameters(\'privateDnsZonesList\')]'
          }
        }
        groupNames: [
          'DNS Zone Control'
        ]
      }
      // Enable Internet Failback Policy
      {
        policyDefinitionId: deployPolicyDefinitions ? policyEnableInternetFailback!.outputs.policyDefinitionId : existingPolicyDefinitionIds.enableInternetFailback
        policyDefinitionReferenceId: 'enable-internet-failback'
        parameters: {
          effect: {
            value: '[parameters(\'enableInternetFailbackEffect\')]'
          }
          privateDnsZonesList: {
            value: '[parameters(\'privateDnsZonesList\')]'
          }
          vnetLinkName: {
            value: '[parameters(\'vnetLinkName\')]'
          }
          vnetResourceId: {
            value: '[parameters(\'vnetResourceId\')]'
          }
        }
        groupNames: [
          'DNS Failback'
        ]
      }
      // Require Internet Failback Policy
      {
        policyDefinitionId: deployPolicyDefinitions ? policyRequireInternetFailback!.outputs.policyDefinitionId : existingPolicyDefinitionIds.requireInternetFailback
        policyDefinitionReferenceId: 'require-internet-failback'
        parameters: {
          effect: {
            value: '[parameters(\'requireInternetFailbackEffect\')]'
          }
          privateDnsZonesList: {
            value: '[parameters(\'privateDnsZonesList\')]'
          }
        }
        groupNames: [
          'DNS Failback'
        ]
      }
      // Deploy DNS Zone Group Policy
      {
        policyDefinitionId: deployPolicyDefinitions ? policyDeployDnsZoneGroup!.outputs.policyDefinitionId : existingPolicyDefinitionIds.deployDnsZoneGroup
        policyDefinitionReferenceId: 'deploy-dns-zone-group'
        parameters: {
          effect: {
            value: '[parameters(\'deployDnsZoneGroupEffect\')]'
          }
          privateDnsZoneResourceGroupName: {
            value: '[parameters(\'privateDnsZoneResourceGroupName\')]'
          }
          privateDnsZoneSubscriptionId: {
            value: '[parameters(\'privateDnsZoneSubscriptionId\')]'
          }
          privateDnsZoneMappings: {
            value: '[parameters(\'dnsZoneMappings\')]'
          }
        }
        groupNames: [
          'Private Endpoint DNS'
        ]
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'DNS Zone Control'
        displayName: 'DNS Zone Creation Control'
        description: 'Policies that control the creation and management of Private DNS zones'
      }
      {
        name: 'DNS Failback'
        displayName: 'DNS Internet Failback'
        description: 'Policies that manage Internet failback settings for Private DNS zones'
      }
      {
        name: 'Private Endpoint DNS'
        displayName: 'Private Endpoint DNS Configuration'
        description: 'Policies that automatically configure DNS for Private Endpoints'
      }
    ]
  }
}

// Outputs
output policyInitiativeId string = policyInitiative.id
output policyInitiativeName string = policyInitiative.name
output policyDefinitionIds object = deployPolicyDefinitions ? {
  denyPrivateLinkZones: policyDenyPrivateLinkZones!.outputs.policyDefinitionId
  enableInternetFailback: policyEnableInternetFailback!.outputs.policyDefinitionId
  requireInternetFailback: policyRequireInternetFailback!.outputs.policyDefinitionId
  deployDnsZoneGroup: policyDeployDnsZoneGroup!.outputs.policyDefinitionId
} : existingPolicyDefinitionIds
