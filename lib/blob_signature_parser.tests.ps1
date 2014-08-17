$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "create signature" {
	$parser = new_blob_signature_parser
	It "capitalizes the verb" {
		$result = $parser.execute("verb1", @{ Length = 5 }, $null, $null, "headers 1", "resource 1")
		$result | should be "VERB1`n`n`n5`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
	}
	Context "when there is no content" {
		It "returns the verb concatenated with twelve new lines, the canonicalized header and resource seperated by a new line" {
			$result = $parser.execute("VERB 1", $null, $null, $null, "headers 1", "resource 1")
			$result | should be "VERB 1`n`n`n`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is content" {
		It "adds the content length at the fourth line" {
			$result = $parser.execute("VERB 1", @{ Length = 5 }, $null, $null, "headers 1", "resource 1")
			$result | should be "VERB 1`n`n`n5`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is no content type" {
		$result = $parser.execute("VERB 1", @{ Length = 12 }, $null, $null, "headers 1", "resource 1")
		It "leaves the sixth line blank" {
			$result | should be "VERB 1`n`n`n12`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is a content type" {
		$result = $parser.execute("VERB 1", @{ Length = 12 }, $null, "text/plain; charset=UTF-8", "headers 1", "resource 1")
		It "sets the 6th line to the hash" {
			$result | should be "VERB 1`n`n`n12`n`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is no md5 hash" {
		$result = $parser.execute("VERB 1", @{ Length = 12 }, $null, "text/plain; charset=UTF-8", "headers 1", "resource 1")
		It "leaves the fifth line blank" {
			$result | should be "VERB 1`n`n`n12`n`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is a md5 hash" {
		$result = $parser.execute("VERB 1", @{ Length = 12 }, "contenthash1", "text/plain; charset=UTF-8", "headers 1", "resource 1")
		It "sets the 5th line to the hash" {
			$result | should be "VERB 1`n`n`n12`ncontenthash1`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
}
