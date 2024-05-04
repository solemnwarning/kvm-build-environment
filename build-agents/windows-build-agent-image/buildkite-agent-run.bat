SET BUILDKITE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT=300
rem SET BUILDKITE_AGENT_SPAWN=2

SET HTTP_PROXY=http://cache.lan.solemnwarning.net:8080
SET HTTPS_PROXY=http://cache.lan.solemnwarning.net:8080

rem When this VM image is deployed using Terraform, we hijack the cloud-init
rem ISO generator, stick the desired hostname in the user-data file and then
rem apply it here on the first boot, before scheduling a system reboot.

IF EXIST D:\user-data (
	SETLOCAL EnableDelayedExpansion
	
	FOR /F "delims=" %%i IN ('hostname') DO SET current_hostname=%%i
	SET /P desired_hostname=<D:\user-data
	
	IF NOT "!current_hostname!" == "!desired_hostname!" (
		wmic computersystem where dnshostname="!current_hostname!" call rename name="!desired_hostname!"
		shutdown /r /f /t 10 /c "Applied hostname from user-data"
		
		EXIT 1
	)
	
	ENDLOCAL
	
	rem The second line user-data specifies the number of agents to spawn
	FOR /f "skip=1" %%G IN (D:\user-data) DO IF not defined BUILDKITE_AGENT_SPAWN SET "BUILDKITE_AGENT_SPAWN=%%G"
	
	rem Also we stash some certificates in it...
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> git-cache-https/{f=1}" D:\user-data > C:\buildkite-agent\git-cache-https.pem
	C:\msys64\usr\bin\awk "/^>>>/{f=0};f;/^>>> vcpkg-cache-https/{f=1}" D:\user-data > C:\buildkite-agent\vcpkg-cache-https.pem
	certutil.exe -addstore Root C:\buildkite-agent\vcpkg-cache-https.pem
)

C:\buildkite-agent\bin\buildkite-agent.exe start

shutdown /s /f /t 0
