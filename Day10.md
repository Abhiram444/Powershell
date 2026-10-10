# PowerShell Day 10 — Advanced Parameters, Validation, and Error Handling

| Field | Value |
|---|---|
| **Day** | 10 of 90 |
| **Topic** | Advanced parameters, parameter validation, and error handling |
| **Primary script** | `Day10_Challenge.ps1` |
| **Filename variants seen in session** | `Day_10.ps1`, `Day10_challenge.ps1` |
| **Environment** | PowerShell 7 on macOS |
| **Working directory** | `/Users/abhiramkulkarni/Downloads/rag-lesson-generator/src` |
| **Hands-on exercises** | Q021, Q022, Q023 |
| **Debugging exercises** | 15 levels |
| **Interview practice** | 10 scenario-based questions |
| **Daily challenge** | Prompt-free parameter design, documented as `about_Functions_Advanced_Parameters` |
| **Git status** | **NOT COMMITTED / NOT PUSHED** — no `git status` output was recorded in this session |

---

## 0. Provenance and evidence labelling

This README was assembled from the Day 10 session record. Every factual claim in it is labelled so that a future read can tell evidence from explanation:

| Label | Meaning |
|---|---|
| **Observed** | Terminal output or code preserved in the session record. Reproduced exactly. |
| **Expected** | Behaviour that follows from documented PowerShell semantics but whose output was not captured in the record. |
| **Reconstructed** | A minimal example written for this README to illustrate a scenario whose original code was not preserved. Clearly marked at each occurrence. |
| **Not recorded** | The session record does not establish this. Not filled in by inference. |
| **Paraphrased in record** | The record summarises what I answered rather than quoting me. Treated as a paraphrase, never as a verbatim quote. |

Two consequences worth stating up front:

1. **The 10 interview questions have no preserved wording and no preserved answers.** The record lists the ten *concepts* covered, not the questions asked or what I said. Section 8 therefore gives reconstructed questions with model answers, and the transcript in section 14 records my original answers for those ten as **Not recorded**. They are not invented.
2. **No Git operation is claimed anywhere in this document.** Section 18 contains instructions only.

### 0.1 Where this README corrects the session record

Documenting a learning session honestly includes documenting where the session's own framing was imprecise. Three such places are flagged inline and listed here:

| Location | Record's framing | Accurate behaviour |
|---|---|---|
| Level 1 | The pre-check stops the mandatory parameter from prompting | An explicitly supplied `""` does **not** prompt — it fails parameter binding. Prompting happens only when the argument is **omitted**. The pre-check is still correct, for a different reason. See §3.2 and §5, Level 1. |
| Q023 warning | `'$row.Server'` was interpolated | The **observed** warning text shows the whole row object was interpolated, not `$row` followed by literal `.Server`. Both traps are documented separately in §4.3. |
| Challenge | `[ValidateNotNullOrEmpty()]` guards the omitted-`Server` case | Validation attributes run only when a value is **bound**. An omitted `[string]` parameter is `""` and the attribute never fires — which is precisely why the internal `IsNullOrWhiteSpace` guard was needed. See §7.5. |

---

## 1. Day 10 learning objectives

1. Understand positional and named parameter binding.
2. Define parameter positions and defaults.
3. Understand mandatory parameters and interactive prompting.
4. Validate parameter values with `ValidateSet`.
5. Handle missing, empty, and whitespace-only input.
6. Understand aliases and CSV field-to-parameter mapping.
7. Use `try`, `catch`, `throw`, `Write-Warning`, and `continue` correctly.
8. Distinguish function-returned failure statuses from terminating exceptions.
9. Validate returned objects and avoid false-positive success messages.
10. Design prompt-free batch processing.
11. Complete a parameter-design challenge and document test evidence.

---

## 2. Learning roadmap

The day moved in one direction throughout: **from "does the call bind correctly?" to "does the call *tell me the truth* about whether it worked?"** That is the spine of Day 10, and it is worth holding onto, because the second question is the one that bites in production.

```
Stage 1  Binding            How does an argument reach a parameter?
         Q021               Position = 0 / Position = 1, named vs positional
         ↓
Stage 2  Admission control  Which values is the parameter allowed to accept?
         Q022               Mandatory, ValidateSet, ValidateNotNullOrEmpty
         ↓
Stage 3  Input shape        What do real records look like when they are broken?
         Q023               $null vs "" vs "   ", aliases, CSV header mapping
         ↓
Stage 4  Control flow       What happens to the loop when one record fails?
         Levels 1–5         try / catch / continue, code outside try/catch
         ↓
Stage 5  Truthfulness       Does my success message mean anything?
         Levels 6–11        $result.Status, -eq vs -ne, missing and empty props
         ↓
Stage 6  Raising failure    How do I make a bad status actually stop something?
         Levels 12–15       throw, throw inside catch, bare throw, rethrow + loops
         ↓
Stage 7  Synthesis          A signature a stranger can call correctly, unattended.
         Challenge          Prompt-free design, external validation, 4 test cases
```

The pivot point is **Level 5**. Everything before it is about making code run. Everything after it is about making code *report accurately*. The single most expensive bug class on Day 10 was not a crash — it was a `Write-Output "success"` that printed when nothing had succeeded.

---

## 3. Core theory

Each concept below uses the structure **Definition → Internal behaviour → Example → Real-world automation scenario → Common mistakes → Interview takeaway**.

### 3.1 Positional and named parameter binding

**Definition.** `Position = n` in a `[Parameter()]` attribute declares where an *unnamed* argument lands. `Position = 0` takes the first unnamed argument, `Position = 1` the second. Named binding (`-Server "SRV-01"`) matches on parameter name and ignores position entirely.

**Internal behaviour.** PowerShell's parameter binder runs in a fixed order for each call:

1. Bind arguments that were given **by name**.
2. Take whatever arguments are **left over** and bind them to the remaining positional parameters, lowest `Position` number first.
3. Apply **defaults** to parameters that are still unbound.
4. Run **argument transformation** attributes, then **validation** attributes, on each bound value.
5. Enter the function body.

Two things fall out of that order and both matter later in this document. First, positional binding operates on *what is left after named binding*, so mixing the two is legal — `Get-ServerReport "SRV-01" -Environment "Production"` works. Second, **validation runs before the function body**, which is why a `ValidateSet` failure can be caught by a `try` around the *call* even though no line of the function ever executed.

**Example.** Both calls below bind identically when the signature declares `Server` at `Position = 0` and `Environment` at `Position = 1`:

```powershell
Get-ServerReport "SRV-01" "Production"

Get-ServerReport -Server "SRV-01" -Environment "Production"
```

**Real-world automation scenario.** A JML (joiner-mover-leaver) script calls `Set-UserAccess -Identity $u -Role $r`. Six months later someone adds a third positional parameter in the middle of the `param()` block. Every *named* caller keeps working. Every *positional* caller silently shifts by one and starts assigning the wrong roles — and because all three parameters are `[string]`, nothing throws. The job completes "successfully" with wrong data.

**Common mistakes.**

- Assuming `Position` is assigned by the order parameters appear in `param()`. It is not: declared `Position` numbers win, and parameters with no `Position` are not positional at all.
- Writing positional calls in a script that other people will maintain. Positional is for the interactive prompt; named is for anything saved to a file.
- Assuming wrong order will produce an error. With compatible types, **wrong order produces wrong data, not an exception.** This is the quiet failure mode of positional binding.

**Interview takeaway.** *"Positional binding is a convenience for the console. In scripts I always use named parameters, because positional arguments of the same type can be silently transposed — the call still succeeds and the data is wrong. I design positions so that a reader who has never seen the signature can still read the call, but I don't rely on it in committed code."*

### 3.2 Mandatory parameters and unattended execution

**Definition.**

```powershell
[Parameter(Mandatory = $true)]
[string]$Server
```

`Mandatory = $true` tells the binder that the call is invalid unless this parameter receives a value.

**Internal behaviour.** What happens next depends entirely on *how* the value is absent, and this distinction is the single most misread point of Day 10:

| How the value is absent | What PowerShell does |
|---|---|
| Argument **omitted entirely** | The binder asks the host to prompt: `Supply values for the following parameters:` |
| Argument supplied as `$null` | Parameter binding **error** — mandatory parameters reject `$null` |
| Argument supplied as `""` | Parameter binding **error** — `Cannot bind argument to parameter 'Server' because it is an empty string.` |
| Argument supplied as `"   "` | **Binds successfully.** Whitespace is a non-empty string. |

Only the first row prompts. The second and third rows raise a catchable terminating error at bind time. The fourth row is the dangerous one: `Mandatory` is satisfied by three spaces.

Prompting is the behaviour that breaks unattended work. A scheduled task, a CI runner, or a pipeline agent has no console to answer the prompt, so the job either blocks until it is killed or fails with a "cannot prompt because the host does not implement it" error. Either way the batch does not finish.

**Why `-ErrorAction Stop` does not help.** `-ErrorAction` controls what happens to **non-terminating errors raised while the command runs**. A mandatory-parameter prompt happens *before* the command runs — during binding — and is not an error at all until the prompt fails. There is no error for `-ErrorAction` to act on. Equally, `-ErrorAction Stop` cannot suppress a binding failure, because binding failures are already terminating for the statement.

**Why removing `Mandatory = $true` is not a fix on its own.** Dropping `Mandatory` removes the prompt and removes the empty-string rejection with it. An unbound `[string]` parameter is `""`, not `$null`, and no validation attribute runs on a parameter that was never bound. So the function will now run cheerfully with an empty server name unless you add an explicit guard in the body.

**Example.**

```powershell
# Prompts (argument omitted entirely)
Get-ServerReport

# Binding error, catchable (argument supplied but empty)
Get-ServerReport -Server ""

# Binds. $Server is "   ". Mandatory is satisfied.
Get-ServerReport -Server "   "
```

**Real-world automation scenario.** An offboarding script runs nightly against a CSV from HR. One row has a blank `SamAccountName` because of an upstream export bug. With `Mandatory` and a direct call, the row raises a binding error the loop can catch. With `Mandatory` removed and no guard, the function runs against an empty identity. Depending on what it does next, that is the difference between one skipped row and a `Get-ADUser -Filter` that matches everything.

**Common mistakes.**

- Treating `Mandatory` as input validation. It is a *presence* check, not a *content* check.
- Expecting `-ErrorAction Stop` to prevent prompting.
- Assuming an omitted argument and an explicitly empty argument behave the same way. They produce entirely different failures.
- Using `Mandatory` in a function whose only caller is an unattended loop. The loop can never answer a prompt.

**Interview takeaway.** *"`Mandatory` is a presence check for interactive use. In unattended automation I validate every record before I call the function and fail the record explicitly, because a mandatory prompt in a scheduled job doesn't error — it hangs, which is worse. And I don't rely on `Mandatory` for content: it rejects null and empty string, but a whitespace-only value binds straight through."*

**Corrected design principle for the day:** *validate inputs before calling the function in unattended workflows, and fail explicitly if a required parameter is missing.* The function keeps an internal guard as a backstop for direct callers; the loop does the warn-and-skip.

### 3.3 Defaults and `ValidateSet`

**Definition.** The signature used throughout Day 10:

```powershell
[Parameter(Position = 1)]
[ValidateSet("Production", "Test", "Development")]
[string]$Environment = "Test"
```

Three independent mechanisms are stacked here: a **position**, a **validation attribute**, and a **default value**. They do not interact the way they look like they should.

**Internal behaviour.** The default and the validator cover **disjoint** cases:

- The **default** applies only when the parameter is **not bound at all**. A default is not a fallback for bad input; it is a value for absent input.
- The **validator** runs only when the parameter **is** bound. It never inspects the default.

So an explicitly supplied invalid value never reaches the default — it is rejected by the validator first. This is the case that surprises people, and it was tested directly on Day 10.

| Input | Expected behaviour |
|---|---|
| `Environment` omitted | Defaults to `Test` |
| `Production` | Accepted |
| `Test` | Accepted |
| `Development` | Accepted |
| `Staging` | Rejected by `ValidateSet` |
| Explicit empty string `""` | **Rejected by validation** — the default does *not* activate |

**Why the explicit empty string is rejected rather than defaulted.** `-Environment ""` *is* a bound value. The binder has been handed an argument, so the default is skipped, and `ValidateSet` compares `""` against the three allowed values and fails. The absence of a value and the presence of an invalid value are different events, and PowerShell treats them differently on purpose.

This has a direct consequence for CSV-driven loops, and it is exactly what the Day 10 challenge had to solve: `Import-Csv` gives you `""` for a blank cell, never "absent". If you pass that straight through, you get a validation error, not the default. **Normalising `""` to the default is the caller's job, not the parameter's.**

```powershell
# This does NOT get the default. It throws.
Get-ServerReport -Server "SRV-01" -Environment ""

# The caller must normalise first.
if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "Test" }
Get-ServerReport -Server "SRV-01" -Environment $Environment
```

**Real-world automation scenario.** An access-request intake form writes `Environment` as an optional free-text field. Users who skip it produce `""`. A `ValidateSet` parameter with a default looks like it handles this and does not: every skipped field becomes a validation error in the nightly run. The fix is a normalisation step at the boundary where the untrusted data enters.

**Common mistakes.**

- Believing a default is a fallback for invalid input. It is a value for *omitted* input only.
- Believing an explicit `""` triggers the default.
- Duplicating the `ValidateSet` list in a caller-side `-notin @(...)` check, creating two sources of truth that drift. (The Day 10 challenge does this; §13.2 shows how to read the list back off the attribute instead.)
- Putting a default on a `Mandatory` parameter. It is unreachable — `Mandatory` forces a value, so the default can never apply.

**Interview takeaway.** *"A default covers an omitted argument; `ValidateSet` covers a supplied one. They never overlap, which means an explicitly empty value is a validation error, not a default. That matters with CSV input, because a blank cell is an empty string, not an absent argument — so I normalise blanks to the intended default before I call the function."*

### 3.4 Empty, null, and whitespace input

**Definition.** Three distinct states that all look like "nothing" and behave differently:

| Value | `$null -eq $x` | `$x -eq ""` | `[string]::IsNullOrEmpty($x)` | `[string]::IsNullOrWhiteSpace($x)` |
|---|---|---|---|---|
| `$null` | `$true` | `$true`¹ | `$true` | `$true` |
| `""` | `$false` | `$true` | `$true` | `$true` |
| `"   "` | `$false` | `$false` | **`$false`** | `$true` |
| `"SRV-01"` | `$false` | `$false` | `$false` | `$false` |

¹ `$null -eq ""` is `$false`, but `"" -eq $null` and `$null -eq ""`-style comparisons are a known trap in their own right — always put `$null` on the **left** of a `-eq` so that an array on the right cannot turn the comparison into a filter.

**Internal behaviour.** The row that matters is `"   "`. A whitespace-only string is a perfectly ordinary non-empty string as far as PowerShell, `Mandatory`, and `[ValidateNotNullOrEmpty()]` are concerned. It has a positive `.Length`. It binds. It passes. And then it reaches your `Get-ADUser -Identity "   "` and does something you did not plan for.

```powershell
[string]::IsNullOrWhiteSpace($Server)
```

This is the only one of the four checks in the table that catches all three failure states, which is why it is the check used everywhere in the Day 10 code.

**`[ValidateNotNullOrEmpty()]` is not the same thing:**

```powershell
[ValidateNotNullOrEmpty()]
[string]$Server
```

| | `$null` | `""` | `"   "` |
|---|---|---|---|
| `[ValidateNotNullOrEmpty()]` | rejects | rejects | **accepts** |
| `[string]::IsNullOrWhiteSpace()` guard | catches | catches | **catches** |

And one further gap: `[ValidateNotNullOrEmpty()]` only runs **when the parameter is bound.** If the parameter is optional and omitted, the attribute never executes and `[string]$Server` is `""`. The attribute cannot protect you from an omitted argument. This is the exact mechanism behind the challenge's `-Server`-omitted bug in §7.5.

The practical rule for Day 10 and beyond: **use the attribute to reject garbage from callers who supply something, and use an explicit `IsNullOrWhiteSpace` guard in the body to catch whitespace and omission.** They are a pair, not alternatives.

**Example.**

```powershell
function Get-ServerReport {
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    # Backstop: catches whitespace-only AND the omitted case,
    # neither of which the attribute above can catch.
    if ([string]::IsNullOrWhiteSpace($Server)) {
        throw "Server name cannot be empty or whitespace."
    }

    "Processing server: $Server"
}
```

**Real-world automation scenario.** A CSV exported from a ticketing system pads fields to a fixed width. Every "empty" cell arrives as `"    "`. `[ValidateNotNullOrEmpty()]` passes all of them, the loop reports 400 successful rows, and the downstream directory query ran 400 times against whitespace. Trimming and whitespace-checking at the boundary is the difference between a clean skip list and a silent no-op batch.

**Common mistakes.**

- Using `-ne ""` or `-ne $null` as an input guard and missing whitespace.
- Believing `[ValidateNotNullOrEmpty()]` implies "not whitespace". It does not.
- Believing a validation attribute protects an *optional* parameter that was omitted. It does not run at all.
- Forgetting that an unbound `[string]` is `""` and an unbound `[object]` or `[string[]]` is `$null` — the type decides which "nothing" you get.

**Interview takeaway.** *"`$null`, `""`, and `"   "` are three different states. `[ValidateNotNullOrEmpty()]` stops the first two; only an explicit `IsNullOrWhiteSpace` check stops the third. And neither runs if the parameter was omitted, so for anything reading untrusted input — CSV, an API payload, a form — I validate in the body as well as on the parameter."*

### 3.5 Aliases and CSV field mapping

**Definition.** `[Alias()]` gives a parameter an alternative *name that callers may type*. It changes nothing else.

The function from the session:

```powershell
function Get-TargetFunction {
    param(
        [Alias("Server")]
        [string]$ComputerName,

        [ValidateSet("Production", "Test", "Development")]
        [string]$Environment
    )

    [PSCustomObject]@{
        ComputerName = $ComputerName
        Environment  = $Environment
    }
}
```

**Internal behaviour.** The alias is registered with the parameter binder as a second lookup key for the *same* parameter. Four consequences, all of which were covered on Day 10:

1. **An alias does not create a second parameter.** `-Server` and `-ComputerName` are two names for one variable. You cannot supply both; doing so is an ambiguous-parameter error, not two values.
2. **An alias does not rename the output.** The returned object has a `ComputerName` property because the hashtable key says `ComputerName`. The binder's input alias has no reach into the function body or the output object.
3. **An alias is not pipeline property mapping.** Binding a CSV column by name requires `ValueFromPipelineByPropertyName = $true` on the parameter *and* piping the objects in. The alias does participate in that matching — but only on the pipeline path, and only when that attribute is present. It does nothing for a plain argument call.
4. **A `foreach` loop with a direct call does no name matching at all.** You are passing values, not objects. Mapping is manual and explicit:

