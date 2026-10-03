$Endpoints = 1..100000 | ForEach-Object {

    $CPU = [double](10 + ($_ % 90))

    [PSCustomObject]@{
        ComputerName   = if ($_ % 2 -eq 0) {
            "LAP-$('{0:D5}' -f $_)"
        }
        else {
            "SRV-$('{0:D5}' -f $_)"
        }

        Status         = if ($_ % 10 -eq 0) {
            "Offline"
        }
        else {
            "Online"
        }

        CPUPercent     = $CPU
        MemoryPercent  = [double](20 + ($_ % 75))
        MissingPatches = $_ % 12
        IsOnline       = ($_ % 10 -ne 0)
        LastChecked    = (Get-Date).AddMinutes(-($_ % 1440))
    }
}
function Get-EndpointHealth {
    param (
        $Endpoints
    )

    $ResultList = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Record in $Endpoints) {

        $ResultList.Add(
            [PSCustomObject]@{
                ComputerName   = $Record.ComputerName
                Status         = $Record.Status
                CPUPercent     = $Record.CPUPercent
                MemoryPercent  = $Record.MemoryPercent
                MissingPatches = $Record.MissingPatches
                IsOnline       = $Record.IsOnline
                LastChecked    = $Record.LastChecked
            }
        )
    }

    return $ResultList
}

function Get-EndpointHealthRecord {
    param (
        $Endpoints
    )
Foreach($Record in $Endpoints){
if ($Record.CPUPercent -le 50 -and $Record.MemoryPercent -le 40 -and $Record.MissingPatches -le 2 -and $Record.IsOnline){
    [PSCustomObject]@{
        ComputerName   = $Record.ComputerName
        CPUPercent     = $Record.CPUPercent
        MemoryPercent  = $Record.MemoryPercent
        MissingPatches = $Record.MissingPatches
        IsOnline       = $Record.IsOnline
        LastChecked    = $Record.LastChecked
        HealthState    = "Healthy"}
    }
elseif (($Record.CPUPercent -gt 50 -and
    $Record.CPUPercent -lt 90) -or
    ($Record.MemoryPercent -gt 40 -and
    $Record.MemoryPercent -lt 80) -or
    ($Record.MissingPatches -gt 2 -and
    $Record.MissingPatches -lt 8)) {

    [PSCustomObject]@{
        ComputerName   = $Record.ComputerName
        CPUPercent     = $Record.CPUPercent
        MemoryPercent  = $Record.MemoryPercent
        MissingPatches = $Record.MissingPatches
        IsOnline       = $Record.IsOnline
        LastChecked    = $Record.LastChecked
        HealthState    = "Warning"
    }}
else {

    [PSCustomObject]@{
        ComputerName   = $Record.ComputerName
        CPUPercent     = $Record.CPUPercent
        MemoryPercent  = $Record.MemoryPercent
        MissingPatches = $Record.MissingPatches
        IsOnline       = $Record.IsOnline
        LastChecked    = $Record.LastChecked
        HealthState    = "Critical"
    }
}
}}

function Get-EndpointStatus {
    param ($Endpoints)
    foreach ($Record in $Endpoints){
        if ($Record.MissingPatches -eq 0){
        [PSCustomObject]@{
            ComputerName   = $Record.ComputerName
            MissingPatches = $Record.MissingPatches
            PatchState     = "Compliant"
            IsOnline       = $Record.IsOnline
            LastChecked    = $Record.LastChecked
}
        }
        elseif ($Record.MissingPatches -le 4){
        [PSCustomObject]@{
    ComputerName   = $Record.ComputerName
    MissingPatches = $Record.MissingPatches
    PatchState     = "Attention"
    IsOnline       = $Record.IsOnline
    LastChecked    = $Record.LastChecked
    }
        }
        else {
        [PSCustomObject]@{
    ComputerName   = $Record.ComputerName
    MissingPatches = $Record.MissingPatches
    PatchState     = "NonCompliant"
    IsOnline       = $Record.IsOnline
    LastChecked    = $Record.LastChecked
}
        }
    }

}
function Get-EndpointRisk{
    param ($Endpoints)
    foreach ($Record in $Endpoints){
        $RiskScore = 0
    if (-not $Record.IsOnline) {
        $RiskScore += 50}
    if($Record.CPUPercent -ge 80) {
    $RiskScore += 20
}
    if($Record.MemoryPercent -ge 70) {
    $RiskScore += 20
}
    if ($Record.MissingPatches -ge 5) {
    $RiskScore += 20
}
    if ($RiskScore -lt 20) {
    $RiskLevel = "Low"
}
elseif ($RiskScore -lt 40) {
    $RiskLevel = "Medium"
}
elseif ($RiskScore -lt 60) {
    $RiskLevel = "High"
}
else {
    $RiskLevel = "Critical"
}
    [PSCustomObject]@{
    ComputerName = $Record.ComputerName
    CPUPercent   = $Record.CPUPercent
    MemoryPercent = $Record.MemoryPercent
    MissingPatches = $Record.MissingPatches
    IsOnline     = $Record.IsOnline
    RiskScore    = $RiskScore
    RiskLevel    = $RiskLevel
}
    }
}

