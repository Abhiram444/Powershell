# Day 8 — Functions, Approved Verbs and Output Control

> **PowerShell Automation Engineer — 90 Day Plan · Week 2**
> This is a **learning-history** document, not a polished tutorial. Mistakes are preserved deliberately, with my original answers kept separate from the corrections.

**Tracker objective**

> Write a function whose output can be predicted exactly, and name functions the way PowerShell expects.

---

## Table of Contents

**Theory**
1. [Function fundamentals](#1-function-fundamentals)
2. [Approved verbs](#2-approved-verbs)
3. [Natural output vs return](#3-natural-output-vs-return)
4. [Collection enumeration](#4-collection-enumeration)
5. [Output streams](#5-output-streams)
6. [Output pollution — the 56-object debug](#6-output-pollution--the-56-object-debug)
7. [Measure-Object validation](#7-measure-object-validation)

**Hands-on**
8. [Q015 — Get-FailedProductionDeployment](#8-q015--get-failedproductiondeployment)
9. [Q016 — Get-SlowProductionDeployment](#9-q016--get-slowproductiondeployment)
10. [Q017 — Get-ProductionDeploymentReport](#10-q017--get-productiondeploymentreport)
11. [Toolkit refactor — scope and intent](#11-toolkit-refactor--scope-and-intent)
12. [Get-EndpointHealth](#12-get-endpointhealth)
13. [Day 8 endpoint dataset change](#13-day-8-endpoint-dataset-change)
14. [Health boundary tests](#14-health-boundary-tests)
15. [Health validation](#15-health-validation)
16. [Get-EndpointStatus](#16-get-endpointstatus)
17. [Daily challenge — Get-DeploymentReport](#17-daily-challenge--get-deploymentreport)

**Record**
18. [Interview round](#18-interview-round)
19. [Documentation reference](#19-documentation-reference)
20. [My mistakes](#20-my-mistakes)
21. [Core mental models](#21-core-mental-models)
22. [Final scorecard](#22-final-scorecard)
23. [Intentionally skipped](#23-intentionally-skipped)
24. [Final Day 8 status](#24-final-day-8-status)

---

# Theory

## 1. Function fundamentals

### What a PowerShell function is

A named, reusable block of code that performs a specific task. It accepts input through parameters and produces output that flows into the pipeline.

### Why functions

| Benefit | What it means in practice |
|---------|--------------------------|
| **Reusability** | Write the logic once, call it by name wherever it is needed |
| **Maintainability** | A change happens in one place, not in fifteen copies |
| **Testability** | A function with defined input and output can be tested in isolation |
| **Parameterized input** | Behaviour is controlled by the caller, not by editing the code |
| **Predictable output** | The caller knows what they will receive before they call it |

### Basic syntax

```powershell
function Verb-Noun {
    param (
        $Parameter
    )

    # function logic

    $Result
}
```

| Element | Purpose |
|---------|---------|
| `function` | The keyword that declares a function |
| `Verb-Noun` | The name, following PowerShell's naming convention |
| `param ( )` | Declares the inputs the function accepts |
| Body | The work |
| `$Result` | The output — note that no `return` is required |

### Example

```powershell
function Get-EndpointHealth {
    param (
        $Endpoints
    )

    foreach ($Endpoint in $Endpoints) {
        # health logic
    }
}
```

### Parameters as inputs

```powershell
function Get-ServerStatus {
    param (
        $Server
    )

    $Server.Status
}
```

```powershell
Get-ServerStatus -Server $MyServer
```

### The predictable output contract

A function should be something the caller can reason about without reading its body:

```
Input → Process → Object Output
```

The caller supplies known input, the function does its work internally, and emits **only** what it promised. Anything else appearing in the output is a defect — which is the subject of [section 6](#6-output-pollution--the-56-object-debug).

---

## 2. Approved verbs

### What approved verbs are

PowerShell defines a standard set of verbs for command names. They are not a style preference — they are a convention the whole ecosystem follows, and tooling relies on them.

```powershell
Get-Verb
```

Lists every approved verb along with its verb group.

### Why Verb-Noun naming matters

| Reason | Explanation |
|--------|------------|
| **Purpose is obvious** | `Get-EndpointHealth` says what it does before you read a line of it |
| **Discoverability** | Someone looking for a retrieval command knows to look for `Get-` |
| **Consistency** | Your functions behave like the built-in commands |
| **Maintainability** | A consistent naming scheme survives handover |

The **verb** describes the action. The **noun** identifies the target.

### Examples covered

```
Get-Endpoint
Set-Endpoint
Remove-Endpoint
Test-Endpoint
Get-EndpointHealth
Export-EndpointReport
```

### Preferred vs invented verbs

```powershell
Get-User        # ✅ Get is the approved verb for retrieval
Fetch-User      # ❌ Fetch is not an approved verb
```

Both work. Only one is discoverable, consistent and conventional.

### Common verbs discussed

| Verb | Typical meaning |
|------|----------------|
| `Get` | Retrieve |
| `Set` | Establish or change a value, state or configuration |
| `New` | Create |
| `Remove` | Delete |
| `Add` | Add |
| `Clear` | Clear or reset |
| `Update` | Update |
| `Test` | Test or evaluate |
| `Convert` | Transform representation or type |
| `Import` | Bring data in |
| `Export` | Send data out |

> **Note on `Set`:** it does not mean only "update". It is the verb for **establishing or changing** a value, configuration or state — which includes setting something that had no previous value.

---

## 3. Natural output vs return

### PowerShell does not require `return`

```powershell
function Get-Number {
    $x = 10
    $x
}
```

This outputs `10`.

**Why:** PowerShell automatically writes **uncaptured expressions** to the success output stream. The bare `$x` is an expression whose value is not assigned to anything, so it becomes the function's output. No `return` needed.

### The critical distinction

```powershell
$Result            # outputs the value, execution CONTINUES
return $Result     # outputs the value, function EXITS IMMEDIATELY
```

### What `return` actually does

`return` has **two** behaviours, and the second is the one people forget:

1. It outputs the specified value.
2. It **immediately exits** the current function or scope.

```powershell
function Get-Number {
    $x = 10

    return $x

    Write-Host "This never executes"
}
```

The `Write-Host` line is unreachable.

### What `return` is NOT for

> `return` is **not** primarily a mechanism for stopping unassigned variables from entering the output.

This was my original misunderstanding, recorded in [Interview Question 2](#question-2). `return` does not filter or suppress anything. If an expression earlier in the function emitted output, `return` does not undo it. Preventing unwanted output is done by **capturing** intermediate results into variables, not by using `return`.

### Mental model

```
return
   → output value
   → exit function
```

---

## 4. Collection enumeration

### The setup

```powershell
$Results = [System.Collections.Generic.List[PSCustomObject]]::new()

$Results.Add([PSCustomObject]@{Name = "Server01"})
$Results.Add([PSCustomObject]@{Name = "Server02"})
$Results.Add([PSCustomObject]@{Name = "Server03"})

$Results
```

### What `.Add()` does

`.Add()` **stores** the object in the list. It produces no pipeline output of its own. That matters in [section 6](#6-output-pollution--the-56-object-debug): adding to a list is not the same as emitting.

### What happens when a collection is emitted

```powershell
$Results
```

PowerShell normally **enumerates** the collection. Three items in the list means the caller receives **three individual objects**, not one list object.

```
List with 3 items
      ↓ emitted
pipeline receives: object, object, object
```

### Preserving the collection as one object

```powershell
return (, $Results)
```

The **unary comma** wraps the collection in a one-element array, which prevents the normal enumeration from unwrapping the list itself.

### Observed behaviour from testing

| Expression | Result | Meaning |
|------------|--------|---------|
| `$result.GetType().Name` | `List`1` | When preserved with `return (, $Results)` — the caller holds the actual List |
| `$result[0].GetType().Name` | `PSCustomObject` | An individual item inside the collection |

### Three things that are easy to confuse

| Concept | What it is |
|---------|-----------|
| **Collection type** | What the container is — `List`1`, `Object[]` |
| **Individual object type** | What each item is — `PSCustomObject` |
| **Pipeline enumeration** | Whether the container was unwrapped on the way out |

An item being a `PSCustomObject` and the container being `Object[]` are **not** in conflict. The container type tells you how it was emitted; the item type tells you what the items are.

### Important

> `return` does **not** prevent enumeration. The **comma** prevents enumeration.
>
> `return $Results` means *output `$Results` and exit*. It does not mean *treat this as one object*.

---

## 5. Output streams

### Write-Output

```powershell
Write-Output "Server checked"
```

- Goes into the **normal success output** stream
- Becomes part of the function's pipeline output
- **Can cause output pollution** when used for status messages

Note that `Write-Output "x"` and a bare `"x"` do the same thing. `Write-Output` is not required to produce output — a bare expression is normally sufficient.

### Write-Host

```powershell
Write-Host "Checking server..."
```

- Writes directly to the **host/display**
- Does **not** become normal structured pipeline data
- Intended for console-facing messages

**Why it should not be the return mechanism of an automation function:** the caller cannot capture it. `$result = Get-Thing` where the function only uses `Write-Host` gives the caller nothing. The message appears on screen and the variable is empty.

### Write-Verbose

```powershell
Write-Verbose "Checking endpoint $($Endpoint.ComputerName)"
```

- Used for **diagnostic** information
- Separate from normal success output
- **Normally hidden** unless `-Verbose` is used

```powershell
Get-EndpointHealth -Endpoints $Endpoints -Verbose
```

> **Prerequisite:** `-Verbose` is a *common parameter*, which only exists on **advanced** functions — those with `[CmdletBinding()]` or at least one `[Parameter()]` attribute. `Get-EndpointHealth` and `Get-EndpointStatus` both qualify because they use `[Parameter(Mandatory)]`.

`Write-Verbose` does **not** automatically write to a log file. It writes to the Verbose stream.

### The final mental model

```
$Object                  → normal pipeline output
Write-Output $Object     → normal pipeline output
Write-Verbose "message"  → optional diagnostic information
Write-Host "message"     → display to the person running the script
```

---

## 6. Output pollution — the 56-object debug

### The scenario

A function that should return **3** critical server objects returned **56**.

### The original problematic function

```powershell
function Get-CriticalServers {
    param (
        [Parameter(Mandatory)]
        $Servers
    )

    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Server in $Servers) {
        Write-Verbose "Checking $($Server.Name)"

        if ($Server.Status -eq "Online" -and $Server.CPU -ge 90) {
            $Result = [PSCustomObject]@{
                Name   = $Server.Name
                CPU    = $Server.CPU
                Status = "Critical"
            }

            $Results.Add($Result)

            Write-Output "Critical server found: $($Server.Name)"
        }

        $Server
    }

    Write-Verbose "Found $($Results.Count) critical servers"

    return $Results
}
```

### Exactly why it polluted

There were **two** defects, and they produced 53 unwanted objects between them.

**Problem 1 — `Write-Output` produced 3 strings**

```powershell
Write-Output "Critical server found: $($Server.Name)"
```

This fires once per critical server. It is a **status message**, but `Write-Output` puts it into the normal success stream, so it becomes pipeline data.

**Problem 2 — the bare `$Server` emitted all 50 servers**

```powershell
foreach ($Server in $Servers) {
    ...
    $Server      # ← uncaptured expression, inside the loop, for EVERY server
}
```

This line sits outside the `if`, so it runs for all 50 iterations regardless of whether the server is critical.

### The arithmetic

| Source | Count |
|--------|-------|
| `return $Results` — the 3 intended objects, enumerated | 3 |
| `Write-Output` strings | 3 |
| Bare `$Server` expression | 50 |
| **Total** | **56** |

### The crucial point about `.Add()`

> `$Results.Add($Result)` only **stores** the object in the List. It does **not** itself create pipeline output.

The 3 intended objects reach the caller because of `return $Results` at the end, not because of `.Add()`. Confusing those two is what makes this bug hard to see — it looks like the `.Add()` is "the output".

Note also that `Write-Verbose` contributed **zero** objects. It is on a separate stream, which is exactly why it is the right tool for diagnostics.

### The corrected version

```powershell
function Get-CriticalServers {
    param (
        [Parameter(Mandatory)]
        $Servers
    )

    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Server in $Servers) {
        Write-Verbose "Checking $($Server.Name)"

        if ($Server.Status -eq "Online" -and $Server.CPU -ge 90) {
            $Results.Add(
                [PSCustomObject]@{
                    Name   = $Server.Name
                    CPU    = $Server.CPU
                    Status = "Critical"
                }
            )
        }
    }

    Write-Verbose "Found $($Results.Count) critical servers"

    $Results
}
```

### Why the corrected version returns only intended objects

| Change | Effect |
|--------|--------|
| `Write-Output` status message removed | 3 strings gone — the information is already available via `Write-Verbose` |
| Bare `$Server` removed | 50 server objects gone |
| `$Result` variable removed, object added directly | One fewer intermediate variable that could leak |
| `return $Results` → `$Results` | Same output, no unnecessary early exit |

Result: **3 objects**, exactly as intended.

### The three sources of accidental output

| # | Source | Example | Fix |
|---|--------|---------|-----|
| **1** | **Uncaptured command** | `Get-ServerStatus` on its own line | Capture it: `$Status = Get-ServerStatus` |
| **2** | **Uncaptured expression** | A bare `$Status` or `$Server` | Remove it, or capture it if needed internally |
| **3** | **Explicit normal output** | `Write-Output "Checking..."` | Use `Write-Verbose` for diagnostics |

---

## 7. Measure-Object validation

### The command

```powershell
FunctionName | Measure-Object
```

### Why it is useful

It counts the objects that **actually reached the pipeline**, which is the only way to verify an output contract empirically. Reading the function and believing it returns 3 is not the same as proving it.

### Three counts that are not the same thing

| Count | What it measures | How to check |
|-------|-----------------|--------------|
| **Internal collection count** | How many items the function stored internally | `$Results.Count` **inside** the function |
| **Pipeline object count** | How many objects reached the caller | `Function \| Measure-Object` |
| **Output object count** | How many the caller ended up holding | `$result.Count` |

In the polluted `Get-CriticalServers`, the internal collection count was **3** while the pipeline object count was **56**. The function was internally correct and externally wrong — which is precisely why you measure the pipeline, not the variable.

### Examples

```powershell
$result | Measure-Object            # Count property shows the real output count
$result.Count                       # how many the caller holds
$result[0].GetType().Name           # what an individual item is
$result[0] | Get-Member             # what properties it has
```

---

# Hands-on

## 8. Q015 — Get-FailedProductionDeployment

### Dataset

```powershell
$Deployments = @(
    [PSCustomObject]@{ Application = "FinanceApp"; Environment = "Production"; Status = "Success" }
    [PSCustomObject]@{ Application = "HRApp";      Environment = "Production"; Status = "Failed" }
    [PSCustomObject]@{ Application = "CRMApp";     Environment = "Test";       Status = "Success" }
    [PSCustomObject]@{ Application = "BillingApp"; Environment = "Production"; Status = "Failed" }
)
```

### Requirements

- Accept `$Deployments`
- Return only **Production** deployments
- Return only **Failed** deployments
- Return the **original objects**
- Produce no extra output
- Use `foreach`
- Do **not** use `return` inside the loop

### My first answer

```powershell
function Get-FailedProductionDeployment { 
    param ($Deployments)
    foreach ($Record in $Deployments){
        if ($_.Environment -eq "Production" -and $_.Status -eq "Failed"){
            $Record
        }
    }
}
```

### Evaluation

**Wrong** — the filtering condition used `$_` instead of the loop variable.

### The mistake

```powershell
foreach ($Record in $Deployments) {
    if ($_.Environment -eq "Production")    # ← $_ is not the loop variable
```

The loop variable is **`$Record`**. `$_` is the current object inside a **pipeline script block**, not inside a `foreach` loop.

**Why it fails silently:** `$_` is `$null` here, so `$null.Environment` is `$null`, so the condition is never true, so the function returns nothing. No error — just empty output.

### Correction

```powershell
function Get-FailedProductionDeployment {
    param ($Deployments)

    foreach ($Record in $Deployments) {
        if ($Record.Environment -eq "Production" -and
            $Record.Status -eq "Failed") {
            $Record
        }
    }
}
```

### Actual output

```
Application Environment Status
----------- ----------- ------
HRApp       Production  Failed
BillingApp  Production  Failed
```

### foreach vs `$_`

```powershell
# foreach → named loop variable
foreach ($Record in $Deployments) {
    $Record.Status
}

# pipeline script block → $_
$Deployments | Where-Object {
    $_.Status -eq "Failed"
}
```

### Lesson learned

> `foreach` gives you a **named loop variable**. `$_` belongs to **pipeline script blocks**. Mixing them produces no error and no results — the worst combination.

**Q015: completed.**

---

## 9. Q016 — Get-SlowProductionDeployment

### Dataset

```powershell
$Deployments = @(
    [PSCustomObject]@{ Application = "FinanceApp"; Environment = "Production"; Status = "Success"; DurationMin = 18 }
    [PSCustomObject]@{ Application = "HRApp";      Environment = "Production"; Status = "Success"; DurationMin = 42 }
    [PSCustomObject]@{ Application = "CRMApp";     Environment = "Test";       Status = "Success"; DurationMin = 55 }
    [PSCustomObject]@{ Application = "BillingApp"; Environment = "Production"; Status = "Failed";  DurationMin = 67 }
    [PSCustomObject]@{ Application = "Analytics";  Environment = "Production"; Status = "Success"; DurationMin = 31 }
)
```

### Requirements

- Production only
- `DurationMin` greater than 30
- Return the **original objects**
- Use `foreach`
- No extra output
- No `return` inside the loop

### My first answer

```powershell
function Get-SlowProductionDeployment {
    param ($Deployments)
    foreach ($Record in $Deployments){
        if ($Record.Environment -eq "Production" -and $Record.DurationMin -gt 30){
            $Record.Application
        }
    }
}
```

### Evaluation

**Partially correct.** The filtering logic was right. The **output contract** was wrong.

### The mistake

```powershell
$Record.Application     # emits a STRING
$Record                 # emits the OBJECT
```

The function returned only the Application name — `HRApp` — instead of the full deployment object.

### Why returning the object matters

A string is a dead end. The caller cannot filter it, sort it on another property, or export it with its other fields. An object keeps every downstream option open:

```powershell
Get-SlowProductionDeployment -Deployments $Deployments |
    Where-Object Status -eq 'Failed' |
    Sort-Object DurationMin -Descending |
    Export-Csv ./slow.csv -NoTypeInformation
```

None of that works on a string. **Extracting a property is the caller's job, not the function's.**

### Correction

```powershell
function Get-SlowProductionDeployment {
    param ($Deployments)

    foreach ($Record in $Deployments) {
        if ($Record.Environment -eq "Production" -and
            $Record.DurationMin -gt 30) {
            $Record
        }
    }
}
```

### Actual output

```
Application Environment Status  DurationMin
----------- ----------- ------ -----------
HRApp       Production  Success 42
BillingApp  Production  Failed  67
Analytics   Production  Success 31
```

### The follow-up test

```powershell
$Result = Get-SlowProductionDeployment -Deployments $Deployments
$Result.Application
```

```
HRApp
BillingApp
Analytics
```

**Clarification:** `$Result` still contains the complete `PSCustomObject`s. `$Result.Application` only **extracts** the Application property from them — it does not mean the function returned strings.

Verification:

```powershell
$Result[0].GetType().Name
# PSCustomObject
```

### Lesson learned

> Return the object. The caller can always take a property out of an object; they cannot put the object back together from a string.

**Q016: completed.**

---

## 10. Q017 — Get-ProductionDeploymentReport

### Requirements

- Accept `$Deployments`
- Production only
- `DurationMin` greater than 30
- Return a **new** `PSCustomObject` per matching record
- Properties: `Application`, `DurationMin`, `Performance`
- `DurationMin > 60` → **Slow**
- `DurationMin 31–60` → **Moderate**
- Use `foreach`
- No extra output
- No `return` inside the loop

### My first answer

```powershell
function Get-ProductionDeploymentReport {
    param ($Deployments)
    $Records = [PSCustomObject]@{}
    foreach ($Record in $Deployments){
        if ($Record.Environment -eq "Production" -and $Record.DurationMin -gt 30){
            $Records.Add($Record.Application,$Record.DurationMin, )
        }
    }
}
```

### Evaluation

**Wrong**, on four counts.

### The mistakes

| # | Mistake | Why it is wrong |
|---|---------|----------------|
| 1 | `$Records = [PSCustomObject]@{}` used as a collection | A `PSCustomObject` is a **single structured object**, not a container |
| 2 | `$Records.Add(...)` | `PSCustomObject` has no `.Add()` method for this purpose. `.Add()` belongs to collection types like `List[T]` |
| 3 | No new object created per record | The requirement was a new `PSCustomObject` for **every** matching deployment |
| 4 | `Performance` never calculated | The business rule was not implemented |

There is also a stray trailing comma in the `.Add(...)` call.

### The key distinction

| Type | What it is | Supports `.Add()` |
|------|-----------|-------------------|
| `[PSCustomObject]` | A **single** structured object with named properties | ❌ No |
| `[System.Collections.Generic.List[T]]` | A **collection** that holds many items | ✅ Yes |

### Correct object design

One new object per matching record:

```powershell
[PSCustomObject]@{
    Application = $Record.Application
    DurationMin = $Record.DurationMin
    Performance = $Performance
}
```

With `Performance` calculated as:

```
DurationMin > 60    → Slow
DurationMin 31–60   → Moderate
```

### Actual output

```
Application DurationMin Performance
----------- ----------- -----------
HRApp                42 Moderate
BillingApp           67 Slow
Analytics            31 Moderate
```

The result objects were verified as `PSCustomObject`.

### Lesson learned

> Know whether you are holding a **container** or an **item**. `.Add()` on a `PSCustomObject` is the same category of error as indexing into a scalar — the type does not support the operation you are assuming.

**Q017: completed.**

---

### What Q015, Q016 and Q017 tested

| Question | Tested | My mistake |
|----------|--------|-----------|
| **Q015** | Filtering and correct use of the `foreach` variable | `$_` instead of `$Record` |
| **Q016** | Returning the object vs returning a property | `$Record.Application` instead of `$Record` |
| **Q017** | Creating a new structured object per record, with calculated business logic | Treating `PSCustomObject` as a collection and calling `.Add()` |

Three questions, three different ways to get the output contract wrong. That was the point of the set.

---

## 11. Toolkit refactor — scope and intent

Day 8 revisited the Day 6 Toolkit utilities, but the purpose was **not** to redesign the business logic.

**The focus was:**

- Function API
- Proper Verb-Noun names
- Parameters
- Predictable output
- Output streams
- Pipeline behaviour
- Function design

**What was actually refactored on Day 8:**

- `Get-EndpointHealth`
- `Get-EndpointStatus`

**What was intentionally skipped:** the remaining Toolkit utilities. The business logic was repetitive and already completed on Day 6, and repeating it would have taught nothing new about function design.

> This document does **not** claim all six Toolkit utilities were rebuilt on Day 8. Two were refactored.

---

## 12. Get-EndpointHealth

### The Day 8 function

```powershell
function Get-EndpointHealth {
    param (
        [Parameter(Mandatory)]
        $Endpoints
    )

    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Record in $Endpoints) {
        if (
            -not $Record.IsOnline -or
            $Record.CPUPercent -ge 90 -or
            $Record.MemoryPercent -ge 80 -or
            $Record.MissingPatches -ge 8
        ) {
            $HealthState = "Critical"
        }
        elseif (
            $Record.CPUPercent -le 50 -and
            $Record.MemoryPercent -le 40 -and
            $Record.MissingPatches -le 2
        ) {
            $HealthState = "Healthy"
        }
        else {
            $HealthState = "Warning"
        }

        $Result = [PSCustomObject]@{
            ComputerName   = $Record.ComputerName
            CPUPercent     = $Record.CPUPercent
            MemoryPercent  = $Record.MemoryPercent
            MissingPatches = $Record.MissingPatches
            IsOnline       = $Record.IsOnline
            LastChecked    = $Record.LastChecked
            HealthState    = $HealthState
        }

        $Results.Add($Result)
    }

    $Results
}
```

### Important corrections applied

| Correction | Why |
|-----------|-----|
| Use `$Record` inside `foreach` | Not `$_` — same mistake as Q015 |
| One result object per record | The function emits one object per input, not a summary |
| End with `$Results` | Pipeline-friendly enumeration; the caller receives individual objects |

### The classification logic

The order of the conditions is the logic. **Critical is evaluated first**, so any single critical condition wins regardless of how good the other metrics are:

```
Critical  ← offline OR CPU ≥ 90 OR Memory ≥ 80 OR Patches ≥ 8   (any one)
Healthy   ← CPU ≤ 50 AND Memory ≤ 40 AND Patches ≤ 2            (all three)
Warning   ← everything else
```

Note the asymmetry: Critical uses `-or` (one bad metric is enough), Healthy uses `-and` (everything must be good). Warning is the remainder, which is why it needs no condition of its own.

---

## 13. Day 8 endpoint dataset change

The endpoint dataset was **regenerated** during Day 8.

```powershell
$Endpoints = 1..100000 | ForEach-Object {
   $CPU = [double](10 + ($_ % 90))

   [PSCustomObject]@{
       ComputerName = if ($_ % 2 -eq 0) { "LAP-$('{0:D5}' -f $_)" } else { "SRV-$('{0:D5}' -f $_) }
       Status = if ($_ % 10 -eq 0) { "Offline" } else { "Online" }
       CPUPercent = $CPU
       MemoryPercent = [double](20 + ($_ % 75))
       MissingPatches = $_ % 12
       IsOnline = ($_ % 10 -ne 0)
       LastChecked = (Get-Date).AddMinutes(-($_ % 1440))
   }
}
```

> ⚠️ **Note on the recorded snippet:** as written above, the `ComputerName` line has an unterminated string — `"SRV-$('{0:D5}' -f $_)` is missing its closing quote. This is preserved exactly as recorded. The working version requires the closing `"`.

### New Day 8 results

| HealthState | Count |
|-------------|-------|
| Critical | 56,886 |
| Healthy | 2,669 |
| Warning | 40,445 |
| **Total** | **100,000** |

### Why the distribution changed

> **The dataset itself changed.** These results are **not** comparable with the Day 6 numbers.

This is worth recording explicitly, because comparing a metric across two different datasets and concluding that something "got worse" is a real and easy mistake. The function did not change its behaviour — the input did.

---

## 14. Health boundary tests

Boundary testing against the classification rules.

### Primary tests

| Test | CPU | Memory | Patches | Online | Result |
|------|-----|--------|---------|--------|--------|
| **A** | 50 | 40 | 2 | Yes | **Healthy** |
| **B** | 51 | 40 | 2 | Yes | **Warning** |
| **C** | 90 | 40 | 2 | Yes | **Critical** |
| **D** | 50 | 80 | 2 | Yes | **Critical** |
| **E** | 50 | 40 | 8 | Yes | **Critical** |
| **F** | 50 | 40 | 2 | **No** | **Critical** |

**Why each lands where it does:**

- **A** sits exactly on every Healthy boundary — `-le 50`, `-le 40`, `-le 2` all hold.
- **B** is one over on CPU. It fails Healthy (which requires *all* conditions) but meets no Critical condition, so it falls through to Warning.
- **C**, **D**, **E** each trip exactly one Critical threshold.
- **F** is offline, which is Critical on its own regardless of perfect metrics.

B is the most informative test: it proves Warning is genuinely the fall-through case, not a condition in its own right.

### Additional tests

| CPU | Memory | Patches | Online | Result | Why |
|-----|--------|---------|--------|--------|-----|
| 45 | 35 | 9 | Yes | **Critical** | Patches ≥ 8 — the other two metrics are irrelevant |
| 50 | 80 | 2 | Yes | **Critical** | Memory ≥ 80 |
| 51 | 40 | 2 | Yes | **Warning** | Fails Healthy, meets no Critical condition |
| 51 | 81 | 9 | **No** | **Critical** | **Three** independent Critical conditions |

### The final case

```
CPU 51, Memory 81, Patches 9, Offline → Critical
```

Three separate conditions each independently make this Critical:

1. `Memory >= 80`
2. `MissingPatches >= 8`
3. Offline

Because the Critical branch uses `-or`, the first one to evaluate true short-circuits the rest. The result is the same whichever fires first — but this is the test that proves the conditions are genuinely independent rather than accidentally coupled.

> **Final corrected rule in force:** `MissingPatches >= 8` is Critical.

---

## 15. Health validation

```powershell
$Health.Count
# 100000

$Health[0].GetType().Name
# PSCustomObject

$Health | Measure-Object
# Count = 100000

$Health | Group-Object HealthState
```

| HealthState | Count |
|-------------|-------|
| Critical | 56,886 |
| Healthy | 2,669 |
| Warning | 40,445 |

### Why the caller may see `Object[]`

The function builds a `List[PSCustomObject]` internally and emits it with a bare `$Results`. PowerShell **enumerates** the list on the way out, so the caller receives 100,000 individual objects. When those are captured into a variable, PowerShell collects them into an **`Object[]`**.

```
inside the function:  List[PSCustomObject] with 100,000 items
          ↓ emitted as $Results → enumerated
pipeline:             100,000 individual PSCustomObjects
          ↓ captured into $Health
caller holds:         Object[] containing 100,000 PSCustomObjects
```

So:

```powershell
$Health.GetType().Name       # Object[]        ← the container
$Health[0].GetType().Name    # PSCustomObject  ← an individual item
```

**These do not contradict each other.** The items never stopped being `PSCustomObject`s. The container type simply reflects how PowerShell collected the enumerated output.

---

## 16. Get-EndpointStatus

```powershell
function Get-EndpointStatus {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object[]]$Endpoints
    )

    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Record in $Endpoints){
        if (-not $Record.IsOnline) {
            $PatchState = "Offline"
        }
        elseif ($Record.MissingPatches -eq 0) {
            $PatchState = "Compliant"
        }
        elseif ($Record.MissingPatches -le 4) {
            $PatchState = "Attention"
        }
        else {
            $PatchState = "NonCompliant"
        }

        $Result = [PSCustomObject]@{
            ComputerName   = $Record.ComputerName
            MissingPatches = $Record.MissingPatches
            IsOnline       = $Record.IsOnline
            LastChecked    = $Record.LastChecked
            PatchState     = $PatchState
        }

        $Results.Add($Result)
    }

    $Results
}
```

### Classification priority

| Order | Condition | PatchState |
|-------|-----------|-----------|
| 1 | Not online | **Offline** |
| 2 | `MissingPatches = 0` | **Compliant** |
| 3 | `MissingPatches 1–4` | **Attention** |
| 4 | `MissingPatches >= 5` | **NonCompliant** |

**Order matters.** Offline is checked first because an offline endpoint's patch count is not trustworthy — reporting it as Compliant because it happens to show zero missing patches would be wrong.

Note the parameter block is stricter here than in `Get-EndpointHealth`: `[ValidateNotNull()]` and `[object[]]` make the input contract explicit at the parameter level rather than leaving it implied.

### Validation

```powershell
$Status.Count
# 100000

$Status[0].GetType().Name
# PSCustomObject

$Status | Measure-Object
# Count = 100000
```

### Group results

| PatchState | Count |
|-----------|-------|
| Attention | 30,003 |
| Compliant | 6,667 |
| NonCompliant | 53,330 |
| Offline | 10,000 |
| **Total** | **100,000** |

### Intentionally stopped here

> `Get-EndpointRisk` was **not** rebuilt. The logic was repetitive and already understood from Day 6, and Day 8's purpose was function API and output behaviour — which two refactors had already demonstrated.

---

## 17. Daily challenge — Get-DeploymentReport

### The requirement

Write a function that performs **six internal operations or side effects** but emits **exactly one object**.

### Input

```powershell
$Deployment = [PSCustomObject]@{
    Application = "FinanceApp"
    StartTime   = (Get-Date).AddMinutes(-47)
    EndTime     = Get-Date
    Status      = "Success"
}
```

### My final function

```powershell
function Get-DeploymentReport {
    param (
        [Parameter(Mandatory)]
        $Deployment
    )

    Write-Verbose "Starting Deployment Check"

    if ($Deployment.Status -eq "Success") {
        $Compliant = $true
    }
    else {
        $Compliant = $false
    }

    $Records = [PSCustomObject]@{
        Application     = $Deployment.Application
        DurationMinutes = ($Deployment.EndTime - $Deployment.StartTime).TotalMinutes
        Status          = $Deployment.Status
        Compliant       = $Compliant
        CheckedAt       = Get-Date
    }

    Write-Verbose "Deployment check completed"

    $Records
}
```

### My mistakes

#### Mistake 1 — unnecessary `foreach` for a single object

**What I did:** wrote a `foreach` loop even though the input was **one** deployment object, not a collection.

**Why it was wrong:** the parameter accepts a single object. Looping over it adds structure that does nothing and signals the wrong intent to a reader.

**Correction:** process the single object directly, with no loop.

**Lesson:** match the control flow to the shape of the input. A loop announces "many"; if there is one, say one.

#### Mistake 2 — TimeSpan instead of numeric minutes

**What I did:**

```powershell
DurationMinutes = ($Deployment.EndTime - $Deployment.StartTime)
```

**Why it was wrong:** subtracting two `DateTime` values produces a **TimeSpan** object, not a number. A property named `DurationMinutes` holding a TimeSpan is misleading, and it does not sort or compare numerically the way a caller would expect.

**Correction:**

```powershell
DurationMinutes = ($Deployment.EndTime - $Deployment.StartTime).TotalMinutes
```

**Lesson:** the property name is a promise about the type. `DurationMinutes` must hold minutes as a number.

#### Mistake 3 — `$Complaint` instead of `$Compliant`

**What I did:** typed `$Complaint` (a grievance) where `$Compliant` (conforming to a rule) was meant.

**Why it mattered:** if the two spellings had been used in different places, the second would have been an undefined variable evaluating to `$null` — with **no error**, silently producing a wrong value in the output object.

**Lesson:** this is the same class of failure as the Day 4 variable typos. PowerShell does not error on an undefined variable; it returns `$null`. A spelling mistake becomes a wrong answer, not an error message.

### The six internal operations

The challenge required six internal operations with one object emitted:

1. `Write-Verbose` start message
2. Status evaluation (`if`/`else`)
3. `$Compliant` assignment
4. Duration calculation
5. `Get-Date` for the `CheckedAt` timestamp
6. `Write-Verbose` completion message

**None of them leaked into the output.** The verbose messages are on a separate stream; the calculations were captured into variables or consumed directly as property values. Only `$Records` is an uncaptured expression.

### Validation

```powershell
Get-DeploymentReport -Deployment $Deployment -Verbose
```

Verbose output:

```
VERBOSE: Starting Deployment Check
VERBOSE: Deployment check completed
```

```powershell
$result.Count
# 1

$result.GetType().Name
# PSCustomObject

$result.DurationMinutes
# approximately 47
```

### On the duration precision

The duration is approximately 47 rather than exactly 47, because `StartTime` was created with `.AddMinutes(-47)` and `EndTime` with a separate `Get-Date` call a fraction of a second later. **Slight floating-point precision is normal.**

Rounding if a clean figure is wanted:

```powershell
[math]::Round((($Deployment.EndTime - $Deployment.StartTime).TotalMinutes), 2)
```

**Daily challenge: completed.** Six internal operations, exactly one object emitted, verified with `$result.Count`.

---

# Record

## 18. Interview round

The questions as asked, my original answers as given, and the corrections. **My original answers are preserved unedited.**

---

### Question 1

> **"What is a function in PowerShell, and why would you use a function instead of writing the same code directly in a script?"**

**My answer:**

> "A function in PowerShell is a named block of reusable code designed to perform a specific task. Instead of rewriting the same lines of code repeatedly across your scripts, you wrap that logic in a function and call it by its name whenever you need it."

**Evaluation:** ✅ **Correct.**

**Correction / addition:** mention parameters, structured output, maintainability, testing and reuse. The answer covered reuse but stopped short of the engineering benefits.

**Strong answer:**

> "A function in PowerShell is a named, reusable block of code designed to perform a specific task. It allows us to avoid duplicating logic and makes scripts easier to maintain, test, and reuse. Functions can accept parameters as input and produce structured output, which can then be passed through the PowerShell pipeline."

---

### Question 2

> **"What does the return statement actually do in PowerShell? Is return required for a function to produce output?"**

**My answer:**

> "No, return is not required in a powershell. it is mostly used to stop the flow of unassigned variable to be in the output."

**Evaluation:** ⚠️ **Partially correct.**

The first half is right: `return` is not required. The second half is a misunderstanding.

**Correction:**

`return` is **not** mainly for preventing unassigned variables from entering output. It does no filtering or suppression at all. If an earlier expression already emitted something, `return` does not undo it.

The correct concept:

- `return` **outputs** a value
- `return` **immediately exits** the current function or scope
- Normal PowerShell expressions output **without** `return`

Preventing unwanted output is done by **capturing** intermediate results into variables — not by using `return`.

**Final interview answer:**

> "No, return is not required to produce output in PowerShell because expressions and variables are automatically written to the success stream. return is mainly used when I want to explicitly output a value and immediately exit the function."

---

### Question 3

> **"You have a function that should return exactly 3 server objects, but when you pipe it to Measure-Object, it returns 56 objects. What are the likely causes of accidental output inside the function?"**

**My answer:**

> "check if the function holds the write-output after every object checkup."

**Evaluation:** ⚠️ **Partially correct.**

`Write-Output` was identified, and it was genuinely one of the two causes in that function. But it is only **one of three** categories.

**Correction — the three sources:**

1. `Write-Output` used for status messages
2. Bare variables / uncaptured expressions
3. Unintended command or method output

**The actual breakdown in the debugging example:**

```
3 intended objects (from return $Results)
+ 3 Write-Output messages
+ 50 bare $Server objects
= 56
```

The **50** came from source 2, not source 1 — which is why identifying only `Write-Output` would not have found the larger half of the bug.

---

### Question 4

> **"Why does PowerShell use the Verb-Noun naming convention for functions?"**

**My answer:**

> "We use Verb-Nounr Naming convention beasuse it gives us an idea about the what action we are performing on. Verb is active like get, set, add, remove. Noun is on what."

**Evaluation:** ✅ **Correct.** The concept was right; the phrasing needed tightening.

**Improved answer:**

> "PowerShell uses the Verb-Noun naming convention because the name clearly describes the action being performed and the object being acted upon. The verb describes the action, such as Get, Set, Add, or Remove, while the noun identifies the target, such as User, Service, or Computer. It also makes functions predictable and consistent with PowerShell's built-in commands."

---

### Interview round summary

| Q | Topic | Result |
|---|-------|--------|
| 1 | What is a function | ✅ Correct, needed depth |
| 2 | What `return` does | ⚠️ Partially correct — real misunderstanding corrected |
| 3 | Sources of accidental output | ⚠️ Partially correct — 1 of 3 identified |
| 4 | Verb-Noun naming | ✅ Correct |

Questions 2 and 3 are the ones to re-rehearse. Both are high-frequency interview questions and both exposed a genuine gap rather than a wording problem.

---

## 19. Documentation reference

The following references were covered:

- `about_Functions`
- `Get-Verb` / Approved Verbs

### Concepts extracted

- Function syntax
- Parameters
- Natural output
- `return`
- Output streams
- Verb-Noun naming
- Approved verbs
- Object-based output
- Output pollution

> This document does **not** claim that a local help page was successfully opened. The concepts above were covered; the reference is recorded for future lookup.

---

## 20. My mistakes

Every Day 8 mistake, preserved. This is the most useful section for revision.

---

### Mistake 1 — `$_` inside `foreach` instead of `$Record`

**The mistake:**

```powershell
foreach ($Record in $Deployments) {
    if ($_.Environment -eq "Production") { ... }
}
```

**Why it was wrong:** `$_` is the current object inside a **pipeline script block**. Inside a `foreach`, the current object is the **named loop variable**. `$_` is `$null` here, so the condition never matched and the function returned nothing — with no error.

**Correction:**

```powershell
if ($Record.Environment -eq "Production") { ... }
```

**Lesson:** `foreach` → named loop variable. Pipeline script block → `$_`. The failure is silent, which makes it worse than an error.

---

### Mistake 2 — returning a string instead of the object

**The mistake:**

```powershell
$Record.Application
```

**Why it was wrong:** the function emitted a string, destroying every downstream option — filtering on other properties, sorting, exporting with full fields.

**Correction:**

```powershell
$Record
```

**Lesson:** extracting a property is the **caller's** job. Return the object.

---

### Mistake 3 — treating `PSCustomObject` as a collection

**The mistake:**

```powershell
$Records = [PSCustomObject]@{}
$Records.Add($Record.Application, $Record.DurationMin, )
```

**Why it was wrong:** `PSCustomObject` is a **single structured object**, not a container. `.Add()` belongs to collection types such as `List[T]`.

**Correction:** create a new `PSCustomObject` per matching record and emit it, or add to a `List[PSCustomObject]`.

**Lesson:** know whether you are holding a container or an item before calling a method on it.

---

### Mistake 4 — unnecessary `foreach` for a single object

**The mistake:** a `foreach` loop in `Get-DeploymentReport`, where the parameter accepts one deployment.

**Why it was wrong:** the loop does nothing and misrepresents the function's contract to anyone reading it.

**Correction:** process the single object directly.

**Lesson:** control flow should match the shape of the input.

---

### Mistake 5 — TimeSpan instead of `TotalMinutes`

**The mistake:**

```powershell
DurationMinutes = ($Deployment.EndTime - $Deployment.StartTime)
```

**Why it was wrong:** `DateTime - DateTime` produces a **TimeSpan**, not a number. A property called `DurationMinutes` holding a TimeSpan breaks the promise its name makes.

**Correction:**

```powershell
DurationMinutes = ($Deployment.EndTime - $Deployment.StartTime).TotalMinutes
```

**Lesson:** the property name is a type contract. Honour it.

---

### Mistake 6 — `$Complaint` instead of `$Compliant`

**The mistake:** a typo producing a different word entirely.

**Why it was wrong:** an undefined variable in PowerShell evaluates to `$null` with **no error**, so a typo silently produces a wrong value rather than a failure.

**Correction:** `$Compliant`.

**Lesson:** same class as the Day 4 variable typos. PowerShell's tolerance of undefined variables turns spelling mistakes into wrong answers.

---

### Mistake 7 — `Write-Output` for diagnostic messages

**The mistake:**

```powershell
Write-Output "Critical server found: $($Server.Name)"
```

**Why it was wrong:** `Write-Output` writes to the **normal success stream**, so a status message became pipeline data — 3 unwanted string objects.

**Correction:** `Write-Verbose` for diagnostics.

**Lesson:** diagnostics and data are different streams. Choose deliberately.

---

### Mistake 8 — emitting `$Server` accidentally

**The mistake:** a bare `$Server` inside the loop, outside the `if`.

**Why it was wrong:** an uncaptured expression inside a loop emits **once per iteration** — 50 unwanted objects, the larger half of the 56.

**Correction:** remove the line.

**Lesson:** a bare variable on its own line inside a loop is a 50-object output, not a no-op.

---

### Mistake 9 — misunderstanding the purpose of `return`

**The mistake:** believing `return` exists mainly to stop unassigned variables entering the output.

**Why it was wrong:** `return` outputs and exits. It suppresses nothing.

**Correction:** capture intermediate results into variables to control output; use `return` for an explicit value plus early exit.

**Lesson:** this misconception would have led to trying to fix output pollution with `return`, which does not work.

---

### Mistake 10 — identifying only `Write-Output` as a pollution source

**The mistake:** naming one of three categories when asked for the sources of accidental output.

**Why it mattered:** in the actual debugging example, `Write-Output` accounted for 3 of the 53 unwanted objects. The bare expression accounted for 50. Knowing only the first source would have found the smaller problem.

**Correction:** three sources — `Write-Output`, bare variables/expressions, unintended command or method output.

**Lesson:** the source you know about is not the one that will cost you the most objects.

---

### Mistake 11 — rebuilding Day 6 business logic instead of focusing on function API

**The mistake:** spending effort re-deriving Toolkit business logic rather than on Day 8's actual subject — function API, naming, parameters and output behaviour.

**Correction:** stopped after two refactors (`Get-EndpointHealth`, `Get-EndpointStatus`) once the function-design points were demonstrated.

**Lesson:** when revisiting earlier work, be explicit about what the current day is actually teaching. Repetition of solved logic is not practice.

---

### Pattern across all eleven

| Category | Mistakes |
|----------|---------|
| Output contract — what the function emits | 2, 7, 8, 9, 10 |
| Type and structure confusion | 3, 5 |
| Variable and scope | 1, 6 |
| Control flow matching the data | 4 |
| Scope of effort | 11 |

**Five of eleven were output-contract mistakes.** That is the theme of the day, and it is exactly what the tracker objective was aiming at.

**Four of eleven failed silently** — 1, 6, 8 and the string-return in 2 produced no error at all. Those are the expensive ones.

---

## 21. Core mental models

### Function

```
Input → Process → Object Output
```

### Verb-Noun

```
Verb = Action
Noun = Target
```

### Output

> PowerShell automatically emits uncaptured expressions.

### return

```
return
   → output value
   → immediate exit
```

### Write-Output

> Normal pipeline output.

### Write-Host

> Host / display output. The caller cannot capture it.

### Write-Verbose

> Diagnostic output. Separate stream. Hidden unless `-Verbose`.

### Output pollution

> Anything unintended entering the normal success stream.

### Collection enumeration

```
$Results            → enumerated, caller receives individual objects
return (, $Results) → preserved, caller receives the collection
```

### Object-oriented automation

> Return structured objects, not display strings.

---

## 22. Final scorecard

### Theory

- [x] Function syntax
- [x] Approved verbs
- [x] `Get-Verb`
- [x] Verb-Noun naming
- [x] Parameters
- [x] Natural output
- [x] `return`
- [x] Early exit
- [x] Collection enumeration
- [x] `List[T]` vs pipeline output
- [x] `Write-Output`
- [x] `Write-Host`
- [x] `Write-Verbose`
- [x] Output pollution
- [x] `Measure-Object` validation
- [x] Object-based output

### Hands-on

- [x] Q015 — `Get-FailedProductionDeployment`
- [x] Q016 — `Get-SlowProductionDeployment`
- [x] Q017 — `Get-ProductionDeploymentReport`
- [x] `Get-EndpointHealth` refactor
- [x] `Get-EndpointStatus` refactor
- [x] Daily Challenge — `Get-DeploymentReport`

### Record

- [x] Interview questions
- [x] Documentation reference

---

## 23. Intentionally skipped

These were **deliberate decisions**, not omissions:

| Item | Reason |
|------|--------|
| Remaining Toolkit utility refactors | The business logic was repetitive and already completed on Day 6. Day 8's subject was function API and output behaviour, which two refactors demonstrated |
| `Get-EndpointRisk` | Logic already understood from Day 6; repeating it would have taught nothing new |
| Git commit and push | Deferred until the end of Week 2 / Day 8 by choice |

> **No files were committed or pushed on Day 8.**

---

## 24. Final Day 8 status

### DAY 8 STATUS: COMPLETED

### What I can now do

- Build named PowerShell functions
- Use approved Verb-Noun naming
- Define parameters
- Understand natural function output
- Understand `return` and early exit
- Control output streams
- Prevent output pollution
- Return structured `PSCustomObject`s
- Work with `List[PSCustomObject]`
- Understand collection enumeration
- Validate output with `Measure-Object`
- Refactor automation utilities into proper functions
- Debug unexpected pipeline output
- Write pipeline-friendly automation functions

### Revisit later

Concepts that genuinely need reinforcement:

- **Value vs reference behaviour** from Day 1
- **Pipeline object flow and `$_`** — the Q015 mistake and the `Get-EndpointHealth` correction were the same error twice
- **Collection vs individual object type** — `Object[]` containing `PSCustomObject`s
- **`return` vs natural output** — Interview Question 2 exposed a real gap
- **Output stream behaviour** — Interview Question 3 identified 1 of 3 sources

**One open item:** the advanced `Get-FailedServers` output-control question (how many objects the caller receives, whether verbose messages become part of the result, and why `return $Results` does not preserve the List) was raised but not answered in writing. The concepts are covered in [section 4](#4-collection-enumeration) and [section 15](#15-health-validation); answering it explicitly would confirm they are understood.

---

**Day 8: COMPLETED**
**Git status: NOT YET COMMITTED / PUSHED**
**Planned commit:** `refactor(functions): convert utilities into named functions`
**Next: Day 9**
