rem When this VM image is deployed using Terraform, we hijack the cloud-init
rem ISO generator to inject our configuration and apply it at startup from this
rem batch script.

SETLOCAL EnableDelayedExpansion

SET BUILDKITE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT=300
SET BUILDKITE_AGENT_TAGS=queue=mingw-x86_64,queue=msvc-x86,queue=msvc-x64

SET PROXY=cache.lan.solemnwarning.net:8080

IF EXIST D:\user-data (
	rem The first line in user-data specifies the system hostname. If the
	rem hostname is changed we reboot the machine immediately.
	
	FOR /F "delims=" %%i IN ('hostname') DO SET current_hostname=%%i
	SET /P desired_hostname=<D:\user-data
	
	IF NOT "!current_hostname!" == "!desired_hostname!" (
		wmic computersystem where dnshostname="!current_hostname!" call rename name="!desired_hostname!"
		shutdown /r /f /t 10 /c "Applied hostname from user-data"
		
		EXIT 0
	)
	
	IF "!PROXY!" == "" (
		rem netsh winhttp reset proxy
		git config --system http.proxy ""
		SET BUILDKITE_PROXY_URL=
	) ELSE (
		rem netsh winhttp set proxy "!PROXY!" "!NOPROXY!"
		git config --system http.proxy "http://!PROXY!/"
		SET BUILDKITE_PROXY_URL=http://!PROXY!
	)
	
	rem The second line user-data specifies the number of agents to spawn
	FOR /f "skip=1" %%G IN (D:\user-data) DO IF not defined BUILDKITE_AGENT_SPAWN SET "BUILDKITE_AGENT_SPAWN=%%G"
	
	rem ...and the third line has any extra agent tags
	FOR /f "skip=2" %%G IN (D:\user-data) DO IF not defined BUILDKITE_EXTRA_TAGS SET "BUILDKITE_EXTRA_TAGS=%%G"
	
	IF NOT "!BUILDKITE_EXTRA_TAGS!" == "NONE" (
		SET BUILDKITE_AGENT_TAGS=!BUILDKITE_AGENT_TAGS!,!BUILDKITE_EXTRA_TAGS!
	)
	
	rem Remaining fields are preceeded by identifiers.
	
	rem Git cache server HTTPS certificate.
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> git-cache-https/{f=1}" D:\user-data > C:\buildkite-agent\git-cache-https.pem
	certutil.exe -addstore Root C:\buildkite-agent\git-cache-https.pem
	
	rem vcpkg cache server HTTPS certificate.
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> vcpkg-cache-https/{f=1}" D:\user-data > C:\buildkite-agent\vcpkg-cache-https.pem
	certutil.exe -addstore Root C:\buildkite-agent\vcpkg-cache-https.pem
	
	rem ccache cache server HTTPS certificates/keys.
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> ccache-cache-https/{f=1}" D:\user-data > "C:\Program Files (x86)\stunnel\config\ccache-cache.build.solemnwarning.net.crt"
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> ccache-cache-client-cert/{f=1}" D:\user-data > "C:\Program Files (x86)\stunnel\config\ccache-cache.client.crt"
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> ccache-cache-client-key/{f=1}" D:\user-data > "C:\Program Files (x86)\stunnel\config\ccache-cache.client.key"
	
	net start stunnel
	
	nssm set "Buildkite Agent" AppEnvironmentExtra ^
		"BUILDKITE_AGENT_SPAWN=!BUILDKITE_AGENT_SPAWN!" ^
		"BUILDKITE_AGENT_TAGS=!BUILDKITE_AGENT_TAGS!" ^
		"BUILDKITE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT=!BUILDKITE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT!" ^
		"HTTP_PROXY=!BUILDKITE_PROXY_URL!" ^
		"HTTPS_PROXY=!BUILDKITE_PROXY_URL!"
	
	net start "Buildkite Agent"
	
	EXIT 0
)

EXIT 1
