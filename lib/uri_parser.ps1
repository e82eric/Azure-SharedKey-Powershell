function new_uri_parser { param($clientType)
	$obj = New-Object PSObject -Property @{ ClientType = $clientType }
	$obj | Add-Member -Type ScriptMethod -Name _splitParameter -Value { param ($parameterString)
		$firstEqualIndex = $parameterString.IndexOf('=')
		$name = $parameterString.SubString(0, $firstEqualIndex)
		$value = $parameterString.SubString($firstEqualIndex + 1, $parameterString.Length - $firstEqualIndex - 1)
		@{ name = $name; value = $value }
	}
	$obj | Add-Member -Type ScriptMethod -Name _splitParameters -Value { param ($queryString)
		$result = $queryString.Split("&") | % { $this._splitParameter($_) } 
		,@($result)
	}
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$uri = $params.Options.Url
		$accountStartIndex = 7

		if($uri.SubString(0, 5) -eq "https") { $accountStartIndex = 8 }

		$blobDomain = ".$($this.ClientType).core.windows.net"
		$startOfBlobDomain = $uri.indexof($blobDomain)
		$params.Account = $uri.substring($accountStartIndex, $startOfBlobDomain - $accountStartIndex)
		
		$startOfResource = $startOfBlobDomain + $blobDomain.Length + 1
		$indexOfQuestionMark = $uri.indexof("?")

		$lengthOfResource = $uri.Length - $startOfResource

		if($indexOfQuestionMark -ne -1) {
			$lengthOfResource = $indexOfQuestionMark - $startOfResource 

			$operationString = $uri.SubString($indexOfQuestionMark + 1, $uri.Length - ($indexOfQuestionMark + 1))
			$operations = $this._splitParameters($operationString) 
			if($null -ne $operations) {
				$params.Operations = $operations
			}
		}

		$params.Resource = $uri.substring($startOfResource, $lengthOfResource)
	}
	$obj
}