```powershell
Get-TargetFunction -ComputerName $row.Server -Environment $row.Environment
```

That line is the entire lesson of Q023. A CSV column called `Server` does not find the `Server` alias on its own, because nothing in a direct call is looking at property names.

**Example — what the alias does and does not do:**

```powershell
# Both of these bind to $ComputerName. Identical result.
Get-TargetFunction -ComputerName "SRV-01" -Environment "Production"
Get-TargetFunction -Server       "SRV-01" -Environment "Production"
```

Expected output in both cases — note the property is `ComputerName`, never `Server`:

```text
ComputerName Environment
------------ -----------
SRV-01       Production
```

**String interpolation inside a warning.** The improved message from the session:

```powershell
Write-Warning "Skipping record: Server is missing. Environment='$($row.Environment)'."
```

`$($row.Environment)` is a **subexpression**: PowerShell evaluates the whole expression inside `$( )` and inserts the result. Without it, `"$row.Environment"` expands only the variable `$row` and then appends the literal characters `.Environment`, because simple variable expansion in a double-quoted string stops at the variable name — it does not follow a property access.

```powershell
$row = @{ Server = "SRV-01"; Environment = "Production" }

"Env is $row.Environment"        # Env is System.Collections.Hashtable.Environment
"Env is $($row.Environment)"     # Env is Production
```

**Real-world automation scenario.** An IAM provisioning script takes a CSV from three different source systems whose headers are `Server`, `Hostname`, and `ComputerName`. Aliases make the *function* pleasant to call by hand from any of those vocabularies. They do not make the CSV self-mapping. The import layer still has to decide which column means what — and writing that mapping explicitly is what makes the script auditable six months later.

**Common mistakes.**

- Expecting `[Alias("Server")]` to make `$result.Server` work on the output object.
- Expecting a CSV header to auto-bind by alias in a direct function call.
- Supplying both the real name and the alias in one call.
- Writing `"$row.Server"` in a log message and shipping `@{...}.Server` to the log file.
- Believing an alias is documentation. It is a convenience; the canonical name is what belongs in a committed script.

**Interview takeaway.** *"An alias adds an accepted input name for a parameter — nothing more. It doesn't create a parameter, it doesn't rename the output property, and in a direct call it doesn't map CSV headers, because a direct call passes values rather than objects. Property-name binding needs `ValueFromPipelineByPropertyName` and an actual pipeline. For CSV-driven batches I write the mapping explicitly anyway, so the field contract is visible in the code."*
---

## 4. Hands-on exercises Q021 – Q023

### 4.1 Q021 — Positional and named binding

**Goal.** Call a function positionally and by name, test mixed binding, and identify the silent data errors caused by incorrect argument order.

**What was practised.**

- Declaring `Position = 0` and `Position = 1` and confirming that the first and second unnamed arguments land on them in order.
- Calling the same function by name and confirming equivalent bindings.
- Mixed binding — one named argument, one positional.
- Inspecting the function signature and the actual values each parameter received.

**The purpose of `Position`.** `Position` exists so that the most important one or two arguments can be supplied without typing their names, in the way `Get-ChildItem C:\Temp` works. It is a readability feature for the console, and the design question it raises is the one the daily challenge asks: *if a reader has never seen the signature, does `Get-ServerReport "SRV-01" "Production"` read correctly?* It does — because the most significant noun comes first and the qualifier second, which is the order a human says it.

**How named parameters improve readability.** A named call is self-documenting at the call site and immune to signature changes. A positional call depends on knowledge the reader may not have and on a parameter order that is not part of any contract.

**How to inspect a function's parameters.**

```powershell
# Does the function exist in this session, and from where?
Get-Command Get-ServerReport

# What does the session think the body is?
(Get-Command Get-ServerReport).Definition

# Parameter-by-parameter detail, including position and attributes
(Get-Command Get-ServerReport).Parameters['Environment']
(Get-Command Get-ServerReport).Parameters['Environment'].Attributes

# What actually bound on this call — put this inside the function body
$PSBoundParameters
```

`$PSBoundParameters` is the one that answers "did my positional call bind the way I thought?", because it contains only parameters that were actually bound — a parameter sitting on its default does not appear in it.

#### The stale function-definition problem (Observed)

This was the most practically useful discovery in Q021. A definition inspection returned an *older* version of a function than the one in the file on disk.

**Observed.** The session record shows that:

```powershell
(Get-Command Get-BackupReport).Definition
```

displayed an older definition containing only `$BackupName`.

**The correction** was to reload the script:

```powershell
. ./Day_10.ps1
```

**Why this happens.** A function in PowerShell is an object in the session's function provider — `Function:\Get-BackupReport` — not a live view of a file. Editing the `.ps1` changes the file and nothing else. The session keeps running the definition it loaded, and it will keep running it until something redefines it. There is no file watcher and no auto-reload.

So the sequence that produces the confusion is:

1. Dot-source the script → the function is created in the session.
2. Edit the file in an editor → the file changes, the session does not.
3. Call the function → the **old** body runs.
4. Conclude the fix did not work → start debugging code that is not the code being executed.

**Why inspecting the definition is the right first move.** When behaviour contradicts the source you are reading, the first hypothesis should be *"I am not running the source I am reading."* `(Get-Command <name>).Definition` tests that hypothesis in one line, and it is faster than any amount of staring at the file. On Day 10 it was decisive: the definition shown had only `$BackupName`, which immediately explained behaviour that made no sense against the edited file.

**Dot-sourcing, precisely.**

```powershell
. ./Day_10.ps1          # dot-source: runs the script IN the current scope
./Day_10.ps1            # call:       runs the script in a CHILD scope
```

The dot and the space matter. A dot-sourced script leaves its functions and variables behind in the current session, which is why it is how you load a function library. A normally-invoked script runs in a child scope that is discarded on exit — its functions vanish with it, which is why `./Day_10.ps1` followed by `Get-ServerReport` reports that the command does not exist.

**Three ways to be certain you are running current code:**

| Approach | Command | Trade-off |
|---|---|---|
| Re-dot-source | `. ./Day10_Challenge.ps1` | Fast. Redefines what the file defines; leaves behind anything you have since deleted from the file. |
| Remove, then reload | `Remove-Item Function:\Get-ServerReport -ErrorAction SilentlyContinue` then dot-source | Clears stale definitions the file no longer contains. |
| Fresh session | `pwsh -NoProfile -File ./Day10_Challenge.ps1` | Definitive. No inherited state at all. The right way to verify a deliverable. |

For a learning session the middle one is the practical default; for "is this script actually correct?", use the third.

**Scope note.** The session record does not preserve the earlier Q021 code or its outputs. The commands above are the inspection techniques documented in the record plus their standard semantics; they are **not** presented as a verbatim Q021 transcript. The only Q021 evidence preserved in the record is the stale-definition observation and its fix.

### 4.2 Q022 — Mandatory parameters, validation, and CSV processing

**Goal.** Process a set of records where some records are invalid, without prompting, without crashing the batch, and without mislabelling anything as successful.

**Concepts practised.** Mandatory parameter behaviour; `ValidateSet`; pre-validating input before the call; `try`/`catch`; skipping invalid records; `continue`; logging a skip rather than substituting an unrelated value.

**The pattern developed in this exercise:**

```powershell
if ([string]::IsNullOrWhiteSpace($Server)) {
    Write-Warning "Skipping record: Server is missing."
    continue
}

try {
    Get-ServerReport -Server $Server -Environment $Environment -ErrorAction Stop
}
catch {
    Write-Warning "Failed: $($_.Exception.Message)"
    continue
}
```

**Two prerequisites for that fragment to work, both of which were explicit points in the session:**

1. **`$Server` and `$Environment` must be initialised before this code.** The fragment reads them; it does not produce them. In the finished challenge they are assigned from `$row` at the top of each iteration.
2. **`continue` must be inside an enclosing loop.** `continue` is a loop-control keyword. Outside `foreach`/`for`/`while`/`do`/`switch` it is an error — and in a `switch`, `continue` means something subtly different from `break`, which is worth keeping in mind separately.

**Why the structure is "guard first, then `try`".** The guard and the `try/catch` handle two different classes of failure, and collapsing them into one loses information:

| Failure class | Caught by | Why it belongs there |
|---|---|---|
| Record is structurally unusable — blank server | The **guard** | This is a data-quality fact, known before the call. Reporting it as "the function failed" would be a lie. |
| The call was reasonable but was rejected or errored | The **`catch`** | Validation failures, connectivity errors, anything from inside the function. |

The guard produces an accurate message — *"this record is missing a server"* — whereas letting the blank reach the function produces either a prompt or a binding error whose message is about parameter binding rather than about the record. When this runs across 5,000 rows at 02:00, the quality of that message is the whole value of the log.

**Why `-ErrorAction Stop` is on the call.** It converts non-terminating errors raised *inside* the function into terminating ones so the `catch` can see them. It is not what catches the `ValidateSet` failure — binding failures are already terminating — but it closes the gap for anything the function body reports as a non-terminating error. Adding it costs nothing and makes the `catch` actually comprehensive.

**Why invalid records must be logged, not quietly reassigned.** The anti-pattern Day 10 rejected was: *blank environment → just use `Production`*. Substituting an unrelated value turns a data problem into a config change nobody requested, and in an access-provisioning context that is a genuine incident. The two defensible options are **skip and log**, or **default to a value that has been explicitly approved as the default**. The challenge takes the second option for `Environment` — and §7.7 records that this is a policy decision rather than a technical one.

### 4.3 Q023 — Aliases and CSV header mapping

**Goal.** Build a function with an aliased parameter, map CSV fields to it explicitly, validate each record, and handle the errors.

**The function (preserved from the record):**

```powershell
function Get-TargetFunction {
    param(
        [Alias("Server")]
        [string]$ComputerName,

        [ValidateSet("Production", "Test", "Development")]
        [string]$Environment
    )

    [PSCustomObject]@{
        ComputerName = $ComputerName
        Environment  = $Environment
    }
}
```

**The loop (preserved from the record):**

```powershell
foreach ($row in $Records) {
    if ([string]::IsNullOrWhiteSpace($row.Server)) {
        Write-Warning "Skipping record: Server is missing."
        continue
    }

    try {
        Get-TargetFunction `
            -ComputerName $row.Server `
            -Environment $row.Environment
    }
    catch {
        Write-Warning "Skipping Computer '$($row.Server)' with environment '$($row.Environment)': $($_.Exception.Message)"
        continue
    }
}
```

**Observed output:**

```text
WARNING: Skipping record: '@{Server=; Environment=Test}' is missing or whitespace-only.
WARNING: Skipping Computer 'SRV-02' with environment 'Staging': Cannot validate argument on parameter 'Environment'. The argument "Staging" does not belong to the set "Production,Test,Development" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.

ComputerName Environment
------------ -----------
SRV-01       Production
SRV-03       Development
```

**What this output proves.** Four things, and they are worth separating because each one answers a question raised earlier in the day:

1. **The blank record was skipped by the guard**, not by the function. The first warning comes from the `if`, before any call.
2. **A `ValidateSet` failure is catchable by a `try` around the call.** The second warning is the catch block reporting a *parameter binding validation* error. The function body never ran for `SRV-02`. This settles Level 2 empirically.
3. **The loop continued after both failures.** `SRV-03` was processed after `SRV-02` was rejected — so neither the guard's `continue` nor the catch's `continue` aborted the batch.
4. **The alias did not rename the output.** The result table's first column is `ComputerName`, even though the input column was `Server` and `Server` is a registered alias. The alias is an input-side name only.

**The input records.** *Reconstructed from the observed output* — the record does not preserve the `$Records` definition for Q023. The four rows implied by the output are:

```powershell
# Reconstructed from the observed output, not preserved verbatim in the record.
$Records = @(
    @{ Server = "SRV-01"; Environment = "Production"  }
    @{ Server = "";       Environment = "Test"        }
    @{ Server = "SRV-02"; Environment = "Staging"     }
    @{ Server = "SRV-03"; Environment = "Development" }
)
```

#### The warning-string defect in the first message

The first warning line is the interesting one:

```text
WARNING: Skipping record: '@{Server=; Environment=Test}' is missing or whitespace-only.
```

`@{Server=; Environment=Test}` is the default string form of the **whole row object**, not of its `Server` property. So the message interpolated the row rather than the field — the log says "this record is missing" and then prints the entire record where the server name should be. The message is not wrong, but it is not what was intended, and the field that is actually missing has to be inferred by the reader.

**Note on labelling:** the record's own explanation for this line is that interpolating `'$row.Server'` does not expand the nested property. That describes a real and closely related trap, but it produces different text — so both are documented separately rather than conflated:

| Written in the message | Expands to | Why |
|---|---|---|
| `"'$row'"` | `'@{Server=; Environment=Test}'` | Variable expanded; this matches the **observed** output. |
| `"'$row.Server'"` | `'@{Server=; Environment=Test}.Server'` | Variable expanded, then the literal text `.Server` appended. |
| `"'$($row.Server)'"` | `''` | Subexpression evaluated — the intended result. |

The second row is the trap the record names; the first is what the output shows. Either way the fix is the same, and it is the subexpression:

```powershell
Write-Warning "Skipping record: Server is missing. Environment='$($row.Environment)'."
```

**Why the fixed message is better than the subexpression alone.** `'$($row.Server)'` interpolates to `''` for a blank server, which prints empty quotes and tells the reader nothing. Naming the missing field in prose — *"Server is missing"* — and then printing a field that **does** have a value — `Environment='Test'` — is what makes the row identifiable in a log of thousands. A log line should carry enough context to find the record again.

### 4.4 Code samples and execution notes

**Filename consistency.** Three spellings of the same script appear in the session: `Day10_Challenge.ps1`, `Day_10.ps1`, and `Day10_challenge.ps1`. On macOS this mostly does not hurt, and that is exactly the problem:

- APFS is **case-insensitive by default**, so `. ./Day10_challenge.ps1` finds `Day10_Challenge.ps1` locally and works.
- **Git is case-sensitive.** Committing `Day10_Challenge.ps1` and then referencing `Day10_challenge.ps1` in a README, another script, or a CI step produces a file-not-found on Linux and in GitHub Actions, while continuing to work perfectly on the Mac it was written on.
- Worse, renaming only the case of a file (`Day_10.ps1` → `Day10_Challenge.ps1`) can leave Git holding the old name unless you use `git mv`, producing a repo with two entries that the local filesystem cannot distinguish.

**Standard for this programme:** one canonical filename per day, `PascalCase_WithUnderscores`, fixed at creation, referenced identically in the script, the README, and any future CI. For Day 10 the canonical name is **`Day10_Challenge.ps1`**.

**Dot-sourcing commands used in the session:**

```powershell
Get-Command Get-ServerReport
```

```powershell
. ./Day10_Challenge.ps1
```

Variants also encountered:

```powershell
. ./Day_10.ps1
. ./Day10_challenge.ps1
```

**What each command does and does not prove:**

| Command | Proves | Does not prove |
|---|---|---|
| `Get-Command Get-ServerReport` | The name resolves in this session | That the loaded definition matches the file |
| `(Get-Command Get-ServerReport).Definition` | What body the session will actually execute | Nothing about the file on disk |
| `. ./Day10_Challenge.ps1` | The file parsed and ran in the current scope | That stale functions the file no longer defines were removed |
| `pwsh -NoProfile -File ./Day10_Challenge.ps1` | The script works from nothing | — (this is the strongest check) |

`Get-Command` confirming that a function exists is the most common false reassurance in interactive PowerShell work. Existence is not freshness. On Day 10 that distinction cost real debugging time, and `.Definition` is the one-line cure.
---

## 5. Debugging exercises — 15 levels

The fifteen levels form one continuous arc. Levels 1–5 ask *does the loop survive a bad record?*; levels 6–11 ask *does my success message mean anything?*; levels 12–15 ask *how do I turn a bad result into a real failure, and what does that do to the batch?*

Each level records: the scenario, the question, my answer as the record preserves it, the evaluation, the correct explanation, the code or output, and the takeaway. Where the record paraphrases my answer rather than quoting it, that is stated. Where original code was not preserved, the example is labelled **Reconstructed**.

**Score across the fifteen:** 8 correct, 4 partially correct, 2 incorrect, 1 with no recorded answer. The two outright misses — Levels 11 and 12 — are the same misconception seen twice, and they are the highest-value revision targets of Day 10.

### Level 1 — Empty server input

**Scenario.** A mandatory-parameter function is called in a loop over an array containing an empty string.

```powershell
function Get-ServerReport {
    param(
        [Parameter(Mandatory)]
        [string]$Server
    )

    "Processing server: $Server"
}

$Servers = @("SRV-01", "", "SRV-03")

foreach ($Server in $Servers) {
    try {
        Get-ServerReport -Server $Server -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed: $($_.Exception.Message)"
    }
}
```

**Question.** What goes wrong with the empty element, and how should the loop handle it?

**My answer** *(paraphrased in record).* The loop should check for an empty or whitespace-only server name **before** calling the function.

**Evaluation.** **Correct.** This is the right instinct and it is the pattern the entire rest of the day builds on.

**Correct explanation — with one precision the record's framing misses.** The record explains the fix as preventing the mandatory parameter from prompting. That is not what happens here, and the distinction is worth getting right because it is the §3.2 table in action:

- `-Server $Server` where `$Server` is `""` **supplies an argument.** The binder therefore does not prompt. It raises `Cannot bind argument to parameter 'Server' because it is an empty string.`
- That is a terminating binding error, so the existing `catch` **would** have caught it and printed a warning.

So the original loop does not hang — it reports a *parameter binding* problem for what is actually a *data quality* problem. The pre-check is still the correct fix, for two better reasons:

1. **Message quality.** `Skipping record: '' is missing or whitespace-only.` identifies the record. `Cannot bind argument to parameter 'Server'...` describes PowerShell's internals and leaves the reader to work out which row caused it.
2. **Whitespace coverage.** `"   "` binds successfully to a `Mandatory [string]`. The empty string is caught by the binder; whitespace is caught by nothing except an explicit `IsNullOrWhiteSpace` check. The guard is the only thing standing between a padded CSV and a batch of no-ops.

Prompting is still a real hazard in this function — it just needs the argument **omitted**, not empty:

