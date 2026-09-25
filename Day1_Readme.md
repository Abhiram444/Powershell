# Day 1 — Objects, Variables and Data Types

> **PowerShell Automation Engineer — 90 Day Plan**
> Week 1: PowerShell programming fundamentals · Environment: `[MAC]` · PowerShell 7.x

---

## Day 1 Objectives

| # | Objective | Status |
|---|-----------|--------|
| 1 | Explain why PowerShell moves **objects** rather than **text** | ✅ |
| 2 | Choose a data type **deliberately** instead of accepting whatever appears | ✅ |

The single idea behind today: **PowerShell is not a text-processing shell. It is an object-processing shell.** Everything else in this README is a consequence of that one fact.

---

## Table of Contents

1. [Variables](#1-variables)
2. [Explicitly Typed Variables](#2-explicitly-typed-variables)
3. [Type Coercion](#3-type-coercion)
4. [Objects vs Text](#4-objects-vs-text)
5. [The Object Model](#5-the-object-model)
6. [The PowerShell Pipeline](#6-the-powershell-pipeline)
7. [Get-Member](#7-get-member)
8. [Value Types vs Reference Types](#8-value-types-vs-reference-types)
9. [Reassignment vs Mutation](#9-reassignment-vs-mutation)
10. [Arrays and Reference Behaviour](#10-arrays-and-reference-behaviour)
11. [PSCustomObject](#11-pscustomobject)
12. [Functions and Reference Types](#12-functions-and-reference-types)
13. [Nested Object and Array Reference Behaviour](#13-nested-object-and-array-reference-behaviour)
14. [Coding Practice Completed](#14-coding-practice-completed)
15. [Interview Questions and Answers](#15-interview-questions-and-answers)
16. [Debugging Section](#16-debugging-section)
17. [Object Model — One Paragraph](#17-object-model--one-paragraph)
18. [Day 1 Cheat Sheet](#18-day-1-cheat-sheet)
19. [Day 1 Status](#19-day-1-status)
20. [Final Takeaway](#20-final-takeaway)

---

## 1. Variables

### What it is

A variable is a named container for a value. In PowerShell every variable name starts with `$`.

```powershell
$Age  = 25
$Name = "Teju"
```

PowerShell is **dynamically typed** by default. You never declare a type up front — PowerShell looks at the value you assigned and picks the type for you.

### Why it matters

Dynamic typing is convenient, but it means a variable's type is decided by whatever data happened to arrive. In automation, data arrives from CSV files, APIs and directories — and it is very often not the type you assumed. Every bug of the form *"why is my comparison wrong?"* starts here.

### How it works conceptually

```
$Age = 25
   │
   ├─ PowerShell inspects the value: 25
   ├─ Decides the best matching .NET type: System.Int32
   └─ Stores the value with that type attached
```

The type is attached to the **value**, not to the variable name. That is why an unconstrained variable can change type later:

```powershell
$Value = 25          # System.Int32
$Value.GetType().Name

$Value = "hello"     # now System.String — perfectly legal
$Value.GetType().Name
```

### Example and what it means

```powershell
$Age = 25
$Age.GetType().FullName     # System.Int32

$Name = "Teju"
$Name.GetType().FullName    # System.String
```

**Behaviour:** an unconstrained variable holds whatever you last assigned to it, with whatever type that value has. Nothing stops it changing.

### Interview-ready answer

> "PowerShell variables are dynamically typed by default. When you assign a value, PowerShell works out the underlying .NET type from the value itself and attaches it. The variable name is just a label, so if I assign a string to a variable that previously held an integer, that's allowed. That flexibility is convenient interactively, but in automation I usually constrain the type explicitly so bad input fails immediately rather than later."

---

## 2. Explicitly Typed Variables

### What it is

You can constrain a variable to a type by putting the type in square brackets before the variable name.

```powershell
[int]$Age        = 25
[string]$Name    = "Teju"
[bool]$IsActive  = $true
[datetime]$Start = "2026-09-24"
[double]$Rate    = 12.5
```

### Why it matters

A type constraint is your **first line of validation**. It is enforced by the language, before any of your own logic runs. It costs one word and it catches an entire class of bug.

### How it works conceptually

The constraint is attached to the **variable**, and it is permanent for the life of that variable.

```
[int]$Age = "25"
        │
        ├─ PowerShell sees the constraint: must be Int32
        ├─ Value supplied is a String: "25"
        ├─ Attempts a conversion String → Int32
        ├─ Conversion succeeds → stores 25 as Int32
        └─ Constraint stays attached: future assignments are also converted or rejected
```

This is the point people usually miss:

> **Explicit typing does not mean the value you assign must already be that exact type.**
> It means the value must be **convertible** to that type. PowerShell will attempt the conversion for you.

### Example and what it means

```powershell
[int]$Age = 25        # ✅ already an Int32 — stored directly
[int]$Age = "25"      # ✅ String "25" is convertible to 25 — conversion succeeds
[int]$Age = "hello"   # ❌ "hello" cannot be converted to a number — error
```

The third line produces:

```
Cannot convert value "hello" to type "System.Int32".
Error: "The input string 'hello' was not in a correct format."
```

| Line | Why |
|------|-----|
| `[int]$Age = 25` | Types already match. No conversion needed. |
| `[int]$Age = "25"` | **Compatible conversion.** The string contains a valid number, so PowerShell converts it. |
| `[int]$Age = "hello"` | **Incompatible.** There is no sensible numeric meaning for `"hello"`, so the conversion fails and the assignment throws. |

The constraint also persists:

```powershell
[int]$Age = 25
$Age = "hello"        # ❌ still fails — the [int] constraint is still on the variable
```

### Interview-ready answer: *"How does explicit typing change variable behaviour?"*

> "Explicit typing attaches a permanent type constraint to the variable rather than just to the current value. It doesn't require the value I assign to already be that type — it requires the value to be convertible to it. So `[int]$Age = '25'` works because PowerShell converts the string to an integer, but `[int]$Age = 'hello'` fails because there's no valid conversion. The practical benefit is that bad input fails at the moment of assignment with a clear error, instead of flowing through my code and producing a wrong result three functions later."

---

## 3. Type Coercion

### What it is

**Type coercion** is PowerShell automatically converting a value from one type to another so an operation can proceed.

### Why it matters

Coercion is helpful right up until it is invisible. PowerShell will quietly convert things for you, and the result can be correct-looking and wrong. Understanding coercion is how you stop guessing at bugs.

### How it works conceptually

```
Operation requested
        │
        ├─ Are the types already compatible? ──→ yes ──→ perform operation
        │
        └─ no ──→ can the value be converted? ──→ yes ──→ convert, then perform
                                               └─ no  ──→ throw a conversion error
```

### Example and what it means

```powershell
[int]$Age = "25"
$Age.GetType().Name     # Int32  — it is now genuinely a number
$Age + 5                # 30
```

Failed conversion:

```powershell
[int]$Age = "hello"     # ❌ throws
```

### Why a value that looks like a number can still be a string

This is the most important practical point of the whole section.

```powershell
$a = "25"       # String — it only looks numeric
$b = 25         # Int32

$a.GetType().Name   # String
$b.GetType().Name   # Int32
```

Where this bites you:

```powershell
$a = "25"
$a + 5          # 255   ← string concatenation, NOT addition
$b = 25
$b + 5          # 30    ← arithmetic
```

PowerShell decides the operation based on the **left-hand operand's type**. A string on the left means `+` is concatenation. This is exactly what happens when you read numbers from a CSV — `Import-Csv` returns **every value as a string**.

Comparisons behave the same way:

```powershell
"10" -gt 9      # False  ← string comparison: "10" sorts before "9"
10 -gt 9        # True   ← numeric comparison
```

`"10" -gt 9` is False because the right side is coerced to a string to match the left, and character by character `"1"` comes before `"9"`.

### How to investigate types

```powershell
$value.GetType()            # the full type information
$value.GetType().Name       # just the short name, e.g. String
$value | Get-Member         # the type plus every property and method
```

### Interview-ready answer: *"What is type coercion?"*

> "Type coercion is PowerShell automatically converting a value to a different type so an operation can go ahead. It's usually helpful — `[int]$x = '25'` converts cleanly. The risk is that it's silent. If a value is a string that looks like a number, `'25' + 5` gives you `255` because the left operand is a string, so `+` means concatenation. Comparisons have the same trap: `'10' -gt 9` is False. This matters constantly with CSV data, because `Import-Csv` returns everything as strings. My habit is to type parameters explicitly and to check with `GetType()` whenever a result looks wrong."

---

## 4. Objects vs Text

### What it is

Traditional shells pass **text** between commands. PowerShell passes **objects** — structured items that carry named data and behaviour.

### Why it matters

If a command hands you text, you have to parse it: split on spaces, count columns, write a regex, and hope the output format never changes. If a command hands you an object, you just ask for the property by name. One is fragile; the other is not.

### How it works conceptually

What you see on screen is **not the object**. It is a formatted rendering of the object, produced at the very end of the pipeline for your benefit.

```
Get-Process
    ↓
Process objects          ← real structured data: Id, ProcessName, CPU, and ~50 more
    ↓
Pipeline                 ← objects flow through here, still fully structured
    ↓
Formatting               ← PowerShell decides which few properties to show
    ↓
Table displayed on screen  ← this is a picture of the data, not the data
```

The table you see might show six columns. The object has dozens of properties. **Do not confuse the display with the data.**

### Example and what it means

```powershell
$process = Get-Process | Select-Object -First 1

$process.Id             # 4821
$process.ProcessName    # pwsh
$process.CPU            # 12.4531
```

You asked for `Id` by name. You did not count columns, split on whitespace or write a regex. If Microsoft changes the default display format tomorrow, `$process.Id` still works.

Compare the two approaches:

```powershell
# Text thinking (fragile — do not do this)
Get-Process | Out-String | Select-String "pwsh"   # now parse the line yourself

# Object thinking
Get-Process | Where-Object { $_.ProcessName -eq "pwsh" }
```

### Interview-ready answer: *"Why does PowerShell pass objects instead of text?"*

> "Because text forces every command to re-parse the previous command's output, and that parsing breaks the moment the format changes. PowerShell commands emit .NET objects that carry named properties and methods, so instead of splitting a line on whitespace and hoping column three is the PID, I just say `$process.Id`. The table you see on screen is only a formatted view generated at the end of the pipeline — the real object usually has far more properties than are displayed. Practically, that makes automation both shorter and far more reliable, because filtering, sorting and exporting all work on structured data rather than on strings."

---

## 5. The Object Model

### What it is

Every object in PowerShell is made of two kinds of member:

```
OBJECT
├── Properties  → data / information   (what the object HAS)
└── Methods     → actions / behaviour  (what the object CAN DO)
```

### Simple rule

| Member | Question it answers | Example |
|--------|--------------------|---------|
| **Property** | What does this object *have*? | `$process.Id`, `$process.ProcessName` |
| **Method** | What can this object *do*? | `$process.Kill()`, `$process.Refresh()` |

Methods are called with **parentheses**. Properties are not.

### Example with a process object

```powershell
$process = Get-Process | Select-Object -First 1

# Properties — data the object holds
$process.Id
$process.ProcessName
$process.StartTime

# Methods — actions the object can perform
$process.Refresh()          # re-read the process state
# $process.Kill()           # would terminate it — don't run this casually
```

### What it means

`$process.Id` returns a value. `$process.Refresh()` performs an action. If you write `$process.Refresh` without parentheses, PowerShell returns a description of the method rather than calling it — a useful clue when something "does nothing".

---

## 6. The PowerShell Pipeline

### What it is

The pipe operator `|` sends the **objects** produced by one command into the next command as input.

```powershell
Get-Process | Where-Object { $_.CPU -gt 50 }
```

### Why it matters

The pipeline is how PowerShell composes small commands into real work. Because objects survive the journey, each stage can inspect the data properly instead of re-parsing it.

### Breaking the command down, piece by piece

| Piece | What it does |
|-------|-------------|
| `Get-Process` | Produces process **objects** — one per running process |
| `\|` | Sends those objects, one at a time, to the next command |
| `Where-Object` | A filter. Keeps objects that match a condition, discards the rest |
| `{ }` | A script block — the condition to evaluate for each object |
| `$_` | **The current object being processed** |
| `.CPU` | Reads the `CPU` property of that current object |
| `-gt 50` | The comparison: "greater than 50" |

### What `$_` means

> **`$_` is the current object being processed.**

The pipeline hands objects to `Where-Object` one at a time. On each pass, `$_` *is* that one object. (`$PSItem` is the longer alias for the same thing.)

### Conceptual walkthrough

```
Get-Process produces three objects:

Process 1 → $_.CPU = 20   → 20  -gt 50 → False → discard
Process 2 → $_.CPU = 75   → 75  -gt 50 → True  → keep  ✅
Process 3 → $_.CPU = 120  → 120 -gt 50 → True  → keep  ✅

Output: Process 2, Process 3
```

### The general shape

```powershell
Something | Where-Object { CONDITION }
```

Read it as: *"produce some objects, then keep only the ones where the condition is true."*

More examples of the same shape:

```powershell
Get-Process  | Where-Object { $_.ProcessName -eq "pwsh" }
Get-ChildItem | Where-Object { $_.Length -gt 1MB }
Get-Process  | Where-Object { $_.CPU -gt 50 } | Select-Object Name, Id, CPU
```

---

## 7. Get-Member

### What it is

`Get-Member` is an **investigation tool**. It tells you what an object actually is and everything it can do.

```powershell
Get-Process | Get-Member
```

### Why it matters

You will constantly work with objects whose shape you do not know — from a new cmdlet, an API response, or a module you have never used. `Get-Member` is how you find out instead of guessing. It is the single most useful command for learning PowerShell.

### When to use it

- You do not know what properties an object has
- A property you expected is missing or empty
- You want to know whether something is a property or a method
- Output looks wrong and you suspect the type

### Reading the output

```
   TypeName: System.Diagnostics.Process

Name            MemberType     Definition
----            ----------     ----------
Kill            Method         void Kill(), void Kill(bool entireProcessTree)
Refresh         Method         void Refresh()
Id              Property       int Id {get;}
ProcessName     Property       string ProcessName {get;}
CPU             ScriptProperty System.Object CPU {get=...}
```

| Column | Meaning |
|--------|---------|
| **TypeName** | The object's full .NET type — here `System.Diagnostics.Process`. This is its identity. |
| **Name** | The name of the member you would type after the dot |
| **MemberType** | What kind of member it is — `Property`, `Method`, `ScriptProperty`, `NoteProperty`, `AliasProperty` |
| **Definition** | The signature: what type a property returns, or what arguments a method takes |

### Property vs Method in the output

- `Id  Property  int Id {get;}` → data you read. `{get;}` means read-only.
- `Kill  Method  void Kill()` → an action you call with `()`.

### `Get-Member` vs `.GetType()`

| | `.GetType()` | `Get-Member` |
|---|---|---|
| **Question it answers** | "What type are you?" | "What members do you have and what can you do?" |
| **Returns** | One type object | A list of every property and method |
| **Use when** | You suspect a type problem | You are exploring an unfamiliar object |

```powershell
$process.GetType().FullName    # System.Diagnostics.Process      ← identity only
$process | Get-Member          # TypeName + ~60 members          ← full capability list
```

Think of it as: `.GetType()` asks *who are you*, `Get-Member` asks *what can you do*.

### Interview-ready answer: *"How do you investigate an unfamiliar PowerShell object?"*

> "I pipe it into `Get-Member`. That gives me the TypeName, which tells me what I'm actually holding, and then every property and method with its definition. I use the MemberType column to tell properties from methods, because methods need parentheses. If I only need to confirm a type — say I suspect a value is a string when I expected a number — I use `.GetType()` instead, since that's a quicker single answer. `Get-Member` is my first move on anything I haven't used before, rather than guessing property names from what's printed on screen."

---

## 8. Value Types vs Reference Types

### What it is

Two different ways a variable can relate to its data.

| | Value type | Reference type |
|---|---|---|
| **Stores** | The actual value | A reference (pointer) to an object elsewhere |
| **Assignment copies** | The value | The reference only |
| **Examples** | `int`, `double`, `bool`, `datetime` | `PSCustomObject`, arrays, hashtables |

### Why it matters

This decides whether changing one variable affects another. Get it wrong and you will see "impossible" bugs where a variable changes on its own.

### Value type behaviour

```powershell
$a = 10
$b = $a      # $b receives a COPY of the value 10
$b = 20      # only $b changes

Write-Host $a $b   # 10 20
```

```
$a ──→ [ 10 ]
$b ──→ [ 10 ]   (a separate copy)

after $b = 20

$a ──→ [ 10 ]
$b ──→ [ 20 ]
```

**Why `$a` stays 10:** `$b = $a` copied the value itself. The two variables were never connected.

### Reference type behaviour

```powershell
$person1 = [PSCustomObject]@{
    Name = "Teju"
    Age  = 25
}

$person2 = $person1      # copies the REFERENCE, not the object
$person2.Age = 30

$person1.Age    # 30
$person2.Age    # 30
```

```
$person1 ──┐
           ├──→ [ OBJECT: Name=Teju, Age=25 ]
$person2 ──┘

after $person2.Age = 30

$person1 ──┐
           ├──→ [ OBJECT: Name=Teju, Age=30 ]   ← one object, both see the change
$person2 ──┘
```

**Why both see 30:** there is only ever **one object**. Both variables point at it. Changing it through either name changes the same thing.

### The two-line definition

> A reference type stores a reference to an object, not a separate copy.
> If two variables reference the same object, changing the object through one can affect what the other sees.

### Interview-ready answer

> "A value type holds the actual data, so assigning it to another variable creates an independent copy — change one and the other is unaffected. A reference type holds a pointer to an object, so assignment copies the pointer, not the object. Both variables then refer to the same thing, and modifying a property through one is visible through the other. In PowerShell, integers, booleans and datetimes behave as value types, while PSCustomObjects, arrays and hashtables are reference types. It matters most when I pass an object into a function, because the function can modify the caller's object."

---

## 9. Reassignment vs Mutation

### What it is

Two operations that look similar and behave completely differently.

| | Mutation | Reassignment |
|---|---|---|
| **Syntax** | `$person2.Age = 30` | `$person2 = [PSCustomObject]@{...}` |
| **Changes** | The object itself | Which object the variable points to |
| **Other references see it?** | ✅ Yes | ❌ No |

### Mutation — changing the object

```powershell
$person2.Age = 30
```

You reached *through* the variable, into the object, and changed a property. Anything else pointing at that object sees the change.

```
$person1 ──┐
           ├──→ [ Name=Teju, Age=30 ]   ← the object was modified
$person2 ──┘
```

### Reassignment — repointing the variable

```powershell
$person2 = [PSCustomObject]@{
    Name = "NewUser"
    Age  = 20
}
```

You did not touch the old object at all. You created a **brand new object** and told `$person2` to point at that instead. `$person1` still points at the original.

```
$person1 ──→ [ Name=Teju,    Age=30 ]      ← unchanged
$person2 ──→ [ Name=NewUser, Age=20 ]      ← new object
```

### Why reassignment breaks the link

The `=` operator on the **variable itself** rebinds the name. It says "this name now means that object". It never modifies whatever the name used to mean. Only reaching through the dot — `$var.Property = value` — modifies the object.

**The rule to remember:**

```
$var.Something = value   →  MUTATION      →  shared, everyone sees it
$var = value             →  REASSIGNMENT  →  local, only this variable changes
```

---

## 10. Arrays and Reference Behaviour

Arrays are **reference types**, so everything from sections 8 and 9 applies — plus one twist with `+=`.

### Assignment shares the array

```powershell
$Servers  = @("Server1", "Server2")
$Hostname = $Servers        # copies the reference
```

```
$Servers  ──┐
            ├──→ [ "Server1", "Server2" ]
$Hostname ──┘
```

### Mutation is shared

```powershell
$Hostname[0] = "Server10"

$Servers[0]     # Server10
$Hostname[0]    # Server10
```

```
$Servers  ──┐
            ├──→ [ "Server10", "Server2" ]   ← one array, modified in place
$Hostname ──┘
```

**Why both see it:** indexing into the array and assigning changes the existing array. There is still only one array.

### `+=` is not mutation

```powershell
$Hostname += "Server3"

$Hostname       # Server10, Server2, Server3
$Servers        # Server10, Server2          ← unchanged!
```

This surprises everyone once. Here is why.

**PowerShell arrays are fixed-size.** You cannot actually append to one. So `+=` does not add an element — it does this instead:

```
$Hostname += "Server3"

is really:

1. Create a NEW array big enough for 3 items
2. Copy all elements from the old array into it
3. Add "Server3" at the end
4. REASSIGN $Hostname to point at the new array
```

Step 4 is a reassignment, so the link is broken:

```
before:
$Servers  ──┐
            ├──→ [ "Server10", "Server2" ]
$Hostname ──┘

after $Hostname += "Server3":
$Servers  ──→ [ "Server10", "Server2" ]                 ← old array, untouched
$Hostname ──→ [ "Server10", "Server2", "Server3" ]      ← brand new array
```

### The summary that makes it click

| Operation | What it is | Shared? |
|-----------|-----------|---------|
| `$Hostname[0] = "x"` | Mutation — modifies the existing array | ✅ Yes |
| `$Hostname += "x"` | Reassignment — builds a new array, repoints the variable | ❌ No |

> `+=` on an array is copy-and-reassign, not append. That is also why building a large array with `+=` in a loop is slow — every iteration copies the whole array. *(Faster alternatives are covered on Day 2.)*

---

## 11. PSCustomObject

### What it is

`[PSCustomObject]` creates a structured object with named properties from a hashtable.

```powershell
[PSCustomObject]@{
    Name = "Teju"
    Age  = 25
}
```

### Why it is useful in automation

Because **functions should return objects, not text**. An object flows into the rest of the pipeline and works with everything:

```powershell
$user = [PSCustomObject]@{ Name = "Teju"; Age = 25; Dept = "IT" }

$user | Where-Object  { $_.Age -gt 18 }
$user | Select-Object Name, Dept
$user | Sort-Object   Age
$user | Export-Csv    users.csv -NoTypeInformation
```

None of that works if your function returned a formatted string. This is the practical payoff of the entire objects-versus-text idea.

### `@{}` vs `[PSCustomObject]@{}`

| | `@{}` (hashtable) | `[PSCustomObject]@{}` |
|---|---|---|
| **What it is** | A key-value lookup table | A real object with properties |
| **Access** | `$h["Name"]` or `$h.Name` | `$o.Name` |
| **Property order** | Not guaranteed | Preserved as written |
| **Pipes to `Select-Object` etc.** | Badly — treated as one item | Correctly |
| **Exports to CSV** | Produces useless output | Produces proper columns |
| **Use for** | Lookups, splatting, config | Anything you output or pipe |

```powershell
$hash = @{ Name = "Teju"; Age = 25 }              # a hashtable
$obj  = [PSCustomObject]@{ Name = "Teju"; Age = 25 }  # an object

$hash.GetType().Name    # Hashtable
$obj.GetType().Name     # PSCustomObject
```

The `[PSCustomObject]` cast takes the hashtable and converts it into an object, keeping your property order.

### Why property names do not use `$`

```powershell
[PSCustomObject]@{
    Name = "Teju"     # ✅ correct — Name is a property NAME
    Age  = 25
}
```

Inside the hashtable, the thing on the left of `=` is a **key**, a literal label you are inventing. `$` means "give me the value stored in this variable" — which is not what you want here. If you wrote `$Name = "Teju"`, PowerShell would look up the variable `$Name` and use *its value* as the property name.

Values on the right **can** use `$` because there you genuinely want a variable's contents:

```powershell
$firstName = "Teju"
[PSCustomObject]@{
    Name = $firstName     # ✅ left = literal key, right = variable value
}
```

---

## 12. Functions and Reference Types

### The practice

```powershell
function Test-Reference {
    param([PSCustomObject]$person)

    $person.Department = "Finance"

    Write-Host "Inside:"
    Write-Host $person.Name $person.Department
}

$person1 = [PSCustomObject]@{
    Name       = "Abhiram"
    Department = "IT"
}

Test-Reference -person $person1

Write-Host "Outside:"
Write-Host $person1.Name $person1.Department
```

### Output

```
Inside:
Abhiram Finance
Outside:
Abhiram Finance      ← the caller's object was changed
```

### Why the change is visible outside

Passing an object to a function copies the **reference**, not the object. The parameter `$person` inside the function points at the very same object as `$person1` outside it.

```
$person1 (caller)  ──┐
                     ├──→ [ Name=Abhiram, Department=IT ]
$person  (function) ─┘

$person.Department = "Finance"   ← mutation on the shared object

$person1 (caller)  ──┐
                     ├──→ [ Name=Abhiram, Department=Finance ]
$person  (function) ─┘
```

`$person.Department = "Finance"` is a **mutation**. It reaches through the reference into the shared object. The caller sees it.

### Key learning

> A function that takes an object can modify the caller's data without returning anything. That is sometimes exactly what you want — and sometimes a silent side effect you did not intend. Knowing which is which is the whole point of this section.

---

## 13. Nested Object and Array Reference Behaviour

This is the hardest idea of the day, and worth slowing down for.

### The setup

```powershell
$person = [PSCustomObject]@{
    Name   = "Teju"
    Skills = @("Koti", "Boti", "Roti")
}
```

### Inside the function

```powershell
$person.Name      = "Abhiram"
$person.Skills[0] = "PowerShell"
$person.Skills   += "Azure"
```

### Line by line

**1. `$person.Name = "Abhiram"`**
Mutation of a property on the shared object. Everyone holding a reference to that object sees `Name` change. ✅ Visible outside.

**2. `$person.Skills[0] = "PowerShell"`**
Reads the `Skills` property (a reference to an array), then indexes into that array and assigns. The **existing array is modified in place**. ✅ Visible outside.

```
$person ──→ [ OBJECT ]
              Name   = "Abhiram"
              Skills ──→ [ "PowerShell", "Boti", "Roti" ]   ← same array, modified
```

**3. `$person.Skills += "Azure"`**
This is the subtle one. It expands to:

```
1. Read $person.Skills            → the current array
2. Build a NEW array = old + "Azure"
3. Assign that new array back to $person.Skills   ← a PROPERTY assignment
```

Step 3 writes to a **property of the shared object**. So although a new array was created, it is stored on the object everybody can see. ✅ **Visible outside.**

```
$person ──→ [ OBJECT ]
              Skills ──→ [ "PowerShell", "Boti", "Roti", "Azure" ]   ← new array, on the shared object
```

### Why this differs from `$Servers += "Server9"`

```powershell
function Array {
    param([array]$Servers)
    $Servers += "Server9"     # ← reassigns the LOCAL PARAMETER VARIABLE
}
```

| Expression | What is on the left of `=` | Result |
|------------|---------------------------|--------|
| `$person.Skills += "Azure"` | A **property of a shared object** | New array stored on the shared object → visible outside ✅ |
| `$Servers += "Server9"` | A **local variable** | Local variable repointed → invisible outside ❌ |

**The distinguishing question:** *what is the `+=` assigning to — a property of a shared object, or a plain local variable?*

- Property of a shared object → the change travels.
- Local variable → the change stays local.

### Why "Azure" accumulates on repeated calls

```powershell
Test-Nested -person $person   # Skills: PowerShell, Boti, Roti, Azure
Test-Nested -person $person   # Skills: PowerShell, Boti, Roti, Azure, Azure
Test-Nested -person $person   # Skills: PowerShell, Boti, Roti, Azure, Azure, Azure
```

Each call reads the object's **current** `Skills` value, appends `"Azure"`, and writes the result back to the shared object. The next call starts from that updated value. The change persists between calls, so it stacks.

`$person.Name = "Abhiram"` does **not** accumulate — it overwrites with the same value every time. `$person.Skills[0] = "PowerShell"` does not accumulate either, for the same reason. Only the `+=` grows, because it builds *on top of what is already there*.

> **This is a real class of production bug.** A function that appends to an object's array property will keep appending every time it is called. If that function runs once per user in a loop, the array grows without limit.

---

## 14. Coding Practice Completed

### Q1 — Typed string parameter

**Objective:** Write a function that accepts a typed string parameter.

```powershell
function Show-Name {
    param([string]$Name)
    Write-Host "User: $Name"
}

Show-Name -Name "Abhiram"
```

**Being tested:** Basic function syntax, `param()` block, `[string]` type constraint, named parameter binding, string interpolation inside double quotes.

**Expected behaviour:**
```
User: Abhiram
```

**Key learning:** Inside double quotes, `$Name` is replaced by its value. Inside single quotes it would print literally as `$Name`.

---

### Q2 — Typed integer parameter and arithmetic

**Objective:** Perform arithmetic on a typed numeric parameter.

```powershell
function Square {
    param([int]$Number)
    Write-Host "Square: $($Number * $Number)"
}

Square -Number 7
```

**Being tested:** `[int]` constraint, arithmetic, and the **subexpression operator** `$( )`.

**Expected behaviour:**
```
Square: 49
```

**Key learning — the `$( )` operator:** inside a string, `"$Number * $Number"` prints `7 * 7` literally. You need `$( )` to make PowerShell *evaluate* the expression first. `$( )` means "run this and insert the result".

> ⚠️ **PowerShell has no `**` operator.** Python's `x ** 2` does not exist here. Use either:
> ```powershell
> $Number * $Number
> [Math]::Pow($Number, 2)
> ```

---

### Q3 — Boolean parameter and conditional logic

**Objective:** Branch on a boolean parameter.

```powershell
function User-Profile {
    param(
        [string]$Username,
        [bool]$IsActive
    )

    if ($IsActive -eq $false) {
        Write-Host "Account is inactive"
    }
    else {
        Write-Host "Account is Active"
    }
}

User-Profile -Username "Abhiram" -IsActive $true
```

**Being tested:** `[bool]` typing, `if`/`else`, and the `-eq` comparison operator.

**Expected behaviour:**
```
Account is Active
```

**Key learning:** PowerShell uses word operators, not symbols — `-eq`, `-ne`, `-gt`, `-lt`, `-ge`, `-le`. `==` is not a PowerShell operator. Booleans are `$true` and `$false`, with the `$`.

> 📌 *Further learning (Day 2):* the idiomatic PowerShell choice here is `[switch]$IsActive` rather than `[bool]`, because a switch can be written as `-IsActive` instead of `-IsActive $true`. Covered on Day 2.

---

### Q4 — DateTime parameter

**Objective:** Accept a datetime and read one of its properties.

```powershell
function Today-Date {
    param([datetime]$Date)
    Write-Host "Year:" $Date.Year
}

Today-Date -Date "2026-09-24"
```

**Being tested:** `[datetime]` coercion from a string, and accessing a property on a typed parameter.

**Expected behaviour:**
```
Year: 2026
```

**Key learning:** This is coercion doing real work. You passed a **string**; the `[datetime]` constraint converted it into a genuine DateTime object, which is why `.Year` exists. Without the type constraint, `$Date` would be a plain string and `.Year` would return nothing. A DateTime object also gives you `.Month`, `.Day`, `.DayOfWeek`, `.AddDays()` and more — run `Get-Date | Get-Member` to see them.

---

### Q5 — Multiple numeric parameters

**Objective:** Multiply two numeric parameters.

```powershell
function Price {
    param(
        [float]$Quantity,
        [float]$Price
    )
    Write-Host "Total cost: $($Quantity * $Price)"
}

Price -Quantity 3 -Price 19.99
```

**Being tested:** multiple typed parameters, floating-point arithmetic, `$( )` again.

**Expected behaviour:**
```
Total cost: 59.97
```

**Key learning:** `[float]` works, but **`[int]` would be more appropriate for a count-like quantity**. You cannot buy 2.5 licences or 3.7 servers. Choosing `[int]` makes the function reject a fractional quantity automatically — the type *is* the validation. This is Day 1 Objective 2 in practice: choose the type deliberately.

> 📌 *Further learning:* for money, `[decimal]` is generally safer than `[float]` or `[double]`, because binary floating point cannot represent some decimal fractions exactly.

---

### Discount Practice

**Objective:** Calculate a percentage discount and a final price.

```powershell
function Calculate-Discount {
    param(
        [int]$Price,
        [int]$Discount
    )

    $Discount_Price = $Price * ($Discount / 100)

    Write-Host "Discount Price:" $Discount_Price
    Write-Host "Final Price: $($Price - $Discount_Price)"
}
```

**Tested examples:**

```powershell
Calculate-Discount -Price 1000 -Discount 2
# Discount Price: 20
# Final Price: 980

Calculate-Discount -Price 991 -Discount 2
# Discount Price: 19.82
# Final Price: 971.18
```

| Input | Calculation | Discount | Final |
|-------|-------------|----------|-------|
| 1000, 2% | `1000 * (2/100)` | 20 | 980 |
| 991, 2% | `991 * (2/100)` | 19.82 | 971.18 |

**Key learning:** the parameters are `[int]`, but the **result is not**. `2 / 100` produces `0.02` as a Double, and `991 * 0.02` is `19.82`. PowerShell promoted the result type automatically — integer division does not truncate here the way it does in some other languages. The type constraint governs what goes *in*, not what comes *out* of the arithmetic.

**Also note:** the two `Write-Host` lines use different syntax and both work:
- `Write-Host "Discount Price:" $Discount_Price` — two separate arguments, joined with a space
- `Write-Host "Final Price: $($Price - $Discount_Price)"` — one string with an evaluated subexpression

---

### Value Type Practice

**Objective:** Prove that value types are copied on assignment.

```powershell
function integer {
    $a = 5
    $b = $a
    $b = 6
    Write-Host $a $b
}

integer
```

**Expected behaviour:**
```
5 6
```

**Why:** `$b = $a` copied the **value** 5 into `$b`. The two variables were never linked. Reassigning `$b` to 6 has no effect on `$a`, which still holds its own independent 5.

**Key learning:** with value types, assignment means *copy the data*.

---

### Reference Object Practice

**Objective:** Prove that reference types share one object.

```powershell
$person1 = [PSCustomObject]@{
    Name = "Abhiram"
    Age  = 26
}

$person2 = $person1
$person2.Age = 28

Write-Host $person1.Age $person2.Age
```

**Expected behaviour:**
```
28 28
```

**Why:** `$person2 = $person1` copied the **reference**. Both names point at one object. `$person2.Age = 28` is a mutation of that single shared object, so reading `.Age` through either name gives 28.

**Key learning:** with reference types, assignment means *copy the pointer*. Compare this directly with the value-type practice above — same-looking code, opposite result.

---

### Reference + Reassignment Practice

**Objective:** Show how reassignment breaks the shared link.

```powershell
$Person1 = [PSCustomObject]@{
    Name = "Abhiram"
    Age  = 36
}

$Person2 = $Person1          # shared reference
$Person2.Age = 37            # MUTATION → both are now 37

$Person2 = [PSCustomObject]@{   # REASSIGNMENT → link broken
    Name = "Teju"
    Age  = 23
}
```

**Final state:**

| Variable | Name | Age |
|----------|------|-----|
| `$Person1` | Abhiram | **37** |
| `$Person2` | Teju | 23 |

**Step by step:**

```
1. $Person2 = $Person1
   $Person1 ──┐
              ├──→ [ Abhiram, 36 ]
   $Person2 ──┘

2. $Person2.Age = 37          (mutation — shared)
   $Person1 ──┐
              ├──→ [ Abhiram, 37 ]
   $Person2 ──┘

3. $Person2 = [PSCustomObject]@{...}   (reassignment — link broken)
   $Person1 ──→ [ Abhiram, 37 ]        ← keeps the mutation from step 2
   $Person2 ──→ [ Teju,    23 ]        ← new, separate object
```

**Key learning:** `$Person1` keeps `Age = 37` — the mutation from step 2 was real and permanent. Reassigning `$Person2` afterwards does not undo it and does not affect `$Person1`. The two variables now point at two different objects.

---

### Array Practice

**Objective:** Show shared array mutation, then `+=` breaking the link.

```powershell
$Servers  = @("Server1", "Server2", "Server3")
$Hostname = $Servers

$Hostname[0] = "Server10"

$Servers     # Server10, Server2, Server3   ← shared change
$Hostname    # Server10, Server2, Server3
```

**Why:** arrays are reference types. `$Hostname = $Servers` shared the reference; indexing and assigning mutated the one array both names point at.

```powershell
$Hostname += "Server4"

$Hostname    # Server10, Server2, Server3, Server4
$Servers     # Server10, Server2, Server3            ← unchanged
```

**Why `$Servers` did not change:** `+=` built a brand new array and repointed `$Hostname` at it. `$Servers` still points at the original three-element array, which still carries the `Server10` mutation from earlier.

**Key learning:** index assignment mutates (shared); `+=` reassigns (not shared).

---

### Function + Array Practice

**Objective:** Show both behaviours together, across a function boundary.

```powershell
function Array {
    param([array]$Servers)

    $Servers[0] = "Server 10"    # MUTATION     → shared
    $Servers += "Server 9"       # REASSIGNMENT → local only

    Write-Host $Servers
}

$Servers = @("Server1", "Server2")

Array $Servers
$Servers
```

**Expected behaviour:**
```
Inside:  Server 10 Server 2 Server 9
Outside: Server 10 Server 2
```

**Why:**

| Line | Operation | Travels back to the caller? |
|------|-----------|----------------------------|
| `$Servers[0] = "Server 10"` | Mutation of the shared array | ✅ Yes — outside sees `Server 10` |
| `$Servers += "Server 9"` | Reassignment of the local parameter variable | ❌ No — `Server 9` stays inside |

```
Before:
$Servers (caller)   ──┐
                      ├──→ [ Server1, Server2 ]
$Servers (function) ──┘

After $Servers[0] = "Server 10":     (mutation, shared)
$Servers (caller)   ──┐
                      ├──→ [ Server 10, Server2 ]
$Servers (function) ──┘

After $Servers += "Server 9":        (reassignment, local)
$Servers (caller)   ──→ [ Server 10, Server2 ]
$Servers (function) ──→ [ Server 10, Server2, Server 9 ]   ← new local array
```

**Key learning:** this single function demonstrates the whole mutation-versus-reassignment distinction in six lines. It is the clearest example of the day.

> 📌 *Further learning (Day 2):* `function Array` and `function integer` use names that clash with type-ish words, and `User-Profile`, `Today-Date` and `Price` use verbs that are not approved. Day 2 covers approved verbs and `Get-Verb`, and you will rename these.

---

### Object Parameter Practice

**Objective:** Show that a function can modify the caller's object.

```powershell
function Test-Reference {
    param([PSCustomObject]$person)

    $person.Department = "Finance"

    Write-Host "Inside:"
    Write-Host $person.Name $person.Department
}

$person1 = [PSCustomObject]@{
    Name       = "Abhiram"
    Department = "IT"
}

Test-Reference -person $person1

Write-Host "Outside:"
Write-Host $person1.Name $person1.Department
```

**Expected behaviour:**
```
Inside:
Abhiram Finance
Outside:
Abhiram Finance
```

**Why the outside object also has `Department = Finance`:** the parameter received a copy of the reference, not a copy of the object. `$person.Department = "Finance"` mutated the one shared object. There is no separate copy for the function to work on.

**Key learning:** passing an object into a function is not a safety barrier. If you want the caller's object left alone, you must deliberately create a copy inside the function.

---

### Final Nested Object Challenge

**Objective:** Combine property mutation, array mutation and array `+=` on a nested object, then observe repeated calls.

```powershell
function Test-Nested {
    param([PSCustomObject]$person)

    $person.Name      = "Abhiram"
    $person.Skills[0] = "PowerShell"
    $person.Skills   += "Azure"

    Write-Host "Inside: " $person.Name $person.Skills
}

$person = [PSCustomObject]@{
    Name   = "Teju"
    Skills = @("Koti", "Boti", "Roti")
}

Test-Nested -person $person
Test-Nested -person $person
Test-Nested -person $person

Write-Host "Outside:" $person.Name $person.Skills
```

**Expected behaviour:**

| Call | Name | Skills |
|------|------|--------|
| 1 | Abhiram | PowerShell, Boti, Roti, Azure |
| 2 | Abhiram | PowerShell, Boti, Roti, Azure, Azure |
| 3 | Abhiram | PowerShell, Boti, Roti, Azure, Azure, Azure |

**Outside afterwards:** `Abhiram` — `PowerShell, Boti, Roti, Azure, Azure, Azure`

**Why each line behaves as it does:**

| Statement | Mechanism | Visible outside? | Accumulates? |
|-----------|-----------|-----------------|--------------|
| `$person.Name = "Abhiram"` | Property mutation on the shared object | ✅ | ❌ — overwrites with the same value |
| `$person.Skills[0] = "PowerShell"` | In-place mutation of the existing array | ✅ | ❌ — overwrites index 0 each time |
| `$person.Skills += "Azure"` | New array built, then **assigned to a property of the shared object** | ✅ | ✅ — each call builds on the previous result |

**Why "Azure" accumulates:** the `+=` reads the object's *current* Skills value, appends, and writes the result back onto the shared object. Because the write lands on the shared object rather than on a local variable, the next call starts from the already-extended array and appends again.

**Contrast with the array practice above:** there, `$Servers += "Server 9"` assigned to a **local parameter variable**, so it vanished when the function ended and never accumulated. Here the `+=` assigns to a **property**, so it persists.

**Key learning:** the deciding factor is always *what is on the left of the `=`*. A property of a shared object → persistent and shared. A local variable → temporary and local.

---

## 15. Interview Questions and Answers

### 1. Why does PowerShell pass objects instead of text?

> "Because passing text means every command has to re-parse the previous one's output, and that breaks whenever the format changes. PowerShell commands emit .NET objects with named properties, so instead of splitting a line on whitespace and hoping column three is the process ID, I just write `$process.Id`. What you see printed is only a formatted view generated at the end of the pipeline — the object usually has far more properties than are displayed. In practice it makes automation shorter and much more reliable, because filtering, sorting and exporting all operate on structured data."

### 2. What does Get-Member tell you and when do you use it?

> "It tells me the object's TypeName and lists every property and method with its definition. I use it whenever I'm working with an object I don't know — a new cmdlet, an API response, a module I haven't used. Rather than guessing property names from what's printed on screen, I pipe the object into `Get-Member` and read the actual structure. It's also how I confirm whether something is a property or a method, which matters because methods need parentheses."

### 3. What is the difference between a value type and a reference type?

> "A value type holds the actual data, so assigning it to another variable makes an independent copy — change one and the other is unaffected. A reference type holds a pointer to an object, so assignment copies the pointer and both variables end up referring to the same object. Integers, booleans and datetimes behave as value types; PSCustomObjects, arrays and hashtables are reference types. It matters most when passing objects into functions, because the function can modify the caller's object without returning anything."

### 4. How does explicit typing change variable behaviour?

> "It attaches a permanent constraint to the variable rather than just describing the current value. It doesn't require the assigned value to already be that type — it requires it to be convertible. `[int]$Age = '25'` works because PowerShell converts the string; `[int]$Age = 'hello'` fails because there's no valid conversion. The constraint also stays in force for later assignments. The benefit is that bad input fails immediately with a clear message rather than flowing through and producing a wrong answer later."

### 5. What is type coercion?

> "It's PowerShell automatically converting a value to another type so an operation can proceed. Usually helpful, but it's silent, which is the risk. If a value is a string that looks like a number, `'25' + 5` gives `255` because the left operand is a string, so `+` means concatenation. Comparisons have the same trap — `'10' -gt 9` is False. This comes up constantly with CSV data, since `Import-Csv` returns every field as a string. I handle it by typing parameters explicitly and checking with `GetType()` when a result looks wrong."

### 6. What is the difference between Get-Member and GetType()?

> "`GetType()` answers 'what type are you' and returns a single type. `Get-Member` answers 'what can you do' and returns every property and method along with the TypeName. I use `GetType()` for a quick check when I suspect a type problem — for example confirming a value is a string when I expected a number. I use `Get-Member` when I'm exploring something unfamiliar and need to know what's available."

### 7. What does `$_` mean in PowerShell?

> "It's the current object being processed in the pipeline. When objects are piped into something like `Where-Object`, they arrive one at a time, and on each pass `$_` is that one object. So `Where-Object { $_.CPU -gt 50 }` evaluates the CPU property of each process in turn. `$PSItem` is the longer form of the same thing."

### 8. What is the difference between a property and a method?

> "A property is data the object has — `$process.Id`, `$process.ProcessName`. A method is an action the object can perform — `$process.Kill()`, `$process.Refresh()`. Methods are called with parentheses; properties aren't. If I write a method name without parentheses I get a description of the method back instead of running it, which is a common source of confusion. `Get-Member` shows which is which in its MemberType column."

### 9. What is the difference between mutation and reassignment?

> "Mutation changes the object itself — `$person.Age = 30` reaches through the variable into the object. Anything else referring to that object sees the change. Reassignment changes which object the variable points at — `$person = [PSCustomObject]@{...}` creates a new object and repoints the name, leaving the original untouched and breaking any shared link. The quick test is what's on the left of the equals sign: a property means mutation, a bare variable means reassignment."

### 10. Why can `+=` behave differently with arrays?

> "Because PowerShell arrays are fixed-size, so `+=` can't actually append. It creates a new array, copies every element across, adds the new one, and reassigns the variable to the new array. That's a reassignment, so any other variable that shared the original array won't see the addition — whereas `$array[0] = 'x'` mutates the existing array in place and is shared. There's a performance consequence too: `+=` in a loop copies the whole array on every iteration."

### 11. How would you investigate an unfamiliar PowerShell object?

> "I pipe it into `Get-Member` first. That gives me the TypeName so I know what I'm actually holding, then the full list of properties and methods with their definitions. If I just need to confirm a type I use `.GetType()` instead, since it's a single quick answer. I'd also pipe it to `Select-Object *` or `Format-List *` to see the actual values of all properties, because the default table view usually shows only a handful of them."

### 12. Why are objects useful in automation?

> "Because they carry structured, named data that survives the whole pipeline. I can filter with `Where-Object`, select fields with `Select-Object`, sort, group, and export straight to CSV or JSON without writing any parsing code. If my function returns a formatted string, none of that works — the caller has to parse it back apart. So the rule I follow is that functions return objects and formatting happens only at the very end, where a human reads it."

---

## 16. Debugging Section

### The classic bug: string vs integer

```powershell
$countFromCsv = "25"     # imported from a CSV — looks like a number

$countFromCsv + 5        # 255      ← expected 30
$countFromCsv -gt 9      # False    ← expected True
```

Nothing threw an error. The script continued happily with wrong answers. **This is why silent coercion is dangerous.**

### Why a value that looks numeric may actually be a string

The screen shows you the *value*, never the *type*. `25` and `"25"` print identically. Sources that commonly hand you strings when you expected numbers:

- `Import-Csv` — **every field is a string**, always
- JSON parsed loosely, or values read from text files
- Command-line arguments
- Any API that returns numbers as quoted strings

### How coercion affects operations

| Expression | Result | Why |
|------------|--------|-----|
| `"25" + 5` | `255` | Left operand is a string → `+` concatenates |
| `25 + "5"` | `30` | Left operand is a number → right is coerced to a number |
| `"10" -gt 9` | `False` | Right coerced to string; `"1"` sorts before `"9"` |
| `10 -gt "9"` | `True` | Right coerced to a number |

**The rule:** PowerShell decides the operation from the **left-hand operand's type**, then coerces the right side to match.

### How to check the type

```powershell
$value.GetType()            # full type information
$value.GetType().Name       # just: String, Int32, Double...
$value | Get-Member          # type plus every available member
```

Both together:

```powershell
$countFromCsv.GetType().Name     # String    ← there's the bug
[int]$countFromCsv + 5           # 30        ← fixed by converting deliberately
```

### The debugging mindset

```
What value did I receive?
        ↓
What type is it?              ← $value.GetType().Name
        ↓
What type SHOULD it be?
        ↓
Is PowerShell converting it?  ← silently, and in which direction?
        ↓
Perform the operation.
```

Run this loop whenever a result is wrong but nothing errored. Nine times out of ten on Day 1 material, the answer is at step two.

### Preventing it rather than debugging it

```powershell
# ❌ trusting whatever arrives
function Add-Five { param($Number) $Number + 5 }
Add-Five "25"        # 255 — silently wrong

# ✅ constraining the type
function Add-Five { param([int]$Number) $Number + 5 }
Add-Five "25"        # 30  — coerced correctly at the boundary
Add-Five "hello"     # throws immediately, with a clear message
```

**This is Day 1 Objective 2 in one example.** Choosing the type deliberately turns a silent wrong answer into either a correct answer or a loud, early failure.

---

## 17. Object Model — One Paragraph

> PowerShell uses an object-based model where commands produce structured objects instead of plain text. Objects contain properties and methods, and these objects flow through the pipeline. Commands such as `Where-Object` and `Select-Object` can inspect and process those objects. `Get-Member` can be used to investigate an unfamiliar object's structure.

---

## 18. Day 1 Cheat Sheet

| Term | One-line explanation |
|------|---------------------|
| **Variable** | A named container for a value, always written with a `$` prefix. |
| **Data type** | What kind of value it is — `String`, `Int32`, `Boolean`, `DateTime`, `Double`. |
| **Explicit typing** | `[int]$Age = 25` — a permanent constraint on the variable; values must be convertible to that type. |
| **Type coercion** | PowerShell silently converting a value to another type so an operation can proceed. |
| **Object** | A structured item carrying named data and behaviour, not plain text. |
| **Property** | Data the object *has* — `$process.Id`. No parentheses. |
| **Method** | An action the object *can do* — `$process.Kill()`. Parentheses required. |
| **Pipeline** | `\|` sends objects from one command to the next, still fully structured. |
| **`$_`** | The current object being processed in the pipeline. |
| **`Get-Member`** | Investigation tool: shows the TypeName plus every property and method. |
| **`GetType()`** | Quick check: returns the object's type and nothing else. |
| **Value type** | Stores the actual value; assignment makes an independent copy (`int`, `bool`, `datetime`). |
| **Reference type** | Stores a pointer to an object; assignment shares it (`PSCustomObject`, arrays, hashtables). |
| **Mutation** | `$obj.Prop = x` — changes the object itself; shared with every reference to it. |
| **Reassignment** | `$obj = x` — repoints the variable at something new; breaks the shared link. |
| **`PSCustomObject`** | `[PSCustomObject]@{...}` builds a real object with ordered properties, ready for the pipeline. |

---

## 19. Day 1 Status

### Theory

- [x] Variables and data types
- [x] Explicit typing
- [x] Type coercion
- [x] Objects vs text
- [x] Pipeline
- [x] `$_`
- [x] `Get-Member`
- [x] Value vs reference types
- [x] Object model

### Coding

- [x] Functions and parameters
- [x] Typed parameters
- [x] Boolean practice
- [x] DateTime practice
- [x] Arithmetic practice
- [x] Value type practice
- [x] Reference object practice
- [x] Array reference practice
- [x] Reference objects in functions
- [x] Nested object / array practice

### Deferred

- [ ] **Bash comparison challenge** — *deferred. Bash is covered in Week 8; not yet learned.*

---

## 20. Final Takeaway

### What I should now be able to do

- [x] **Explain PowerShell's object-based pipeline** — why commands emit objects, and why the screen output is only a formatted view.
- [x] **Inspect unfamiliar objects using `Get-Member`** — read TypeName, MemberType and Definition rather than guessing property names.
- [x] **Distinguish properties and methods** — data the object has versus actions it can perform, and why methods need parentheses.
- [x] **Explain dynamic vs explicit typing** — how PowerShell infers a type, and what a `[type]` constraint actually enforces.
- [x] **Explain type coercion** — why `"25" + 5` is `255`, why `"10" -gt 9` is False, and why CSV data causes both.
- [x] **Explain value vs reference behaviour** — why `$a` stays 10 but `$person1.Age` becomes 30.
- [x] **Understand array mutation vs `+=` reassignment** — indexing modifies in place and is shared; `+=` copies and repoints and is not.
- [x] **Create PSCustomObjects** — and explain why they beat hashtables and strings for function output.
- [x] **Write typed PowerShell functions** — with `param()` blocks and deliberate type choices.
- [x] **Explain all of the above in an interview** — in practical terms, not textbook definitions.

### The one sentence to carry forward

> **PowerShell moves structured objects, not text — and the type of a value decides how every operation on it behaves.**

Everything from Day 2 onwards (functions, parameters, validation, the pipeline, modules) is built on those two facts.

---

*Day 1 of 90 · PowerShell Automation Engineer plan · Next: Day 2 — Arrays, hashtables and PSCustomObject in depth*
