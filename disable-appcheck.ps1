$token = gcloud auth application-default print-access-token
$projectId = "mix-and-mingle-v2"
$serviceName = "firestore.googleapis.com"

$url = "https://firebaseappcheck.googleapis.com/v1/projects/$projectId/services/$serviceName/enforcement"
$body = @{
    enforcementMode = "UNENFORCED"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "Disabling AppCheck enforcement..."
Write-Host "URL: $url"
Write-Host "Payload: $body"

try {
    $response = Invoke-WebRequest -Uri $url -Method PATCH -Headers $headers -Body $body
    Write-Host "✅ Success! Status: $($response.StatusCode)"
    Write-Host "Response: $($response.Content)"
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)"
    Write-Host "Response: $($_.Exception.Response.StatusCode)"
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails)"
    }
    exit 1
}
