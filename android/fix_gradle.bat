@echo off
set JAVA_HOME=C:\Program Files\Android\Android Studio1\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

echo Stopping Gradle daemon...
call gradlew.bat --stop

echo Cleaning Gradle cache...
call gradlew.bat clean

echo Done!
pause
