@echo off

:: ----
:: build the data time string and put it into buildDate.dart
:: - reformating standard dos date to something nicer
set mydate=%date:~10,4%-%date:~7,2%-%date:~4,2%
set mytime=%time%

:: - pipe the dart string into buildDate.dart
>lib/buildDate.dart echo final String buildDateTime = '%mydate% %mytime%';

:: ----
:: build the web release code using flutter
echo.
echo Starting web release build ...
:: - print date and time to screen
echo BuildDateTime = %mydate% %mytime%

:: - call the flutter build command
call flutter build web

:: ----
:: deploy
echo.
echo Deploying ...
echo.
call firebase deploy --only hosting
echo.
