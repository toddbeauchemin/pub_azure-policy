# Private DNS Zones Enable Internet Failback Policy

This document describes an Azure Policy that enables Internet Failback on Private Link Azure Private DNS Zones to ensure DNS resolution falls back to public DNS when private resolution fails.

## Policy Overview

**File**: `privateDnsZones-EnableInternetFailback.json`
**Display Name**: "Enable Internet Failback for Private Link Azure Private DNS Zones"
**Category**: Network
**Mode**: All
**Policy Type**: Custom
**Version**: 1.0.0

## Purpose

This policy enables Internet Failback on any Private Link Azure Private DNS Zone. Internet Failback allows DNS queries to fall back to public DNS resolution when private DNS resolution fails, ensuring service continuity while maintaining private connectivity when available.

## Key Features

- **Automatic Configuration**: Enables failback on Private Link DNS zones without manual intervention
- **Service Continuity**: Ensures DNS resolution works even when private endpoints are unavailable
- **Flexible Effects**: Supports both automatic deployment and audit-only modes
- **ARM Template Integration**: Uses embedded ARM templates for reliable configuration

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect` | String | No | "DeployIfNotExists" | Policy effect (DeployIfNotExists/AuditIfNotExists/Disabled) |

## Prerequisites

### Required Permissions
The policy's managed identity needs:
- **Private DNS Zone Contributor** role on the Private DNS zones
- **Reader** role on resource groups containing DNS zones

### Private DNS Zone Requirements
- Target zones must be Private Link zones (privatelink.* naming convention)
- Zones should be linked to virtual networks where failback is needed

## Policy Logic

The policy operates as follows:

1. **Zone Identification**: Targets Private DNS zones with privatelink.* naming pattern
2. **Failback Check**: Verifies if Internet Failback is already enabled
3. **Configuration**: Enables failback if not already configured
4. **ARM Deployment**: Uses ARM templates to apply the configuration

## Common Use Cases

### 1. Hybrid Connectivity
Ensure DNS resolution works during hybrid cloud scenarios where private endpoints may be temporarily unavailable.

### 2. Service Resilience
Provide DNS failback for critical services that need both private and public accessibility.

### 3. Migration Scenarios
Support gradual migration from public to private endpoints with seamless DNS resolution.

### 4. Disaster Recovery
Maintain service availability during private endpoint outages.

## Deployment Examples

### Azure CLI

```bash
# Create policy definition
az policy definition create \
  --name "enable-dns-failback" \
  --display-name "Enable Internet Failback for Private DNS Zones" \
  --description "Enables Internet failback on Private Link DNS zones" \
  --rules @privateDnsZones-EnableInternetFailback.json \
  --mode All

# Create managed identity for policy
az identity create \
  --name "policy-dns-identity" \
  --resource-group "myPolicyRg"

# Get identity principal ID
IDENTITY_ID=$(az identity show --name "policy-dns-identity" --resource-group "myPolicyRg" --query principalId -o tsv)

# Assign Private DNS Zone Contributor role
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Private DNS Zone Contributor" \
  --scope "/subscriptions/{subscription-id}"

# Assign policy with managed identity
az policy assignment create \
  --name "enable-dns-failback-assignment" \
  --display-name "Enable DNS Internet Failback" \
  --policy "enable-dns-failback" \
  --assign-identity \
  --identity-scope "/subscriptions/{subscription-id}" \
  --location "eastus" \
  --params '{"effect": {"value": "DeployIfNotExists"}}' \
  --scope "/subscriptions/{subscription-id}"
```

### Azure PowerShell

```powershell
# Create policy definition
$PolicyDef = New-AzPolicyDefinition `
  -Name "enable-dns-failback" `
  -DisplayName "Enable Internet Failback for Private DNS Zones" `
  -Description "Enables Internet failback on Private Link DNS zones" `
  -Policy (Get-Content -Path "privateDnsZones-EnableInternetFailback.json" -Raw) `
  -Mode "All"

# Create managed identity
$Identity = New-AzUserAssignedIdentity `
  -ResourceGroupName "myPolicyRg" `
  -Name "policy-dns-identity"

# Assign Private DNS Zone Contributor role
New-AzRoleAssignment `
  -ObjectId $Identity.PrincipalId `
  -RoleDefinitionName "Private DNS Zone Contributor" `
  -Scope "/subscriptions/{subscription-id}"

