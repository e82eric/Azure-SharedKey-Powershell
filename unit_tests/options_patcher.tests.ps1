$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\..\lib\$sut"

$script:numberOfMsHeadersCalls = 0
$script:numberOfBaseOptionsCalls = 0

$version = "version1"
$msHeadersPatcher = New-Object PSObject
$msHeadersPatcher | Add-Member -Type ScriptMethod execute { param($options) $script:numberOfMsHeadersCalls++ }
$baseOptionsPatcher = New-Object PSObject
$baseOptionsPatcher | Add-Member -Type ScriptMethod execute { param($options) $script:numberOfBaseOptionsCalls++ }

$patcher = new_options_patcher $baseOptionsPatcher $version $msHeadersPatcher

Describe "options_patcher" {
	Context "version is not set" {
		$options = @{ }
		$patcher.execute($options)
		It "sets the version to the default" {
			$options.Version | should equal "version1" 
		}
	}
	Context "version is set" {
		$options = @{ Version = "version2" }
		$patcher.execute($options)
		It "sets the version to the default" {
			$options.Version | should equal "version2" 
		}
	}
	Context "delegate to other option patchers" {
		It "calls the ms headers options patcher" {
			$script:numberOfMsHeadersCalls = 0
			$patcher.execute(@{})
			$script:numberOfMsHeadersCalls | should be 1
		}
		It "calls the base options patcher" {
			$script:numberOfBaseOptionsCalls = 0
			$patcher.execute(@{})
			$script:numberOfBaseOptionsCalls | should be 1
		}
	}
}
