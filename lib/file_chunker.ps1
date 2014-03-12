function new_file_chunker {
	$obj = New-Object PSObject -Property @{
		BufferSize = 4096 * 1024
	}
	$obj | Add-Member -Type ScriptMethod _calculateNumberOfBlocks { param($contentLength)
		if($contentLength % $this.BufferSize -eq 0) {
			$contentLength / $this.BufferSize
		} else {
			$toTruncate = $contentLength / $this.BufferSize
			[Math]::Truncate($toTruncate) + 1	
		}
	}
	$obj | Add-Member -Type ScriptMethod _calculateBuffer { param($stream)
		$remaining = $stream.Length - $stream.Position
		if($remaining -lt $this.BufferSize) { 
			$remaining
		} else {
			$this.BufferSize
		}
	}
	$obj | Add-Member -Type ScriptMethod _createBlockId { param($blockNumber)
		$longBlockId = $blockNumber.ToString("d10")
		$utf8BlockId = [Text.Encoding]::UTF8.GetBytes($longBlockId)
		[Convert]::ToBase64String($utf8BlockId)
	}
	$obj | Add-Member -Type ScriptMethod ChunkFile { param($filePath, $chunkFunc)
		$file = Get-Item $filePath
		$file = new-object IO.FileStream($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read)
		$numberOfBlocks = $this._calculateNumberOfBlocks($file.Length)

		for($i = 0; $i -le $numberOfBlocks - 1; $i++) {
			$blockId = $this._createBlockId($i)
			$bufferLength = $this._calculateBuffer($file)
			$buffer = new-object byte[] $bufferLength 
			$file.Read($buffer, 0, $bufferLength) | out-null
			$md5 = [Security.Cryptography.MD5]::Create()
			$hashBytes = $md5.ComputeHash($buffer)
			$hash = [Convert]::ToBase64String($hashBytes)

			& $chunkFunc $buffer $blockId $hash
		}	
	}
	$obj
}
