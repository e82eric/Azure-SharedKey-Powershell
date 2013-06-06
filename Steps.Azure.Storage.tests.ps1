$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "create operations string" {
	Context "when the operations are null" {
		It "returns an empyt string" {
			$result = _createOperationsString
			$result | should equal ""
		}
	}
	Context "when there are no operations" {
		It "returns an empty string" {
			$result = _createOperationsString @()
			$result | should equal ""
		}
	}
	Context "when there is one operation" {
		It "converts the name to lower case" {
			$operation = _nameValue "OpNaMe" "opvalue"
			$result = _createOperationsString $operation
			$result | should equal "opname:opvalue"
		}
		It "converts the value to lower case" {
			$operation = _nameValue "opname" "OpVAlUe"
			$result = _createOperationsString $operation
			$result | should equal "opname:opvalue"
		}
		It "concatenates the name and value with a :" {
			$operation = _nameValue "opname" "opvalue"
			$result = _createOperationsString $operation
			$result | should be "opname:opvalue"
		}
	}
	Context "when there are two operations" {
		It "concatenates the operations with a new line" {
			$operation1 = _nameValue "op1name" "op1value"
			$operation2 = _nameValue "op2name" "op2value"
			$result = _createOperationsString @($operation1,$operation2)
			$result | should be "op1name:op1value`nop2name:op2value"
		}
		It "sorts the operations alphabetically by name" {
			$operation1 = _nameValue "bop1name" "op1value"
			$operation2 = _nameValue "aop2name" "op2value"
			$result = _createOperationsString @($operation1,$operation2)
			$result | should be "aop2name:op2value`nbop1name:op1value"
			
		}
	}
	Context "when there are three operations" {
		It "concatenates the operations with a new line" {
			$operation1 = _nameValue "op1name" "op1value"
			$operation2 = _nameValue "op2name" "op2value"
			$operation3 = _nameValue "op3name" "op3value"
			$result = _createOperationsString @($operation1,$operation2,$operation3)
			$result | should be "op1name:op1value`nop2name:op2value`nop3name:op3value"
		}
		It "sorts the operations alphabetically by name" {
			$operation1 = _nameValue "bopname" "opbvalue"
			$operation2 = _nameValue "aopname" "opavalue"
			$operation3 = _nameValue "copname" "opcvalue"
			$result = _createOperationsString @($operation1,$operation2,$operation3)
			$result | should be "aopname:opavalue`nbopname:opbvalue`ncopname:opcvalue"
			
		}
	}
}

Describe "create canonicalized resource" {
	Context "when there are operations" {
		It "concatenates the account, uri with a / and the operations string with new line" {
			$sutOperations = "operations 1"
			Mock _createOperationsString { return "operations string 1" } -ParameterFilter { $operations -eq $sutOperations }
			$result = _createCanonicalizedResource "account 1" "uri 1" $sutOperations
			$result | should equal "/account 1/uri 1`noperations string 1"
		}
	}
	Context "when there are not operations" {
		It "concatenates the account and uri with a /" {
			$sutOperations = "operations 1"
			Mock _createOperationsString { return [string]::empty } -ParameterFilter { $operations -eq $sutOperations }
			$result = _createCanonicalizedResource "account 1" "uri 1" $sutOperations
			$result | should equal "/account 1/uri 1"
		}
	}
}

