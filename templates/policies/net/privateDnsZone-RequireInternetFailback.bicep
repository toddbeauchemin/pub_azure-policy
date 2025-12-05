// Template to deploy the Require Internet Failback policy using Azure Verified Modules
// This policy requires that Private Link Azure Private DNS Zones have Internet failback enabled

metadata name = 'Require Internet Failback for Private DNS Zones Policy'
metadata description = 'This template creates a policy definition to require Internet failback for Private Link Azure Private DNS Zones'
metadata owner = 'Azure Platform Team'

targetScope = 'managementGroup'

@description('Organization identifier')
param org string

@description('Name for the policy definition')
param policyDefinitionName string = '${org}-net-internetfailback-require-v1'

// Create the policy definition directly with inline content
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Require Internet Failback for Private Link Azure Private DNS Zones'
    description: 'This policy ensures that Internet Failback is enabled on any Private Link Azure Private DNS Zone.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Specifies the enforcement of the policy. If set to Deny, the policy will block non-compliant resources. If set to Audit, the policy will log non-compliance without blocking resources.'
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
          description: 'List of Private Link DNS zones to enable Internet Failback. A single entry "*" applies to all Private Link DNS zones (privatelink.*).'
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
            equals: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
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
                    value: '[split(field(\'id\'), \'/\')[8]]'
                    like: 'privatelink.*'
                  }
                ]
              }
              {
                value: '[split(field(\'id\'), \'/\')[8]]'
                in: '[parameters(\'privateDnsZonesList\')]'
              }
            ]
          }
          {
            field: 'Microsoft.Network/privateDnsZones/virtualNetworkLinks/resolutionPolicy'
            notEquals: 'NxDomainRedirect'
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