```powershell
Get-ServerReport               # prompts: Supply values for the following parameters:
Get-ServerReport -Server ""    # binding error, catchable
Get-ServerReport -Server "   " # binds. Runs. "Processing server:    "
```

**Corrected loop:**

```powershell
foreach ($Server in $Servers) {
    if ([string]::IsNullOrWhiteSpace($Server)) {
        Write-Warning "Skipping record: '$Server' is missing or whitespace-only."
        continue
    }

    try {
        Get-ServerReport -Server $Server -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed: $($_.Exception.Message)"
        continue
    }
}
```

**Observed output:**

```text
Processing server: SRV-01
WARNING: Skipping record: '' is missing or whitespace-only.
Processing server: SRV-03
```

**A secondary note on this code.** The loop variable is `$Server` — the same name as the function's parameter. This is legal and harmless, because the function's `$Server` lives in the function's own scope. But it makes the code harder to reason about while debugging scope questions, and `foreach ($s in $Servers)` or `foreach ($row in $Records)` costs nothing and removes the ambiguity. The challenge script in §7.4 keeps the collision; worth changing on the next pass.

**Takeaway.** Validate the record before the call. The function's own parameter machinery will refuse some bad input, but it refuses it in its own vocabulary — and it will not refuse whitespace at all.

### Level 2 — Invalid `ValidateSet` input

**Scenario.** A valid server name with environment `Staging`, against `[ValidateSet("Production", "Test", "Development")]`.

**Question.** Where does this fail, can the loop catch it, and how does processing continue?

**My answer** *(paraphrased in record).* Parameter validation fails before the function body executes; `catch` can handle the validation error if the call is inside `try`; `continue` can move to the next record.

**Evaluation.** **Correct — all three parts.** This is the strongest answer of the fifteen, because it gets the *ordering* right, not just the outcome.

**Correct explanation.** `ValidateSet` is enforced by the parameter binder in step 4 of the binding sequence in §3.1 — after the argument is matched to the parameter, before the function body is entered. The failure surfaces as a `ParameterBindingValidationException`, wrapped as an `ActionPreferenceStopException`-class terminating error for that statement. Three practical consequences:

1. **No line of the function ran.** There is nothing to clean up, no partial work, no side effects. A `ValidateSet` rejection is the cheapest possible failure.
2. **A surrounding `try` catches it.** Binding failures are terminating for the statement, so they propagate to the enclosing `catch`.
3. **`-ErrorAction Stop` is irrelevant to it.** The error is already terminating. `-ErrorAction` affects non-terminating errors raised while the command *runs*, and this command never ran.

**Observed confirmation.** This is not theory — the Q023 output in §4.3 proves it directly:

```text
WARNING: Skipping Computer 'SRV-02' with environment 'Staging': Cannot validate argument on parameter 'Environment'. The argument "Staging" does not belong to the set "Production,Test,Development" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.
```

The message came out of the `catch` block, and `SRV-03` was processed afterwards. Caught, and the loop survived.

**One design point worth noting.** The `ValidateSet` message is unusually good — it names the parameter, the rejected value, and the complete allowed set. That is free diagnostic quality you get from using the attribute rather than hand-rolling `if ($Environment -notin @(...)) { throw "bad environment" }`. Prefer the attribute where you can.

**Takeaway.** Validation errors happen at bind time, are catchable, and cost nothing. `try/catch` around the call plus `continue` is the correct batch pattern for them.

### Level 3 — Successful function call followed by an error

**Scenario.** The function call succeeds, and a later statement inside the same `try` throws.

**Question.** Does the `catch` run, even though the function call itself succeeded?

**My answer.** **Not recorded.** The session record does not preserve an answer for this level. Nothing is inferred here.

**Evaluation.** Not applicable — no answer to evaluate.

**Correct explanation.** `try` guards a **block**, not a call. Any terminating error anywhere in the block transfers control to `catch`, regardless of how much of the block had already succeeded. The `catch` therefore tells you *"something in this block failed"* and nothing more precise than that. If the block contains several operations, the catch cannot distinguish which one failed unless the message or the exception type says so — which is a direct argument for keeping `try` blocks narrow.

**Reconstructed example** *(the original code for this level was not preserved):*

```powershell
# Reconstructed example — not preserved verbatim in the session record.
try {
    Get-ServerReport -Server "SRV-01" -Environment "Production"
    throw "Simulated failure"
}
catch {
    Write-Warning "Something went wrong: $($_.Exception.Message)"
}
```

**Expected output** (the function emits its object, then the throw is caught):

```text
Server Environment Status
------ ----------- ------
SRV-01 Production  Success
WARNING: Something went wrong: Simulated failure
```

Note what this shows: the function's output **was** produced and is still on the stream. A catch does not roll anything back. Partial work stays done — which in a provisioning script means a user may be half-created when the catch fires.

**The practical lesson.** A wide `try` produces an unactionable log line. Compare:

```powershell
# Hard to diagnose: which of the three failed?
try {
    $acct = New-UserAccount -Name $n
    Add-GroupMembership -Identity $acct -Group "Staff"
    Send-WelcomeMail -To $acct.Mail
}
catch { Write-Warning "Failed: $($_.Exception.Message)" }

# Diagnosable: the message says which stage, and the state is known.
try   { $acct = New-UserAccount -Name $n }
catch { Write-Warning "Create failed for '$n': $($_.Exception.Message)"; continue }

try   { Add-GroupMembership -Identity $acct -Group "Staff" }
catch { Write-Warning "Account '$n' created but group add failed: $($_.Exception.Message)" }
```

**Takeaway.** `catch` means "the block failed", not "the call failed". Scope each `try` to the operation whose failure you want to name.

### Level 4 — Does the loop continue without `continue` in `catch`?

**Scenario.**

```powershell
foreach ($row in $Servers) {
    try {
        Get-ServerReport -Server $row.Server -Environment $row.Environment
    }
    catch {
        Write-Warning "Failed: $($_.Exception.Message)"
    }
}
```

**Question.** Without `continue` in the `catch`, does the loop move to the next record?

**My answer** *(paraphrased in record).* My initial instinct was that `continue` must be added to move to the next iteration.

**Evaluation.** **Partially correct — the conclusion about what `continue` does is right, but it is not required here.**

**Correct explanation.** A `catch` block that completes normally has **handled** the error. Control then falls out of the `try/catch` statement and continues with the rest of the loop body; when the body ends, `foreach` advances to the next element on its own. `continue` is not what makes a loop iterate — the loop does that.

What `continue` actually does is **skip the remainder of the current iteration**. It matters only when there is something after the `try/catch` that you do not want to run for a failed record:

```powershell
foreach ($row in $Servers) {
    try {
        Get-ServerReport -Server $row.Server -Environment $row.Environment
    }
    catch {
        Write-Warning "Failed: $($_.Exception.Message)"
        continue        # <- skips the lines below for this record
    }

    Write-Output "Finished processing $($row.Server)"   # <- the reason continue exists
    Add-Content -Path ./processed.log -Value $row.Server
}
```

Without `continue` there, a failed record would be logged as finished and appended to `processed.log`. That is Level 5's bug, and it is why `continue` in a `catch` is a good habit even when it is technically redundant: it makes the catch block a hard exit from the iteration, so adding a line below it later cannot silently include failed records.

**Why the instinct was still reasonable.** It is a correct *defensive* habit resting on an incorrect *mechanical* belief. The habit survives; the belief needs fixing, because believing `continue` is required for iteration leads to thinking a `catch` without it somehow aborts the loop — which would make the Level 15 output inexplicable.

**Takeaway.** A handled error does not stop a `foreach`. `continue` skips the rest of the current iteration — use it when there is something after the `try/catch` that must not run for a failed record.

### Level 5 — Code after `try/catch`

**Scenario.**

```powershell
foreach ($row in $Servers) {
    try {
        Get-ServerReport -Server $row.Server -Environment $row.Environment
    }
    catch {
        Write-Warning "Failed: $($_.Exception.Message)"
    }

    Write-Output "Finished processing $($row.Server)"
}
```

**Question.** Can `Finished processing ...` appear for a record whose call failed validation?

**My answer** *(paraphrased in record).* Yes — the message can still appear after a validation failure, because the output statement is outside the `try/catch`.

**Evaluation.** **Correct**, and this is the pivot of the whole debugging sequence.

**Correct explanation.** The `Write-Output` is a sibling of the `try/catch`, not part of it. Once the error is handled, execution resumes at the next statement in the loop body — which is the message. So the log reads:

```text
WARNING: Failed: Cannot validate argument on parameter 'Environment'. ...
Finished processing SRV-02
```

Both lines, for the same record, in that order. `Finished processing` is true in the most literal sense — the loop did finish processing that iteration — and completely misleading in the sense any reader will take it.

**Why this is the most dangerous bug class on Day 10.** It is not a crash. It produces a log that *looks* like a successful run. Grep the log for `Failed` and you find the warnings; grep for `Finished` and you get a count that matches your record count, and a dashboard built on that count reports 100% success. The failure is invisible at exactly the altitude where people look.

**Where the success message belongs.** Inside the `try`, immediately after the call that it is asserting succeeded:

```powershell
foreach ($row in $Servers) {
    try {
        $result = Get-ServerReport -Server $row.Server -Environment $row.Environment -ErrorAction Stop
        Write-Output "Finished processing $($row.Server)"   # only reachable if the call returned
    }
    catch {
        Write-Warning "Failed on '$($row.Server)': $($_.Exception.Message)"
        continue
    }
}
```

Now the message is **unreachable** unless the call returned without throwing. Reachability is the mechanism that makes it honest — not the wording.

And a distinction for the levels that follow: this version proves the call **did not throw**. It does not prove the call **succeeded**, because a function can return `Status = "Failed"` without throwing anything. That gap is Levels 6 to 11.

**Takeaway.** A success message outside the `try` is structurally incapable of telling the truth. Put it inside, after the call, and let reachability do the work.

### Level 6 — Function output and status checking

**Scenario.** Capture the returned object in `$result` and inspect `$result.Status`.

**Question.** How do you check whether the function reported success?

**My answer** *(paraphrased in record).* Store the result in a variable.

**Evaluation.** **Partially correct.** The right first move — capturing the return value — but it stops short of the check itself, and the check is where the remaining nine levels live.

**Correct explanation.** Two separate claims hide in "the function worked":

| Claim | Established by |
|---|---|
| The call did not raise a terminating error | No exception reached the `catch` |
| The operation the function performed succeeded | **Inspecting what the function returned** |

A function that returns a status object is making the second claim *in its output*. If you discard the output, you have discarded the only evidence of it. Assignment is therefore not optional bookkeeping — it is how you get access to the result at all.

```powershell
$result = Get-ServerReport -Server $row.Server -Environment $row.Environment

if ($result.Status -eq "Failed") {
    Write-Warning "Server $($row.Server) failed."
    continue
}

Write-Output "Successfully processed $($row.Server)"
```

**Two caveats, both load-bearing for later levels.**

1. **This code assumes a `Status` property exists.** If it does not, `$result.Status` is `$null`, `$null -eq "Failed"` is `$false`, and the success branch runs. That is Level 8.
2. **`$result = ...` suppresses the function's output from the console.** Assignment consumes the pipeline output. If you want both the object on screen and the status check, you need `$result` *and* an explicit emit — which is also why the Level 11 output is only `Script completed` and no object table.

**One honest observation about this specific function.** The `Get-ServerReport` used on Day 10 returns a hard-coded `Status = "Success"`:

```powershell
[PSCustomObject]@{
    Server      = $Server
    Environment = $Environment
    Status      = "Success"
}
```

`$result.Status -eq "Failed"` can therefore never be true for this function as written. The status check is being practised against a function that cannot fail — which is fine for learning the pattern, and worth remembering before trusting the pattern as *tested*. A `Status` field that is a literal is decoration, not a signal. In a real function the status has to be derived from something that actually happened.

**Takeaway.** Capture the output, then interrogate it. And make sure the status you are interrogating is computed from real work rather than hard-coded.

### Level 7 — `-eq` versus `-ne`

**Question.** What is the difference between these, and does the second one prove success?

```powershell
$result.Status -eq "Failed"
$result.Status -ne "Failed"
```

**My answer** *(paraphrased in record).* The first checks equality; the second checks inequality.

**Evaluation.** **Correct** on the mechanics.

**Correct explanation.** Mechanically, `-eq` tests equality and `-ne` tests inequality — but the important point is logical, not mechanical. `-ne "Failed"` partitions the value space into *one* excluded value and *everything else*, and "everything else" includes a great deal that is not success:

| `$result.Status` | `-ne "Failed"` | Is this success? |
|---|---|---|
| `"Success"` | `$true` | Yes |
| `"Pending"` | `$true` | **No** — in progress |
| `"Timeout"` | `$true` | **No** |
| `"PartiallyCompleted"` | `$true` | **No** |
| `""` | `$true` | **No** — no status was set |
| `$null` | `$true` | **No** — property missing or unset |

So `-ne "Failed"` is a **blocklist** containing exactly one entry. Every status anyone adds to the function in future automatically counts as success, including statuses invented to describe new failure modes. `-eq "Success"` is an **allowlist**: new statuses default to not-success, which is the safe direction.

This is the same security principle as `deny-by-default` in an access model, and it is worth recognising as such — *enumerate what is permitted, not what is forbidden*, because the forbidden set grows without you.

**Takeaway.** Test for the state you require, not against one state you don't. `-ne "Failed"` is a one-entry blocklist on an open-ended value space.

### Level 8 — Missing `Status` property

**Scenario.**

```powershell
$result = [PSCustomObject]@{
    Server      = "SRV-01"
    Environment = "Production"
}

if ($result.Status -ne "Failed") {
    Write-Output "Server processing successful"
}
```

**Question.** Does the success message print?

**My answer** *(paraphrased in record).* Yes — the message prints, because the missing property evaluates to `$null`, which is not equal to `"Failed"`.

**Evaluation.** **Correct**, including the reason, which is the part that matters.

**Correct explanation.** Accessing a property that does not exist on a `PSCustomObject` returns `$null` rather than raising an error. `$null -ne "Failed"` is `$true`, so the success branch runs. Expected output:

```text
Server processing successful
```

A function that forgot to set `Status`, a `Select-Object` that dropped the column, a JSON payload whose schema changed — all three produce a confident success message from an object that contains no status at all. This is the Level 5 failure mode again, one layer deeper: the previous version lied because of *where* the message was; this one lies because of *what it tested*.

**Safer pattern — check existence, then value, and make the fallthrough a warning:**

```powershell
if ($null -eq $result.PSObject.Properties["Status"]) {
    Write-Warning "Status property is missing."
}
elseif ($result.Status -eq "Success") {
    Write-Output "Server processing successful"
}
else {
    Write-Warning "Processing was not successful."
}
```

Three branches, and the shape is the point: **success is one specific branch, and everything unrecognised lands in a warning.** There is no path through this that prints success for an object it did not understand.

`$result.PSObject.Properties["Status"]` asks the object's member collection whether the property is defined, which is a different question from whether its value is null. A property that exists and holds `$null` is a function that tried and has nothing to report; a property that does not exist is a contract mismatch. They deserve different log lines.

**Engineer-level note — `Set-StrictMode`.** Under `Set-StrictMode -Version 3.0` (or higher), referencing a non-existent property raises `PropertyNotFoundException` instead of returning `$null`. Enabling it at the top of a script converts this entire class of silent bug into a loud one:

```powershell
Set-StrictMode -Version 3.0
```

That is a genuinely good default for new automation. Two cautions: it must go in before the code it governs, and it will surface existing latent property typos across the whole script — which is the point, but it means retrofitting it to a working script is a deliberate task rather than a free win.

**Takeaway.** A missing property is `$null`, not an error. Check that the property exists before trusting its value, and consider `Set-StrictMode -Version 3.0` so the shell does it for you.

### Level 9 — Empty `Status` property

**Scenario.**

```powershell
$result = [PSCustomObject]@{
    Server = "SRV-01"
    Status = ""
}

if ($result.Status -ne "Failed") {
    Write-Output "Server processing successful"
}
```

**Question.** Does the success message print, and what exactly is `$result.Status`?

**My answer** *(paraphrased in record).* The success message prints — but I initially described the value as `$null`.

**Evaluation.** **Partially correct.** Right outcome, wrong value. And the wrong value is the interesting part, because it is the same conflation that §3.4 exists to prevent.

**Correct explanation.** The property **exists** and holds an **empty string**. That is a third state, distinct from both "missing" and "has a value":

| State | `PSObject.Properties["Status"]` | `.Status` value | `-ne "Failed"` | What it means |
|---|---|---|---|---|
| Missing | `$null` | `$null` | `$true` | Contract mismatch — nothing set it |
| Exists, empty | an object | `""` | `$true` | Something set it, to nothing |
| Exists, valued | an object | `"Success"` | `$true` | Real signal |

All three satisfy `-ne "Failed"`, which is why Level 7's point holds regardless of which one you have. But they need different diagnoses: a missing property means the producer's schema is wrong; an empty one means the producer ran and declined to say anything, which usually means a code path that assigns the status was skipped.

The existence check from Level 8 does **not** catch the empty case — `PSObject.Properties["Status"]` returns an object, so the first branch passes. To catch both:

```powershell
if ($null -eq $result.PSObject.Properties["Status"] -or
    [string]::IsNullOrWhiteSpace($result.Status)) {
    Write-Warning "Status is missing or blank for '$($result.Server)'."
}
elseif ($result.Status -eq "Success") {
    Write-Output "Server processing successful"
}
else {
    Write-Warning "Processing reported status '$($result.Status)'."
}
```

**Why this mistake is worth logging rather than waving away.** Saying "it's null" when it is `""` is harmless *here* — both branches go the same way. It stops being harmless the moment the code tests `$null -eq $result.Status`, which is `$false` for an empty string and sends an unset status down the success path. The distinction only costs you when you have forgotten it, which is the definition of a trap.

**Takeaway.** Missing, empty, and valued are three states. `-ne` cannot tell them apart; an existence check cannot tell empty from valued; only `IsNullOrWhiteSpace` plus an existence check covers all three.

### Level 10 — Choose the exact success condition

**Question.** Which of these is the correct success test?

**A.**

```powershell
if ($result.Status -ne "Failed")
```

**B.**

```powershell
if ($result.Status -eq "Success")
```

**C.**

```powershell
if ($result.Status)
```

**My answer** *(paraphrased in record).* **B** — the code should check exactly what is required rather than merely excluding an unwanted value.

**Evaluation.** **Correct**, and the reasoning given is the right reasoning, not just the right letter.

