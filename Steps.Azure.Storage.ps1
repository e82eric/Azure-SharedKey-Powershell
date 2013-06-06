param ($storageKey)
$ErrorActionPreference = "Stop"
$script:storageKey = $storageKey

function _nameValue ($name, $value) {
	New-Object PsObject -Property @{Name = $name; Value = $value }
}

function _hash ($signature) {
	Write-Host $script:storageKey
	$signatureBytes = [Text.Encoding]::UTF8.GetBytes($signature)
	$sixtyFourString = [Convert]::FromBase64String($script:storageKey)
	$sha256 = New-Object System.Security.Cryptography.HMACSHA256
	$sha256.Key = $sixtyFourString
	$hash = $sha256.ComputeHash($signatureBytes)
	[Convert]::ToBase64String($hash)
}

function _createOperationsString ($operations) {
	if($operations -eq $null) { return [String]::Empty }
	if($operations.Length -eq 0) { return [String]::Empty }
	[String]::Join("`n", $($operations | %  {"$($_.Name.ToLower()):$($_.Value.ToLower())" } | Sort))
}

function _createCanonicalizedResource ($account, $uri, $operations) {
	$operationsString= _createOperationsString $operations
	if($operationsString -eq [string]::empty) { return "/$account/$uri" } 
	"/$account/$uri`n$operationsString"	
}

function _createCanonicalizedHeaders ($msHeaders) {
	$concatenatedHeaders = $msHeaders | % { "$($_.Name):$($_.Value)" }
	[string]::join("`n", ($concatenatedHeaders | Sort))
}

function _createSignature ($verb, $canonicalizedHeaders, $canonicalizedResource, $contentLength) {
	"$($verb.ToUpper())`n`n`n$contentLength`n`n`n`n`n`n`n`n`n$canonicalizedHeaders`n$canonicalizedResource"
}

function _createAuthorizationHeader ($account, $signaturehash) {
	_nameValue "Authorization" "SharedKey $account`:$signaturehash"
}

function _parseUri ($uri) {
	$blobDomain = ".blob.core.windows.net"
	$startOfBlobDomain = $uri.indexof($blobDomain);
	$account = $uri.substring(7, $startOfBlobDomain -7)
	
	$startOfResource = $startOfBlobDomain + $blobDomain.Length + 1
	$indexOfQuestionMark = $uri.indexof("?")

	$lengthOfResource = $uri.Length - $startOfResource
	
	$operations = $null

	if($indexOfQuestionMark -ne -1) {
		$lengthOfResource = $indexOfQuestionMark - $startOfResource 

		$operationString = $uri.SubString($indexOfQuestionMark + 1, $uri.Length - ($indexOfQuestionMark + 1))
		$operations = @($operationString.split('&') | % { $split = $_.split('='); _nameValue $split[0] $split[1] })
	}

	$resource = $uri.substring($startOfResource, $lengthOfResource)

	New-Object PsObject -Property @{Account = $account; Resource = $resource; Operations = $operations }
}

function _createMSHeaders ($content) {
	$now = [DateTime]::UtcNow.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
	$dateHeader = _nameValue "x-ms-date" $now
	$versionHeader = _nameValue "x-ms-version" "2009-09-19"
	$result = @($dateHeader, $versionHeader)
	if($content -ne $null) {
		$blobHeader = _nameValue "x-ms-blob-type" "BlockBlob"
		$result = $result + $blobHeader
	}
	$result
}

function _createSignatureElements ($verb, $urlElements, $msHeaders, $contentLength) {
	$canonicalizedHeaders = _createCanonicalizedHeaders $msHeaders
	$canonicalizedResource = _createCanonicalizedResource $urlElements.Account $urlElements.Resource $urlElements.Operations 
	$signature = _createSignature $verb $canonicalizedHeaders $canonicalizedResource $contentLength
	$signatureHash = _hash $signature
	New-Object PsObject -Property @{
		CanonicalizedHeaders = $canonicalizedHeaders; 
		CanonicalizedResource = $canonicalizedResource;
		Signature = $signature;
		SignatureHash = $signatureHash
	}
}

function Request ($verb, $url, $content) {
	$contentLength = $content.Length
	$msHeaders = _createMSHeaders $content
	$urlElements = _parseUri $url
	
	$signatureElements = _createSignatureElements $verb $urlElements $msHeaders $contentLength 
	$authorizationHeader = _createAuthorizationHeader $urlElements.Account $signatureElements.SignatureHash
	$webRequest = [Net.WebRequest]::Create($url)
	$webRequest.Method = $verb 
	$webRequest.ContentLength = 0
	
	$msHeaders | % { $webRequest.Headers.Add($_.Name, $_.Value) }

	$webRequest.Headers.Add($authorizationHeader.Name, $authorizationHeader.Value) | Out-Null
	if($content -ne $null) {
		$webRequest.ContentLength = $contentLength 
		$requestStream = $webRequest.GetRequestStream()
		$requestStream.Write($content, 0, $contentLength)
		$requestStream.Close()
	}

	$response = $webRequest.GetResponse()
	
	$xmlResponseBlock = { 
		$stream = $this.Response.GetResponseStream()
		$reader = New-Object IO.StreamReader($stream)
		$result = $reader.ReadToEnd()
		$this.Response.Close()
		$stream.Close()
		$reader.Close()
		[xml]$result
	}	

	$downloadResponseBlock = {
		param($filePath)
		$stream = $this.Response.GetResponseStream()
		$file = [System.IO.File]::Create($filePath)
		$buffer = New-Object Byte[] 1024

		Do {
			$bytesRead = $stream.Read($buffer, 0, $buffer.Length)
			$file.Write($Buffer, 0, $BytesRead)
		} While ($bytesRead -gt 0)

		$this.Response.Close()
		$stream.Close()

		$file.Flush()
		$file.Close()
		$file.Dispose()
	}

	$result = New-Object PsObject -Property @{ 
		WebRequest = $webRequest;
		UrlElements = $urlElements;
		SignatureElements = $signatureElements;
		Response = $response
	}
	
	Add-Member -InputObject $result -MemberType ScriptMethod -Name GetXmlResponse -Value $xmlResponseBlock
	Add-Member -InputObject $result -MemberType ScriptMethod -Name DownloadResponse -Value $downloadResponseBlock
	$result
}
