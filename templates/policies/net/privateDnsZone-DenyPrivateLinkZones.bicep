// Template to deploy the Deny Private Link DNS Zones policy using Azure Verified Modules
// This policy prevents creation of Private Link Azure Private DNS Zones

metadata name = 'Deny Private Link DNS Zones Policy'
metadata description = 'This template creates a policy definition to deny the creation of Private Link Azure Private DNS Zones'
metadata owner = 'Azure Platform Team'

targetScope = 'managementGroup'

@description('Organization identifier')
param org string

@description('Name for the policy definition')
param policyDefinitionName string = '${org}-net-privatednszone-deny-v1'

// Create the policy definition directly with inline content
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Deny the Creation of Private Link Azure Private DNS Zones'
    description: 'This policy denies the creation of Private Link Azure Private DNS Zone.'
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
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Deny'
      }
      excludedResourceGroupIds: {
        type: 'Array'
        metadata: {
          displayName: 'Excluded Resource Groups'
          description: 'List of Resource Group Ids that are excluded from this policy and where Private Link DNS zones can be created.'
        }
        defaultValue: []
      }
      excludedPrivateDnsZones: {
        type: 'Array'
        metadata: {
          displayName: 'Excluded Private DNS Zones'
          description: 'List of Private DNS Zones that are excluded from this policy and which can be created.'
        }
        defaultValue: []
      }
      privateDnsZonesList: {
        type: 'Array'
        metadata: {
          displayName: 'Private DNS Zones List'
          description: 'List of Private Link DNS zones to deny creation. A single entry "*" applies to all Private Link DNS zones (privatelink.*).'
        }
        defaultValue: [
          '*'
        ]
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
            not: {
              anyOf: [
                {
                  value: '[resourceGroup().id]'
                  in: '[parameters(\'excludedResourceGroupIds\')]'
                }
                {
                  field: 'name'
                  in: '[parameters(\'excludedPrivateDnsZones\')]'
                }
              ]
            }
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
      }
    }
  }
}

// Outputs
output policyDefinitionId string = policyDefinition.id
output policyDefinitionName string = policyDefinition.name
