$ErrorActionPreference = "stop"

function new_azure_resource_management { param($resourceRestClient, $resourceGroupManagement)
	$obj = new_azure_resource_management_base $resourceRestClient "2015-01-01"
	$obj | Add-Member -Type NoteProperty ResourceGroupManagement $resourceGroupManagement
	$obj | Add-Member -Type ScriptMethod DeployTemplate { param($resourceGroupName, $dataCenter, $templateDef, $templateParameters)
		$path = "resourcegroups/$($resourceGroupName)/providers/microsoft.resources/deployments/$($resourceGroupName)"

		$def = @{
			properties = @{
				mode = "Incremental";
				template = $templateDef;
				parameters = $templateParameters;
			}
		}

		$result = $this.PutOperation($path, $def)
		$result
	}
	$obj
}
