$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "create signature" {
	$parser = new_table_signature_parser
	Context "the verb is lowercase" {
		It "capitalizes the verb" {
			$result = $parser.execute("verb1", $null, $null, "date1", "resource 1")
			$result | should be "VERB1`n`n`ndate1`nresource 1"
		}
	}
	Context "the verb is upper case" {
		It "leaves the verb capitalized" {
			$result = $parser.execute("VERB1", $null, $null, "date1", "resource 1")
			$result | should be "VERB1`n`n`ndate1`nresource 1"
		}
	}
	Context "the no required fields are null" {
		It "leaves lines 2 and 3 blank" {
			$result = $parser.execute("VERB1", $null, $null, "date1", "resource 1")
			$result | should be "VERB1`n`n`ndate1`nresource 1"
		}
	}
	Context "content hash is not null" {
		It "sets the second line to the hash" {
			$result = $parser.execute("VERB1", "hash1", $null, "date1", "resource 1")
			$result | should be "VERB1`nhash1`n`ndate1`nresource 1"
		}
	}
	Context "content type is not null" {
		It "sets the third line to the content type" {
			$result = $parser.execute("VERB1", $null, "text/plain", "date1", "resource 1")
			$result | should be "VERB1`n`ntext/plain`ndate1`nresource 1"
		}
	}
}
