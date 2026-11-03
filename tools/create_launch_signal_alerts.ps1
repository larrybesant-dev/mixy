#!/usr/bin/env pwsh
param(
    [string]$ProjectId = "mixvy-v2",
    [string]$NotificationChannel = ""
)

$ErrorActionPreference = "Stop"

$signals = @(
    @{ Code = "launch_auth_failure"; Name = "Authentication failures" },
    @{ Code = "launch_stale_room_navigation"; Name = "Stale room navigation" },
    @{ Code = "launch_messaging_freshness"; Name = "Messaging freshness" },
    @{ Code = "launch_rtc_recovery_exhausted"; Name = "RTC reconnect exhaustion" },
    @{ Code = "launch_payment_entitlement_mismatch"; Name = "Payment entitlement mismatch" },
    @{ Code = "launch_uncaught_error"; Name = "Uncaught web errors" }
)

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw "gcloud is required to create launch signal alerts."
}

if (-not $NotificationChannel) {
    $channelRows = gcloud alpha monitoring channels list `
        --project=$ProjectId `
        --format="csv[no-heading](name,enabled)" 2>$null
    $NotificationChannel = $channelRows |
        ForEach-Object {
            $fields = $_ -split ",", 2
            if ($fields.Count -eq 2 -and $fields[1].Trim() -eq "True") {
                $fields[0].Trim()
            }
        } |
        Select-Object -First 1
}

if (-not $NotificationChannel) {
    throw "No enabled notification channel was found. Create or verify one, then rerun with -NotificationChannel <resource-name>."
}

$existingPolicies = @(
    gcloud alpha monitoring policies list `
        --project=$ProjectId `
        --format="value(displayName)" 2>$null
)

foreach ($signal in $signals) {
    $displayName = "MixVy Launch - $($signal.Name)"
    if ($existingPolicies -contains $displayName) {
        Write-Host "Existing: $displayName"
        continue
    }

    $policy = @{
        displayName = $displayName
        combiner = "OR"
        enabled = $true
        conditions = @(
            @{
                displayName = "Signal $($signal.Code)"
                conditionMatchedLog = @{
                    filter = "resource.type=`"cloud_run_revision`" AND jsonPayload.message=`"mixvy_launch_signal`" AND jsonPayload.code=`"$($signal.Code)`""
                }
            }
        )
        notificationChannels = @($NotificationChannel)
        alertStrategy = @{
            notificationRateLimit = @{ period = "300s" }
            autoClose = "604800s"
        }
        documentation = @{
            mimeType = "text/markdown"
            content = "MixVy launch guard triggered by structured signal ``$($signal.Code)``. Inspect the matching Cloud Run log entry for bounded operational metadata."
        }
    }

    $policyFile = Join-Path $env:TEMP "mixvy-$($signal.Code)-alert.json"
    try {
        $policy | ConvertTo-Json -Depth 10 | Set-Content -Path $policyFile -Encoding utf8
        gcloud alpha monitoring policies create `
            --project=$ProjectId `
            --policy-from-file=$policyFile
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create $displayName."
        }
        Write-Host "Created: $displayName"
    } finally {
        Remove-Item $policyFile -Force -ErrorAction SilentlyContinue
    }
}