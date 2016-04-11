$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\..\lib\$sut"
. "$here\fake_announcer.ps1"
$script:fakeAnnouncer = new_fake_announcer

Describe "get web exception" {
	$handler = new_retry_handler { } $script:fakeAnnouncer
	Context "when the first exception has a WexExceptionStatus" {
		It "returns the first exception" {
			$exception = @{ Status = [Net.WebExceptionStatus]::Timeout }
			$handler._getWebException($exception) | should equal $exception
		}
	}
	Context "when the second exception has a WebExceptionStatus" {
		It "returns the second exception" {
			$secondException = @{ Status = [Net.WebExceptionStatus]::Timeout }
			$handler._getWebException(@{ InnerException = $secondException }) | should equal $secondException
		}
	}
	Context "when the third exception has a WebExceptionStatus" {
		It "returns the third exception" {
			$thirdException = @{ Status = [Net.WebExceptionStatus]::Timeout }
			$handler._getWebException(@{ InnerException = @{ InnerException = $thirdException } }) | should equal $thirdException
		}
	}
}
Describe "write response" {
	Context "When the exception does not have a response" {
		It "does not call the exception response handler when the exception does not have a response" {
			$script:numberOfResponseHandlerCalls = 0;
			$responseHandler = { param($response)
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler $script:fakeAnnouncer
			$handler._writeResponse(@{ Respone = $null }) 

			$script:numberOfResponseHandlerCalls | should be 0
		}
	}
	Context "When the exception has a response" {
		It "it calls the exception respone handler" {
			$script:numberOfResponseHandlerCalls = 0;
			$expected = New-Object Net.HttpWebResponse
			$responseHandler = { param($response)
				$response | should be $expected
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler $script:fakeAnnouncer
			$handler._writeResponse(@{ Respone = $expected }) 

			$script:numberOfResponseHandlerCalls | should be 0
		}
	}
}
Describe "retry handler" {
	$handler = new_retry_handler { } $script:fakeAnnouncer
	$exceptionToThrow = New-Object Exception
	$webException = New-Object Net.WebException("Timeout", [Net.WebExceptionStatus]::Timeout) 
	Context "When a timeout exception is thrown" {
		$handler | Add-Member _getWebException -Type ScriptMethod { param($exceptionPassed)
			if($exceptionPassed -ne $exceptionToThrow) { throw "wrong exception passed to getWebException" }
			else { $webException }
		} -Force
		It "executes the action once when it does not throw an exception" {
			$script:numberOfTries = 0
			$handler.execute(3, { $script:numberOfTries++ })
			$script:numberOfTries | should equal 1
		}
		It "executes the action twice when it throws a web exception the first time" {
			$script:numberOfTries = 0
			$handler.execute(3, { 
				if($script:numberOfTries -eq 0) {
					$script:numberOfTries++ 
					throw $exceptionToThrow 
				}
				$script:numberOfTries++ 
			})
			$script:numberOfTries | should equal 2
		}
		It "executes the action three times when it throws a web exception the first and second times" {
			$script:numberOfTries = 0
			$handler.execute(3, { 
				if($script:numberOfTries -lt 2) {
					$script:numberOfTries++ 
					throw $exceptionToThrow
				}
				$script:numberOfTries++ 
			})
			$script:numberOfTries | should equal 3
		}
		It "executes the action three times when it throws a web exception the first and second times" {
			$script:numberOfTries = 0
			$handler.execute(3, { 
				if($script:numberOfTries -lt 3) {
					$script:numberOfTries++ 
					throw $exceptionToThrow
				}
				$script:numberOfTries++ 
			})
			$script:numberOfTries | should equal 4
		}
		It "throws the exception when the action throws more times that the retry count" {
			$script:numberOfTries = 0
			{ 
				$handler.execute(3, { 
					if($script:numberOfTries -lt 4) {
						$script:numberOfTries++ 
						throw $exceptionToThrow
					}
					$script:numberOfTries++ 
				}) 
			} | Should throw
		}
		It "writes the exceptions each time an exception is throws" {
			$script:numberOfWriteCalls = 0;
			$expected = New-Object Net.HttpWebResponse
			$handler | Add-Member -Type ScriptMethod _writeResponse { param($exceptionPassed)
				$exceptionPassed | should be $webException
				$script:numberOfWriteCalls++
			} -Force
			$script:numberOfTries = 0;
			{
				$handler.execute(3, { 
					if($script:numberOfTries -lt 4) {
						$script:numberOfTries++ 
						throw $exceptionToThrow
					}
				}) 
			} | should throw

			$script:numberOfWriteCalls | should be 4
		}
	}
	Context "when a non timeout exception is thrown" {
		$handler = new_retry_handler { } $script:fakeAnnouncer
		$exceptionToThrow = New-Object Exception
		$webException = New-Object Net.WebException("ConnectFailure", [Net.WebExceptionStatus]::ConnectFailure) 
		$handler | Add-Member _getWebException -Type ScriptMethod { param($exceptionPassed)
			if($exceptionPassed -ne $exceptionToThrow) { throw "wrong exception passed to getWebException" }
			else { $webException }
		} -Force
		It "throws" {
			$script:numberOfTries = 0
			{
				$handler.execute(3, { 
					if($script:numberOfTries -eq 0) {
						$script:numberOfTries++ 
						throw $exceptionToThrow
					}
					$script:numberOfTries++ 
				})
			} | Should throw

			$script:numberOfTries | should be 1
		}
		It "it writes the exception" {
			$script:numberOfWriteCalls = 0;
			$handler | Add-Member -Type ScriptMethod _writeResponse { param($exceptionPassed)
				$exceptionPassed | should be $webException
				$script:numberOfWriteCalls++
			} -Force
			{
				$handler.execute(3, {
					throw $exceptionToThrow
				})
			} | should throw

			$script:numberOfWriteCalls | should be 1
		}
	}
}
