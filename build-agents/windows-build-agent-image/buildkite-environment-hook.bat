SET toolchain_selected=0

set BUILDKITE_CLEAN_CHECKOUT=true
set BUILDKITE_NO_LOCAL_HOOKS=true

rem Add MSYS to PATH so buildkite-agent can find its Git.
set PATH=%PATH%;C:\msys64\usr\bin

set X_PARALLEL_JOBS=%NUMBER_OF_PROCESSORS%
set VCPKG_BINARY_SOURCES=clear;http,https://vcpkg-cache.build.solemnwarning.net/{name}/{version}/{sha},readwrite

FOR /F %%i IN ('buildkite-agent step get --format json agents ^| jq ".[]"') DO (
	IF [%%i] == ["queue=mingw-x86_64"] (
		ECHO Using 64-bit MinGW toolchain
		
		IF "%toolchain_selected%" == "1" (
			ECHO Multiple toolchains requested, aborting!
			EXIT 1
		)
		
		SET MSYSTEM=MINGW64
		
		SET toolchain_selected=1
	)
	
	IF [%%i] == ["queue=msvc-x86"] (
		ECHO Using 32-bit MSVC toolchain
		
		IF "%toolchain_selected%" == "1" (
			ECHO Multiple toolchains requested, aborting!
			EXIT 1
		)
		
		"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars32.bat"
		
		SET toolchain_selected=1
	)
	
	IF [%%i] == ["queue=msvc-x64"] (
		ECHO Using 64-bit MSVC toolchain
		
		IF "%toolchain_selected%" == "1" (
			ECHO Multiple toolchains requested, aborting!
			EXIT 1
		)
		
		CALL "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
		
		SET toolchain_selected=1
	)
)

IF "%toolchain_selected%" == "0" (
	ECHO Couldn't determine toolchain to use!
	EXIT 1
)
