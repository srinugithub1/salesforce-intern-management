$path = "d:\Google Chrome Downloads\Salesforce Project\salesforce_app\force-app\main\default\lwc\landingAdminDashboard\landingAdminDashboard.js"
$lines = Get-Content $path
$newLines = $lines[0..643] + $lines[1211..($lines.Count - 1)]
$newLines | Set-Content $path