**Correct explanation.** Each option against the six states from Level 7:

| `$result.Status` | A: `-ne "Failed"` | B: `-eq "Success"` | C: truthiness |
|---|---|---|---|
| `"Success"` | success ✓ | success ✓ | success ✓ |
| `"Failed"` | not success ✓ | not success ✓ | **success ✗** |
| `"Pending"` | **success ✗** | not success ✓ | **success ✗** |
| `""` | **success ✗** | not success ✓ | not success ✓ |
| `$null` | **success ✗** | not success ✓ | not success ✓ |
| property missing | **success ✗** | not success ✓ | not success ✓ |

**Why C is the worst of the three**, and worth more than a passing mention: `if ($result.Status)` tests the *truthiness* of the value. A non-empty string is `$true` in PowerShell — including the string `"Failed"`. So option C reports success **specifically when the operation failed**. It is not merely imprecise; it is inverted for the one case that matters most. ("Is there a status?" and "is the status good?" are different questions, and C asks the first while appearing to ask the second.)

**Why A fails.** Four of six states are misreported as success, as established in Level 7.

**Why B is right and still not sufficient.** B gets all six rows correct. What it does not do is *distinguish* the four not-success rows from each other. Robust automation wants to know which:

```powershell
if ($null -eq $result -or
    $null -eq $result.PSObject.Properties["Status"]) {
    Write-Warning "No status returned for '$($row.Server)' — check the function contract."
    continue
}

if ($result.Status -eq "Success") {
    Write-Output "Successfully processed $($row.Server)"
    continue
}

Write-Warning "Processed '$($row.Server)' with status '$($result.Status)'."
```

Note `$null -eq $result` first: if the function threw and was caught, or returned nothing at all, `$result` itself is `$null` and `$result.PSObject` would be a null-reference access. Guard the object before guarding its properties.

**Takeaway.** `-eq "Success"` is the only one of the three that is safe, and `if ($result.Status)` is actively wrong because `"Failed"` is a truthy string. Allowlist the success value; route everything else to a warning that prints what it actually got.

### Level 11 — Returned failure status without an exception

**Scenario.**

```powershell
try {
    $result = Get-ServerReport -Server "SRV-01" -Environment "Production"

    if ($result.Status -eq "Success") {
        Write-Output "Server processing successful"
    }
}
catch {
    Write-Warning "Error: $($_.Exception.Message)"
}

Write-Output "Script completed"
```

Assume the function returns `Status = "Failed"` **without throwing**.

**Question.** What is printed?

**My answer** *(paraphrased in record).* I initially said that `catch` runs.

**Evaluation.** **Incorrect.** This is the first of the two outright misses, and it is the central misconception of Day 10.

**Correct explanation.** Walk it line by line:

1. `$result = Get-ServerReport ...` — the function returns an object. No exception. The assignment consumes the output, so nothing prints.
2. `if ($result.Status -eq "Success")` — `"Failed" -eq "Success"` is `$false`. The body is skipped. **Nothing is printed and nothing is reported.**
3. The `try` block ends normally. **`catch` is never entered**, because no terminating error occurred.
4. `Write-Output "Script completed"` runs.

**Expected output:**

```text
Script completed
```

One line. No success message, no warning, no error — and a failed server.

**The misconception, named precisely.** `catch` does not respond to *bad results*. It responds to *terminating errors*. A returned status is **data**; an exception is **control flow**. They travel by completely different mechanisms:

| | Returned status | Exception |
|---|---|---|
| Travels via | the output stream, as a value | the error/exception mechanism |
| Reaches you by | being assigned or piped | unwinding to the nearest `catch` |
| Seen by `catch`? | **Never** | Yes |
| Must be acted on by | **an explicit `if`** | `catch` |
| Ignoring it | compiles, runs, reports nothing | is caught or crashes the script |

A function that returns `Status = "Failed"` has **not failed, from PowerShell's point of view.** It ran to completion and returned a value describing a bad outcome. That is a successful function call with a disappointing result. Nothing in the runtime cares about the contents of your return value.

**Why this specific shape is so dangerous.** The code *looks* exhaustive. It has a `try`, a `catch`, and a success condition. A reviewer skimming it sees error handling and moves on. But the `if` has no `else`, and the `catch` cannot see the status, so the failure falls through a gap between the two constructs — into silence. Not a wrong message: **no message**. In a 500-record batch, 40 silent failures and a final "Script completed" is indistinguishable from a clean run.

**The fix is Level 12 and 13: give the failure path a voice.** Either handle it as data:

```powershell
if ($result.Status -eq "Success") {
    Write-Output "Server processing successful"
}
else {
    Write-Warning "Processing failed. Status: $($result.Status)"
}
```

…or convert it into control flow with `throw`, so the existing `catch` becomes able to see it. What you must not do is leave the `if` without an `else` and assume the `catch` has you covered.

**Takeaway.** `catch` sees exceptions, never return values. An `if` with no `else` around a status check is a silent-failure generator. This is Day 10's single most important correction.

### Level 12 — Use `throw` for a failed status

**Original attempted code:**

```powershell
if ($result.Status -eq "Success") {
    Write-Output "Server processing successful"
}
else {
    "Server processing failed"
}
```

**Question.** Will this cause the surrounding `catch` to run?

**My answer** *(preserved as the code above).* I wrote the `else` branch without `throw` — a bare string expression.

**Evaluation.** **Incorrect.** Same root misconception as Level 11, now expressed in code rather than in a prediction. Having been told in Level 11 that a returned status does not reach `catch`, the `else` branch here still does not raise anything — so the correction had not yet taken hold. That repetition is why this pair is revision priority #1.

**Correct explanation.** A bare string in PowerShell is an **expression statement**. Its value goes to the success output stream — exactly as if you had written `Write-Output "Server processing failed"`. Three things follow, and all three are bad:

1. **No exception is raised.** `catch` is not entered. Execution continues to the next statement.
2. **The string joins the function's data output.** If the surrounding code does `$report = & { ... }` or pipes the loop into `Export-Csv`, that sentence is now a row in the report. This is output-stream pollution — the same failure mode as Day 8's `return`/`Write-Output` arithmetic.
3. **It is invisible where failures are looked for.** It goes to stdout, not to the warning or error stream, so `2>` redirection, `-WarningVariable`, and any log filter watching for warnings all miss it.

**Corrected code:**

```powershell
if ($result.Status -eq "Success") {
    Write-Output "Server processing successful"
}
else {
    throw "Server processing failed. Status: $($result.Status)"
}
```

**What `throw` does that the string does not.** It raises a terminating error: it stops the current block immediately, unwinds to the nearest enclosing `catch`, and if there is none, terminates the script with a non-zero outcome. It also populates `$_` in the catch so the message is available to the handler.

Including `Status: $($result.Status)` in the message is not decoration. `throw "Server processing failed"` tells the log that something went wrong; `throw "Server processing failed. Status: Timeout"` tells the next engineer which failure it was. The status is in hand at the moment of throwing and will not be later — put it in the message.

**The three ways to signal a bad status, and when each is right:**

| Mechanism | Stream | Reaches `catch`? | Stops the block? | Use when |
|---|---|---|---|---|
| `"text"` or `Write-Output` | Success | No | No | **Never, for failures.** This is data output. |
| `Write-Warning` | Warning | No | No | The record is skippable and the batch should carry on. |
| `throw` | Error (terminating) | Yes | Yes | The failure must be handled, retried, or must stop the work. |

Level 12's `else` needed `throw` because the question was explicitly "make the `catch` run". In the Day 10 batch loops the right choice for a skippable bad record is `Write-Warning` + `continue` — which is why both patterns appear in this document and why knowing *which* you want is the actual skill.

**Takeaway.** Emitting a string is not raising an error. `throw` raises a terminating error that `catch` can handle; a bare string silently pollutes your data output and is never seen.

### Level 13 — Throwing inside `try`

**Scenario.**

```powershell
try {
    $result = Get-ServerReport -Server "SRV-01" -Environment "Production"

    if ($result.Status -ne "Success") {
        throw "Server processing failed"
    }

    Write-Output "Server processing successful"
}
catch {
    Write-Warning "Error: $($_.Exception.Message)"
}

Write-Output "Script completed"
```

Assume `Status = "Failed"`.

**Question.** What is printed?

**My answer** *(paraphrased in record).* The catch warning and `Script completed` appear; the success message is skipped.

**Evaluation.** **Correct** — and notably, this is the Level 11 scenario with `throw` added, answered correctly. The mechanism was understood once it was written out in code.

**Correct explanation.**

1. The function returns `Status = "Failed"`. No exception yet.
2. `-ne "Success"` is `$true`, so `throw` raises a terminating error.
3. The rest of the `try` is abandoned — `Write-Output "Server processing successful"` is **unreachable**, which is the structural guarantee from Level 5 doing its job.
4. `catch` runs and warns.
5. The error is handled, so execution continues after the `try/catch`.
6. `Script completed` prints.

**Expected messages:**

```text
WARNING: Error: Server processing failed
Script completed
```

**Why this pattern is worth internalising.** Compare directly against Level 11:

| | Level 11 (no `throw`) | Level 13 (with `throw`) |
|---|---|---|
| Output on failure | `Script completed` only | Warning **and** `Script completed` |
| Failure visible? | **No** | Yes |
| Success message | skipped silently | skipped, provably unreachable |
| `catch` entered | no | yes |

One keyword converts a silent failure into a reported one. That is the entire delta — and it is the strongest argument in this document for the "validate the result, then `throw`" pattern.

**One design note.** `-ne "Success"` is used here as the *failure* test, which is the correct direction for `-ne`: as a **failure** condition, "anything that is not exactly Success" is appropriately suspicious. The same operator was wrong in Level 7 because it was being used as a *success* test. The operator is not the problem; which side of the question it is asked on is.

**Takeaway.** `throw` inside `try` makes the rest of the block unreachable and routes the failure to `catch`. A handled error does not stop the script — code after the `try/catch` still runs.

### Level 14 — Throwing again inside `catch`

**Scenario.**

```powershell
try {
    throw "First error"
}
catch {
    Write-Warning "Caught: $($_.Exception.Message)"
    throw "Second error"
}

Write-Output "Script completed"
```

**Question.** Does `Script completed` print?

**My answer** *(paraphrased in record).* No — the second error prevents `Script completed` from being printed.

**Evaluation.** **Correct.**

**Correct explanation.** A `catch` block is ordinary code with one special property: it has already consumed the error it was entered for. A `throw` inside it raises a **new** terminating error, and that error is **not** handled by the `catch` it was thrown from — a `catch` cannot catch itself. With no outer `try/catch`, it propagates to the top and terminates the script, so the statement after the `try/catch` never runs.

**Expected messages:**

```text
WARNING: Caught: First error
Second error
```

