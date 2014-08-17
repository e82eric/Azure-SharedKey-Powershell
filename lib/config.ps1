$ErrorActionPreference = "stop"

function __.azure.rest.get_config { param($key)
	switch ($key) {
		"management_version" { "2014-06-01" }
		"storage_version" { "2013-08-15" }
		"scheme" { "https" }
		"retry_count" { 3 }
		"management_content_type" { "application/xml" }
		"timeout" { 20000 }
		"acs_content_type" { "application/atom+xml" }
		default { throw "unknown config key: $key" }
	}
}
