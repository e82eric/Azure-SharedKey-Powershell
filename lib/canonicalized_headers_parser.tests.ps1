$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "create canonicalized headers" {
	$parser = new_canonicalized_headers_parser
	Context "where this is only one header" {
		It "concatenates the header together with :" {
			$msHeaders = @( @{ name = "x-ms-date"; value = "d-header-v" } )
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-date:d-header-v"
		}
	}
	Context "when there are two headers" {
		It "concatenates the headers together with : and seperates them with new lines" {
			$msHeaders = @(
				@{ name = "x-ms-date"; value = "d-header-v" },
				@{ name = "x-ms-version"; value = "v-header-v" }
			)
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
		It "sorts the headers alphabeticaly" {
			$msHeaders = @(
				@{ name = "x-ms-version"; value = "v-header-v" },
				@{ name = "x-ms-date"; value = "d-header-v" }
			)
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
	}
	Context "when there are three headers" {
		It "concatenates the headers together with : and seperates them with new lines" {
			$msHeaders = @(
				@{ name = "x-ms-blob"; value = "BlockBlob" },
				@{ name = "x-ms-date"; value = "d-header-v" },
				@{ name = "x-ms-version"; value = "v-header-v" }
			)
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-blob:BlockBlob`nx-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
		It "sorts the headers alphabeticaly" {
			$msHeaders = @(
				@{ name = "x-ms-version"; value = "v-header-v" },
				@{ name = "x-ms-blob"; value = "BlockBlob" },
				@{ name = "x-ms-date"; value = "d-header-v" }
			)
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-blob:BlockBlob`nx-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
	}
	Context "when there are 3 ms headers and non ms headers" {
			$msHeaders = @(
				@{ name = "header1"; value = "header1Value" },
				@{ name = "x-ms-version"; value = "v-header-v" },
				@{ name = "x-ms-blob"; value = "BlockBlob" },
				@{ name = "x-ms-date"; value = "d-header-v" },
				@{ name = "header2"; value = "header2Value" }
			)
			$result = $parser.execute($msHeaders)
			$result | should equal "x-ms-blob:BlockBlob`nx-ms-date:d-header-v`nx-ms-version:v-header-v"
	}
}