The warning appears because `Write-Warning` runs before the `throw`. The second line is PowerShell reporting the unhandled error (in PowerShell 7 at the console this appears with the `Exception:` / `Line |` formatting seen in Level 15's observed output).

**To catch a rethrow, you need an outer frame:**

```powershell
try {
    try {
        throw "First error"
    }
    catch {
        Write-Warning "Caught: $($_.Exception.Message)"
        throw                      # bare: rethrows "First error", preserving it
    }
}
catch {
    Write-Warning "Outer handler: $($_.Exception.Message)"
}

Write-Output "Script completed"
```

Expected:

```text
WARNING: Caught: First error
WARNING: Outer handler: First error
Script completed
```

**When rethrowing is the right thing to do.** Rethrowing is how you log locally and still let the caller decide. The inner handler adds context — which record, which server — and the outer handler owns the policy of whether the batch continues. The anti-pattern is catching an error, logging it, and swallowing it at a level that has no authority to decide the work can proceed.

**Takeaway.** A `throw` inside `catch` raises a new, unhandled error unless an outer `try/catch` exists. It terminates everything after the `try/catch` statement.

### Level 15 — Rethrowing an error terminates the loop

**Original code:**

```powershell
foreach ($server in @("SRV-01", "SRV-02", "SRV-03")) {
    try {
        if ($server -eq "SRV-02") {
            throw "Connection failed"
        }

        Write-Output "Success: $server"
    }
    catch {
        Write-Warning "Failed: $server"
        throw
    }
}

Write-Output "All servers processed"
```

**Question.** What is printed, and is `SRV-03` processed?

**My answer** *(paraphrased in record).* The loop stops at `SRV-02` and `SRV-03` is not processed. I initially missed that the catch warning **is** displayed, because `Write-Warning` is explicitly present.

**Evaluation.** **Partially correct.** The control-flow conclusion — the headline question — was right. The missed detail is that the handler's own output still happens before the rethrow.

**Correct explanation.**

1. `SRV-01` — no throw, `Success: SRV-01` prints.
2. `SRV-02` — `throw "Connection failed"` fires. `catch` is entered.
3. `Write-Warning "Failed: SRV-02"` **runs** — the catch block executes top to bottom, and the `throw` is the *last* statement, not the first.
4. Bare `throw` rethrows the current exception. Nothing catches it. The loop is torn down.
5. `SRV-03` is never reached. `All servers processed` is never reached.

**Observed output:**

```text
Success: SRV-01
WARNING: Failed: SRV-02
Exception:
Line |
   4 |              throw "Connection failed"
     |              ~~~~~~~~~~~~~~~~~~~~~~~~~
     | Connection failed
```

**A detail in that output worth noticing.** The error points at **line 4** — the *original* `throw "Connection failed"` — not at the bare `throw` in the `catch`. That is bare `throw` doing exactly its job: it rethrows the existing exception object with its original message, type, and **original stack position** preserved. The traceback still points at where the problem happened rather than at where it was re-raised, which is the whole reason to prefer bare `throw` over `throw $_`.

**Bare `throw` versus `throw "message"`:**

| | Bare `throw` | `throw "Second error"` |
|---|---|---|
| Exception object | the original, re-raised | a brand-new `RuntimeException` |
| Message | preserved | replaced |
| Original error record | preserved, including position | **lost** |
| Points at | the original failing line | the `throw` statement |
| Use for | passing a failure up after local logging | signalling a *different* failure you detected |

Using `throw "Connection failed to $server"` in the catch would have replaced `Connection failed` and moved the reported line to the catch block — losing the original location. Bare `throw` is the correct choice when the intent is "log and escalate".

#### A critical observation about the final line (Observed)

After the loop terminated, the session separately entered:

```powershell
Write-Output "All servers processed"
```

The terminal printed that command's output **because it was a new command typed at the prompt after the failed loop — not because the original script reached that statement.**

This is worth dwelling on because it is a reasoning error about *evidence*, not about PowerShell. In an interactive session, the terminal is a single transcript: output from a script, output from a manually typed command, and error text all interleave in one scrollback with nothing to distinguish them. A line appearing after an error does not establish that the erroring code produced it.

In this instance it produced a scrollback that reads like a script which failed and then carried on to completion — exactly the opposite of what happened. Had this been accepted at face value, the conclusion would have been "a rethrow doesn't stop the loop", which is false.

**How to avoid the ambiguity:**

| Technique | Why |
|---|---|
| Run the whole thing as a file: `pwsh -NoProfile -File ./test.ps1` | One process, one outcome. If the script died, nothing after it prints. |
| Check `$?` or `$LASTEXITCODE` immediately after | Separates "it ran" from "it worked". |
| Prefix markers: `"=== starting batch ==="` / `"=== batch complete ==="` | Makes the script's own boundaries visible in the transcript. |
| Dot-source into a fresh `pwsh` for each test | No inherited state, no interleaving with earlier experiments. |

For verifying a deliverable, the first one is the only answer. Interactive exploration is for building understanding; a file run in a fresh process is for establishing that something works.

#### The alternative: continue instead of abort

```powershell
catch {
    Write-Warning "Failed: $server"
    continue
}
```

**Expected output** with that change:

```text
Success: SRV-01
WARNING: Failed: SRV-02
Success: SRV-03
All servers processed
```

**Choosing between them is a design decision, not a style preference:**

| Use `continue` in the catch when | Use `throw` in the catch when |
|---|---|
| Records are independent | Records are interdependent, or order matters |
| A partial run is useful | A partial run leaves inconsistent state |
| You want a skip list at the end | The first failure indicates something systemic (expired credential, unreachable DC) |
| Example: reporting across 500 servers | Example: a staged provisioning sequence where step 2 must not run if step 1 failed |

Both are correct code; they encode different answers to "what should happen to the rest of the batch?" The one thing that is *not* acceptable is leaving it unanswered — which is Level 11's silent gap.

**Takeaway.** Bare `throw` in a `catch` escalates and tears down the loop, after the catch's own output has run. `continue` logs and proceeds. And output appearing in a terminal after an error is not evidence that the script reached it.

**— End of the 15 debugging levels. —**
---

## 6. Interview preparation — 10 scenario-based questions

**Labelling, stated plainly:** the session record preserves the **ten concepts** covered in Day 10's interview practice. It does **not** preserve the questions as they were asked, nor my answers to them. Every question below is therefore a **reconstructed question** written for this README against the recorded concept, and every answer is a **model answer**, not a transcript of what I said. My original answers to these ten are recorded as **Not recorded** in §10.3. They have not been invented.

### Q1 — Parameter-binding order and positional vs. named calls

> *Reconstructed:* "A colleague's script calls `Set-ServerConfig $name $env $region`. It ran fine for months and now assigns the wrong region. Nothing in the call changed. What do you look at first?"

**Interview answer.** The function signature. If a parameter was added or reordered in the `param()` block, every positional caller shifted by one — and because these are all strings, nothing throws. The call still succeeds and the data is wrong. I'd confirm with `(Get-Command Set-ServerConfig).Parameters` and the signature's `Position` values, then convert the call to named parameters.

**Detailed explanation.** The binder resolves named arguments first, then fills remaining positional parameters in ascending `Position` order, then applies defaults, then runs validation. A positional call depends on an ordering that is not part of any contract and that nothing enforces. With type-compatible parameters, a transposition is undetectable at runtime.

**Example.**

```powershell
# Fragile: meaning is carried by position
Set-ServerConfig "SRV-01" "Production" "eu-west"

# Durable: meaning is carried by name
Set-ServerConfig -Name "SRV-01" -Environment "Production" -Region "eu-west"
```

**Real-world automation scenario.** A JML script passes `-Identity`, `-Department`, `-Manager` positionally. A new `-CostCentre` parameter is inserted second. Overnight, every user's department is set to their cost centre and their manager field holds a department name. No errors, 400 corrupted records, and the detection comes from a human noticing an org chart looks wrong.

**Common misconception.** *"Position follows the order in `param()`."* It does not — declared `Position` numbers win, and a parameter with no `Position` is not positional at all. Checking `param()` order instead of the attributes will mislead you.

### Q2 — Why mandatory parameters can cause unattended prompts

> *Reconstructed:* "Your nightly job used to finish in four minutes. Last night it ran for six hours and was killed by the scheduler. No error in the log. Where do you look?"

**Interview answer.** A mandatory parameter that received no argument. PowerShell asked the host to prompt for it, the scheduled host had no console to answer, and the job blocked until it was killed. There's no error in the log because nothing errored — it was waiting. I'd check whether an input record had a blank required field, and fix it by validating records before the call rather than relying on `Mandatory`.

**Detailed explanation.** Prompting occurs only when the argument is **omitted**. An explicitly supplied `$null` or `""` raises a catchable binding error instead, and a whitespace-only string binds successfully. `-ErrorAction Stop` does not help, because the prompt happens during binding, before the command runs, and is not an error until the prompt itself fails.

**Example.**

```powershell
# Hazardous in a scheduled context
function Invoke-Task {
    param([Parameter(Mandatory)][string]$Target)
    "working on $Target"
}

# Safe: the caller owns presence-checking, and failure is explicit
foreach ($row in $Records) {
    if ([string]::IsNullOrWhiteSpace($row.Target)) {
        Write-Warning "Skipping record: Target is missing."
        continue
    }
    Invoke-Task -Target $row.Target
}
```

**Real-world automation scenario.** An offboarding job reads an HR export. One row has a blank `SamAccountName`. Interactively the engineer sees a prompt and types the name. At 02:00 the same code hangs, holds the job slot, and the deprovisioning SLA is missed for every row after it.

**Common misconception.** *"`Mandatory` validates the input."* It is a presence check only. It rejects `$null` and `""`, accepts `"   "`, and prompts when the argument is absent — none of which is content validation.

### Q3 — Why aliases are useful and when full names are preferable

> *Reconstructed:* "You're writing a function three teams will call, and each team calls the same thing by a different name. How do you handle it, and what do you put in the committed scripts?"

**Interview answer.** `[Alias()]` on the parameter so each team can use its own vocabulary interactively. In committed scripts I use the canonical parameter name, because the alias is a convenience for humans at a prompt, not a contract — and a reader of the script shouldn't have to look up which alias maps to which parameter.

**Detailed explanation.** An alias registers an extra lookup key with the binder for the same parameter. It creates no second parameter, cannot be supplied alongside the canonical name, does not rename the output property, and participates in property-name binding only when `ValueFromPipelineByPropertyName` is set and objects are actually piped.

**Example.**

```powershell
function Get-TargetFunction {
    param(
        [Alias("Server", "Hostname")]
        [string]$ComputerName
    )
    [PSCustomObject]@{ ComputerName = $ComputerName }
}

Get-TargetFunction -Server "SRV-01"        # works
Get-TargetFunction -Hostname "SRV-01"      # works
Get-TargetFunction -ComputerName "SRV-01"  # canonical — use this in scripts
```

**Real-world automation scenario.** A shared IAM module is called by a service-desk team that says "username", an AD team that says "SamAccountName", and an HR integration that says "EmployeeID"-keyed objects. Aliases make the module pleasant for the first two at the console; the integration still needs explicit mapping in code.

**Common misconception.** *"The alias will make `$result.Server` work."* The output property name comes from whatever the function puts in its output object. The binder's input-side alias has no reach into the function body or its return value.

### Q4 — Why CSV headers require explicit field mapping

> *Reconstructed:* "Your script imports a CSV whose header is `Server`, and your function has `[Alias('Server')][string]$ComputerName`. In a `foreach` loop it binds nothing. Why?"

**Interview answer.** Because a `foreach` loop with a direct call passes **values**, not objects — nothing is matching property names. Alias-based property binding only happens on the pipeline, and only when the parameter declares `ValueFromPipelineByPropertyName`. In a direct call the mapping is mine to write: `-ComputerName $row.Server`.

**Detailed explanation.** Property-name binding is a pipeline feature. `Import-Csv | Get-TargetFunction` can match a `Server` column to a parameter aliased `Server` **if** that parameter opts in. `foreach ($row in $rows) { Get-TargetFunction -ComputerName $row.Server }` never consults property names at all — and that explicitness is usually what you want in an import layer, because the field contract is then visible in the code.

**Example.**

```powershell
# Explicit mapping — direct call
foreach ($row in $Records) {
    Get-TargetFunction -ComputerName $row.Server -Environment $row.Environment
}

# Pipeline binding — requires the parameter to opt in
function Get-TargetFunction {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Server")]
        [string]$ComputerName
    )
    process { [PSCustomObject]@{ ComputerName = $ComputerName } }
}
Import-Csv ./servers.csv | Get-TargetFunction
```

Note the `process` block — a pipeline-binding function needs one, or it will only see the last object.

**Real-world automation scenario.** An access-recertification feed changes its header from `Server` to `ServerName`. With explicit mapping, the script fails loudly at one line you can fix. With implicit pipeline binding, every row silently binds `$null` and the report comes out empty but "successful".

**Common misconception.** *"Matching names means matching fields."* Name matching is a pipeline mechanism that must be opted into. Everywhere else, a shared spelling is a coincidence.

### Q5 — The difference between defaults and `ValidateSet`

> *Reconstructed:* "`[ValidateSet('Production','Test','Development')][string]$Environment = 'Test'`. A CSV row has a blank environment cell. Does the default apply?"

**Interview answer.** No. A blank cell is an empty string, which is a *supplied* value — so the default is skipped and `ValidateSet` rejects `""`. The default applies only when the parameter is omitted entirely. Normalising blanks to the intended default is the caller's job, before the call.

**Detailed explanation.** Defaults and validators cover disjoint cases: the default applies to unbound parameters, the validator runs on bound ones. There is no path where an invalid supplied value falls back to the default. `Import-Csv` never produces "absent" — a blank cell is `""` — so CSV-driven code must normalise at the boundary.

**Example.**

```powershell
Get-ServerReport -Server "SRV-01"                  # Environment omitted -> "Test"
Get-ServerReport -Server "SRV-01" -Environment ""  # throws: "" not in set

# Normalise first
if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "Test" }
Get-ServerReport -Server "SRV-01" -Environment $Environment
```

**Real-world automation scenario.** An optional free-text field on an access-request form. Every user who skips it produces `""`, and the nightly run logs a validation error per skipped field — a flood of errors that are really one missing normalisation step.

**Common misconception.** *"A default is a fallback for bad input."* It is a value for **absent** input. And a default on a `Mandatory` parameter is unreachable code, since `Mandatory` guarantees a value will be bound.

### Q6 — Why invalid environment values must be rejected

> *Reconstructed:* "A record arrives with environment `Staging`, which isn't a valid value. A colleague suggests defaulting it to `Production` so the batch doesn't fail. What's your position?"

**Interview answer.** I'd reject the record, log it with enough context to find it, and continue the batch. Substituting `Production` for an unrecognised value turns a data-quality problem into an unrequested configuration change — and in an access or deployment context that is a change nobody approved and nobody will see in the log.

**Detailed explanation.** There are exactly two defensible responses to an invalid value: reject it, or substitute a default that has been **explicitly approved as the default for that field**. What makes the `Production` suggestion unacceptable isn't the mechanism, it's the choice of value: silently escalating an unknown record to the most sensitive environment. `ValidateSet` is the cheap enforcement point, and its error message names the parameter, the bad value, and the allowed set for free.

**Example.**

```powershell
if ($Environment -notin $AllowedEnvironments) {
    Write-Warning "Skipping server '$Server': invalid environment '$Environment'."
    continue
}
```

**Real-world automation scenario.** A deployment pipeline defaults unknown environment tags to `Production`. A typo'd tag in a feature branch sends a test build to production. Everything reports success, because every layer did exactly what it was told.

**Common misconception.** *"Defaulting is more robust than failing, because the batch completes."* A batch that completes by inventing values has not succeeded — it has hidden its failures and added new ones. Robustness means surviving the bad record while reporting it, not absorbing it.

### Q7 — Why an alias does not change an output object's property name

> *Reconstructed:* "You aliased `ComputerName` as `Server`, the caller used `-Server`, and now downstream code doing `$result.Server` gets nothing. Why?"

**Interview answer.** The output property name comes from the hashtable key in the function's return object — `ComputerName`. The alias affects only which parameter names the binder accepts on input. Input naming and output shape are independent; if downstream code needs `Server`, the function has to emit `Server`.

**Detailed explanation.** `[Alias()]` is registered with the parameter binder. The function body sees one variable under its canonical name, and the output object is built from whatever the body writes. If both spellings genuinely must work downstream, either rename the emitted property or add a calculated/alias property to the output object — an explicit act on the output side.

**Example.**

```powershell
$r = Get-TargetFunction -Server "SRV-01" -Environment "Production"
$r.ComputerName   # SRV-01
$r.Server         # $null

# If both are genuinely needed, do it on the output object
$r | Add-Member -MemberType AliasProperty -Name Server -Value ComputerName
$r.Server         # SRV-01
```

**Real-world automation scenario.** A function is refactored from `-Server` to `-ComputerName` with an alias kept for compatibility. Every *caller* keeps working; every *consumer* of the output that reads `.Server` silently gets `$null`. The alias covered the input half of the contract and nothing warned about the other half.

**Common misconception.** *"The alias makes the two names interchangeable everywhere."* It makes them interchangeable in one place: parameter binding.

### Q8 — Why `catch` does not automatically handle every reported failure

> *Reconstructed:* "A function returns an object with `Status = 'Failed'`. The call is inside `try/catch`. The catch never fires and the log shows nothing. Explain."

**Interview answer.** Because a returned status is **data** and `catch` only responds to **terminating errors**. The function ran to completion and returned a value describing a bad outcome — from the runtime's point of view that's a successful call. If the status matters, I have to test it with an `if` and then either warn-and-skip or `throw` to convert it into control flow.

**Detailed explanation.** Two independent channels. Return values travel on the output stream and must be assigned or piped to be seen. Exceptions unwind to the nearest `catch`. Nothing inspects the *content* of a return value on your behalf. The classic silent-failure shape is an `if ($result.Status -eq 'Success')` with no `else` inside a `try/catch`: the success branch is skipped, the catch is never entered, and nothing is logged at all.

**Example.**

```powershell
try {
    $result = Get-ServerReport -Server "SRV-01" -Environment "Production"

    if ($result.Status -eq "Success") {
        Write-Output "Server processing successful"
    }
    else {
        throw "Server processing failed. Status: $($result.Status)"   # <- the missing half
    }
}
catch {
    Write-Warning "Error: $($_.Exception.Message)"
}
```

**Real-world automation scenario.** A provisioning function returns `Status = 'Failed'` for 40 of 500 users because a downstream API rate-limited. The loop has a `try/catch` and no `else`. The run reports "Script completed", the dashboard shows 500 processed, and the 40 users discover it when they can't log in.

**Common misconception.** *"If there's a `try/catch`, failures are handled."* `try/catch` handles exceptions. Bad return values are a separate obligation, and the `if` without an `else` is where they disappear.

### Q9 — How `try/catch`, `throw`, and `continue` interact

> *Reconstructed:* "In a batch loop, when do you use `throw` in a catch and when `continue`? What does a bare `throw` do differently from `throw \"message\"`?"

**Interview answer.** `continue` when records are independent and a partial run is useful — log the failure, skip the record, keep going. `throw` when the failure is systemic or records are interdependent, so the batch should stop rather than produce inconsistent state. A bare `throw` re-raises the original exception with its message and original position preserved; `throw "message"` creates a new exception and loses the original error record, including where it actually happened.

**Detailed explanation.** A `catch` that finishes normally has handled the error, and execution continues after the `try/catch` — a `foreach` then advances on its own, with or without `continue`. `continue` skips the *remainder of the current iteration*, which matters when statements follow the `try/catch`. A `throw` inside a `catch` raises a new terminating error that the same `catch` cannot handle; without an outer `try/catch` it terminates the script.

**Example.**

```powershell
# Independent records: log and carry on
catch {
    Write-Warning "Failed '$($row.Server)': $($_.Exception.Message)"
    continue
}

# Systemic failure: log locally, let the caller decide
catch {
    Write-Warning "Failed '$($row.Server)': $($_.Exception.Message)"
    throw            # bare: original exception and position preserved
}
```

**Real-world automation scenario.** A 500-server inventory sweep should `continue` — one unreachable host shouldn't cost you the other 499. A three-step provisioning sequence should `throw` — if the account wasn't created, running the group-membership and mailbox steps produces a half-built identity that is harder to clean up than to redo.

**Common misconception.** *"`continue` is required for the loop to advance after a caught error."* It isn't; the loop advances anyway. `continue` exists to skip what comes *after* the `try/catch` in that iteration — which is exactly what stops a failed record being logged as finished.

### Q10 — How to debug an end-to-end CSV-processing workflow

> *Reconstructed:* "A CSV-driven script reports every row as processed, but the target system shows no changes. Walk me through your debugging."

**Interview answer.** In order: confirm I'm running the code I'm reading, confirm the data arrived as I think, confirm the arguments bound, then confirm the success message is actually conditional on success. In my experience the last one is the usual culprit — a `Write-Output "done"` sitting outside the `try/catch`, or a status check with no `else`.

**Detailed explanation — the checklist, cheapest first.**

```powershell
# 1. Am I running the code I'm reading? (stale definition — cost real time on Day 10)
(Get-Command Get-ServerReport).Definition
. ./Day10_Challenge.ps1

# 2. Did the data arrive as I think?
$Records | Select-Object -First 3 | Format-List *
$Records.Count
$Records | Where-Object { [string]::IsNullOrWhiteSpace($_.Server) } | Measure-Object

# 3. Did the arguments bind? (put inside the function body)
$PSBoundParameters

# 4. Is the success message conditional on success?
#    - is it inside the try, after the call?
#    - does the status check have an else?
#    - is it -eq "Success", not -ne "Failed" and not if ($result.Status)?

# 5. Run it clean, so terminal scrollback can't mislead me
pwsh -NoProfile -File ./Day10_Challenge.ps1
```

**Real-world automation scenario.** A recertification script logs 1,200 rows processed and changes nothing. Cause: the source column was renamed, every `$row.Server` bound `$null`, the function's guard threw, the catch warned — and a `Write-Output "Processed $($row.Server)"` after the `try/catch` printed 1,200 cheerful lines with a blank server name that nobody read closely.

**Common misconception.** *"If it printed, it worked."* Output proves a statement was reached, not that an operation succeeded. And in an interactive terminal, output appearing after an error doesn't even prove the script reached it — Level 15's `All servers processed` was a separately typed command.

---

## 7. Day 10 daily challenge

### 7.1 The requirement

> **Design a signature that reads correctly when called positionally by someone who has never seen it.**

**Deliverable:** a prompt-free function set, documented as `about_Functions_Advanced_Parameters`.

Two constraints are doing the real work in that sentence, and they pull against each other:

- **"Reads correctly when called positionally"** — the most significant noun first, the qualifier second, so `Get-ServerReport "SRV-01" "Production"` is comprehensible to someone who has never opened the file.
- **"Prompt-free"** — no execution path may ever ask a human for input, because the function must be safe in a scheduled job.

The tension: the natural way to guarantee `Server` is present is `Mandatory = $true`, and that is precisely what introduces the prompt. Resolving it is the challenge.

### 7.2 The initial challenge function

```powershell
function Get-ServerReport {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Position = 1)]
        [ValidateSet("Production", "Test", "Development")]
        [string]$Environment = "Test"
    )

    if ([string]::IsNullOrWhiteSpace($Server)) {
        throw "Server name cannot be empty or whitespace."
    }

    [PSCustomObject]@{
        Server      = $Server
        Environment = $Environment
        Status      = "Success"
    }
}
```

**Why this version does not satisfy the challenge.** `Mandatory = $true` means an omitted `-Server` prompts. That is the one behaviour the brief rules out. So `Mandatory = $true` was removed, and the function kept its explicit guard:

```powershell
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Server name cannot be empty or whitespace."
}
```

**What was gained and what was given up by that removal:**

| | With `Mandatory = $true` | Without it |
|---|---|---|
| `-Server` omitted | **prompts** (disqualifying) | `$Server` is `""` → the guard throws |
| `-Server ""` | binding error | `[ValidateNotNullOrEmpty()]` rejects it |
| `-Server "   "` | binds, then the guard throws | binds, then the guard throws |
| Unattended-safe | **No** | **Yes** |

The guard is what makes the removal safe. Without it, dropping `Mandatory` would mean an omitted `-Server` runs the function with an empty name and returns `Status = "Success"`.

### 7.3 Two layers of validation, and why both exist

This is the architectural point of the challenge, and it is worth stating explicitly because it recurs in every batch script:

| Layer | Mechanism | Audience | Behaviour on bad input |
|---|---|---|---|
| **Internal guard** — inside the function | `throw` | A developer calling the function directly, by hand | Terminating error. Loud, immediate, unmissable. |
| **External validation** — in the batch loop | `Write-Warning` + `continue` | A scheduled job processing many records | Log the record, skip it, carry on. |

They are not redundant. Each is wrong in the other's context:

- If the function only warned, a developer typing `Get-ServerReport -Environment "Test"` at the prompt would get a cheerful `Status = "Success"` object with a blank server. The guard must throw.
- If the loop only relied on the function's throw, one bad record would abort the batch (or, with a `try/catch`, produce a message about parameter internals rather than about the record). The loop must pre-validate.

The function defends its own contract. The loop owns the batch policy. **Two layers, two different jobs** — and that division is the reusable lesson, not the specific code.

### 7.4 Final challenge script

```powershell
function Get-ServerReport {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Position = 1)]
        [ValidateSet("Production", "Test", "Development")]
        [string]$Environment = "Test"
    )

    if ([string]::IsNullOrWhiteSpace($Server)) {
        throw "Server name cannot be empty or whitespace."
    }

    [PSCustomObject]@{
        Server      = $Server
        Environment = $Environment
        Status      = "Success"
    }
}

$Records = @(
    @{ Server = "SRV-01"; Environment = "Production" }
    @{ Server = "";       Environment = "Test" }
    @{ Server = "SRV-03"; Environment = "" }
    @{ Server = "SRV-04"; Environment = "Staging" }
)

foreach ($row in $Records) {
    $Server = $row.Server
    $Environment = $row.Environment

    if ([string]::IsNullOrWhiteSpace($Server)) {
        Write-Warning "Skipping record: Server is missing."
        continue
    }

    if ([string]::IsNullOrWhiteSpace($Environment)) {
        $Environment = "Test"
    }

    if ($Environment -notin @("Production", "Test", "Development")) {
        Write-Warning "Skipping server '$Server': invalid environment '$Environment'."
        continue
    }

    Get-ServerReport -Server $Server -Environment $Environment
}
```

**Reading the loop as a pipeline of decisions** — each `if` answers one question, in the order that costs least:

1. *Is the record usable at all?* Blank server → warn, skip. Nothing downstream can fix this.
2. *Is the optional field absent?* Blank environment → apply the approved default. This is the §3.3 normalisation that the parameter's own default cannot do.
3. *Is the supplied value permitted?* Not in the allowed set → warn, skip. Reject rather than substitute (Q6).
4. *Call the function.* By this point every argument is known good, so no `try/catch` is needed — and notably there isn't one.

**On the absence of a `try/catch` in the final loop.** The pre-validation makes the function's guard unreachable for these four records, so the loop runs clean. That is a legitimate design — but it means the loop has **no safety net** if the function later grows a new failure mode, or if a fifth record form appears that the three guards don't anticipate. For a committed deliverable, wrapping the call is cheap insurance:

```powershell
    try {
        Get-ServerReport -Server $Server -Environment $Environment -ErrorAction Stop
    }
    catch {
        Write-Warning "Unexpected failure for '$Server': $($_.Exception.Message)"
        continue
    }
```

Carried forward to §14.1 as an improvement, not presented as something the session ran.

### 7.5 The key correction made during debugging (Observed)

The call initially omitted `-Server`:

```powershell
Get-ServerReport -Environment $Environment
```

This caused the function's guard to throw:

```text
Server name cannot be empty or whitespace.
```

The corrected call:

```powershell
Get-ServerReport -Server $Server -Environment $Environment
```

**Why the error message was exactly right, and why it still took a moment to read.** With `Mandatory` removed, an omitted `[string]$Server` is `""` — not `$null`, and not a binding error. `[ValidateNotNullOrEmpty()]` **never ran**, because validation attributes only execute on *bound* values and this parameter was never bound. So the only thing standing between the omitted argument and a false `Status = "Success"` was the internal guard, which fired and said so.

This is the most instructive moment in the challenge: the guard that looked like belt-and-braces duplication of `[ValidateNotNullOrEmpty()]` turned out to be the **only** check covering the omitted case. The attribute and the guard are not redundant — they cover different events:

| Event | `[ValidateNotNullOrEmpty()]` | The `IsNullOrWhiteSpace` guard |
|---|---|---|
| `-Server ""` | **rejects** | would catch (never reached) |
| `-Server "   "` | accepts | **catches** |
| `-Server` omitted | **never runs** | **catches** |

**The one thing this episode does not justify:** keeping the guard as a substitute for getting the call right. The guard caught a bug in the *caller*. It should be a backstop that never fires in correct code, not a routine part of control flow.

### 7.6 Actual final challenge output (Observed)

```text
WARNING: Skipping record: Server is missing.
WARNING: Skipping server 'SRV-04': invalid environment 'Staging'.
Server Environment Status
------ ----------- ------
SRV-01 Production  Success
SRV-03 Test        Success
```

**Reading it against the four inputs:**

| # | Input | Expected behaviour | Observed result |
|---|---|---|---|
| 1 | `SRV-01`, `Production` | Process successfully | **Passed** — row in output, `Production` preserved |
| 2 | Empty server, `Test` | Warn and skip | **Passed** — first warning, no output row |
| 3 | `SRV-03`, empty environment | Use default `Test` | **Passed** — row shows `Test` |
| 4 | `SRV-04`, `Staging` | Warn and skip | **Passed** — second warning, no output row |

Four cases, four passes, and the output confirms each independently:

- **Row 3 is the strongest evidence in the whole document.** `SRV-03` appears with `Environment = Test` even though its input was `""`. That proves the *loop's* normalisation ran — because as §3.3 establishes, passing `-Environment ""` would have hit `ValidateSet` and been rejected. The parameter's own `= "Test"` default could not have produced this row. The normalisation step is load-bearing, and the output proves it.
- **The two warnings precede the table** because PowerShell renders the accumulated success-stream output as one table at the end, while warnings go to the warning stream as they occur. The ordering is a stream artefact, not the execution order. Reading the warnings as "both skips happened before any processing" would be wrong — `SRV-04` was evaluated after `SRV-03` succeeded.
- **The batch completed.** Two bad records, zero aborts, two good rows out.

### 7.7 The environment fallback is a policy decision

Defaulting a blank environment to `Test` is an **intentional policy decision in this challenge**, not a technical necessity. In a real production workflow, a missing environment should default to `Test` **only if that behaviour has been explicitly approved.**

The reasoning matters more than the rule. Three options for a blank optional field:

| Option | When it is right | Risk |
|---|---|---|
| Skip the record | The field is genuinely required and "optional" is a schema error | Records are silently not processed; needs a visible skip report |
| Default to the **least** privileged value (`Test`) | A sensible, approved default exists and under-provisioning is recoverable | Work may land in the wrong place and need redoing |
| Default to the **most** privileged value (`Production`) | **Essentially never** | A data-quality problem becomes a production change nobody requested |

`Test` is defensible precisely because it is the *least* consequential of the three environments. The same code defaulting to `Production` would be the Q6 anti-pattern. The direction of the default is the control — which is why "we default blanks to X" belongs in a comment with the name of whoever approved it, not buried in a loop.

### 7.8 Dot-sourcing and running the script

Commands used during the session:

```powershell
Get-Command Get-ServerReport
```

```powershell
. ./Day10_Challenge.ps1
```

Variants also encountered:

```powershell
. ./Day_10.ps1
. ./Day10_challenge.ps1
```

**The points established:**

- Dot-sourcing loads function definitions into the **current** PowerShell session; a normally-invoked script runs in a child scope and its functions disappear with it.
- A **stale function definition** can remain loaded until the script is reloaded or the function is redefined. Editing a file changes nothing in a running session.
- `Get-Command` confirms that a function **exists**; it does not prove the loaded definition is the newest version.
- `(Get-Command Get-BackupReport).Definition` was used during the session to inspect an older definition — the diagnostic that resolved the Q021 confusion.
- **Use one consistent filename** for the final repository deliverable, and make sure it matches the file you execute. macOS is case-insensitive and will forgive `Day10_challenge.ps1`; Git and Linux CI will not.

---

## 8. Proposed additional test matrix

**This section is a plan, not evidence.** Every row marked "No" under execution evidence has **not** been run — it is proposed for the next session. Only the rows whose output appears in §7.6 and §5 (Level 1, Level 15) carry recorded evidence.

| # | Test case | Input | Expected behaviour | Execution evidence available | Notes |
|---|---|---|---|---|---|
| 1 | Valid positional call | `Get-ServerReport "SRV-01" "Production"` | Object with `Server=SRV-01`, `Environment=Production`, `Status=Success` | **No** | The challenge brief's central claim. Never actually tested positionally — all recorded calls were named. **Highest priority.** |
| 2 | Valid named call | `-Server "SRV-01" -Environment "Production"` | Same object as #1 | **Yes** — §7.6 row 1 | Confirmed |
| 3 | Environment omitted | `Get-ServerReport -Server "SRV-01"` | Defaults to `Test` | **No** | §7.6 row 3 proves the *loop's* normalisation, not the *parameter's* default. Different mechanism — test separately. |
| 4 | Invalid environment | `-Server "SRV-01" -Environment "Staging"` | `ValidateSet` rejects at bind time | **Partial** — Q023 §4.3 shows this for `Get-TargetFunction` | Confirmed for the aliased function; the loop's `-notin` guard intercepts it before the call in the challenge |
| 5 | Empty server | `-Server ""` | `[ValidateNotNullOrEmpty()]` rejects | **No** | Attribute path untested. §7.6 row 2 tested the *loop guard* instead. |
| 6 | Whitespace-only server | `-Server "   "` | Binds, then the internal guard throws | **No** | The gap `[ValidateNotNullOrEmpty()]` cannot cover. Proves why the guard exists. **High priority.** |
| 7 | Server argument omitted | `Get-ServerReport -Environment "Test"` | Internal guard throws | **Yes** — §7.5 | Confirmed: `Server name cannot be empty or whitespace.` |
| 8 | Empty environment supplied explicitly | `-Server "SRV-01" -Environment ""` | `ValidateSet` rejects; default does **not** apply | **No** | The §3.3 claim, untested directly. **High priority** — it is the most counter-intuitive behaviour of the day. |
| 9 | Function returns `Status = "Failed"` without throwing | A variant that can actually fail | `if` is false, `catch` not entered, only `Script completed` | **No** | Cannot be tested with the current function — `Status` is hard-coded `"Success"`. Needs a variant that derives status. |
| 10 | Returned object missing `Status` | `[PSCustomObject]@{ Server="SRV-01"; Environment="Production" }` | `-ne "Failed"` is true → false success message | **No** | Level 8, reasoned not run |
| 11 | Returned object with `Status = ""` | `[PSCustomObject]@{ Server="SRV-01"; Status="" }` | Success message prints; value is `""`, not `$null` | **No** | Level 9 — worth running specifically to *see* that it is `""`, since that was the recorded mistake |
| 12 | Exception raised inside `try` | `throw "Simulated failure"` after a successful call | `catch` runs despite the call succeeding | **No** | Level 3 — reconstructed example, no recorded answer or run |
| 13 | Exception rethrown inside `catch` | `throw "Second error"` inside `catch` | New unhandled error; statement after `try/catch` skipped | **No** | Level 14, reasoned not run |
| 14 | Loop continues after a failed record | `continue` in the `catch` | All three servers attempted; final line prints | **No** | The counterpart to #15. Running both back to back is the clearest demonstration of the choice. |
| 15 | Loop terminates after a rethrown exception | bare `throw` in the `catch` | Stops at `SRV-02`; `SRV-03` and the final line never run | **Yes** — Level 15 | Confirmed, with the caveat that the trailing `All servers processed` was a separately typed command |

**Priority order for the next session,** given that #1 tests the challenge's own premise and #6, #8, #9 test the three behaviours most likely to be misremembered:

```powershell
# 1. The challenge's central claim — never actually tested
Get-ServerReport "SRV-01" "Production"

# 6. Whitespace binds, then the guard throws
Get-ServerReport -Server "   "

# 8. Explicit empty does NOT get the default
Get-ServerReport -Server "SRV-01" -Environment ""

# 3. Omitted DOES get the default (the parameter's own, not the loop's)
Get-ServerReport -Server "SRV-01"

# 9. Needs a function whose status is derived, not hard-coded
function Get-ServerReportV2 {
    param([string]$Server, [string]$Environment = "Test")
    $ok = Test-Connection -TargetName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Server      = $Server
        Environment = $Environment
        Status      = if ($ok) { "Success" } else { "Failed" }
    }
}
```

Record the actual output of each next to its row.

---

## 9. Mistakes, confusions, and corrections

| # | Mistake or confusion | Why it was wrong | Correct understanding | Corrected code or practice |
|---|---|---|---|---|
| 1 | Assuming `Write-Warning` raises an exception | `Write-Warning` writes to the warning stream. It does not raise, does not stop the block, and does not reach `catch`. | Only a terminating error reaches `catch`. `Write-Warning` is for reporting a condition while continuing. | Use `throw` when `catch` must run; `Write-Warning` + `continue` when the record is skippable. |
| 2 | Confusing warning output with a terminating error | Both appear as attention-grabbing text in a terminal, so they look equivalent on screen. | Different streams, different control flow. A warning never alters execution. | `Write-Warning` → log and continue. `throw` → stop and unwind. Pick by intent, not by how loud it looks. |
| 3 | Assuming `catch` always runs when a status is `"Failed"` | A returned status is data on the output stream; `catch` only sees terminating errors. | The runtime never inspects the content of a return value. | `if ($result.Status -eq "Success") { ... } else { throw "... Status: $($result.Status)" }` |
| 4 | Forgetting that a returned failure status is data, not an exception | A function returning `Status = "Failed"` ran to completion successfully. | Bad result ≠ failed call. Converting one to the other is an explicit act. | Test the status with an `if`; `throw` or warn deliberately. |
| 5 | Assuming `-ne "Failed"` proves success | It is a one-entry blocklist. `Pending`, `""`, `$null`, and a missing property all satisfy it. | Allowlist the required state. New statuses should default to not-success. | `if ($result.Status -eq "Success")` |
| 6 | Confusing a missing property (`$null`) with an empty string (`""`) | Three distinct states — missing, empty, valued — behave differently under `$null -eq`, existence checks, and `IsNullOrEmpty`. | Check existence with `PSObject.Properties["Status"]`, blankness with `IsNullOrWhiteSpace`. | See the three-branch pattern in Level 9. |
| 7 | Omitting `throw` when the goal is to trigger `catch` | A bare string is an expression statement; its value goes to the success stream. | Emitting a string is data output, not error signalling. | `else { throw "Server processing failed. Status: $($result.Status)" }` |
| 8 | Assuming `continue` is required every time an error is caught | A `catch` that finishes normally has handled the error; `foreach` advances on its own. | `continue` skips the *remainder of the current iteration*. | Use `continue` when statements follow the `try/catch` that must not run for a failed record. |
| 9 | Assuming code after `try/catch` is skipped when an exception is handled | Handling an error resumes normal execution at the next statement. | A handled error does not terminate the script. | Put the success message **inside** `try`, after the call, so reachability guarantees it. |
| 10 | Misunderstanding the effect of a `throw` inside `catch` | A `catch` cannot catch its own `throw`; the new error needs an outer frame. | `throw` in a `catch` raises a new unhandled error unless nested in another `try`. | Nest a `try/catch` if the rethrow must be handled locally. |
| 11 | Forgetting that a bare `throw` rethrows the current exception | Bare `throw` preserves the original exception, message, and position; `throw "msg"` replaces all three. | Level 15's traceback pointed at line 4 — the *original* throw — proving preservation. | Bare `throw` to escalate after logging; `throw "msg"` only for a genuinely new failure. |
| 12 | Forgetting that `continue` must be inside a loop | `continue` is loop control; outside a loop construct it is an error. | Valid in `foreach`/`for`/`while`/`do`/`switch` — and in `switch` its meaning differs from `break`. | Keep the guard-and-skip pattern inside the enclosing `foreach`. |
| 13 | Assuming the function's default environment replaces an explicitly supplied empty string | `""` is a *bound* value, so the default is skipped and `ValidateSet` rejects it. | Default = absent argument. Validator = supplied argument. Disjoint. | Normalise in the caller: `if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "Test" }` |
| 14 | Omitting `-Server` from the final function call | `Get-ServerReport -Environment $Environment` left `$Server` unbound, so it was `""`. | An unbound `[string]` is `""`, and `[ValidateNotNullOrEmpty()]` never runs on an unbound parameter. | `Get-ServerReport -Server $Server -Environment $Environment` |
| 15 | Assuming a mandatory parameter is always suitable for unattended automation | An omitted mandatory argument prompts; a scheduled host cannot answer, so the job hangs. | `Mandatory` is for interactive use. Unattended code validates records before calling. | Drop `Mandatory`, keep an internal guard, pre-validate in the loop. |
| 16 | Using `$row.Server` in a warning string without `$()` | Simple expansion stops at the variable name; `.Server` is appended as literal text. | `$( )` evaluates a whole expression inside a double-quoted string. | `Write-Warning "Skipping record: Server is missing. Environment='$($row.Environment)'."` |
| 17 | Forgetting to dot-source the latest function definition after changing a script | A session holds the definition it loaded. Editing the file changes nothing until reload. | Functions live in `Function:\`, not in the file. | `(Get-Command X).Definition` to check; `. ./Day10_Challenge.ps1` to reload; fresh `pwsh` to be certain. |
| 18 | Confusing a separate terminal command with code reached by the original script | Interactive scrollback interleaves script output, typed commands, and errors with nothing distinguishing them. | Output after an error does not prove the script reached it. | Verify with `pwsh -NoProfile -File ./script.ps1`. |
| 19 | Treating `"Finished processing"` as proof of success when it appears outside the `try/catch` | The statement is a sibling of the `try/catch`; it runs whether or not the call failed. | A success message must be structurally unreachable on failure. | Move it inside `try`, immediately after the call. |
| 20 | Failing to distinguish parameter validation errors from errors inside the function body | A `ValidateSet` rejection happens at bind time — the body never ran, so there is nothing to clean up. | Binding/validation errors are terminating and catchable; `-ErrorAction` is irrelevant to them. | Catch both, but read the message: `Cannot validate argument on parameter` means the body never executed. |

### 9.1 Pattern analysis

Grouping the twenty by root cause is more useful than the list, because it shows where the revision effort should go:

| Root cause | Entries | Count |
|---|---|---|
| **Confusing data with control flow** — a bad value is not an error | 1, 2, 3, 4, 7 | **5** |
| **Imprecise truth tests** — testing the wrong thing, or testing nothing | 5, 6, 19 | 3 |
| **Control-flow mechanics** — what `continue`, `throw`, and handled errors actually do | 8, 9, 10, 11, 12 | **5** |
| **Binding and validation semantics** — when attributes and defaults apply | 13, 14, 15, 20 | 4 |
| **Environment and evidence discipline** — trusting the terminal, trusting the file | 17, 18 | 2 |
| **String interpolation** | 16 | 1 |

Two clusters of five dominate, and they are related: *"a returned `Failed` doesn't reach `catch`"* (the first cluster) and *"a handled error doesn't stop anything"* (the third) are both failures to see that **PowerShell's error machinery and your function's return value are entirely separate systems.** Internalise that one sentence and ten of the twenty entries stop being possible.

**The single highest-value correction of Day 10** is entries 3, 4, and 7 together — the Level 11 → Level 12 pair. The misconception appeared as a wrong *prediction* at Level 11, was explained, and then reappeared as wrong *code* at Level 12. A misconception that survives its own correction is the one to drill, which is why it heads the revision list in §13.1.
---

## 10. Day 10 Complete Q&A Transcript

**What this section is.** A single consolidated record of every question recoverable from the Day 10 session, with my original answer as the record preserves it, the evaluation, the corrected answer, and the explanation. It is the audit view of the day; §3 to §9 hold the depth, and each entry cross-references them.

**What this section is not.** It is **not a verbatim transcript.** The session record preserves my answers as paraphrase for the debugging levels, as code for two of them, and not at all for the ten interview questions. Every entry is labelled accordingly:

| Label | Meaning |
|---|---|
| **Paraphrased in record** | The record summarises what I answered. Not a quotation. |
| **Preserved as code** | My answer survives as the actual code I wrote. This *is* original. |
| **Not recorded** | No answer is preserved. Nothing has been invented to fill the gap. |
| **Reconstructed question** | The question's wording was not preserved; it has been reconstructed from the recorded concept and is marked as such. |

**Recoverable totals:** 15 debugging levels, 10 interview questions, 6 practice-exercise entries, 5 daily-challenge questions, 11 follow-up topic threads — **47 entries**.

### 10.1 Debugging levels 1–15

| # | Question | My original answer | Source label | Evaluation | Correct answer | Explanation |
|---|---|---|---|---|---|---|
| L1 | Mandatory function called in a loop over `@("SRV-01", "", "SRV-03")` — what goes wrong and how should the loop handle it? | The loop should check for an empty or whitespace-only server name before calling the function. | Paraphrased in record | **Correct** | Guard with `[string]::IsNullOrWhiteSpace($Server)` + `continue` before the call. | An explicitly supplied `""` does **not** prompt — it raises a catchable binding error. The guard is still right, for message quality and because whitespace-only binds successfully and nothing else catches it. See §5 L1. |
| L2 | Valid server, environment `Staging`, against `ValidateSet` — where does it fail, can it be caught, how does the loop continue? | Parameter validation fails before the function body executes; `catch` can handle it if the call is inside `try`; `continue` moves to the next record. | Paraphrased in record | **Correct — all three parts** | Exactly as answered. | `ValidateSet` runs during binding, before the body. The failure is terminating for the statement, so an enclosing `catch` sees it. `-ErrorAction Stop` is irrelevant. Proven by the Q023 output in §4.3. |
| L3 | A function call succeeds and a later statement in the same `try` throws — does `catch` run? | **Not recorded** | Not recorded | — | Yes. `try` guards a block, not a call. | Any terminating error in the block transfers to `catch`, however much already succeeded. The function's output is already on the stream — a catch rolls nothing back. See §5 L3 (reconstructed example). |
| L4 | Without `continue` in the `catch`, does the loop move to the next record? | My initial instinct was that `continue` must be added to move to the next iteration. | Paraphrased in record | **Partially correct** | Not required. A `catch` that finishes normally has handled the error, and `foreach` advances on its own. | `continue` skips the *remainder of the current iteration*. It matters only when statements follow the `try/catch` — which is Level 5's bug. Good habit, wrong mechanism. |
| L5 | Can `Finished processing ...` print for a record whose call failed validation? | Yes — the message can still appear, because the output statement is outside the `try/catch`. | Paraphrased in record | **Correct** | Yes; move the message inside `try`, after the call. | The statement is a sibling of the `try/catch`, so it runs once the error is handled. Reachability — not wording — is what makes a success message honest. The pivot of the whole sequence. |
| L6 | How do you check whether the function reported success? | Store the result in a variable. | Paraphrased in record | **Partially correct** | `$result = ...`, then `if ($result.Status -eq "Success")`, plus an existence check on the property. | Right first move, stops short of the check. Also: this `Get-ServerReport` hard-codes `Status = "Success"`, so the check can never fail against it — the pattern is being practised, not tested. |
| L7 | Difference between `$result.Status -eq "Failed"` and `-ne "Failed"` — does the second prove success? | The first checks equality; the second checks inequality. | Paraphrased in record | **Correct** on mechanics | `-ne "Failed"` does not prove success. | It is a one-entry blocklist: `Pending`, `Timeout`, `""`, `$null`, and a missing property all satisfy it. Allowlist with `-eq "Success"` so new statuses default to not-success. |
| L8 | `PSCustomObject` with no `Status`, tested `-ne "Failed"` — does the success message print? | Yes — because the missing property evaluates to `$null`, which is not equal to `"Failed"`. | Paraphrased in record | **Correct, including the reason** | Prints. Check existence first: `$null -eq $result.PSObject.Properties["Status"]`. | A missing property returns `$null` rather than erroring. Three-branch pattern: missing → warn, `-eq "Success"` → success, everything else → warn. `Set-StrictMode -Version 3.0` turns this class of bug loud. |
| L9 | `Status = ""`, tested `-ne "Failed"` — does it print, and what exactly is the value? | The success message prints — but I initially described the value as `$null`. | Paraphrased in record | **Partially correct** | Prints. The property **exists** and holds `""` — a third state, distinct from missing. | Harmless here (both go the same way) but fatal once code tests `$null -eq $result.Status`, which is `$false` for `""`. Needs existence **and** `IsNullOrWhiteSpace`. |
| L10 | Choose the success condition: A `-ne "Failed"` / B `-eq "Success"` / C `if ($result.Status)` | **B** — the code should check exactly what is required rather than merely excluding an unwanted value. | Paraphrased in record | **Correct**, with correct reasoning | B. | A misreports four of six states. **C is actively inverted**: a non-empty string is truthy, so `"Failed"` reports success. B is correct but still does not distinguish the four not-success states from each other. |
| L11 | Function returns `Status = "Failed"` without throwing, inside `try/catch` — what prints? | I initially said that `catch` runs. | Paraphrased in record | **Incorrect** | Only `Script completed`. No success message, no warning, no error. | `catch` responds to terminating errors, never to return values. A returned status is **data**; an exception is **control flow**. An `if` with no `else` inside a `try/catch` is a silent-failure generator. **The central misconception of Day 10.** |
| L12 | Will an `else` branch containing a bare string cause `catch` to run? | `else { "Server processing failed" }` | **Preserved as code** | **Incorrect** | `else { throw "Server processing failed. Status: $($result.Status)" }` | A bare string is an expression statement — its value goes to the **success** stream. No exception, `catch` not entered, and the sentence pollutes the function's data output where no log filter watching for warnings will see it. Same misconception as L11, now in code. |
| L13 | Same scenario with `throw` added inside `try`, `Status = "Failed"` — what prints? | The catch warning and `Script completed` appear; the success message is skipped. | Paraphrased in record | **Correct** | `WARNING: Error: Server processing failed` then `Script completed`. | `throw` makes the rest of the `try` unreachable and routes to `catch`; a handled error does not stop the script. One keyword converts L11's silence into a reported failure. |
| L14 | `throw "Second error"` inside `catch` — does `Script completed` print? | No — the second error prevents it from being printed. | Paraphrased in record | **Correct** | `WARNING: Caught: First error` then the unhandled `Second error`. | A `catch` cannot catch its own `throw`. With no outer frame the new error terminates the script, so the statement after the `try/catch` never runs. |
| L15 | Bare `throw` in a `catch` inside a `foreach` — what prints, and is `SRV-03` processed? | The loop stops at `SRV-02` and `SRV-03` is not processed. I initially missed that the catch warning **is** displayed, because `Write-Warning` is explicitly present. | Paraphrased in record | **Partially correct** | `Success: SRV-01`, `WARNING: Failed: SRV-02`, then the unhandled exception. `SRV-03` and the final line never run. | The catch runs top to bottom; the `throw` is its last statement, so the warning precedes the teardown. Bare `throw` preserves the original exception **and its position** — the traceback points at line 4, the original throw. |

**Debugging score:** 8 correct (L1, L2, L5, L7, L8, L10, L13, L14) · 4 partially correct (L4, L6, L9, L15) · 2 incorrect (L11, L12) · 1 not recorded (L3).

### 10.2 The L11 → L12 sequence, recorded explicitly

This pair is the only place in Day 10 where a misconception **survived its own correction**, which is why it is called out separately rather than left as two table rows.

| Stage | What happened |
|---|---|
| **Level 11** | Asked what prints when a function returns `Status = "Failed"` without throwing. I answered that `catch` runs. **Wrong.** |
| **Correction given** | A returned status is data on the output stream; `catch` only sees terminating errors. The `if` is simply false and nothing is reported. |
| **Level 12** | Asked to make `catch` run for a failed status. I wrote `else { "Server processing failed" }` — a bare string, which raises nothing. **Wrong again, same root cause.** |
| **Correction given** | A bare string is an expression statement writing to the success stream. `throw` is what raises a terminating error. |
| **Level 13** | Same scenario with `throw` present. Answered **correctly** — the mechanism had landed once it was written out in code. |

The sequence is diagnostic: the understanding was not absent, it was **passive**. It transferred as soon as the code made the control flow explicit. The revision implication is in §13 — drill it by *writing* the else branch, not by re-reading the rule.

### 10.3 Interview questions 1–10

**Original answers: Not recorded.** The session record preserves the ten *concepts* covered in Day 10's interview practice. It does not preserve the questions as asked or my answers to them. Nothing has been invented. The questions below are **reconstructed from the recorded concepts**; the full model answers are in §6.

| # | Concept (recorded) | Reconstructed question | My original answer | Model answer summary |
|---|---|---|---|---|
| I1 | Parameter-binding order; positional vs named | A long-working positional call now assigns the wrong value, with no code change at the call site. First thing you check? | **Not recorded** | The signature. An inserted or reordered parameter shifts every positional caller; with compatible types nothing throws. Convert to named. §6 Q1 |
| I2 | Why mandatory parameters cause unattended prompts | A nightly job ran six hours and was killed, with no error logged. Where do you look? | **Not recorded** | A mandatory parameter with no argument; the host was asked to prompt and could not. No error because nothing errored — it waited. §6 Q2 |
| I3 | Why aliases are useful, when full names are preferable | Three teams call the same thing by different names. How do you handle it, and what goes in committed scripts? | **Not recorded** | `[Alias()]` for the console; canonical names in scripts. An alias is a convenience, not a contract. §6 Q3 |
| I4 | Why CSV headers need explicit mapping | CSV header is `Server`, parameter is `[Alias('Server')]$ComputerName`, and in a `foreach` it binds nothing. Why? | **Not recorded** | A direct call passes values, not objects — nothing matches property names. Needs `ValueFromPipelineByPropertyName` and a real pipeline, or explicit mapping. §6 Q4 |
| I5 | Defaults vs `ValidateSet` | A CSV row has a blank environment cell. Does the parameter's default apply? | **Not recorded** | No. `""` is a *supplied* value, so the default is skipped and `ValidateSet` rejects it. Normalise in the caller. §6 Q5 |
| I6 | Why invalid environment values must be rejected | A colleague suggests defaulting unrecognised environments to `Production` so the batch doesn't fail. Your position? | **Not recorded** | Reject and log. Substituting an unapproved value turns a data problem into an unrequested production change. §6 Q6 |
| I7 | Why an alias does not rename an output property | Caller used `-Server`; downstream `$result.Server` is empty. Why? | **Not recorded** | The output property name comes from what the function emits. The alias affects parameter binding only. §6 Q7 |
| I8 | Why `catch` does not handle every reported failure | `Status = 'Failed'`, call inside `try/catch`, catch never fires, log empty. Explain. | **Not recorded** | Returned status is data; `catch` sees terminating errors. Test with `if`, then warn or `throw`. §6 Q8 |
| I9 | How `try/catch`, `throw`, and `continue` interact | When `throw` in a catch and when `continue`? What does bare `throw` do differently? | **Not recorded** | `continue` for independent records; `throw` when failure is systemic. Bare `throw` preserves the original exception and its position. §6 Q9 |
| I10 | Debugging an end-to-end CSV workflow | Every row reports processed; the target system shows no changes. Walk through it. | **Not recorded** | Confirm the loaded definition, the data, the binding, then whether the success message is conditional on success. Usually the last. §6 Q10 |

### 10.4 Practice exercises Q021 – Q023

| Exercise | Question / task | My original work | Source label | Evaluation | Correction and explanation |
|---|---|---|---|---|---|
| **Q021** | Call a function positionally and by name; test mixed binding; identify silent data errors from wrong argument order. | **Not recorded** — no Q021 code or output is preserved in the record. | Not recorded | — | Positional binding fills remaining parameters in ascending `Position` after named binding. With compatible types, wrong order yields wrong data, not an error. §4.1 |
| **Q021 follow-up** | Why does `(Get-Command Get-BackupReport).Definition` show an older definition than the file? | Identified the stale definition by inspecting `.Definition`; fixed by re-dot-sourcing `. ./Day_10.ps1`. | **Observed** in record | **Correct — and the most practically useful find of the day** | A function is an object in `Function:\`, not a view of a file. Editing the `.ps1` changes nothing in a running session. `Get-Command` proves existence, not freshness. §4.1 |
| **Q022** | Mandatory parameters, `ValidateSet`, input pre-validation, `try/catch`, skipping invalid records, `continue`. | The guard-then-`try` pattern: `IsNullOrWhiteSpace` → `Write-Warning` → `continue`, then `try { ... -ErrorAction Stop } catch { ... continue }`. | Preserved as code | **Correct pattern** | `$Server`/`$Environment` must be initialised first, and `continue` must sit inside the enclosing loop. The guard reports data quality; the catch reports call failure. Two different messages for two different problems. §4.2 |
| **Q022 follow-up** | Why log an invalid record instead of assigning it an unrelated environment? | Recorded as a point established in the session: invalid records should be logged, not silently reassigned. | Paraphrased in record | **Correct** | Substituting an unrelated value converts a data-quality problem into an unrequested configuration change. Only skip, or default to an explicitly approved value. §4.2, §7.7 |
| **Q023** | Build an aliased function, map CSV fields explicitly, validate records, handle errors. | `Get-TargetFunction` with `[Alias("Server")][string]$ComputerName`, plus the explicit-mapping loop. | Preserved as code | **Correct**, with one defect in the warning string | The alias does not create a parameter, rename the output, or auto-map CSV headers in a direct call. Output column was `ComputerName`. §4.3 |
| **Q023 follow-up** | Why did the first warning print `'@{Server=; Environment=Test}'`? | Defect in my warning string — the whole row object was interpolated rather than the missing field. | **Observed** output | **Defect identified** | Simple expansion stops at the variable name. `"$row"` gives the object's string form; `"$row.Server"` gives that plus literal `.Server`; only `"$($row.Server)"` evaluates the property. Better still: name the field in prose and print a field that has a value. §4.3 |

### 10.5 Daily challenge questions

| # | Question | My original work | Source label | Evaluation | Correction and explanation |
|---|---|---|---|---|---|
| C1 | Design a signature that reads correctly when called positionally by someone who has never seen it. | `Position = 0` on `$Server`, `Position = 1` on `$Environment`. | Preserved as code | **Correct design** | Most significant noun first, qualifier second — `Get-ServerReport "SRV-01" "Production"` reads as a sentence. **Never actually tested positionally** (test matrix #1). |
| C2 | Make it prompt-free. | Initially `Mandatory = $true, Position = 0`; later removed `Mandatory`, keeping the internal `IsNullOrWhiteSpace` guard. | Preserved as code | **Correct resolution** | `Mandatory` prompts when the argument is omitted — disqualifying for unattended use. Removing it gives up the empty-string rejection, which is why the body guard is mandatory in its place. §7.2 |
| C3 | Why did `Get-ServerReport -Environment $Environment` throw `Server name cannot be empty or whitespace.`? | The call omitted `-Server`; corrected to `-Server $Server -Environment $Environment`. | **Observed** | **Correct fix** | An unbound `[string]` is `""`, and `[ValidateNotNullOrEmpty()]` **never runs** on an unbound parameter. The internal guard was the only check covering the omitted case — not redundant with the attribute. §7.5 |
| C4 | How does a blank environment end up as `Test` when `ValidateSet` would reject `""`? | The loop normalises: `if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "Test" }`. | Preserved as code | **Correct** | The parameter's own default cannot do this — `-Environment ""` is a *bound* value, so the default is skipped and the validator rejects it. Output row `SRV-03 / Test` is the proof that the loop's normalisation ran. §7.6 |
| C5 | What should happen to a record whose environment is `Staging`? | `if ($Environment -notin @("Production","Test","Development")) { Write-Warning ...; continue }` | Preserved as code | **Correct** | Reject and log; do not substitute. One maintenance hazard: the allowed list is now duplicated between the attribute and the loop. §13 has the single-source fix. |

### 10.6 Follow-up topic threads

These eleven threads ran through the session as follow-up questions rather than numbered exercises. The record preserves the **topics and their resolutions**, not the individual question wordings or my answers to each. Questions are therefore **reconstructed**; where no answer is preserved, that is stated.

| # | Topic | Reconstructed question | My original answer | Resolution |
|---|---|---|---|---|
| F1 | Parameter binding | In what order does PowerShell bind arguments? | **Not recorded** | Named first → remaining positionals by ascending `Position` → defaults → transformation then validation → body. §3.1 |
| F2 | `ValidateSet` | When does it run, and is its failure catchable? | **Answered at L2** — before the body; catchable inside `try` | Enforced during binding. Terminating for the statement, so an enclosing `catch` sees it. `-ErrorAction` is irrelevant. Observed in §4.3. |
| F3 | Mandatory parameters | What happens when a mandatory argument is omitted vs supplied empty? | **Not recorded** | Omitted → prompts. `$null` or `""` → catchable binding error. `"   "` → **binds**. Only the first hangs an unattended job. §3.2 |
| F4 | Defaults | Does a default apply when an invalid value is supplied? | **Partially — see mistake #13** | No. Default = absent argument; validator = supplied argument. Disjoint sets, no fallback path. §3.3 |
| F5 | Empty values | Are `$null`, `""`, and `"   "` interchangeable? | **Conflated `$null` and `""` at L9** | Three distinct states. Only `[string]::IsNullOrWhiteSpace()` covers all three; `[ValidateNotNullOrEmpty()]` accepts whitespace. §3.4 |
| F6 | `Write-Warning` | Does it raise an exception or reach `catch`? | **Not recorded** | No to both. Warning stream; no effect on control flow. It is for reporting while continuing. Mistakes #1, #2 |
| F7 | `throw` | What does it do that emitting a string does not? | **Answered wrongly at L12, then correctly at L13** | Raises a terminating error: stops the block, unwinds to the nearest `catch`, populates `$_`. A bare string goes to the success stream and is never seen. §5 L12 |
| F8 | `catch` | Does it run whenever something fails? | **Answered wrongly at L11** | Only for terminating errors. Never for a bad return value. The `if`-without-`else` inside a `try/catch` is where failures disappear. §5 L11 |
| F9 | `continue` | Is it required for a loop to advance after a caught error? | **Answered as "required" at L4** | No. A handled error resumes normal execution and `foreach` advances itself. `continue` skips the remainder of the current iteration. §5 L4 |
| F10 | Returned status values | Does `Status = "Failed"` mean the call failed? | **Answered wrongly at L11** | No — the call succeeded and returned a value describing a bad outcome. Converting that into a failure is an explicit act (`throw`) or a logged skip (`Write-Warning` + `continue`). §5 L11 |
| F11 | Missing properties | What does accessing a non-existent property return? | **Answered correctly at L8** | `$null`, not an error. So `-ne "Failed"` is true and a naive success message prints. Check `PSObject.Properties["Status"]`, or enable `Set-StrictMode -Version 3.0`. §5 L8 |

### 10.7 Transcript coverage summary

| Group | Entries | Verbatim originals | Paraphrased | Not recorded |
|---|---|---|---|---|
| Debugging levels | 15 | 1 (L12, as code) | 13 | 1 (L3) |
| Interview questions | 10 | 0 | 0 | **10** |
| Practice Q021–Q023 | 6 | 4 (as code/observed) | 1 | 1 (Q021 body) |
| Daily challenge | 5 | 5 (as code/observed) | 0 | 0 |
| Follow-up threads | 11 | 0 | 8 (via levels) | 3 |
| **Total** | **47** | **10** | **22** | **15** |

The largest gap is the interview block — ten questions whose wording and answers are entirely unpreserved. If those answers matter for revision, they need to be re-answered rather than reconstructed, and §6 provides the questions to re-answer against.

---

## 11. Technical accuracy reference

Each statement below is a precise formulation of something Day 10 tested. This is the section to re-read before an interview.

| # | Statement | Why it holds |
|---|---|---|
| 1 | **`Write-Warning` does not itself cause `catch` to run.** | It writes to the warning stream. It raises nothing, stops nothing, and is invisible to `catch`. |
| 2 | **`throw` raises a terminating error.** | It stops the current block immediately, unwinds to the nearest enclosing `catch`, and populates `$_` for the handler. |
| 3 | **A caught error does not necessarily terminate the script.** | A `catch` that finishes normally has handled the error; execution resumes at the next statement after the `try/catch`. |
| 4 | **An unhandled rethrown error can terminate the loop and the script.** | A `throw` inside `catch` is not handled by that same `catch`. Without an outer frame it propagates to the top. |
| 5 | **`continue` skips the remainder of the current loop iteration.** | It is loop control, not error handling. The loop would advance anyway; `continue` prevents the statements below from running. |
| 6 | **`ValidateSet` validates allowed values during parameter binding.** | It runs after the argument is matched to the parameter and before the body is entered — so the body never executes on rejection. |
| 7 | **A default value is used when the parameter is omitted, not when an invalid explicit value is supplied.** | A supplied argument means the parameter is bound, so the default is skipped and the validator runs on the supplied value. |
| 8 | **`Mandatory = $true` may cause interactive prompting if a value is omitted.** | The binder asks the host to prompt. A non-interactive host cannot answer, so the job hangs or fails on the prompt itself. |
| 9 | **`-ErrorAction Stop` promotes non-terminating errors to terminating ones but does not prevent mandatory-parameter prompts.** | The prompt happens during binding, before the command runs. There is no error for `-ErrorAction` to act on. |
| 10 | **`$null`, `""`, and whitespace-only strings are distinct cases.** | Only `IsNullOrWhiteSpace` covers all three. `[ValidateNotNullOrEmpty()]` rejects the first two and accepts the third. |
| 11 | **A property missing from a `PSCustomObject` evaluates to `$null` when accessed.** | No error is raised by default, so `-ne "Failed"` is true and a naive success message prints. `Set-StrictMode -Version 3.0` changes this to an error. |
| 12 | **`-ne "Failed"` is not a reliable success test.** | It is a one-entry blocklist on an open-ended value space: `Pending`, `""`, `$null`, and a missing property all pass it. |
| 13 | **Explicit field mapping is required between CSV columns and function parameters.** | A direct call passes values, not objects. Property-name binding needs `ValueFromPipelineByPropertyName` and an actual pipeline. |
| 14 | **Aliases change accepted parameter names, not returned object properties.** | The alias is a binder lookup key. Output property names come from what the function emits. |
| 15 | **Dot-sourcing loads functions into the current session.** | `. ./script.ps1` runs in the current scope; `./script.ps1` runs in a child scope that is discarded. |
| 16 | **A function that returns `Status = "Failed"` has not necessarily thrown an exception.** | It ran to completion and returned data. From the runtime's point of view that is a successful call. |
| 17 | **A validation attribute does not run on a parameter that was never bound.** | This is why the challenge's internal guard — not `[ValidateNotNullOrEmpty()]` — caught the omitted `-Server`. |
| 18 | **`if ($result.Status)` is a truthiness test, and `"Failed"` is truthy.** | A non-empty string evaluates to `$true`, so this reports success precisely when the operation failed. |
| 19 | **A bare `throw` preserves the original exception, message, and position; `throw "msg"` replaces all three.** | Level 15's traceback pointed at line 4 — the original `throw` — not at the rethrow in the `catch`. |
| 20 | **`Get-Command` proves a function exists; it does not prove the loaded definition matches the file.** | Use `(Get-Command X).Definition`, or run the script in a fresh `pwsh` process. |

---

## 12. Key takeaways

**1. The error machinery and your return value are two separate systems.** Ten of the twenty logged mistakes reduce to this one sentence. `catch` watches for terminating errors. Your `Status` field is data on the output stream. Nothing in the runtime inspects the content of a return value on your behalf — if a bad status should cause something to happen, you write the `if` that makes it happen.

**2. A success message must be structurally unable to lie.** Not carefully worded — *unreachable* on failure. Inside the `try`, after the call. Levels 5, 8, 9, 10, and 11 are five different ways of printing "success" when nothing succeeded, and every one of them is fixed by making the message reachable only on the success path.

**3. Allowlist the state you need.** `-eq "Success"`, never `-ne "Failed"`, and never `if ($result.Status)`. New statuses should default to not-success, because the set of ways something can go wrong grows without your involvement. Same principle as deny-by-default in an access model.

**4. Defaults and validators never overlap.** A default is for an **omitted** argument; a validator runs on a **supplied** one. `Import-Csv` never produces "omitted" — a blank cell is `""` — so normalising blanks is the caller's job. The `SRV-03 / Test` row in the challenge output is the proof.

**5. `Mandatory` is for humans.** It prompts on omission, which hangs unattended jobs; it rejects `$null` and `""`; it cheerfully accepts `"   "`. For batch work: drop it, keep an internal guard, and pre-validate every record in the loop.

**6. Validate in two layers, because they have different audiences.** The function throws, to protect its contract from a developer calling it by hand. The loop warns and skips, to keep a 5,000-row batch moving. Neither substitutes for the other, and the challenge's omitted-`-Server` bug proved it — the guard caught what the attribute structurally could not.

**7. Confirm you are running the code you are reading.** A function lives in `Function:\`, not in a file. `(Get-Command X).Definition` is a one-line test of the first hypothesis that should occur to you when behaviour contradicts the source. For verifying a deliverable, nothing beats `pwsh -NoProfile -File ./script.ps1`.

**8. Terminal scrollback is not a transcript of one execution.** Level 15's `All servers processed` was typed by hand after the loop had already died. The scrollback read like a script that failed and recovered. Interactive sessions interleave script output, typed commands, and errors with nothing to distinguish them — which is why evidence for a claim about a script comes from running the script, as a file, in a fresh process.

**9. A log line's job is to identify the record.** `Cannot bind argument to parameter 'Server'` describes PowerShell's internals. `Skipping record: Server is missing. Environment='Test'.` describes the data. At 02:00, across 5,000 rows, the difference between those two is the entire value of the log.

**10. The misconception that survives its own correction is the one to drill.** Level 11 got the explanation and Level 12 reproduced the error in code. Passive understanding transferred only when the control flow had to be written out. Re-reading a rule is not practice; writing the `else` branch is.

---

## 13. Final revision cheat sheet

### 13.1 Revision priorities, highest first

| Priority | What to drill | Why | How |
|---|---|---|---|
| **1** | A returned `Status = "Failed"` never reaches `catch` | Wrong at L11, **wrong again at L12** — the only misconception that survived correction | Write the `else` branch from memory, with `throw` and the status in the message. Then write the warn-and-skip variant. |
| **2** | Success tests: `-eq "Success"` only | L7 and L10 were right in principle; the six-state table is what makes it automatic | Reproduce the §5 L10 table from memory — all three options against all six states |
| **3** | `continue` is not what makes a loop advance | L4 instinct was defensively right, mechanically wrong | Explain out loud why L15's loop died and L4's did not |
| **4** | Defaults vs supplied-empty | Mistake #13; the most counter-intuitive behaviour of the day | Run test-matrix rows #3 and #8 back to back and read the two outcomes |
| **5** | Missing vs empty vs valued property | L9 conflated `$null` with `""` | Run test-matrix rows #10 and #11 and inspect `PSObject.Properties["Status"]` in both |
| **6** | `Mandatory` prompts on **omission** only | The L1 framing conflated omission with empty-string binding | Run `Get-ServerReport`, then `-Server ""`, then `-Server "   "`, and compare the three failures |

### 13.2 The patterns, in the form to memorise

```powershell
# 1. Guard, then call — the batch loop skeleton
foreach ($row in $Records) {
    if ([string]::IsNullOrWhiteSpace($row.Server)) {
        Write-Warning "Skipping record: Server is missing. Environment='$($row.Environment)'."
        continue
    }

    try {
        $result = Get-ServerReport -Server $row.Server -Environment $row.Environment -ErrorAction Stop
        Write-Output "Processed $($row.Server)"          # inside try = cannot lie
    }
    catch {
        Write-Warning "Failed '$($row.Server)': $($_.Exception.Message)"
        continue
    }
}

