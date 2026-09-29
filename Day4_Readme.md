# Day 4 — Control Flow, File Boundaries and Data Integrity

> **PowerShell Automation Engineer — 90 Day Plan**
> Theme: control flow, file boundaries, CSV/JSON serialization, data integrity, performance and debugging.

---

## Day 4 Objectives

**Control flow**

- Iterating collections with `foreach`
- Pipeline iteration with `ForEach-Object`
- Choosing between the two
- Repeated execution with `while` and `do...while`
- Routing discrete values with `switch`
- Measuring script performance with `Measure-Command`

**File boundaries**

- Moving PowerShell objects across file boundaries
- CSV serialization and deserialization
- JSON serialization and deserialization
- Nested object handling and JSON depth
- Detecting data loss after a round trip
- Debugging serialization problems
- Validating data after import and export

### The central engineering lesson

> PowerShell objects are structured data.
> When they cross a file boundary, the structure and type information may change.
> An Automation Engineer must validate the data after serialization and deserialization.

This is not a theoretical concern. Today's CSV experiment proved that `Int32` and `Boolean` both came back as `String`, and the JSON experiment proved that nested data silently disappeared at the default depth.

---

## Table of Contents

**Control flow**
1. [foreach](#1-foreach)
2. [ForEach-Object](#2-foreach-object)
3. [Large dataset performance test](#3-large-dataset-performance-test)
4. [while](#4-while)
5. [Cumulative while practice](#5-cumulative-while-practice)
6. [do...while](#6-dowhile)
7. [do...while practice 1 — backup job](#7-dowhile-practice-1--backup-job)
8. [do...while — service health](#8-dowhile--service-health)
9. [do...while — deployment challenge](#9-dowhile--deployment-challenge)
10. [switch](#10-switch)
11. [switch practice 1 — service status](#11-switch-practice-1--service-status)
12. [switch practice 2 — employee access review](#12-switch-practice-2--employee-access-review)
13. [switch practice 3 — incident routing](#13-switch-practice-3--incident-routing)

**File boundaries**
14. [Import-Csv and Export-Csv](#14-import-csv-and-export-csv)
15. [CSV practice — 50,000 servers](#15-csv-practice--50000-servers)
16. [CSV type comparison](#16-csv-type-comparison)
17. [CSV count validation](#17-csv-count-validation)
18. [JSON theory](#18-json-theory)
19. [Out-File](#19-out-file)
20. [Get-Content -Raw](#20-get-content--raw)
21. [JSON nested object dataset](#21-json-nested-object-dataset)
22. [JSON round-trip function](#22-json-round-trip-function)
23. [JSON count validation](#23-json-count-validation)
24. [JSON nested property validation](#24-json-nested-property-validation)
25. [JSON depth](#25-json-depth)
26. [JSON performance](#26-json-performance)
27. [The file boundary concept](#27-the-file-boundary-concept)

**Debugging, environment and review**
28. [Scope and dot-sourcing](#28-scope-and-dot-sourcing)
29. [Working directory](#29-working-directory)
30. [Measure-Command](#30-measure-command)
31. [Debugging log](#31-debugging-log)
32. [JSON truncation scenario](#32-json-truncation-scenario)
33. [Code review notes](#33-code-review-notes)

**Status**
34. [Q10 / Q11 / Q12](#34-q10--q11--q12)
35. [Interview questions](#35-interview-questions)
36. [Key mental models](#36-key-mental-models)
37. [Day 4 final checklist](#37-day-4-final-checklist)
38. [Day 4 summary](#38-day-4-summary)

---

# Part 1 — Control Flow

## 1. foreach

### What it is

`foreach` directly iterates an in-memory collection. It takes the whole collection, walks it, and runs the body once per item.

```powershell
foreach ($Device in $Devices) {
    $Device.Name
}
```

### Object flow

```
$Devices  (a collection already in memory)
    │
    ├─ item 1 → $Device → body runs
    ├─ item 2 → $Device → body runs
    └─ item 3 → $Device → body runs
```

Each item is bound to `$Device` in turn. The collection is already fully in memory before the loop starts.

### Why it matters for automation

It works naturally with PowerShell objects and is often efficient for large in-memory collections, because there is no pipeline machinery between the collection and the loop body.

> **Important caveat:** this does **not** mean `foreach` is always faster. Performance depends on the workload and the implementation. Today's test measured one specific workload.

---

## 2. ForEach-Object

### What it is

`ForEach-Object` is a **pipeline cmdlet**. It receives objects from the pipeline one at a time and runs a script block for each.

```powershell
$Devices | ForEach-Object {
    $_.Name
}
```

- Objects arrive through the pipeline
- `$_` represents the current pipeline object
- The script block is invoked once per incoming object
- Pipeline processing introduces overhead

### Side by side

```powershell
# Direct collection iteration
foreach ($Device in $Devices) {
    $Device.Name
}

# Pipeline iteration
$Devices | ForEach-Object {
    $_.Name
}
```

Same result. Different mechanism.

### Interview point

> `ForEach-Object` can be slower than `foreach` for large in-memory collections because each object passes through the PowerShell pipeline and the script block is invoked for each object.

Do **not** say `foreach` is always faster. The honest claim is about pipeline overhead on large in-memory collections.

---

## 3. Large dataset performance test

### The dataset

```powershell
$Servers = 1..100000 | ForEach-Object {
    [PSCustomObject]@{
        Name   = "SRV$_"
        Status = if ($_ % 10 -eq 0) { "Stopped" } else { "Running" }
        CPU    = Get-Random -Minimum 10 -Maximum 95
    }
}
```

### Measured results

| Approach | Time |
|----------|------|
| `foreach` | **274.1824 ms** |
| `ForEach-Object` | **384.677 ms** |
| Difference | approximately **110.5 ms** |

### What this means

- At 100,000 objects, pipeline overhead becomes visible and measurable.
- `ForEach-Object` was slower **in this particular test**.
- This is an observation for this workload, not a universal rule.

The initial test returned all servers; filtering was discussed afterwards as a refinement.

### Why it matters for automation

At 100 objects the difference is irrelevant and readability should win. At 100,000 objects it is worth measuring. The engineering habit is to **measure rather than assume** — which is why `Measure-Command` appears throughout today's work.

---

## 4. while

### What it is

`while` checks its condition **before** each iteration.

- It can execute **zero** times if the condition is false at the start
- The loop state must change inside the body
- Failure to update state creates an infinite loop
- Useful for polling and monitoring workflows

```
        ┌──────────────────┐
        │ check condition  │◄────┐
        └────────┬─────────┘     │
                 │ true          │
                 ▼               │
            run the body ────────┘
                 │ false
                 ▼
               exit
```

### Actual practice

```powershell
function Wait-DeploymentCompletion {
    param ($DeploymentStatus)

    $Count = 0

    while ($DeploymentStatus -eq "Running") {

        $Count++

        if ($Count -ge 3) {
            $DeploymentStatus = "Completed"
        }
    }

    [PSCustomObject]@{
        Status = $DeploymentStatus
        Checks = $Count
    }
}
```

**Behaviour:** the loop runs while the status is `Running`. On the third check the status is changed to `Completed`, which makes the condition false and ends the loop. Returns `Status = Completed`, `Checks = 3`.

### Debugging lessons from this exercise

| Problem | Lesson |
|---------|--------|
| Wrong variable updated | The variable in the condition must be the one the body changes, or the loop never ends |
| Variable spelling mistakes | A misspelled variable is `$null`, not an error — the condition silently misbehaves |
| Extra output | Statements that produce values inside a function leak into the output stream |
| Loop termination | Every `while` needs a guaranteed path to a false condition |

### Why it matters for automation

Polling is everywhere in automation: waiting for a deployment, a backup, an API job, a directory replication. A `while` loop that cannot terminate is a script that hangs a scheduled job overnight.

---

## 5. Cumulative while practice

### The dataset

```powershell
$Deployments = @(
    [PSCustomObject]@{
        ID="D101"
        Application="PaymentAPI"
        Environment="Production"
        Status="Running"
        DurationMin=18
    }
    [PSCustomObject]@{
        ID="D102"
        Application="UserAPI"
        Environment="Production"
        Status="Completed"
        DurationMin=12
    }
    [PSCustomObject]@{
        ID="D103"
        Application="OrderAPI"
        Environment="Development"
        Status="Running"
        DurationMin=25
    }
    [PSCustomObject]@{
        ID="D104"
        Application="AuthAPI"
        Environment="Production"
        Status="Failed"
        DurationMin=8
    }
)
```

**Function concept:** `Get-DeploymentMonitoringReport`

### Skills practised

- `while` monitoring loop
- Changing `Running` to `Completed`
- Filtering out `Failed` deployments
- Calculated property `DeploymentHours`
- Sorting
- Grouping by `Environment`
- `Measure-Command`

### Mistakes made

| Mistake | Correction |
|---------|-----------|
| `-Deployements` typo | Parameter name must match exactly |
| `$Deployemnts` typo | A misspelled variable is `$null` — no error, just empty results |
| Used `=` instead of `-eq` | `=` assigns and always succeeds, so the condition stayed true → infinite loop |
| Wrong filter | Filtered the wrong property / wrong direction |
| Sorted after grouping | Grouping changes the shape of the data; sort before grouping, or sort within groups |
| Loop termination issue | The state the condition reads was not being updated |

**Observed timing:** approximately **1.2617 ms**

### The `=` vs `-eq` lesson

```powershell
while ($Status = "Running")   # ❌ assignment — always truthy — infinite loop
while ($Status -eq "Running") # ✅ comparison
```

PowerShell uses `-eq` for comparison. `=` is assignment only, and an assignment inside a condition evaluates as truthy, so the loop never ends.

---

## 6. do...while

### What it is

`do...while` executes the body **first**, then evaluates the condition.

- The body therefore runs **at least once**
- Useful for retry and verification workflows

```
            run the body ◄────┐
                 │            │
                 ▼            │
        ┌──────────────────┐  │
        │ check condition  │──┘ true
        └────────┬─────────┘
                 │ false
                 ▼
               exit
```

### Basic example

```powershell
do {
    $CheckCount++
} while ($CheckCount -lt 3)
```

### while vs do...while

| | `while` | `do...while` |
|---|---|---|
| Condition checked | Before the body | After the body |
| Minimum executions | 0 | 1 |
| Use for | Polling where there may be nothing to do | Retry or verification that must happen at least once |

---

## 7. do...while practice 1 — backup job

```powershell
function Test-BackupJob {
    param ($BackupStatus)

    $CheckCount = 0

    do {
        $CheckCount++

        if ($CheckCount -eq 3) {
            $BackupStatus = "Completed"
        }

    } while ($CheckCount -lt 3)

    [PSCustomObject]@{
        Status = $BackupStatus
        Checks = $CheckCount
    }
}
```

**Behaviour:** the body runs, incrementing the counter. On the third pass the status becomes `Completed` and the condition `3 -lt 3` is false, so the loop exits. Returns `Status = Completed`, `Checks = 3`.

### Mistakes made

| Mistake | Correction |
|---------|-----------|
| Extra `{` after `while` | `do { } while (condition)` — the condition is in parentheses, with no block after it |
| Initially returned only the status | Corrected to return **both** the status and the check count |

**Key learning:** returning both values makes the function's result useful to a caller. "It completed" is far less useful than "it completed after three checks" when you are diagnosing a slow backup.

---

## 8. do...while — service health

### The dataset

```powershell
$Services = @(
    [PSCustomObject]@{
        Name="AuthService"
        Status="Running"
        CPU=25
        Environment="Production"
    }
    [PSCustomObject]@{
        Name="PaymentService"
        Status="Stopped"
        CPU=0
        Environment="Production"
    }
    [PSCustomObject]@{
        Name="OrderService"
        Status="Running"
        CPU=75
        Environment="Development"
    }
    [PSCustomObject]@{
        Name="BackupService"
        Status="Running"
        CPU=60
        Environment="Production"
    }
)
```

**Function concept:** `Get-ServiceHealthReport`

### Skills practised

- `do...while` verification cycle
- Pipeline filtering
- Calculated property `CPUPercentage`
- Calculated property `CPULevel`
- Sorting
- Grouping
- `Measure-Command`

### Debugging encountered

| Problem | Resolution |
|---------|-----------|
| Script loading problems | Functions were not available after running the script |
| Dot-sourcing | `. ./Script.ps1` loads the definitions into the current session (see [section 28](#28-scope-and-dot-sourcing)) |
| `C:\Temp\Script1.ps1` example | Path example discussed while working out script loading |
| Unwanted variable output | Bare variable references inside a function emit to the output stream |

### Observed results

| Environment | Count |
|-------------|-------|
| Production | 2 |
| Development | 1 |

**Timing:** approximately **2 ms**

---

## 9. do...while — deployment challenge

### The dataset

```powershell
$Deployments = @(
    [PSCustomObject]@{
        ID="D101"
        Application="PaymentAPI"
        Environment="Production"
        Status="Running"
        DurationMin=120
        ServerCount=15
    }
    [PSCustomObject]@{
        ID="D102"
        Application="AuthAPI"
        Environment="Production"
        Status="Failed"
        DurationMin=90
        ServerCount=10
    }
    [PSCustomObject]@{
        ID="D103"
        Application="OrderAPI"
        Environment="Development"
        Status="Running"
        DurationMin=30
        ServerCount=10
    }
    [PSCustomObject]@{
        ID="D104"
        Application="BillingAPI"
        Environment="Production"
        Status="Completed"
        DurationMin=150
        ServerCount=20
    }
)
```

**Function concept:** `Get-DeploymentHealthReport`

### Skills practised

- `do...while`
- Changing `Running` to `Completed`
- Excluding `Failed` deployments
- Calculated property `DurationHours`
- Calculated property `ServersPerHour`
- Sorting
- Grouping
- `Measure-Command`

### Observed calculations

| ID | DurationMin | ServerCount | DurationHours | ServersPerHour |
|----|------------|-------------|---------------|----------------|
| D104 | 150 | 20 | 2.5 | 8 |
| D101 | 120 | 15 | 2 | 7.5 |
| D103 | 30 | 10 | 0.5 | 20 |

D102 was excluded because its status was `Failed`.

**Timing:** approximately **2.1195 ms**

### Mistakes made

| Mistake | Lesson |
|---------|--------|
| Count increment placed inside the wrong block | Where a counter increments decides how many times the loop runs |
| Wrong filter | Check both the property and the comparison direction |
| Missing fields | The output object must carry everything the report needs |
| Incorrect `ServersPerHour` calculation | The formula was wrong before it was right |
| Confusion between minutes-per-server and servers-per-hour | **Units matter.** `ServerCount / DurationHours` is servers per hour; inverting it silently produces a plausible-looking wrong number |

> The units confusion is worth remembering. Nothing errors when you divide the wrong way round — you get a number, it looks reasonable, and it is wrong. This is the same class of failure as the type coercion problem: a silent wrong answer.

---

## 10. switch

### What it is

`switch` matches **one value against several discrete values**.

```powershell
$Status = "Running"

switch ($Status) {
    "Running" { "Application is running" }
    "Stopped" { "Application is stopped" }
    "Failed"  { "Application failed" }
}
```

### When to use switch

**Good fit — discrete categories:**

- Service status
- Severity
- Environment
- Any fixed set of known values

**Prefer `if` / `elseif` for:**

- Numeric ranges
- Complex Boolean conditions
- Combined conditions

### Why it matters for automation

Status-to-action routing is the shape of a huge amount of identity and infrastructure automation. `switch` expresses that mapping clearly, and a reader can see every case at a glance rather than tracing an `if` chain.

---

## 11. switch practice 1 — service status

### The dataset

```powershell
$ServiceStatuses = @(
    "Running"
    "Stopped"
    "Failed"
    "Maintenance"
    "Degraded"
)
```

### The function

```powershell
function Get-ServiceAction {
    param ($ServiceStatuses)

    foreach ($object in $ServiceStatuses) {

        $Action = switch ($object) {
            "Running"     { "No Action" }
            "Stopped"     { "Start Service" }
            "Failed"      { "Create Incident" }
            "Maintenance" { "Skip Monitoring" }
            "Degraded"    { "Investigate" }
        }

        [PSCustomObject]@{
            Status = $object
            Action = $Action
        }
    }
}
```

### Mistakes made

| Mistake | Correction |
|---------|-----------|
| Reversed case and action | The value being matched goes in `switch ( )`; the result goes in the block |
| Used object properties on strings | This collection holds **strings**, not objects — `$object.Status` does not exist |
| Did not capture the switch result | `switch` returns a value; it must be assigned: `$Action = switch (…) { … }` |

**Key learning:** `switch` is an expression. Its matching block's output becomes its value, and that value has to be captured or it goes straight to the output stream.

---

## 12. switch practice 2 — employee access review

### The dataset

```powershell
$Employees = @(
    [PSCustomObject]@{
        Name="Arun"
        Department="Finance"
        AccessStatus="Active"
        RiskScore=25
    }
    [PSCustomObject]@{
        Name="Priya"
        Department="HR"
        AccessStatus="Suspended"
        RiskScore=70
    }
    [PSCustomObject]@{
        Name="Rahul"
        Department="IT"
        AccessStatus="Review"
        RiskScore=85
    }
    [PSCustomObject]@{
        Name="Sneha"
        Department="Finance"
        AccessStatus="Revoked"
        RiskScore=95
    }
    [PSCustomObject]@{
        Name="Vikram"
        Department="IT"
        AccessStatus="Active"
        RiskScore=40
    }
)
```

### The final function

```powershell
function Get-Employee_Review_Report {

    param ($Employees)

    $Active = foreach ($Employee in $Employees) {

        $Action = switch ($Employee.AccessStatus) {
            "Active"     { "User is Active" }
            "Suspended"  { "User is Suspended" }
            "Review"     { "Needs to be reviewed" }
            "Revoked"    { "User is Revoked" }
        }

        [PSCustomObject]@{
            Name         = $Employee.Name
            Department   = $Employee.Department
            AccessStatus = $Employee.AccessStatus
            RiskScore    = $Employee.RiskScore
            Action       = $Action
        }
    }

    $Active |
        Where-Object { $_.AccessStatus -ne "Revoked" } |
        Select-Object Name, Department, AccessStatus, RiskScore,
            @{Name = "RiskLevel"; Expression = {
                if ($_.RiskScore -ge 80) {
                    "Critical"
                }
                elseif ($_.RiskScore -ge 50) {
                    "High"
                }
                else {
                    "Normal"
                }
            }},
            Action |
        Sort-Object RiskScore -Descending
}
```

### Output

| Name | RiskScore | RiskLevel |
|------|-----------|-----------|
| Rahul | 85 | Critical |
| Priya | 70 | High |
| Vikram | 40 | Normal |
| Arun | 25 | Normal |

Sneha was excluded because `AccessStatus = Revoked`.

### Two techniques worth noting

**1. Capturing loop output into a variable**

```powershell
$Active = foreach ($Employee in $Employees) { ... }
```

Everything the loop emits is collected into `$Active`. This is a cleaner alternative to building an array with `+=`.

**2. `switch` for categories, `if/elseif` for ranges**

`AccessStatus` is a discrete set → `switch`.
`RiskScore` is a numeric range → `if/elseif` inside the calculated property.

Both appear in one function, each used where it fits. That is the lesson of section 10 applied.

### Mistakes made

| Mistake | Correction |
|---------|-----------|
| Missing switch input | `switch` needs the value to match: `switch ($Employee.AccessStatus)` |
| Wrong property names | Property names must match the source objects exactly |
| Duplicate variables | Two variables holding related data caused confusion about which to use |
| Pipeline applied to the wrong collection | The pipeline must run on the **transformed** collection (`$Active`), not the source |
| Confusion between source collection and transformed collection | `$Employees` is the input; `$Active` is the enriched output. They are not interchangeable |

---

## 13. switch practice 3 — incident routing

### The dataset

```powershell
$Alerts = @(
    [PSCustomObject]@{
        ID="A101"
        Application="Payments"
        Severity="Critical"
        Status="Open"
        AgeHours=6
    }
    [PSCustomObject]@{
        ID="A102"
        Application="HRPortal"
        Severity="Warning"
        Status="Open"
        AgeHours=30
    }
    [PSCustomObject]@{
        ID="A103"
        Application="Orders"
        Severity="Info"
        Status="Resolved"
        AgeHours=12
    }
    [PSCustomObject]@{
        ID="A104"
        Application="Identity"
        Severity="Critical"
        Status="Open"
        AgeHours=52
    }
    [PSCustomObject]@{
        ID="A105"
        Application="Backup"
        Severity="Warning"
        Status="Open"
        AgeHours=10
    }
)
```

### Routing logic — `switch` on discrete severity

| Severity | Route to |
|----------|----------|
| Critical | Security |
| Warning | Operations |
| Info | ServiceDesk |

### Priority logic — `if/elseif` on a numeric range

| AgeHours | Priority |
|----------|----------|
| 48 and above | Escalate |
| 24 to 47 | High |
| Below 24 | Normal |

### Observed active incidents

| ID | AgeHours | Priority |
|----|----------|----------|
| A104 | 52 | Escalate |
| A102 | 30 | High |
| A105 | 10 | Normal |
| A101 | 6 | Normal |

A103 was excluded because its status was `Resolved`.

**Timing:** approximately **2.1195 ms**

### Important debugging lesson

> For numeric ranges, `if/elseif` was clearer and more reliable than `switch ($true)`.

`switch ($true)` with condition blocks is a known pattern, but it inverts how the statement reads and makes range logic harder to follow. This exercise made the rule concrete: **discrete values → `switch`; ranges → `if/elseif`.** This function uses both, each in its correct place.

---

# Part 2 — File Boundaries

## 14. Import-Csv and Export-Csv

| Cmdlet | Direction |
|--------|-----------|
| `Export-Csv` | PowerShell object → CSV text |
| `Import-Csv` | CSV text → PowerShell objects |

### CSV is

- Flat
- Tabular
- Column-based
- Useful for reports and data exchange

### CSV is not

- A full PowerShell object serialization format

That distinction is the whole of today's CSV lesson. CSV has columns and values. It has no concept of types, nesting or behaviour.

---

## 15. CSV practice — 50,000 servers

### The dataset

```powershell
$Servers = 1..50000 | ForEach-Object {
    [PSCustomObject]@{
        Name       = "SRV$_"
        CPU        = Get-Random -Minimum 10 -Maximum 95
        MemoryGB   = Get-Random -Minimum 8 -Maximum 128
        IsCritical = ($_ % 20 -eq 0)
        Status     = if ($_ % 10 -eq 0) { "Stopped" } else { "Running" }
    }
}
```

Note the deliberate mix of types: `String`, `Int32`, `Int32`, `Boolean`, `String`. That mix is what makes the round-trip test meaningful.

### The function used

```powershell
Function Get-Servers1 {

    Param ($Servers)

    $ExportTime = Measure-Command {
        $Servers | Export-Csv -Path "./servers.csv" -NoTypeInformation
    }

    $Imported = $null

    $ImportTime = Measure-Command {
        $Imported = Import-Csv -Path "./servers.csv"
    }

    $Imported

    $Status = [PSCustomObject]@{
        ImportedServers = $Imported
        ExportTime      = $ExportTime.TotalMilliseconds
        ImportTime      = $ImportTime.TotalMilliseconds
    }

    $Status
}
```

### Measured results

| Run | ExportTime | ImportTime |
|-----|-----------|-----------|
| 1 | approximately 96.319 ms | approximately 131.7571 ms |
| 2 | approximately 91.6602 ms | approximately 169.8071 ms |

**Observation:** import was consistently slower than export in these runs, and timings vary between runs and between machines. A single measurement is not a benchmark.

> ⚠️ See [section 33](#33-code-review-notes) for a review note on this function's output behaviour.

---

## 16. CSV type comparison

This is the most important experiment of the day.

### The comparison performed

```powershell
$OriginalType1 = $Servers[0].CPU.GetType().Name
$ImportedType1 = $Imported[0].CPU.GetType().Name

$OriginalType2 = $Servers[0].MemoryGB.GetType().Name
$ImportedType2 = $Imported[0].MemoryGB.GetType().Name

$OriginalType3 = $Servers[0].IsCritical.GetType().Name
$ImportedType3 = $Imported[0].IsCritical.GetType().Name

$OriginalType1 -ne $ImportedType1
$OriginalType2 -ne $ImportedType2
$OriginalType3 -ne $ImportedType3
```

### Observed results

```
Int32   -ne String
Int32   -ne String
Boolean -ne String
```

| Property | Original type | Type after Import-Csv |
|----------|--------------|----------------------|
| `CPU` | `Int32` | **`String`** |
| `MemoryGB` | `Int32` | **`String`** |
| `IsCritical` | `Boolean` | **`String`** |

All three comparisons returned `True`, meaning every type changed.

### Why this matters for automation

- **Arithmetic may require conversion.** `$imported.CPU + 10` would concatenate, not add.
- **Boolean logic may require conversion.** `IsCritical` is now the string `"True"` or `"False"`. The string `"False"` is a non-empty string, which is **truthy**. An `if ($server.IsCritical)` test would pass for every row.
- **Validation is necessary after `Import-Csv`.** Never assume the types you exported are the types you get back.

```
Export-Csv writes:   85         True
                     │          │
                     ▼          ▼
Import-Csv returns:  "85"       "True"
                     String     String
```

### The fix pattern

```powershell
$Imported | ForEach-Object {
    [PSCustomObject]@{
        Name       = $_.Name
        CPU        = [int]$_.CPU
        MemoryGB   = [int]$_.MemoryGB
        IsCritical = [bool]::Parse($_.IsCritical)
        Status     = $_.Status
    }
}
```

Types must be restored deliberately on the way back in, because CSV never carried them.

---

## 17. CSV count validation

```powershell
$Servers.Count
$Imported.Count
```

### Observed

```
Servers       : 50000
ImportedCount : 50000
CountsMatch   : True
```

### Why it matters

Record count validation is one of the first checks after a file round trip. It catches truncation, a partial write, a locked file, or a disk that filled up.

> Count validation proves **how many** records survived. It says nothing about whether their **types** survived. Both checks are needed — as section 16 demonstrated, the counts matched perfectly while every type had changed.

---

## 18. JSON theory

| Cmdlet | Direction |
|--------|-----------|
| `ConvertTo-Json` | PowerShell object → JSON text |
| `ConvertFrom-Json` | JSON text → PowerShell object |

### JSON is useful for

- APIs
- Configuration
- Nested data
- Structured automation data

Unlike CSV, JSON **can represent nested structures**. That is the reason it is the format of every REST API you will touch.

---

## 19. Out-File

```powershell
$Json | Out-File "./servers.json"
```

### The distinction learned

- `ConvertTo-Json` performs the **serialization** — it turns objects into JSON text.
- `Out-File` **writes text to disk**.
- `Out-File` by itself does **not** convert a PowerShell object into JSON.

```
$Servers ──ConvertTo-Json──> JSON text ──Out-File──> servers.json
           (serialization)               (writing)
```

Two separate responsibilities. Confusing them produces a file full of type names instead of data.

---

## 20. Get-Content -Raw

```powershell
$JsonText = Get-Content -Path "./servers.json" -Raw
```

| | Behaviour |
|---|---|
| Without `-Raw` | Returns an **array of lines** |
| With `-Raw` | Returns the **complete file as one string** |

JSON is a single document, not a set of independent lines. Passing an array of lines to `ConvertFrom-Json` is not the same as passing the whole document, which is why `-Raw` is the correct choice before:

```powershell
$Restored = $JsonText | ConvertFrom-Json
```

---

## 21. JSON nested object dataset

```powershell
$Servers = 1..10000 | ForEach-Object {

    $CPU = Get-Random -Minimum 10 -Maximum 95
    $MemoryGB = Get-Random -Minimum 8 -Maximum 128

    [PSCustomObject]@{
        Name        = "SRV$_"
        IsCritical  = ($CPU -gt 80)
        Status      = if ($_ % 10 -eq 0) { "Stopped" } else { "Running" }
        Environment = if ($_ % 2 -eq 0) { "Production" } else { "Development" }

        Monitoring = [PSCustomObject]@{
            CPU      = $CPU
            MemoryGB = $MemoryGB
        }

        Owner = "Team-$($_ % 5 + 1)"
        Tags  = "Role:App, Region:US-East"
    }
}
```

Note the structure: `Monitoring` is a **nested object**, which is exactly what CSV cannot represent and what makes the JSON depth test meaningful.

### Parser error encountered

At one point `IsCritical` was declared twice, producing:

```
ParserError: Duplicate keys 'IsCritical' are not allowed in hash literals.
```

**Fix:** the duplicate property was removed.

**Lesson:** a hashtable literal cannot contain the same key twice. This error is caught at parse time, which is the helpful kind of failure — unlike the silent ones documented elsewhere today.

---

## 22. JSON round-trip function

```powershell
Function Server-Collection {

    Param($Servers)

    $Json = $Servers | ConvertTo-Json -Depth 3

    $Json | Out-File "./Servers.Json"

    $JsonText = Get-Content -Path "./servers.json" -Raw

    $Restored = $JsonText | ConvertFrom-Json

    $Restored
}
```

### The workflow

```
$Servers
    │
    ├─ ConvertTo-Json -Depth 3   → JSON text
    ├─ Out-File                  → ./Servers.Json on disk
    ├─ Get-Content -Raw          → the whole file as one string
    ├─ ConvertFrom-Json          → PowerShell objects
    └─ $Restored                 → returned to the caller
```

Every stage is a separate, nameable operation. Understanding which stage does what is what makes the failures in section 31 diagnosable.

---

## 23. JSON count validation

```powershell
$Restored = Server-Collection -Servers $Servers

$Servers.Count
$Restored.Count
```

### Observed

```
10000
10000
```

Original and restored record counts matched.

---

## 24. JSON nested property validation

```powershell
$Restored[0].Monitoring
```

### Observed

```
CPU MemoryGB
19  44
```

Then:

```powershell
$Restored[0].Monitoring.CPU
```

### Observed

```
19
```

This confirmed that the nested `Monitoring` data survived the JSON round trip **at depth 3**.

### Why this specific check matters

The count check passed. The top-level properties looked fine. Only by reaching **into** the nested object was it possible to prove the nesting survived. A validation that only checks record counts would have reported success on a truncated export.

---

## 25. JSON depth

### The rule

> `ConvertTo-Json` has a **default depth of 2**. Depth determines how deeply nested PowerShell objects are serialized.

### The actual experiment

**Without an explicit depth:**

```powershell
$TestJson = $Servers[0] | ConvertTo-Json

$TestObject = $TestJson | ConvertFrom-Json
```

The nested `Monitoring` data was **not available as expected**.

**With an explicit depth:**

```powershell
$TestJson = $Servers[0] | ConvertTo-Json -Depth 3

$TestObject = $TestJson | ConvertFrom-Json
```

Verification:

```powershell
$TestObject.Monitoring
$TestObject.Monitoring.CPU
```

The CPU value was successfully restored.

### What makes this dangerous

`ConvertTo-Json` does not throw when it hits the depth limit. It serializes what it can and stops. The file is written, the export "succeeds", and the nested data is gone. This is a **silent data loss**, the same failure class as the CSV type loss — and the reason validation after a round trip is not optional.

### Interview statement

> "The `-Depth` parameter controls how deeply `ConvertTo-Json` serializes nested objects. The default depth is 2, so I specify an appropriate depth when working with nested data."

---

## 26. JSON performance

```powershell
Measure-Command {
    Server-Collection -Servers $Servers
}
```

### Observed

| Run | Time |
|-----|------|
| Final measurement | **468.8936 ms** |
| Earlier measurement | approximately **299 ms** |

### What this means

Execution time varies between runs. Do not treat a single measurement as an absolute benchmark. Variation between two runs of identical code is normal and is caused by machine state, caching and background load.

The engineering habit: measure more than once, and compare like with like.

---

## 27. The file boundary concept

### Definition

> A **file boundary** is where structured PowerShell data leaves memory and becomes serialized data.

### CSV path

```
PowerShell Objects
    → Export-Csv
    → CSV file
    → Import-Csv
    → PowerShell Objects
```

**What can be lost or changed:**

- Original data types
- Nested structures
- Methods
- Object behaviour

### JSON path

```
PowerShell Objects
    → ConvertTo-Json
    → JSON file
    → Get-Content -Raw
    → ConvertFrom-Json
    → PowerShell Objects
```

**What can be lost or changed:**

- Nested data beyond the serialization depth
- Unsupported object behaviour
- Methods are not preserved as methods
- Serialization decisions affect the restored structure

### Key engineering lesson

> **Never assume a file round trip preserves the original object exactly. Validate.**

### Today's proof

| Format | What was validated | Result |
|--------|-------------------|--------|
| CSV | Record count | 50,000 = 50,000 ✅ |
| CSV | Types | `Int32` → `String`, `Boolean` → `String` ❌ |
| JSON | Record count | 10,000 = 10,000 ✅ |
| JSON | Nested property at depth 3 | Survived ✅ |
| JSON | Nested property at default depth 2 | Lost ❌ |

The counts passed in both cases. The interesting failures were only visible to a type check and a nested-property check.

---

# Part 3 — Debugging, Environment and Review

## 28. Scope and dot-sourcing

### The problem

Running:

```powershell
./Script.ps1
```

did **not** leave the functions available in the current terminal session.

### The fix

```powershell
. ./Script.ps1
```

### Explanation

The leading dot followed by a space **dot-sources** the script into the current PowerShell scope. Running a script normally executes it in its own scope, which is discarded when it finishes — taking the function definitions with it.

```
./Script.ps1      → runs in a child scope → definitions discarded on exit
. ./Script.ps1    → runs in the CURRENT scope → definitions remain available
```

This was required so that functions such as `Get-Servers1` and `Server-Collection` could be called afterwards.

---

## 29. Working directory

### The problem

The terminal was in:

```
/Users/abhiramkulkarni
```

The project was actually in:

```
/Users/abhiramkulkarni/Downloads/rag-lesson-generator/src
```

### The fix

```powershell
cd "/Users/abhiramkulkarni/Downloads/rag-lesson-generator/src"

Get-Location

ls
```

`ls` then showed `Script.ps1`.

### Why this matters

Every relative path in today's work resolves against the **current working directory**:

```
./servers.csv
./servers.json
./Script.ps1
```

If the working directory is wrong, `Export-Csv -Path "./servers.csv"` silently writes the file somewhere unexpected, and the later `Import-Csv` fails or reads a stale file. `Get-Location` is the check.

---

## 30. Measure-Command

```powershell
Measure-Command {
    Server-Collection -Servers $Servers
}
```

### What it does

Measures the execution time of a script block.

### The result is a TimeSpan

Useful properties:

```powershell
.TotalMilliseconds
.TotalSeconds
```

### Practical guidance

- Benchmark with **realistic dataset sizes**. A 10-item test tells you nothing about a 100,000-item workload.
- Run more than once. Today's JSON round trip measured 299 ms and 468.8936 ms on different runs of the same code.
- Be careful about variable scope inside the measured block (see debugging item 4 below).

---

## 31. Debugging log

Every item below is a real problem hit during Day 4.

### 1. Function not recognized

**Cause:** the script was not loaded into the current scope.
**Fix:** `. ./Script.ps1`

### 2. Script not found

**Cause:** wrong current directory.
**Fix:** `cd` to the project `src` directory.

### 3. Monitoring created as a script block

```powershell
# ❌ Wrong — this is a script block, not an object
Monitoring = {
    CPU = ...
    MemoryGB = ...
}
```

**Problem:** it stored a script block rather than a nested object.

```powershell
# ✅ Correct
Monitoring = [PSCustomObject]@{
    CPU      = ...
    MemoryGB = ...
}
```

**Lesson:** `{ }` is a script block. `@{ }` is a hashtable. `[PSCustomObject]@{ }` is an object. They look similar and behave completely differently.

### 4. `$Imported` not available after `Measure-Command`

**Lesson:** be careful about scope and how data is captured from a measured script block. The variable must be reachable after the block finishes — which is why `$Imported = $null` was declared before the `Measure-Command` block in section 15.

### 5. Incorrect `ConvertFrom-Json` usage

```powershell
# ❌ Wrong
$JsonText | ConvertFrom-Json "./servers.json"

# ✅ Correct
$Restored = $JsonText | ConvertFrom-Json
```

**Lesson:** `ConvertFrom-Json` converts the JSON **text** it receives. It does not take a file path — reading the file is `Get-Content`'s job.

### 6. `$TestObject` scope issue

`$TestObject` was created inside a function and then inspected outside it. Variables created inside a function do not exist in the caller's scope.

### 7. Forgot to return `$Restored`

**Fix:** the function must emit the value:

```powershell
$Restored
```

**Lesson:** a function that computes the right answer and never emits it returns nothing at all.

### 8. Default JSON depth did not preserve required nested data

**Fix:**

```powershell
ConvertTo-Json -Depth 3
```

### 9. Created `$Json1` from already-serialized JSON

```powershell
# ❌ Wrong — serializing JSON text again
$Json1 = $Json | ConvertTo-Json -Depth 3

# ✅ Correct
$Json = $Servers | ConvertTo-Json -Depth 3
```

**Lesson:** `ConvertTo-Json` takes **objects**. Passing it a JSON string produces a JSON-encoded string containing JSON — double serialization.

### 10. Saved the wrong JSON variable to file

The JSON produced with the appropriate depth must be the one written to disk. Writing the wrong variable means the file does not contain what the later validation assumes.

### 11. Duplicate `IsCritical` property

```
ParserError: Duplicate keys 'IsCritical' are not allowed in hash literals.
```

**Fix:** remove the duplicate key.

### 12. Variable naming mistakes

Repeated issues with inconsistent variable names throughout Day 4: `-Deployements`, `$Deployemnts`, and general inconsistency between where a variable was defined and where it was used.

**Lesson:** PowerShell does not error on an undefined variable — it evaluates to `$null`. A typo produces empty results, not an error message. This was the single most repeated problem of the day.

> `Set-StrictMode -Version Latest` makes undefined variables throw instead of silently returning `$null`. Marked as further learning, not covered today.

### 13. Infinite loop from `=` instead of `-eq`

```powershell
while ($Status = "Running")    # ❌ assignment — always truthy
while ($Status -eq "Running")  # ✅ comparison
```

**Lesson:** `=` assigns, `-eq` compares. An assignment inside a condition evaluates as truthy, so the loop never terminates.

### The pattern across all thirteen

| Category | Items |
|----------|-------|
| Environment and scope | 1, 2, 4, 6 |
| Wrong construct for the job | 3, 5, 9, 13 |
| Incomplete function contract | 7, 10 |
| Serialization configuration | 8 |
| Typos and naming | 11, 12 |

Four of the thirteen were **silent** failures — nothing errored, the wrong result just appeared. Those are the expensive ones.

---

## 32. JSON truncation scenario

### The scenario

A JSON export silently loses nested data.

### Cause

Insufficient `ConvertTo-Json` depth. The default is **2**.

### Fix

```powershell
$Json = $Servers | ConvertTo-Json -Depth 3
```

### Verify after import

```powershell
$Restored[0].Monitoring.CPU
```

### Why verification is the real answer

Setting the depth fixes this instance. **Checking a nested property after the round trip** is what catches the next one, when the object gains a fourth level and depth 3 is no longer enough. The fix is a value; the practice is a validation step.

---

## 33. Code review notes

These are observations from reviewing the Day 4 code, not errors encountered during the session. Recorded here for the refactor that is still pending.

### `Get-Servers1` emits twice

```powershell
$Imported        # ← emits all 50,000 imported objects

$Status = [PSCustomObject]@{ ... }
$Status          # ← then emits the status object
```

The function outputs the full 50,000-record collection **and** a status object that also contains that collection in its `ImportedServers` property. A caller receives both streams mixed together. This is the output pollution pattern from Day 1: anything not captured is emitted.

**To address in the refactor:** decide on a single return value and emit only that.

### Function naming

| Function | Note |
|----------|------|
| `Get-Servers1` | Trailing digit; the noun should describe what is returned |
| `Server-Collection` | Noun-noun, not verb-noun |
| `Get-Employee_Review_Report` | Underscores are not the PowerShell convention |

Approved verb-noun naming was covered on Day 2. These are candidates for renaming during the refactor.

### Parameters are untyped

```powershell
Param ($Servers)
```

None of today's functions type their parameters. Typed parameters were covered on Day 1 and 2 and would be a straightforward improvement — particularly on the functions that assume a collection of objects.

---

# Part 4 — Status

## 34. Q10 / Q11 / Q12

### Q10 — ✅ COMPLETED

**Scenario:** 10,000-server infrastructure inventory.

**Requirements:**
- Function-based ✅
- Export JSON ✅
- Import JSON ✅
- Appropriate depth ✅
- Verify count ✅
- Verify nested Monitoring ✅
- Measure round trip ✅

**Results:**

| Check | Result |
|-------|--------|
| Original count | 10,000 |
| Restored count | 10,000 |
| Nested `Monitoring` | Survived |
| `Monitoring.CPU` | Accessible |
| Round-trip timing | approximately 468.8936 ms |

### Q11 — ⬜ PENDING

CSV vs JSON nested round-trip comparison.

Not completed at the time this README was written. The individual CSV and JSON round trips were each performed; the **side-by-side comparison of the same nested object through both formats**, documenting every property that changed type, was not.

### Q12 — ⬜ PENDING

Debugging and file-boundary validation exercise.

Not completed at the time this README was written.

---

## 35. Interview questions

### Q1 — When is ForEach-Object slower than foreach?

> `ForEach-Object` can be slower when processing large in-memory collections because objects move through the pipeline and the script block is invoked for each object. `foreach` directly iterates the collection and often has less overhead. It is not correct to say `foreach` is always faster — it depends on the workload. In my own test over 100,000 objects, `foreach` took about 274 ms and `ForEach-Object` about 385 ms, so the pipeline overhead was around 110 ms for that specific workload.

### Q2 — What does ConvertTo-Json -Depth default to?

> The default depth is 2. The `-Depth` parameter controls how deeply nested PowerShell objects are serialized. The important part is that exceeding the depth does not throw — it silently drops the nested data, so the export appears to succeed. I hit this directly: a nested `Monitoring` object was missing after a default-depth round trip and came back correctly at `-Depth 3`.

### Q3 — What type information survives a CSV round trip?

> CSV preserves column names and values but does not preserve the original PowerShell object type information. Imported values commonly come back as strings. I tested this on a 50,000-row export: `CPU` went from `Int32` to `String`, `MemoryGB` from `Int32` to `String`, and `IsCritical` from `Boolean` to `String`. The record count matched perfectly, which is exactly why a count check alone is not enough — I check types too, and cast deliberately after import.

### Q4 — When would you use switch instead of if?

> I use `switch` when matching one value against multiple discrete cases such as service status, severity or environment. I use `if/elseif` for ranges or more complex Boolean conditions. In an incident-routing function I wrote both in the same place: `switch` on severity to pick the routing team, and `if/elseif` on age in hours to set the priority. I tried `switch ($true)` for the numeric ranges first and found `if/elseif` clearer and more reliable.

---

## 36. Key mental models

| Construct | Mental model |
|-----------|-------------|
| `foreach` | Direct collection iteration |
| `ForEach-Object` | Pipeline-based iteration |
| `while` | Check condition first — may run zero times |
| `do...while` | Execute first, check afterwards — runs at least once |
| `switch` | Match discrete values |
| CSV | Flat / tabular representation |
| JSON | Structured / nested representation |
| `ConvertTo-Json` | PowerShell object → JSON text |
| `ConvertFrom-Json` | JSON text → PowerShell object |
| `Export-Csv` | PowerShell object → CSV file |
| `Import-Csv` | CSV file → PowerShell objects |
| `Out-File` | Writes text to a file |
| `Get-Content -Raw` | Reads the complete file as one string |
| `-Depth` | Controls JSON nesting serialization |
| `Measure-Command` | Measures execution time |
| **File boundary** | The point where in-memory object structure becomes serialized data |

---

## 37. Day 4 final checklist

### Completed

- [x] `foreach`
- [x] `ForEach-Object`
- [x] `while`
- [x] `do...while`
- [x] `switch`
- [x] Performance comparison
- [x] `Import-Csv`
- [x] `Export-Csv`
- [x] CSV round trip
- [x] CSV type-loss investigation
- [x] CSV count validation
- [x] `ConvertTo-Json`
- [x] `ConvertFrom-Json`
- [x] `Out-File`
- [x] `Get-Content -Raw`
- [x] JSON nested objects
- [x] JSON `-Depth`
- [x] JSON round trip
- [x] JSON count validation
- [x] JSON nested-property validation
- [x] `Measure-Command`
- [x] Interview questions
- [x] Q10

### Pending

- [ ] Nested JSON vs CSV round-trip comparison (Q11)
- [ ] JSON truncation debugging exercise
- [ ] File-boundary debugging exercise (Q12)
- [ ] Four-level Daily Challenge
- [ ] Import/export helpers finalized
- [ ] Code refactored
- [ ] Day 4 fully completed

### Daily challenge — ⬜ PENDING

**Requirement:** serialize a four-level object and restore it with zero loss.

Not completed. Expected skills when attempted:

- `PSCustomObject`
- Nested objects
- Arrays and collections where relevant
- Functions
- Serialization with `ConvertTo-Json` / `ConvertFrom-Json`
- `-Depth`
- Validation
- Data integrity
- Performance
- Debugging

### Deliverable — ⬜ PENDING

**Requirement:** import and export helpers committed.

Planned helper concepts:

- CSV export helper
- CSV import helper
- JSON export helper
- JSON import helper

### Git tracking — ⬜ NOT COMPLETED

- [ ] Created code
- [ ] Tested code
- [ ] Refactored code
- [ ] Committed code
- [ ] Pushed code

**Planned commit:**

```
feat(core): add JSON and CSV import and export helpers
```

No Git work was performed. Nothing has been committed or pushed.

---

## 38. Day 4 summary

### What I learned

- **Control-flow selection** — which construct fits which problem, rather than defaulting to one
- **Collection iteration** with `foreach`
- **Pipeline iteration** with `ForEach-Object`, and the overhead it introduces
- **Performance measurement** with `Measure-Command`, and that a single run is not a benchmark
- **CSV serialization** and what it cannot carry
- **JSON serialization** and what depth controls
- **Nested data** handling and validation
- **JSON depth** and its silent failure mode
- **File boundaries** as a concept worth naming
- **Data integrity validation** after every round trip
- **Debugging** across scope, working directory, construct choice and typos

### What I can now explain in an interview

- `foreach` vs `ForEach-Object`, with a measured example
- `while` vs `do...while`
- `switch` vs `if/elseif`
- CSV type loss, with a concrete `Int32` → `String` result
- JSON `-Depth` and why exceeding it fails silently
- Serialization and deserialization as distinct operations
- File-boundary risks and what validation catches them
- Performance measurement and its limits

### The single idea to carry forward

> A file boundary is where structure goes to die quietly. The count matching proves nothing about the types or the nesting. **Validate after every round trip, and validate the thing you actually depend on.**

### What remains for Day 4

1. Q11 — nested JSON vs CSV round-trip comparison
2. Q12 — file-boundary debugging exercise
3. JSON truncation debugging exercise
4. Daily challenge — four-level object, zero-loss round trip
5. Import and export helpers finalized
6. Code refactored (see [section 33](#33-code-review-notes))
7. Git: create, test, refactor, commit, push

---

*Day 4 of 90 · PowerShell Automation Engineer plan · Status: partially complete*
