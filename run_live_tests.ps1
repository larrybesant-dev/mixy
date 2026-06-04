$server = Start-Process npx -ArgumentList 'http-server', 'build/web', '-p', '9090', '-a', '127.0.0.1', '-s' -PassThru
Start-Sleep -Seconds 3
$env:PLAYWRIGHT_BASE_URL = 'http://127.0.0.1:9090/'
$env:CI = 'true'
npx playwright test
Stop-Process -Id $server.Id -Force
