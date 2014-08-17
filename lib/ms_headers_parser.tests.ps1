$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "add the ms headers to the options" {
	$stubedNow = "now1"
	$parser = new_ms_headers_parser
	$parser | Add-Member -Type ScriptMethod _now { $stubedNow } -Force
	Context "when the options do not have any ms headers" {
		$options = @{ Version = "version1"; BlobType = "blobType1" }
		$parser.execute($options)
		It "adds the data header" {
			($options.Headers | ? { $_.name -eq "x-ms-date" }).value | should equal $stubedNow
		}
		It "adds the version header" {
			($options.Headers | ? { $_.name -eq "x-ms-version" }).value | should equal $options.Version
		}
		It "adds three headers" {
			$options.Headers.Count | should equal 3
		}
		It "adds the blob type from the options" {
			$options = @{ Version = "version1"; BlobType = "blobType1" }
			$parser.execute($options)
			($options.Headers | ? { $_.name -eq "x-ms-blob-type" }).value | should equal $options.BlobType
		}
		It "does not add the blob type when the options does not have a blob type" {
			$options = @{ Version = "version1"; }
			$parser.execute($options)
			$options.Headers | ? { $_.name -eq "x-ms-blob-type" } | should equal $null 
		}
	}
	Context "when the ms headers are not null is the ms headers" {
		It "it adds the date version and blob type and leaves the existing headers" {
			$options = @{
				Version = "version1";
				BlobType = "blobType1";
				Headers = @( @{ name = "x-ms-prop1"; value = "val1"; }, @{ name = "x-ms-prop2"; value = "val2" } )
			}
			$parser.execute($options)
			$options.Headers.Count | should equal 5
		}
		It "it does not add the standard properties again if they already exist" {
			$options = @{
				Version = "version1";
				BlobType = "blobType1";
				Headers = @(
					@{ name = "x-ms-prop1"; value = "val1"; },
					@{ name = "x-ms-prop2"; value = "val2" },
					@{ name = "x-ms-date"; value = "date1" },
					@{ name = "x-ms-version"; value = "version1" },
					@{ name = "x-ms-blob-type"; value = "blobtype1" },
					@{ name = "header1"; value = "header1Value" }
				)
			}
			$parser.execute($options)
			$options.Headers.Count | should equal 6
		}
	}
}
