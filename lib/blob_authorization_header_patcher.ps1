$ErrorActionPreference = "stop"

function new_blob_authorization_header_patcher { param(
	$uriParser,
	$canonicalizedResourcesParser,
	$canonicalizedHeadersParser,
	$signatureParser,
	$signatureHashParser,
	$authorizationHeaderParser)
	$obj = New-Object PSObject -Property @{
		UriParser = $uriParser;
		CanonicalizedResourcesParser = $canonicalizedResourcesParser;
		CanonicalizedHeadersParser = $canonicalizedHeadersParser;
		SignatureParser = $signatureParser;
		SignatureHashParser = $signatureHashParser;
		AuthorizationHeaderParser = $authorizationHeaderParser;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$uriElements = $this.UriParser.execute($options.Url)
		$canonicalizedResources = $this.CanonicalizedResourcesParser.execute($uriElements.Operations, $uriElements.Resource)
		$canonicalizedHeaders = $this.CanonicalizedHeadersParser.execute($options.Headers)
		$signature = $this.SignatureParser.execute($options.Verb, $options.Content, $options.ContentHash, $options.ContentType, $canonicalizedHeaders, $canonicalizedResources)
		Write-Host "***Signature***"
		Write-Host $signature
		Write-Host "***End Signature***"
		$signatureHash = $this.SignatureHashParser.execute($signature)
		$options.AuthorizationHeader = $this.AuthorizationHeaderParser.execute($signatureHash)
	}
	$obj
}
