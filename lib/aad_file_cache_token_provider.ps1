$ErrorActionPreference = "stop"
[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null

function new_aad_file_cache_token_provider { param($cacheIdentifier, $aadTenantId, $resourceAppIdUri, $tokenProvider, $filePath, $loginHint)
	$obj = New-Object PSObject -Property @{
		FilePath = $filePath;
		Serializer = (New-Object Web.Script.Serialization.JavaScriptSerializer);
		Encoder = (New-Object Text.Utf8Encoding);
		Resource = $resourceAppIdUri;
		AadTenantId = $aadTenantId;
		TokenProvider = $tokenProvider;
		CacheIdentifier = $cacheIdentifier;
		LoginHint = $loginHint;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$token = $this._getToken()
		$options.AuthorizationHeader = "Bearer $($token.AccessToken)"
	}
	$obj | Add-Member -Type ScriptMethod _getToken {
		$result = $null
		Write-Debug "checking for cache file $($this.FilePath)"
		if ((Test-Path $this.FilePath)) {
			Write-Debug "--cache file found. $($this.FilePath)"
			$tokens = $this._getTokensFromFile()
			$trimmedTokens = $this._trimExpired($tokens)
			Write-Debug "checking for cached token $($this.CacheIdentifier)"
			$savedToken = $trimmedTokens | ? { $this.CacheIdentifier -eq $this.CacheIdentifier -and $_.Resource -eq $this.Resource -and $_.AadTenantId -eq $this.AadTenantId } | Select -First 1
			if($null -ne $savedToken) {
				Write-Debug "--found cached token $($this.CacheIdentifier)"
				$adalToken = $this.TokenProvider.GetTokenByRefreshToken($savedToken.RefreshToken)
				$result = $this._saveTokens($adalToken, $trimmedTokens)
			} else {
				Write-Debug "--could not find cached token $($this.CacheIdentifier)"
				$adalToken = $this.TokenProvider.GetToken()
				$result = $this._saveTokens($adalToken, $trimmedTokens)
			}
		} else {
			Write-Debug "--could not find a cache file $($this.FilePath)"
			$adalToken = $this.TokenProvider.GetToken()
			$result = $this._saveTokens($adalToken, @())
		}
		$result
	}
	$obj | Add-Member -Type ScriptMethod _mapAdalToken { param($adalToken)
		@{
			Resource = $this.Resource;
			AadTenantId = $this.AadTenantId;
			RefreshToken = $adalToken.RefreshToken;
			ExpiresOn = $adalToken.ExpiresOn;
			AccessToken = $adalToken.AccessToken;
			CacheIdentifier = $this.CacheIdentifier;
		}
	}
	$obj | Add-Member -Type ScriptMethod _saveTokens { param($newAdalToken, $tokens)
		$tokensToSave = New-Object Collections.ArrayList
		$newToken = $this._mapAdalToken($newAdalToken)
		Write-Debug "Checking if tokens should be saved."
		$tokens | % {
			Write-Debug "--Token: Resource: $($_.Resource), AadTenantId: $($_.AadTenantId), ExpiresOn: $($_.ExpiresOn), CacheIdentifier: $($_.CacheIdentifier)"
			Write-Debug "--Criteria: $($_.CacheIdentifier) -ne $($this.CacheIdentifier) -and $($_.Resource) -ne $($this.Resource) -and $($_.AadTenantId) -ne $($this.AadTenantId)"
			$shouldAdd = $_.CacheIdentifier -ne $this.CacheIdentifier -and $_.Resource -ne $this.Resource -and $_.AadTenantId -ne $this.AadTenantId
			Write-Debug "--Result: $($shouldAdd)"
			if($true -eq $shouldAdd) {
				$tokensToSave.Add($_) | Out-Null
			}
		 }
		$tokensToSave.Add($newToken) | Out-Null

		$tokensJson = $this.Serializer.Serialize($tokensToSave)
		$tokensJsonBytes = $this.Encoder.GetBytes($tokensJson)
		$tokensJsonEncryptedBytes = [Security.Cryptography.ProtectedData]::Protect(
			$tokensJsonBytes, 
			$null, 
			[Security.Cryptography.DataProtectionScope]::CurrentUser)
		[IO.File]::WriteAllBytes($this.FilePath, $tokensJsonEncryptedBytes)
		$newToken
	}
	$obj | Add-Member -Type ScriptMethod _getTokensFromFile {
		$tokensJsonEncryptedBytes = [IO.File]::ReadAllBytes($this.FilePath)	
		$tokensJsonBytes = [Security.Cryptography.ProtectedData]::Unprotect(
			$tokensJsonEncryptedBytes, 
			$null, 
			[Security.Cryptography.DataProtectionScope]::CurrentUser)	
		$tokensJson = $this.Encoder.GetString($tokensJsonBytes)
		$result = $this.Serializer.DeserializeObject($tokensJson)
		Write-Debug "Tokens retrived from file"
		$result | % {
			Write-Debug "--Token: Resource: $($_.Resource), AadTenantId: $($_.AadTenantId), ExpiresOn: $($_.ExpiresOn), CacheIdentifier: $($_.CacheIdentifier)"
		}
		$result
	}
	$obj | Add-Member -Type ScriptMethod _trimExpired { param($tokens)
		$result = $tokens | ? {
			Write-Debug "Checking if Token is expired"
			Write-Debug "--Token: Resource: $($_.Resource), AadTenantId: $($_.AadTenantId), ExpiresOn: $($_.ExpiresOn), CacheIdentifier: $($_.CacheIdentifier)"
			Write-Debug "--Criteria: $($_.ExpiresOn) -gt $([DateTime]::UtcNow)"
			$expired = $_.ExpiresOn -gt [DateTime]::UtcNow
			Write-Debug "--Result: $($expired)"
			$expired
		}
		$result
	}
	$obj._getToken() | Out-Null
	$obj
}