# Create policy assignment
New-AzPolicyAssignment `
  -Name "enable-dns-failback-assignment" `
  -DisplayName "Enable DNS Internet Failback" `
  -PolicyDefinition $PolicyDef `
  -AssignIdentity `
  -IdentityType "UserAssigned" `
  -IdentityId $Identity.Id `
  -Location "eastus" `
  -Scope "/subscriptions/{subscription-id}"
```

### ARM Template

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "policyAssignmentName": {
            "type": "string",
            "defaultValue": "enable-dns-failback"
        },
        "policyDefinitionId": {
            "type": "string"
        }
    },
    "variables": {
        "identityName": "policy-dns-identity"
    },
    "resources": [
        {
            "type": "Microsoft.ManagedIdentity/userAssignedIdentities",
            "apiVersion": "2023-01-31",
            "name": "[variables('identityName')]",
            "location": "[resourceGroup().location]"
        },
        {
            "type": "Microsoft.Authorization/policyAssignments",
            "apiVersion": "2022-06-01",
            "name": "[parameters('policyAssignmentName')]",
            "location": "[resourceGroup().location]",
            "dependsOn": [
                "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', variables('identityName'))]"
            ],
            "identity": {
                "type": "UserAssigned",
                "userAssignedIdentities": {
                    "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', variables('identityName'))]": {}
                }
            },
            "properties": {
                "displayName": "Enable DNS Internet Failback",
                "policyDefinitionId": "[parameters('policyDefinitionId')]",
                "parameters": {
                    "effect": {
                        "value": "DeployIfNotExists"
                    }
                }
            }
        }
    ]
}
```

## Best Practices

### DNS Zone Management
- **Selective Application**: Only enable failback where business continuity requires it
- **Zone Documentation**: Document which zones have failback enabled and why
- **Regular Review**: Periodically review failback configurations for continued need
- **Monitoring**: Monitor DNS resolution patterns to validate failback effectiveness

### Security Considerations
- **Data Sensitivity**: Consider if public DNS fallback is appropriate for sensitive services
- **Network Isolation**: Ensure failback doesn't compromise network security requirements
- **Access Control**: Restrict who can modify Private DNS zone configurations
- **Audit Logging**: Enable logging for DNS zone configuration changes

### Implementation Strategy
- **Phased Rollout**: Start with non-critical zones to validate behavior
- **Testing**: Test failback scenarios in development environments
- **Documentation**: Document expected behavior during failback scenarios
- **Monitoring**: Implement monitoring for DNS resolution failures and fallback usage

## Troubleshooting

### Common Issues

**Issue**: Failback not working as expected
- **Cause**: Zone may not be properly configured or linked to VNets
- **Solution**: Verify zone configuration and virtual network links

**Issue**: Policy not applying to some DNS zones
- **Cause**: Zones may not match the privatelink.* pattern
- **Solution**: Check zone naming and ensure they are Private Link zones

**Issue**: Permission errors during deployment
- **Cause**: Managed identity lacks sufficient permissions
- **Solution**: Verify Private DNS Zone Contributor role assignment

### Validation Steps

1. **Zone Identification**: Verify policy targets correct Private Link DNS zones
2. **Permission Check**: Confirm managed identity has appropriate roles
3. **Configuration Test**: Test DNS resolution with and without private endpoints
4. **Monitoring**: Monitor DNS queries to validate failback behavior

### Monitoring and Alerts

```bash
# Check policy compliance
az policy state list --filter "policyDefinitionName eq 'enable-dns-failback'"

# List Private DNS zones with failback enabled
az network private-dns zone list --query "[].{Name:name,Failback:failback}"
```

## Related Policies

- **Private DNS Zone Links**: Ensure zones are properly linked to virtual networks
- **Private Endpoint DNS**: Manage DNS configuration for Private Endpoints
- **Network Connectivity**: Broader network connectivity and routing policies

## Compliance and Security Benefits

### Business Continuity
- **Service Availability**: Maintains DNS resolution during private endpoint outages
- **Hybrid Support**: Enables smooth hybrid cloud operations
- **Migration Support**: Facilitates gradual migration strategies
- **Disaster Recovery**: Supports DR scenarios with DNS failover

### Operational Benefits
- **Automated Configuration**: Eliminates manual DNS configuration tasks
- **Consistent Behavior**: Ensures uniform failback behavior across zones
- **Reduced Downtime**: Minimizes service disruption from DNS resolution issues
- **Simplified Management**: Centralized policy-based configuration management

---

**Version**: 1.0.0
**Last Updated**: December 4, 2025
**Author**: Azure Network Team