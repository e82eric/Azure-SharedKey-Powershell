$ErrorActionPreference = "stop"

function new_signature_hash_parser { param($storageKey)
	$obj = New-Object PSObject -Property @{ StorageKey = $storageKey }
	$obj | Add-Member -Type ScriptMethod execute { param ($signature)
		$signatureBytes = [Text.Encoding]::UTF8.GetBytes($signature)
		$keyBytes = [Convert]::FromBase64String($this.StorageKey)
		$sha256 = New-Object Security.Cryptography.HMACSHA256(,[byte[]]$keyBytes)
		$hash = $sha256.ComputeHash($signatureBytes)
		[Convert]::ToBase64String($hash)
	}
	$obj
}
