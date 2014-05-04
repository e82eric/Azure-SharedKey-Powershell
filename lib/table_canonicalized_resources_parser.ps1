$ErrorActionPreference = "stop"

function new_table_canonicalized_resources_parser { param($storageAccount)
	$obj = New-Object PSObject -Property @{ StorageAccount = $storageAccount }
	$obj | Add-Member -Type ScriptMethod execute -Value { param ($params)
		$params.CanonicalizedResources = "/$($this.StorageAccount)/$($params.Resource)"
	}
	$obj
}
