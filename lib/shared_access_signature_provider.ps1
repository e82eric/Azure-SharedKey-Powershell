param($libDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"
.	"$libDir\blob_canonicalized_resources_parser.ps1"
. "$libDir\signature_hash_parser.ps1"

function new_shared_access_signature_provider { param(
	$storageAccountName,
	$storageAccountKey,
	$version = "2013-08-15",
	$scheme = "https")
	$obj = New-Object PSObject -Property @{
		ResourceCanonicalizer = (new_blob_canonicalized_resources_parser $storageAccountName);
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
		$resource,
		$expiryTimeString)
		$canonicalizedResource = $this.ResourceCanonicalizer.execute(@(), $resource)
		"$signedPermissions`n`n$($expiryTimeString)`n$canonicalizedResource`n`n$($this.Version)`n`n`n`n`n"
	}
	$obj | Add-Member -Type ScriptMethod GetQueryString { param($resource, $signedResource, $signedPermissions, $expiryTime)
		$expiryTimeString = $this._get_date_string($expiryTime)
		$stringToSign = $this._get_string_to_sign($signedPermissions, $resource, $expiryTimeString)
		Write-Host $stringToSign
		$hash = $this.SignatureHasher.execute($stringToSign)
		Write-Host $hash
		#"$resource`?sv=$($this.Version)&sr=$signedResource&st=$($startTimeString)&se=$($expiryTimeString)&sp=$signedPermissions&sig=$hash"
		"$resource`?sv=$($this.Version)&sr=$signedResource&se=$($expiryTimeString)&sp=$signedPermissions&sig=$hash"
	}
	$obj | Add-Member -Type ScriptMethod GetUrl { param($resource, $signedResource, $signedPermissions, $expiryTime)
		"$($this.Scheme)://$($this.StorageAccountName).blob.core.windows.net/$($this.GetQueryString($resource, $signedResource, $signedPermissions, $expiryTime))"
	}
	$obj
}