# 2. Status validation — three branches, success is one of them
if ($null -eq $result -or $null -eq $result.PSObject.Properties["Status"]) {
    Write-Warning "No status returned — check the function contract."
}
elseif ($result.Status -eq "Success") {
    Write-Output "Success"
}
else {
    Write-Warning "Status was '$($result.Status)'."
}

# 3. Prompt-free signature with a two-layer guard
function Get-ServerReport {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]          # rejects $null and "" when SUPPLIED
        [string]$Server,

        [Parameter(Position = 1)]
        [ValidateSet("Production", "Test", "Development")]
        [string]$Environment = "Test"       # applies only when OMITTED
    )

    if ([string]::IsNullOrWhiteSpace($Server)) {    # catches "   " AND omission
        throw "Server name cannot be empty or whitespace."
    }
    ...
}

# 4. Normalise before calling — the default cannot do this
if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "Test" }

# 5. Single source of truth for an allowed set (fixes the challenge's duplication)
$Allowed = (Get-Command Get-ServerReport).Parameters['Environment'].Attributes.
           Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues

if ($Environment -notin $Allowed) {
    Write-Warning "Skipping server '$Server': invalid environment '$Environment'. Allowed: $($Allowed -join ', ')"
    continue
}

# 6. Am I running the code I am reading?
(Get-Command Get-ServerReport).Definition
. ./Day10_Challenge.ps1
pwsh -NoProfile -File ./Day10_Challenge.ps1      # the only definitive answer
```

### 13.3 Decision tables

**Which signalling mechanism?**

| Want | Use | Stream | Reaches `catch`? | Stops the block? |
|---|---|---|---|---|
| Report and carry on | `Write-Warning` | Warning | No | No |
| Fail this record, keep the batch | `Write-Warning` + `continue` | Warning | No | Skips rest of iteration |
| Fail and let `catch` handle it | `throw "msg"` | Error | Yes | Yes |
| Escalate after local logging | bare `throw` | Error | Outer `catch` only | Yes |
| **Never, for a failure** | bare string / `Write-Output` | **Success** | No | No |

**Which "nothing" check?**

| Need to catch | Use |
|---|---|
| `$null` only | `$null -eq $x` — `$null` on the **left** |
| `$null` and `""` | `[string]::IsNullOrEmpty($x)` or `[ValidateNotNullOrEmpty()]` |
| `$null`, `""`, and `"   "` | `[string]::IsNullOrWhiteSpace($x)` |
| A property that does not exist | `$null -eq $obj.PSObject.Properties["Name"]` |
| All of the above, loudly | `Set-StrictMode -Version 3.0` at the top of the script |

**Loop failure policy:**

| `continue` in the catch | bare `throw` in the catch |
|---|---|
| Records are independent | Records are interdependent |
| A partial run is useful | A partial run leaves inconsistent state |
| You want a skip list | The first failure looks systemic |
| 500-server inventory sweep | Staged provisioning sequence |

---

## 14. Day 10 completion checklist

- [x] Q021 — positional and named binding, including the stale-definition diagnosis
- [x] Q022 — mandatory parameters, `ValidateSet`, pre-validation, `try/catch`, skip-and-continue
- [x] Q023 — aliases, explicit CSV field mapping, observed warning and result output
- [x] 10 scenario-based interview questions completed *(concepts recorded; questions and answers not preserved — see §10.3)*
- [x] 15 debugging questions completed
- [x] Daily challenge implemented and final output verified *(§7.6, four test cases, all four passed)*
- [ ] Final README reviewed for accuracy
- [ ] Git repository status checked
- [ ] Day 10 changes committed if appropriate

**The three unchecked items are unchecked deliberately.** No `git status` output and no commit result appear anywhere in the session record, so neither is claimed. The README review is for you to do, since you are the only person who can confirm the record matches what happened.

### 14.1 Carried forward to the next session

**Untested behaviour** — the test matrix in §8 has the full list; these four are the priorities:

```powershell
Get-ServerReport "SRV-01" "Production"          # #1  the challenge's own premise, never tested
Get-ServerReport -Server "   "                  # #6  whitespace binds, then the guard throws
Get-ServerReport -Server "SRV-01" -Environment ""   # #8  explicit empty ≠ default
Get-ServerReport -Server "SRV-01"               # #3  omitted DOES get the parameter's default
```

**Code improvements identified but not applied:**

1. Add a `try/catch` around the challenge loop's call (§7.4) — the pre-validation makes the guard unreachable today, which leaves no safety net for a future failure mode.
2. Replace the duplicated allowed-environment list with a single source read off the `ValidateSet` attribute (§13.2, pattern 5).
3. Rename the `foreach ($Server in $Servers)` loop variable in the Level 1 code so it does not shadow the parameter name (§5 L1).
4. Build a `Get-ServerReportV2` whose `Status` is **derived** rather than hard-coded, so the status-checking patterns can actually be tested (§8, row 9).
5. Consider `Set-StrictMode -Version 3.0` at the top of the challenge script, turning the missing-property class of bug into a loud failure (§5 L8).
6. Settle on `Day10_Challenge.ps1` as the one canonical filename and make every reference match it (§4.4).

**Documentation deliverable named in the challenge brief:** `about_Functions_Advanced_Parameters`. The record names it as the challenge's documentation target. Whether it was reviewed or written is **Not recorded**.

---

## 15. Git checkpoint

**Status: NOT COMMITTED / NOT PUSHED.** No Git command output appears in the session record. Nothing below has been executed — these are instructions only.

```powershell
# 1. What changed?
git status --short

