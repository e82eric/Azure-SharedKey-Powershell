$ErrorActionPreference = "stop"

function new_request_builder { param($storageName)
	$obj = New-Object PSObject -Property @{ StorageName = $storageName }
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
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$options = $params.Options
		$content = $options.Content
		$contentType = $null
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
		
		$params.MsHeaders | % {
			$request.Headers.Add($_.name, $_.value) | Out-Null
		}

    if($null -ne $params.AuthorizationHeader) {
      $request.Headers.Add("Authorization", $params.AuthorizationHeader) | Out-Null
    } elseif ($null -ne $options.AuthorizationHeader) {
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
				$this._use_disposeable(($streamWriter = New-Object IO.StreamWriter($request.GetRequestStream())), {
					$streamWriter.Write($content)
					$streamWriter.Flush()
					$streamWriter.Close()
				})
			} else {
				$request.ContentLength = $options.Content.Length
				$requestStream = $request.GetRequestStream()
				$requestStream.Write($options.Content, 0, $options.Content.Length)
				$requestStream.Close()
			}
		}
		$request
	}
	$obj
}
