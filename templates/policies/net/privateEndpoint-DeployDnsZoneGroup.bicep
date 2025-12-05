// Template to deploy the Deploy DNS Zone Group policy
// This policy deploys DNS zone groups for Private Endpoints to ensure proper DNS resolution

metadata name = 'Deploy Private Endpoint DNS Zone Group Policy'
metadata description = 'This template creates a policy definition to deploy and audit private DNS zone groups for Private Endpoints'
metadata owner = 'Azure Platform Team'

targetScope = 'managementGroup'

@description('Organization identifier')
param org string

@description('Name for the policy definition')
param policyDefinitionName string = '${org}-net-privateendpoint-deploy-v1'

// Create the policy definition directly with inline content
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Deploy and audit private DNS zone groups for Private Endpoints'
    description: 'Deploys Private DNS Zone Groups for Private Endpoints to ensure proper DNS resolution. Also audits existing Private Endpoints to verify they have appropriate DNS zone configurations.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      version: '1.0.0'
      category: 'Network'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
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
      privateDnsZoneMappings: {
        type: 'Object'
        metadata: {
          displayName: 'DNS Zone Mappings'
          description: 'Object mapping private endpoint group IDs to their corresponding Private DNS zone names'
        }
        defaultValue: {
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
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Network/privateEndpoints'
          }
          {
            field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].groupIds[*]'
            exists: 'true'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
          ]
          existenceCondition: {
            field: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/privateDnsZoneConfigs[*].privateDnsZoneId'
            exists: 'true'
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  privateEndpointName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  privateDnsZoneResourceGroupName: {
                    type: 'string'
                  }
                  privateDnsZoneSubscriptionId: {
                    type: 'string'
                  }
                  privateDnsZoneMappings: {
                    type: 'object'
                  }
                  groupIds: {
                    type: 'array'
                  }
                }
                variables: {
                  targetSubscriptionId: '[if(empty(parameters(\'privateDnsZoneSubscriptionId\')), subscription().subscriptionId, parameters(\'privateDnsZoneSubscriptionId\'))]'
                  groupId: '[first(parameters(\'groupIds\'))]'
                  privateDnsZoneName: '[if(contains(parameters(\'privateDnsZoneMappings\'), variables(\'groupId\')), parameters(\'privateDnsZoneMappings\')[variables(\'groupId\')], concat(\'privatelink.\', variables(\'groupId\'), \'.azure.com\'))]'
                  privateDnsZoneId: '[resourceId(variables(\'targetSubscriptionId\'), parameters(\'privateDnsZoneResourceGroupName\'), \'Microsoft.Network/privateDnsZones\', variables(\'privateDnsZoneName\'))]'
                }
                resources: [
                  {
                    name: '[concat(parameters(\'privateEndpointName\'), \'/deployedByPolicy\')]'
                    type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
                    apiVersion: '2022-07-01'
                    properties: {
                      privateDnsZoneConfigs: [
                        {
                          name: '[concat(variables(\'groupId\'), \'-privateDnsZone\')]'
                          properties: {
                            privateDnsZoneId: '[variables(\'privateDnsZoneId\')]'
                          }
                        }
                      ]
                    }
                  }
                ]
                outputs: {
                  privateDnsZoneId: {
                    type: 'string'
                    value: '[variables(\'privateDnsZoneId\')]'
                  }
                  groupId: {
                    type: 'string'
                    value: '[variables(\'groupId\')]'
                  }
                }
              }
              parameters: {
                privateEndpointName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
                privateDnsZoneResourceGroupName: {
                  value: '[parameters(\'privateDnsZoneResourceGroupName\')]'
                }
                privateDnsZoneSubscriptionId: {
                  value: '[parameters(\'privateDnsZoneSubscriptionId\')]'
                }
                privateDnsZoneMappings: {
                  value: '[parameters(\'privateDnsZoneMappings\')]'
                }
                groupIds: {
                  value: '[field(\'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].groupIds[*]\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// Outputs
output policyDefinitionId string = policyDefinition.id
output policyDefinitionName string = policyDefinition.name
