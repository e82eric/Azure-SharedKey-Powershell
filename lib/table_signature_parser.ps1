$ErrorActionPreference = "stop"

function new_table_signature_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param ($params)
		$options = $params.Options
		$verb = $options.Verb.ToUpper()
		$contentHash = $options.ContentHash
		$contentType = $options.ContentType 
		$date = ($params.MsHeaders | ? { $_.name -eq "x-ms-date" }).value
		$cannonicalizedResources = $params.CanonicalizedResources

		$params.Signature = "$verb`n$contentHash`n$contentType`n$date`n$cannonicalizedResources"
	}
	$obj
}
