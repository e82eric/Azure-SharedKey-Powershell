param($libDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"
.	"$($libDir)\table_canonicalized_resources_parser.ps1"
. "$($libDir)\signature_hash_parser.ps1"
[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

function new_table_shared_access_signature_provider { param(
	$storageAccountName,
	$storageAccountKey,
	$version = "2013-08-15",
	$scheme = "https")
	$obj = New-Object PSObject -Property @{
		ResourceCanonicalizer = (new_table_canonicalized_resources_parser $storageAccountName);
		SignatureHasher = (new_signature_hash_parser $storageAccountKey);
		StorageAccountName = $storageAccountName;
		Version = $version;
		Scheme = $scheme;
	}
	$obj | Add-Member -Type ScriptMethod _get_date_string { param($dateTime)
		$dateTime.ToString("yyyy-MM-ddTHH:mm:ssZ", [Globalization.CultureInfo]::InvariantCulture)
	}
	$obj | Add-Member -Type ScriptMethod _get_string_to_sign { param(
		$signedPermissions,
		$tableName,
		$expiryTimeString)
		$lowerTableName = $tableName.ToLower()
		$canonicalizedResource = $this.ResourceCanonicalizer.execute($lowerTableName)
		"$($signedPermissions)`n`n$($expiryTimeString)`n$($canonicalizedResource)`n`n$($this.Version)`n`n`n`n"
	}
	$obj | Add-Member -Type ScriptMethod GetQueryString { param($tableName, $signedPermissions, $expiryTime)
		$expiryTimeString = $this._get_date_string($expiryTime)
		$stringToSign = $this._get_string_to_sign($signedPermissions, $tableName, $expiryTimeString)
		Write-Verbose "Shared access signature string to sign: $($stringToSign)"
		$hash = $this.SignatureHasher.execute($stringToSign)
		Write-Verbose "Shared access signature hash: $($hash)"
		$encodedHash = [Web.HttpUtility]::UrlEncode($hash) 
		"$resource`?sv=$($this.Version)&tn=$tableName&se=$($expiryTimeString)&sp=$signedPermissions&sig=$encodedHash"
	}
	$obj | Add-Member -Type ScriptMethod GetUrl { param($tableName, $signedPermissions, $expiryTime)
		"$($this.Scheme)://$($this.StorageAccountName).table.core.windows.net/$($tableName)$($this.GetQueryString($tableName, $signedPermissions, $expiryTime))"
	}
	$obj
}
