@echo off

rem setup here please:
set windowskit=F:\Windows Kits\10\bin\10.0.19041.0\x64

goto main

:require
where %1 >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo %1 was not found
  exit /B 1
)
exit /B 0
goto :EOF

:unzip
set to=%~dp1
if "%2" neq "" set to=%2
call powershell -command "Expand-Archive -Force '%1' '%to%'"
goto :EOF

:download
call curl %1 -L -o %2
if %ERRORLEVEL% neq 0 exit /B 1
if NOT EXIST %3 mkdir %3
call :unzip %2 %3
if %ERRORLEVEL% neq 0 exit /B 1
del %2
if %ERRORLEVEL% neq 0 exit /B 1
exit /B 0
goto :EOF

:expand
set %2="%~f1"
goto :EOF

:main

rem check tools version
call :require java
if %ERRORLEVEL% neq 0 (
 echo "Please install java 8 from e.g. openJDK"
 exit /B 1
)
call :require javac
if %ERRORLEVEL% neq 0 (
 echo "You need the JDK, not the JRE"
 exit /B 1
)
call :require git
if %ERRORLEVEL% neq 0 (
 echo "Please install git from git-scm"
 exit /B 1
)
call :require curl
if %ERRORLEVEL% neq 0 (
 echo "Please update Windows, curl should be shipped with it"
 exit /B 1
)

rem check that we have java 8 - this is really retarded since oracle switched version schemes, but here we go...
for /f tokens^=2-5^ delims^=.-_^" %%j in ('java -fullversion 2^>^&1') do (
 set "jverma=%%j"
 set "jvermi=%%k"
)
if %jverma% GTR 1 (
 echo Your java version is to recent! Java 8 Please
 exit /B 1
) else (
 if %jvermi% LSS 8 (
  echo Your java version is to dated! Java 8 Please
  exit /B 1
 )
)

rem check that we have a Windows Kits
if "%windowskit%" == "" (
 echo The script was not set up correctly, pease specify the windows kits directory!
 exit /B 1
)

rem why?
set JAVA1.8_HOME=%JAVA_HOME%

echo Windows Kits: %windowskit%
if NOT EXIST "%windowskit%\rc.exe" (
 echo Could not validate the windows kits directory, please check again!
 exit /B 1
)

rem set up ikvm
if NOT EXIST ikvm mkdir ikvm
cd ikvm

echo Setting up IKVM for .NET cross-compilation...
if NOT EXIST "nant-0.92" (
 echo :: Fetching NAnt...
 call :download https://deac-ams.dl.sourceforge.net/project/nant/nant/0.92/nant-0.92-bin.zip tmp.zip .
 if %ERRORLEVEL% neq 0 (
  echo Failed to download NAnt
  cd ..
  exit /B 1
 )
)
rem can be used to change the ikvm fork
set ikvmdir=ikvm8
if NOT EXIST %ikvmdir% (
 echo :: Fetching windward IKVM8...
 call git clone https://github.com/windward-studios/ikvm8.git
 if %ERRORLEVEL% neq 0 (
  echo Repository is gone
  cd ..
  exit /B 1
 )
)
if NOT EXIST "openjdk-8u45-b14" (
 echo :: Fetching openjdk-8u45-b14...^?
 call :download http://www.frijters.net/openjdk-8u45-b14-stripped.zip tmp.zip .
 if %ERRORLEVEL% neq 0 (
  echo Could not download jdk
  cd ..
  exit /B 1
 )
)
if NOT EXIST "%ikvmdir%\bin\ICSharpCode.SharpZipLib.dll" (
 echo :: Patching Project...
 call :download https://github.com/icsharpcode/SharpZipLib/releases/download/v1.3.2/SharpZipLib.1.3.2.nupkg tmp.zip szl
 copy szl\lib\net45\*.dll %ikvmdir%\bin\
 if %ERRORLEVEL% neq 0 (
  echo Could not patch project
  cd ..
  exit /B 1
 )
)
set PRE_PATH="%PATH%"
if EXIST "%ikvmdir%\bin\IKVM.Runtime.JNI.dll" goto lysis
echo :: Trying to build project...
cd %ikvmdir%
call :expand ..\nant-0.92\bin\ nantdir
set PATH="%PRE_PATH%;%nantdir%;%windowskit%"
set JDK1.8_HOME=%JAVA_HOME%
call NAnt
if %ERRORLEVEL% neq 0 (
 echo IKVM build failed
 cd ..\..
 set PATH="%PRE_PATH%"
 exit /B 1
)
set PATH="%PRE_PATH%"
cd ..

:lysis
cd ..

echo Checking artifact...
if NOT EXIST "lysis-java" (
 echo :: Downloading lysis-java...
 call git clone https://github.com/DosMike/lysis-java.git
 if %ERRORLEVEL% neq 0 (
  echo Could not clone lysis
  exit /B 1
 )
 cd lysis-java
) else (
 cd lysis-java
 echo :: Updating lysis-java...
 call git pull
)
echo :: Compiling...
call gradlew jar
if %ERRORLEVEL% neq 0 (
 echo lysis build failed
 exit /B 1
)
rem find an copy first file to PWD
set lysisjar=
pushd build\libs\
for /f %%x in ('dir lysis-java-*a.jar /B /O:-D') do set "lysisjar=%%x" & goto foundjar
:foundjar
popd
if "" equ "%lysisjar%" (
 echo Compile artifact failed / not found
 exit /B 1
)
echo Compiled: build\libs\%lysisjar%
copy build\libs\%lysisjar% ..\lysis-java.jar
cd ..

echo Cross-Compiling...

set PATH="%PRE_PATH%"
call :expand .\ikvm\%ikvmdir%\bin ikvmbin
%ikvmbin%\ikvmc.exe -out:lysis-java.dll -assembly:lysis-java -target:library lysis-java.jar
exit /B %ERRORLEVEL%