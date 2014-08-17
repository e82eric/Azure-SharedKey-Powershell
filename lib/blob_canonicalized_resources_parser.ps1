$ErrorActionPreference = "stop"

function new_blob_canonicalized_resources_parser { param($storageName)
	$obj = New-Object PSObject -Property @{ StorageName = $storageName }
	$obj | Add-Member -Type ScriptMethod _createOperationsString { param ($operations)
		if($operations -eq $null) { return [String]::Empty }
		if($operations.Length -eq 0) { return [String]::Empty }
		[String]::Join("`n", $($operations | %	{"$($_.Name.ToLower()):$($_.Value)" } | Sort))
	}
	$obj | Add-Member -Type ScriptMethod execute { 
		param(
			$operations=$(throw "operations is mandatory"),
			$resource=$(throw "resource is mandatory")
		)
		$operationsString= $this._createOperationsString($operations)
		if($operationsString -eq [string]::empty) { 
			#return
			"/$($this.StorageName)/$($resource)" 
		} else { 
			#return
			"/$($this.StorageName)/$($resource)`n$operationsString"
		}
	}
	$obj
}
