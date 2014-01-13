function new_azure_rest_client ($subscriptionId, $cert) {
	$obj = New-Object PSObject -Property @{
		Cert = $cert;
		SubscriptionId = $subscriptionId

	}
        $obj | Add-Member -Type ScriptMethod -Name Request -Value { param ($options)
		$options.Url = "https://management.core.windows.net/$($this.subscriptionId)/$($options.Resource)"

                $content = $options.Content
                $contentType = $null
                $contentLength = $null
                
                if($content -ne $null) {
                        $contentLength = $options.Content.Length
                }
                
                $request = [Net.WebRequest]::Create($options.Url)
                $request.ClientCertificates.Add($this.Cert) | Out-Null
		$request.Headers.Add("x-ms-version", "2013-08-01") | Out-Null

		$request.ContentType = "application/xml"
                $request.Method = $options.Verb

                if($content -ne $null) {
                        $request.ContentLength = $options.Content.Length
                        $requestStream = $request.GetRequestStream()
			$byteArray = [Text.Encoding]::UTF8.GetBytes($options.Content)
                        $requestStream.Write($byteArray, 0, $byteArray.Length) | Out-Null
                        $requestStream.Close() | Out-Null
                }
                
                $response = $request.GetResponse()
                
                $result = $null
                
                try {
			if($options.OnResponse -ne $null) {
				$result = & $options.OnResponse $response
			}
                }
                catch { 
                        throw $_ 
                } finally {
                        $response.Close() | Out-Null
                }
                
                $result
        }
	$obj | Add-Member -Type ScriptMethod ExecuteOperation { param ($verb, $resource, $content)
		$serviceResult = $this.Request(@{ Verb = $verb; Resource = $resource; Content = $content; OnResponse = $parse_operation_id })

		$status = $null
		while ($true) {
			$operationResult = $this.Request(@{ Verb = "GET"; Resource = "operations/$($serviceResult.OperationId)"; OnResponse = $parse_xml })
			$status = $operationResult.Operation.Status
			Write-Host $status
			if($operationResult.Body -ne $null) {
				Write-Host $operationResult.Body
			}
			if($status -ne "InProgress") {
				break
			}
		}
		if($status -ne "Succeeded") {
			throw $status
		}
	}
	$obj
}
                
$parse_operation_xml = { param ($response)
	$operationId = $response.Headers.Get("x-ms-request-id")
        $stream = $response.GetResponseStream()
        $reader = New-Object IO.StreamReader($stream)
        $result = $reader.ReadToEnd()
        $stream.Close()
        $reader.Close()
        $body = [xml]$result
	@{ Body = $body; OperationId = $operationId }
}

$parse_operation_id = { param ($response)
	$operationId = $response.Headers.Get("x-ms-request-id")
        $stream = $response.GetResponseStream()
        $reader = New-Object IO.StreamReader($stream)
        $result = $reader.ReadToEnd()
        $stream.Close()
        $reader.Close()
        $body = $result
	@{ Body = $body; OperationId = $operationId }
}

$parse_xml = { param ($response)
        $stream = $response.GetResponseStream()
        $reader = New-Object IO.StreamReader($stream)
        $result = $reader.ReadToEnd()
        $stream.Close()
        $reader.Close()
        [xml]$result
}
