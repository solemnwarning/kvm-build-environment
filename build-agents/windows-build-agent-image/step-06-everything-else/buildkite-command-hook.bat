@ECHO OFF

SETLOCAL EnableDelayedExpansion

rem Map the working directory to a free drive letter using subst so we can run
rem the actual build commands with a shorter effective path to the working
rem directory to work around paths exceeding the classic Windows filename limit
rem and breaking things in stupid ways.

ECHO Looking for a free drive letter...

SET subst_letter=NONE
for %%x in (Z, Y, X, W, V, U, T, S, R, Q, P, O, N, M, L, K, J, I, H, G, F, E, D, C, B, A) do (
	if !subst_letter! == NONE (
		ECHO Trying %%x...
		SUBST %%x: . > %TEMP%\subst.%%x.lck && SET subst_letter=%%x
	)
)

IF %subst_letter% == NONE (
	ECHO Unable to subst %cd% to a virtual drive
	EXIT 1
)

ECHO Mapped %cd% to %subst_letter%:

rem If MSYSTEM has been set in the environment, then we are running a job for a
rem MinGW queue and should pipe the commands into bash.

IF NOT "%MSYSTEM%" == "" (
	C:\msys64\usr\bin\bash.exe -lec "cd \"$1\" && PATH=\"/c/Program Files/Git/cmd:/c/buildkite-agent/bin:${PATH}\" bash -xe <<< $BUILDKITE_COMMAND" -- "/%subst_letter%/"
	EXIT !ERRORLEVEL!
)

rem Write out a file containing all of the commands from the BUILDKITE_COMMAND
rem environment variable outside of the working directory so we can execute
rem them as a batch file.
C:\msys64\usr\bin\bash.exe -c "cat > \"%cd%.bat\" <<< $BUILDKITE_COMMAND"

ECHO --- Running commands

CMD /C "%subst_letter%: && CD \ && %cd%.bat"
SET job_status=%ERRORLEVEL%

SUBST %subst_letter%: /D

EXIT %job_status%
