$ErrorActionPreference = "stop"

function new_blob_canonicalized_resources_parser { param($storageName)
	$obj = New-Object PSObject -Property @{ StorageName = $storageName }
	$obj | Add-Member -Type ScriptMethod _createOperationsString { param ($operations)
		if($operations -eq $null) { return [String]::Empty }
		if($operations.Length -eq 0) { return [String]::Empty }
		[String]::Join("`n", $($operations | %  {"$($_.Name.ToLower()):$($_.Value)" } | Sort))
	}
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$operationsString= $this._createOperationsString($params.Operations)
		if($operationsString -eq [string]::empty) { 
			$params.CanonicalizedResources = "/$($this.StorageName)/$($params.Resource)" 
		} else { 
			$params.CanonicalizedResources ="/$($this.StorageName)/$($params.Resource)`n$operationsString"
		}
	}
	$obj
}