Describe "create canonicalized headers" {
	Context "where this is only one header" {
		It "concatenates the header together with :" {
			$dateHeader = _nameValue "x-ms-date" "d-header-v"
			$result = _createCanonicalizedHeaders $dateHeader
			$result | should equal "x-ms-date:d-header-v"
		}
	}
	Context "when there are two headers" {
		It "concatenates the headers together with : and seperates them with new lines" {
			$dateHeader = _nameValue "x-ms-date" "d-header-v"
			$versionHeader = _nameValue "x-ms-version" "v-header-v"
			$result = _createCanonicalizedHeaders @($dateHeader, $versionHeader)
			$result | should equal "x-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
		It "sorts the headers alphabeticaly" {
			$dateHeader = _nameValue "x-ms-date" "d-header-v"
			$versionHeader = _nameValue "x-ms-version" "v-header-v"
			$result = _createCanonicalizedHeaders @($versionHeader, $dateHeader) 
			$result | should equal "x-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
	}
	Context "when there are three headers" {
		It "concatenates the headers together with : and seperates them with new lines" {
			$blobHeader = _nameValue "x-ms-blob" "BlockBlob"
			$dateHeader = _nameValue "x-ms-date" "d-header-v"
			$versionHeader = _nameValue "x-ms-version" "v-header-v"
			$result = _createCanonicalizedHeaders @($blobHeader, $dateHeader, $versionHeader)
			$result | should equal "x-ms-blob:BlockBlob`nx-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
		It "sorts the headers alphabeticaly" {
			$blobHeader = _nameValue "x-ms-blob" "BlockBlob"
			$dateHeader = _nameValue "x-ms-date" "d-header-v"
			$versionHeader = _nameValue "x-ms-version" "v-header-v"
			$result = _createCanonicalizedHeaders @($versionHeader, $blobHeader, $dateHeader) 
			$result | should equal "x-ms-blob:BlockBlob`nx-ms-date:d-header-v`nx-ms-version:v-header-v"
		}
	}
}

Describe "create signature" {
	It "capitalizes the verb" {
			$result = _createSignature "verb1" "headers 1" "resource 1" 5
			$result | should be "VERB1`n`n`n5`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
	}
	Context "when there is no content" {
		It "returns the verb concatenated with twelve new lines, the canonicalized header and resource seperated by a new line" {
			$result = _createSignature "VERB 1" "headers 1" "resource 1"
			$result | should be "VERB 1`n`n`n`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
	Context "when there is content" {
		It "adds the content length at the fourth line" {
			$result = _createSignature "VERB 1" "headers 1" "resource 1" 5
			$result | should be "VERB 1`n`n`n5`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
		}
	}
}

Describe "create authorization header" {
	Context "create authorization header" {
		It "sets the name to Authorization Header" {
			$result = _createAuthorizationHeader "account1" "signaturehash1"
			$result.Name | should equal "Authorization"
		}
		It "concatenates SharedKey the account name and the signature hash for the value" {
			$result = _createAuthorizationHeader "account1" "signaturehash1"
			$result.Value | should equal "SharedKey account1:signaturehash1"
		}
	}
}

Describe "parse uri" {
	Context "when there are no operations and the resource is a container" {
		It "parses the account name out of the start of the uri" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/resource"
			$result.Account | should equal "AccountName1"
		}
		It "parses the name from the end of the uri" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/resource"
			$result.Resource | should equal "resource"
		}
		It "returns null for operation" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/resource"
			$result.Operations | should equal $null 
		}
	}
	Context "when there are no operations and the resource is a blob" {
		It "parses the account name out of the start of the uri" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob"
			$result.Account | should equal "AccountName1"
		}	
		It "uses the end the url for the resource" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob"
			$result.Resource | should equal "container/blob"
		}	
		It "returns null for operation" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob"
			$result.Operations | should equal $null 
		}
	}
	Context "when there is one operation and the resource is a blob" {
		It "parses the account name out of the start of the uri" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob?comp=list"
			$result.Account | should equal "AccountName1"
		}	
		It "uses the end the url before the ? for the resource" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob?comp=list"
			$result.Resource | should equal "container/blob"
		}	
		It "parses the name and value of the operation between the =" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob?comp=list"
			$result.Operations.Length | should equal 1
			$result.Operations[0].Name | should equal "comp"
			$result.Operations[0].Value | should equal "list"
		}
	}
	Context "when there is two operations and the resource is a blob" {
		It "parses the name and value of the operation between the =" {
			$result = _parseUri "http://AccountName1.blob.core.windows.net/container/blob?restype=container&comp=list"
			$result.Operations.Length | should equal 2 
			$result.Operations[0].Name | should equal "restype"
			$result.Operations[0].Value | should equal "container"
			$result.Operations[1].Name | should equal "comp"
			$result.Operations[1].Value | should equal "list"
		}
	}
}
