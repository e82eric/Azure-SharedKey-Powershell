$ErrorActionPreference = "stop"

function new_blob_signature_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute {
		param(
			[ValidateNotNullOrEmpty()]$verb=$(throw "verb is mandatory"),
			$content,
			$contentHash,
			$contentType,
			[ValidateNotNullOrEmpty()]$canonicalizedHeaders=$(throw "canonicalizedHeaders is mandatory"),
			[ValidateNotNullOrEmpty()]$canonicalizedResources=$(throw "canonicalizedResources is mandatory")
		)
		$contentLength = $null
		if($null -ne $content) {
			$contentLength = $content.Length
		}
		"$verb`n`n`n$contentLength`n$contentHash`n$contentType`n`n`n`n`n`n`n$canonicalizedHeaders`n$canonicalizedResources"
	}
	$obj
}
