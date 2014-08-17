$ErrorActionPreference = "stop"

function new_table_signature_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { 
		param (
			[ValidateNotNullOrEmpty()]$verb=$(throw "verb is mandatory"),
			$contentHash=$(throw "contenthash is mandatory"),
			$contentType=$(throw "contenttype is mandatory"),
			[ValidateNotNullOrEmpty()]$date=$(throw "date is mandatory"),
			[ValidateNotNullOrEmpty()]$cannonicalizedResources=$(throw "cannonicalizedResoures is mandatory")
		)
		"$verb`n$contentHash`n$contentType`n$date`n$cannonicalizedResources"
	}
	$obj
}
