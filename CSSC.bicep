param AcrName string
param AcrLocation string = resourceGroup().location

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource acr 'Microsoft.ContainerRegistry/registries@2019-05-01' existing = {
  name: AcrName
}

resource csscWebhook 'Microsoft.Logic/workflows@2019-05-01' = {
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              properties: {
                action: {
                  type: 'string'
                }
                id: {
                  type: 'string'
                }
                request: {
                  properties: {
                    host: {
                      type: 'string'
                    }
                    id: {
                      type: 'string'
                    }
                    method: {
                      type: 'string'
                    }
                    useragent: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
                target: {
                  properties: {
                    digest: {
                      type: 'string'
                    }
                    length: {
                      type: 'integer'
                    }
                    mediaType: {
                      type: 'string'
                    }
                    repository: {
                      type: 'string'
                    }
                    size: {
                      type: 'integer'
                    }
                    tag: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
                timestamp: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      actions: {
        Condition: {
          actions: {
            Invoke_resource_operation: {
              runAfter: {}
              type: 'ApiConnection'
              inputs: {
                body: {
                  isArchiveEnabled: false
                  overrideTaskStepProperties: {
                    arguments: []
                    values: [
                      {
                        isSecret: false
                        name: 'REPOSITORY'
                        value: '@{triggerBody()?[\'target\']?[\'repository\']}'
                      }
                      {
                        isSecret: false
                        name: 'TAG'
                        value: '@{triggerBody()?[\'target\']?[\'tag\']}'
                      }
                    ]
                  }
                  taskName: acrCsscTask.name
                  type: 'TaskRunRequest'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'arm\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '${replace(acr.id,'registries/','registries%2F')}/scheduleRun'
                queries: {
                  'x-ms-api-version': '2019-04-01'
                }
              }
            }
          }
          runAfter: {}
          expression: {
            and: [
              {
                not: {
                  equals: [
                    '@triggerBody()?[\'target\']?[\'tag\']'
                    '@null'
                  ]
                }
              }
            ]
          }
          type: 'If'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          arm: {
            connectionId: armConnection.id
            connectionName: 'arm'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', AcrLocation, 'arm')
          }
        }
      }
    }
    zoneRedundancy: 'Enabled'
  }
  name: 'AcrCsscWebhook'
  location: AcrLocation
  identity: {
    type: 'SystemAssigned'
  }
}
resource csscWebhookTrigger 'Microsoft.Logic/workflows/triggers@2019-05-01' existing = {
  name: 'manual'
  parent: csscWebhook
}
resource armConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  properties: {
    displayName: 'System'
    api: {
      name: 'arm'
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', AcrLocation, 'arm')
      type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValueType: 'Alternative'
  }
  name: 'Arm'
  location: AcrLocation
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: csscWebhook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrCsscwebhook 'Microsoft.ContainerRegistry/registries/webhooks@2023-01-01-preview' = {
  name: 'CsscWebhook'
  location: AcrLocation
  parent: acr
  properties: {
    actions: [
      'push'
    ]
    serviceUri: csscWebhookTrigger.listCallbackUrl().value
  }
}

resource acrCsscTask 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = {
  name: 'AcrCSSCTask'
  location: AcrLocation
  parent: acr
  properties: {
    platform: {
      os: 'linux'
      architecture: 'amd64'
    }
    agentConfiguration: {
      cpu: 2
    }
    timeout: 3600
    step: {
      type: 'EncodedTask'
      encodedTaskContent: 'dmVyc2lvbjogdjEuMS4wCnZlcnNpb246IHYxLjEuMApzdGVwczoKICAjIFRhc2sxLiBQZXJmb3JtIHRoZSB2dWxuZXJhYmlsaXR5IHNjYW4gZm9yIHRoZSBpbnB1dCBpbWFnZQogIC0gY21kOiB8CiAgICAgIGdoY3IuaW8vYXF1YXNlY3VyaXR5L3RyaXZ5IGltYWdlIFwKICAgICAge3suUnVuLlJlZ2lzdHJ5fX0ve3suVmFsdWVzLlJFUE9TSVRPUll9fTp7ey5WYWx1ZXMuVEFHfX0gXAogICAgICAtLWZvcm1hdCBzYXJpZiBcCiAgICAgIC0tb3V0cHV0IC4vdnVsbmVyYWJpbGl0eXNjYW4uc2FyaWYKICAjIFRhc2syLiA8VEJEPiBTaWduIHRoZSB2dWxuZXJhYmlsaXR5IHNjYW5uZWQgc2FyaWYgaW1hZ2UKICAjIFRhc2szLiBHZW5lcmF0ZSBTQk9NIGZvciB0aGUgaW5wdXQgaW1hZ2UgYW5kIHRhZwogIC0gY21kOiB8CiAgICAgIGdoY3IuaW8vYXF1YXNlY3VyaXR5L3RyaXZ5IGltYWdlIFwKICAgICAge3suUnVuLlJlZ2lzdHJ5fX0ve3suVmFsdWVzLlJFUE9TSVRPUll9fTp7ey5WYWx1ZXMuVEFHfX0gXAogICAgICAtLWZvcm1hdCBzcGR4IFwKICAgICAgLS1vdXRwdXQgLi9zYm9tLnNwZHgKICAjIFRhc2s0LiA8VEJEPiBTaWduIHRoZSBnZW5lcmF0ZWQgU0JPTSBzcGR4IGZpbGUKICAjIFRhc2s1LiBQdXNoIHRoZSBhcnRpZmFjdHMgdG8gdGhlIHJlZ2lzdHJ5IGFzIE9DSS1yZWZlcnJlcnMKICAtIGNtZDogfAogICAgICBnaGNyLmlvL29yYXMtcHJvamVjdC9vcmFzOnYxLjEuMCBhdHRhY2ggXAogICAgICAtLWFydGlmYWN0LXR5cGUgdnVsbmVyYWJpbGl0eVNjYW5SZXN1bHQvZXhhbXBsZSBcCiAgICAgIHt7LlJ1bi5SZWdpc3RyeX19L3t7LlZhbHVlcy5SRVBPU0lUT1JZfX06e3suVmFsdWVzLlRBR319IFwKICAgICAgLi92dWxuZXJhYmlsaXR5c2Nhbi5zYXJpZgogICMgVGFzazYuIFB1c2ggdGhlIGFydGlmYWN0cyB0byB0aGUgcmVnaXN0cnkgYXMgT0NJLXJlZmVycmVycwogIC0gY21kOiB8CiAgICAgIGdoY3IuaW8vb3Jhcy1wcm9qZWN0L29yYXM6djEuMS4wIGF0dGFjaCBcCiAgICAgIC0tYXJ0aWZhY3QtdHlwZSBTQk9NL2V4YW1wbGUgXAogICAgICB7ey5SdW4uUmVnaXN0cnl9fS97ey5WYWx1ZXMuUkVQT1NJVE9SWX19Ont7LlZhbHVlcy5UQUd9fSBcCiAgICAgIC4vc2JvbS5zcGR4'
    }
    isSystemTask: false
  }
}
