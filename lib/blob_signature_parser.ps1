$ErrorActionPreference = "stop"

function new_blob_signature_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$options = $params.Options
		$verb = $options.Verb.ToUpper()
		$contentLength = $null
		if($null -ne $options.Content) {
			$contentLength = $options.Content.Length
		}
		$contentHash = $options.ContentHash
		$contentType = $options.ContentType 
		$date = $params.DateHeader.Value
		$canonicalizedResources = $params.CanonicalizedResources
		$canonicalizedHeaders = $params.CanonicalizedHeaders
		
		$params.Signature = "$verb`n`n`n$contentLength`n$contentHash`n$contentType`n`n`n`n`n`n`n$canonicalizedHeaders`n$canonicalizedResources"
	}
	$obj
}
