# Denge testini çalıştırır. Fetih klasöründen kullanım:
#   powershell -ExecutionPolicy Bypass -File tools\run_balance_test.ps1
#   powershell -ExecutionPolicy Bypass -File tools\run_balance_test.ps1 -Seeds 20 -Budget 150
# Rapor: tools\reports\balance_latest.md
# Godot başka bir yerdeyse GODOT ortam değişkenine exe yolunu yaz.
param(
	[int]$Seeds = 10,
	[int]$Budget = 100
)

$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Users\Samet PC\Desktop\Godot_v4.7.2-stable_win64.exe" }
$project = Split-Path $PSScriptRoot -Parent

& $godot --headless --path $project -s res://tools/balance_test.gd -- --seeds=$Seeds --budget=$Budget
