// Template to deploy the Enable Internet Failback policy using Azure Verified Modules
// This policy enables Internet failback for Private Link Azure Private DNS Zones

metadata name = 'Enable Internet Failback for Private DNS Zones Policy'
metadata description = 'This template creates a policy definition to enable Internet failback for Private Link Azure Private DNS Zones'
metadata owner = 'Azure Platform Team'

targetScope = 'managementGroup'

@description('Organization identifier')
param org string

@description('Name for the policy definition')
param policyDefinitionName string = '${org}-net-internetfailback-deploy-v1'

// Create the policy definition directly with inline content
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Enable Internet Failback for Private Link Azure Private DNS Zones'
    description: 'This policy enables Internet Failback on any Private Link Azure Private DNS Zone.'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      privateDnsZonesList: {
        type: 'Array'
        metadata: {
          displayName: 'Private DNS Zones List'
          description: 'List of Private Link DNS zones to enable Internet Failback. A single entry "*" applies to all Private Link DNS zones (privatelink.*).'
        }
        defaultValue: [
          '*'
        ]
      }
      vnetLinkName: {
        type: 'String'
        metadata: {
          displayName: 'Virtual Network Link Name'
          description: 'The name of the Virtual Network Link to which the private DNS zone is linked.'
        }
        defaultValue: 'setByPolicy-PrivateLink-InternetFailbackEnabled'
      }
      vnetResourceId: {
        type: 'String'
        metadata: {
          displayName: 'Virtual Network Resource ID'
          description: 'The resource ID of the virtual network to which the private DNS zone is linked.'
          strongType: 'Microsoft.Network/virtualNetworks'
          assignPermissions: true
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Network/privateDnsZones'
          }
          {
            anyOf: [
              {
                allOf: [
                  {
                    value: '[first(parameters(\'privateDnsZonesList\'))]'
                    equals: '*'
                  }
                  {
                    field: 'name'
                    like: 'privatelink.*'
                  }
                ]
              }
              {
                field: 'name'
                in: '[parameters(\'privateDnsZonesList\')]'
              }
            ]
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
          evaluationDelay: 'AfterProvisioning'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks/virtualNetwork.id'
                equals: '[parameters(\'vnetResourceId\')]'
              }
              {
                field: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks/resolutionPolicy'
                equals: 'NxDomainRedirect'
              }
            ]
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
            '/providers/Microsoft.Authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f'
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'http://schema.management.azure.com/schemas/2019-08-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  resourceName: {
                    type: 'string'
                  }
                  vnetLinkName: {
                    type: 'string'
                  }
                  vnetResourceId: {
                    type: 'string'
                  }
                }
                variables: {}
                resources: [
                  {
                    type: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
                    apiVersion: '2024-06-01'
                    name: '[concat(parameters(\'resourceName\'), \'/\', parameters(\'vnetLinkName\'))]'
                    location: 'global'
                    properties: {
                      registrationEnabled: false
                      resolutionPolicy: 'NxDomainRedirect'
                      virtualNetwork: {
                        id: '[parameters(\'vnetResourceId\')]'
                      }
                    }
                  }
                ]
                outputs: {
                  policy: {
                    type: 'string'
                    value: '[concat(\'VNet Link, \', parameters(\'vnetLinkName\'), \' for Private DNS Zone (microsoft.network/privateDnsZones), \', parameters(\'resourceName\'), \', to VNet \', parameters(\'vnetResourceId\'), \' configured with Internet Failback enabled.\')]'
                  }
                }
              }
              parameters: {
                resourceName: {
                  value: '[field(\'name\')]'
                }
                vnetLinkName: {
                  value: '[parameters(\'vnetLinkName\')]'
                }
                vnetResourceId: {
                  value: '[parameters(\'vnetResourceId\')]'
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