# 2. Review before staging — read the diff, do not stage blind
git diff

# 3. Stage the Day 10 work
git add Day10_Challenge.ps1
git add Day10/README.md

# 4. Confirm what is staged
git diff --staged --stat

# 5. Commit
git commit -m "feat(day10): advanced parameters, validation, and error handling

- Prompt-free Get-ServerReport with positional design and two-layer validation
- External record validation with warn-and-skip batch policy
- 15 debugging exercises on try/catch/throw/continue and status checking
- Day 10 learning-history README with complete Q&A transcript"

# 6. Push
git push
```

**Before committing, verify:**

- [ ] The filename on disk is `Day10_Challenge.ps1` and every reference to it matches that casing exactly — macOS will forgive a mismatch, Git and Linux CI will not (§4.4)
- [ ] The README's `.md` extension is correct, so GitHub renders it
- [ ] `pwsh -NoProfile -File ./Day10_Challenge.ps1` reproduces the §7.6 output in a clean process
- [ ] Nothing in the committed script prompts — run it non-interactively to confirm

---

## 16. Further practice

Limited to Day 10 concepts. Each exercise targets something this document identifies as untested or passively understood.

**1. Close the Level 11/12 gap by writing it, not reading it.** Build a function whose `Status` is genuinely derived, then write three callers from memory: one that silently ignores a `Failed` status, one that warns and skips, one that throws. Run all three and compare the logs. This is revision priority #1 and the only exercise that addresses it properly.

**2. Prove the default/validator boundary empirically.** Run test-matrix rows #3 and #8 back to back. Record both outputs side by side in this README. The claim in §3.3 is the most counter-intuitive thing on Day 10 and currently rests on reasoning rather than evidence.

**3. Test the challenge's own premise.** `Get-ServerReport "SRV-01" "Production"` was never run. Run it, confirm the binding with `$PSBoundParameters` inside the function, then deliberately swap the arguments and observe that nothing errors — the silent-transposition failure from §3.1, seen first-hand.

**4. Build the three-state status harness.** Three objects — `Status` missing, `Status = ""`, `Status = "Success"` — through all three conditions from Level 10 (`-ne "Failed"`, `-eq "Success"`, truthiness). Nine results in a table. Then add `Set-StrictMode -Version 3.0` and see which of the nine change.

**5. Write the whitespace test.** `-Server "   "` against the current function. Confirm that `[ValidateNotNullOrEmpty()]` passes it and the internal guard catches it. This is the single clearest demonstration of why the two layers are not redundant.

**6. Convert the loop to a pipeline function.** Rewrite `Get-TargetFunction` with `ValueFromPipelineByPropertyName` and a `process` block, then pipe a CSV into it. Watch the `Server` column bind through the alias — and then remove the alias and watch it stop. That is the clearest possible demonstration of what an alias does and does not do.

**7. Make the loop's allowed-value list single-sourced.** Implement pattern 5 from §13.2, then add `"Staging"` to the `ValidateSet` and confirm the loop's guard accepts it without being edited. One source of truth, demonstrated.

**8. Deliberately reproduce the stale-definition trap.** Dot-source the script, edit the function in the file, call it, and watch the old body run. Then diagnose it with `(Get-Command ...).Definition`. Having made it happen on purpose once, you will recognise it instantly the next time it happens by accident.

**9. Write the batch-policy pair.** The same 500-record loop twice: once with `continue` in the catch, once with bare `throw`. Compare what each leaves behind. Then write one sentence for each explaining which kind of work it suits — that sentence is the §13.3 decision table in your own words.

---

*Day 10 of 90 — PowerShell Automation Engineer programme.*
*Built from the Day 10 session record. Evidence labelled per §0; no Git operation is claimed.*
