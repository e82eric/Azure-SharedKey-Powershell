$ErrorActionPreference = "stop"

function new_request_builder {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod _use_disposeable { param($disposeable, $useFunc)
		try {
			& $useFunc
		} finally {
			if ($disposeable -ne $null) {
				if ($disposeable.psbase -eq $null) {
					$disposeable.Dispose()
				} else {
					$disposeable.psbase.Dispose()
				}
			}
		}
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$content = $options.Content
		$contentLength = 0
		
		if($null -ne $content) {
			$contentLength = $options.Content.Length
		}
		
		$request = [Net.WebRequest]::Create($options.Url)

		if($null -ne $options.Timeout) {
			$request.Timeout = $options.Timeout
		}
		
		if($null -ne $options.ContentType) {
			$request.ContentType = $options.contentType
		}

		if($null -ne $options.Accept) {
			$request.Accept = $options.Accept
		}
		
		$request.Method = $options.Verb
		
		if($null -ne $options.AuthorizationHeader) {
			$request.Headers.Add("Authorization", $options.AuthorizationHeader) | Out-Null
		}

		if($null -ne $options.ClientCertificate) {
			$request.ClientCertificates.Add($options.ClientCertificate) | Out-Null
		}

		if($null -ne $options.Headers) {
			$options.Headers | % { $request.Headers.Add($_.name, $_.value) | Out-Null }
		}
		
		if($null -ne $content) {
			if($content -is [string]) {
				Write-Verbose "Executing rest api request. Url: $($options.Url), Verb: $($options.Verb), Content: $($content)"
				$this._use_disposeable(($requestStream = $request.GetRequestStream()), {
					$this._use_disposeable(($streamWriter = New-Object IO.StreamWriter($requestStream)), {
						$streamWriter.Write($content)
						$streamWriter.Flush()
						$streamWriter.Close()
					})
					$requestStream.Close()
				})
			} else {
				Write-Verbose "Executing rest api request. Url: $($options.Url), Verb: $($options.Verb), Content: binary"
				$request.ContentLength = $options.Content.Length
				$this._use_disposeable(($requestStream = $request.GetRequestStream()), {
					$requestStream.Write($options.Content, 0, $options.Content.Length)
					$requestStream.Close()
				})
			}
		} else {
			Write-Verbose "Executing rest api request. Url: $($options.Url), Verb: $($options.Verb)"
		}
		$request
	}
	$obj
}