function Get-EndpointSummary {
    param ($Endpoints)

    $TotalEndpoints        = 0
    $OnlineEndpoints       = 0
    $OfflineEndpoints      = 0
    $TotalCPU              = 0.0
    $TotalMemory           = 0.0
    $TotalMissingPatches   = 0
    $CriticalRiskEndpoints = 0

    foreach ($Record in $Endpoints) {

        $TotalEndpoints++

        if ($Record.IsOnline) {
            $OnlineEndpoints++
        }
        else {
            $OfflineEndpoints++
        }

        $TotalCPU += $Record.CPUPercent
        $TotalMemory += $Record.MemoryPercent
        $TotalMissingPatches += $Record.MissingPatches

        $RiskScore = 0

        if (-not $Record.IsOnline) {
            $RiskScore += 50
        }

        if ($Record.CPUPercent -ge 80) {
            $RiskScore += 20
        }

        if ($Record.MemoryPercent -ge 70) {
            $RiskScore += 20
        }

        if ($Record.MissingPatches -ge 5) {
            $RiskScore += 20
        }

        if ($RiskScore -ge 60) {
            $CriticalRiskEndpoints++
        }
    }

    $AverageCPU = if ($TotalEndpoints -gt 0) {
        [math]::Round($TotalCPU / $TotalEndpoints, 2)
    }
    else {
        0
    }

    $AverageMemory = if ($TotalEndpoints -gt 0) {
        [math]::Round($TotalMemory / $TotalEndpoints, 2)
    }
    else {
        0
    }

    [PSCustomObject]@{
        TotalEndpoints        = $TotalEndpoints
        OnlineEndpoints       = $OnlineEndpoints
        OfflineEndpoints      = $OfflineEndpoints
        AverageCPU            = $AverageCPU
        AverageMemory         = $AverageMemory
        TotalMissingPatches   = $TotalMissingPatches
        CriticalRiskEndpoints = $CriticalRiskEndpoints
    }
}

function Get-EndpointExceptions{
    param (
        $Endpoints
    )
    $ExceptionList = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($Record in $Endpoints){
        $Reasons = [System.Collections.Generic.List[string]]::new()
        if (-not $Record.IsOnline) {
                $Reasons.Add("Offline")
            }
            if ($Record.CPUPercent -ge 90) {
                $Reasons.Add("High CPU")
            }
            if ($Record.MemoryPercent -ge 85) {
                $Reasons.Add("High Memory")
            }
            if ($Record.MissingPatches -ge 8) {
                $Reasons.Add("Missing Patches")
            }
            if ($Reasons.Count -gt 0) {
                $ExceptionList.Add(
                    [PSCustomObject]@{
                        ComputerName     = $Record.ComputerName
                        Status           = if ($Record.IsOnline) { "Online" } else { "Offline" }
                        CPUPercent       = $Record.CPUPercent
                        MemoryPercent    = $Record.MemoryPercent
                        MissingPatches   = $Record.MissingPatches
                        IsOnline         = $Record.IsOnline
                        LastChecked      = $Record.LastChecked
                        ExceptionReasons = $Reasons.ToArray()
                    })
    }
}
Return $ExceptionList
}

function Get-EndpointReport {
    [CmdletBinding()]
    param (
        $Endpoints
    )

    process {
        # Delegate baseline aggregations to Utility 4
        $Summary = Get-EndpointSummary -Endpoints $Endpoints

        # Delegate exception scanning to Utility 5
        $Exceptions = Get-EndpointExceptions -Endpoints $Endpoints

        # Return single consolidated executive report object
        return [PSCustomObject]@{
            TotalEndpoints         = $Summary.TotalEndpoints
            OnlineEndpoints        = $Summary.OnlineEndpoints
            OfflineEndpoints       = $Summary.OfflineEndpoints
            AverageCPU             = $Summary.AverageCPU
            AverageMemory          = $Summary.AverageMemory
            TotalMissingPatches    = $Summary.TotalMissingPatches
            CriticalRiskEndpoints  = $Summary.CriticalRiskEndpoints
            ExceptionEndpointCount = $Exceptions.Count
            GeneratedAt            = Get-Date
        }
    }
}
