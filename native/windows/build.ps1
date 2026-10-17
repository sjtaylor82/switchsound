$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
dotnet publish .\SwitchSound\SwitchSound.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false -o .\dist
Write-Host "Built: $PSScriptRoot\dist\SwitchSound.exe"
