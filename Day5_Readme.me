# Day 5 — PowerShell Regex and Measurement

> **PowerShell Automation Engineer — 90 Day Plan**
> Theme: regex for Identity Engineering, pattern validation at scale, and measuring instead of guessing.

---

## Day 5 Objectives

**Regex**

- Write regex patterns an Identity Engineer actually needs
- Understand regex rather than blindly memorizing patterns
- Validate UPN, SAMAccountName, EmployeeID and Email
- Extract structured information from Identity logs
- Understand `-match`, `-notmatch`, `-replace`, `Select-String` and `$Matches`
- Understand anchors, character classes, quantifiers, groups, named groups, alternation, escaping, whitespace classes and non-capturing groups
- Build a reusable regex pattern library
- Test patterns against valid, invalid, empty, whitespace and boundary inputs
- Parse an Identity authentication log into a typed PowerShell object

**Measurement**

- Understand `Measure-Command`
- Understand `[System.Diagnostics.Stopwatch]`
- Understand what timing tools tell you and what they do **not** tell you
- Measure instead of guessing
- Compare regex parsing with `Split()` over 100,000 records

### The two lessons that carried the day

> **1.** A regex can be syntactically perfect and still encode the wrong business rule. The 100,000-record validation proved this at scale.
>
> **2.** Timing answers *how long*. It never answers *why*. Those are two different engineering activities.

---

## Table of Contents

**Regex**
1. [Regex mental model](#1-regex-mental-model)
2. [Literal matching and escaping](#2-literal-matching-and-escaping)
3. [Character classes](#3-character-classes)
4. [Quantifiers](#4-quantifiers)
5. [Anchors](#5-anchors)
6. [Groups and non-capturing groups](#6-groups-and-non-capturing-groups)
7. [Named groups](#7-named-groups)
8. [Alternation](#8-alternation)
9. [Whitespace classes](#9-whitespace-classes)
10. [PowerShell regex operators and commands](#10-powershell-regex-operators-and-commands)

**Validation at scale**
11. [Identity directory dataset](#11-identity-directory-dataset)
12. [Directory validation script](#12-directory-validation-script)
13. [Regex vs business rule — the 99,001 lesson](#13-regex-vs-business-rule--the-99001-lesson)
14. [Anchor debugging test](#14-anchor-debugging-test)
15. [Edge case testing](#15-edge-case-testing)

**Measurement**
16. [Measure-Command](#16-measure-command)
17. [Stopwatch](#17-stopwatch)
18. [How long vs why slow](#18-how-long-vs-why-slow)
19. [Regex vs Split — 100,000 record benchmark](#19-regex-vs-split--100000-record-benchmark)

**Challenge, library and record**
20. [Daily challenge — Identity log parser](#20-daily-challenge--identity-log-parser)
21. [Pattern library](#21-pattern-library)
22. [about_Regular_Expressions](#22-about_regular_expressions)
23. [Debugging log](#23-debugging-log)
24. [Interview questions](#24-interview-questions)
25. [Day 5 status](#25-day-5-status)
26. [Final takeaways](#26-final-takeaways)
27. [Technical skill summary](#27-technical-skill-summary)

---

# Part 1 — Regex

## 1. Regex mental model

Regex does four jobs. Naming which one you need first stops most bad patterns from being written at all.

```
MATCH      → does this text follow a pattern?          "-match"
EXTRACT    → pull named parts out of the text          named groups + $Matches
VALIDATE   → does the WHOLE value conform?             anchors
TRANSFORM  → rewrite text using a pattern              "-replace"
```

### Identity Engineering mapping

| Job | Identity example |
|-----|-----------------|
| **Match** | Does this line in the auth log concern a failed login? |
| **Extract** | Pull the timestamp, user, action and status out of a raw log line |
| **Validate** | Is `EMP-123456` a correctly formed Employee ID? |
| **Transform** | Rewrite a legacy domain suffix across a bulk import file |

### Why this distinction matters

**Validation** and **matching** need different patterns even for the same data. Matching asks whether the pattern appears *somewhere*. Validation asks whether the value *is exactly* the pattern, and that requires anchors. Confusing the two is how `ABC-EMP-123456` gets accepted as a valid Employee ID.

### Note on the engine

PowerShell uses the **.NET regular expression engine**. Every pattern in this document is .NET regex, which is why constructs like `\z` and named groups written as `(?<Name>...)` are available. Patterns copied from Perl, Python or JavaScript tutorials mostly work, but the edge cases differ — `\z` being one of them.

---

## 2. Literal matching and escaping

### Theory

Regex starts as literal text matching. Most characters match themselves.

```regex
EMP-
```

This matches the four literal characters `E`, `M`, `P`, `-`. Nothing clever is happening yet.

### What happens internally

The engine walks the input, character by character, trying to match the pattern from each position. A literal pattern is a straight comparison. Complexity only enters when a character has special meaning.

### The metacharacters that bite

| Character | Special meaning | Literal form |
|-----------|----------------|--------------|
| `.` | Any single character | `\.` |
| `\|` | Alternation (or) | `\\|` |
| `*` `+` `?` | Quantifiers | `\*` `\+` `\?` |
| `(` `)` | Group | `\(` `\)` |
| `[` `]` | Character class | `\[` `\]` |
| `^` `$` | Anchors | `\^` `\$` |
| `{` `}` | Counted quantifier | `\{` `\}` |
| `\` | Escape character | `\\` |

### `.` versus `\.`

This is the single most common escaping error in identity validation.

```powershell
'user@companyXcom' -match '^[a-z]+@company.com$'    # True  ← WRONG
'user@companyXcom' -match '^[a-z]+@company\.com$'   # False ← correct
```

Unescaped, `.` means **any character**. So `companyXcom`, `company-com` and `company9com` all pass a pattern that was supposed to require a literal dot. The domain check silently stops being a domain check.

### `|` versus `\|`

`|` means alternation. In a pipe-delimited log format, the separator must be escaped:

```regex
^(?<Timestamp>...)\|(?<User>[^|]+)\|(?<Action>[^|]+)\|(?<Status>[^|]+)$
```

Without the backslash, `A|B` means "A or B" rather than "A, then a pipe, then B". This pattern is from the benchmark in [section 19](#19-regex-vs-split--100000-record-benchmark), where the log format is `timestamp|user|action|status`.

> Note that inside a character class, `[^|]` needs no escape — `|` has no special meaning there. `[^|]+` means "one or more characters that are not a pipe", which is how each field is captured up to the next delimiter.

### Interview answer

> "Most characters in a regex match themselves, but a set of metacharacters have special meaning and need escaping to be treated literally. The one that causes real bugs is the dot. In `@company.com` the unescaped dot matches any character, so `company-com` or `companyXcom` would validate. Writing `@company\.com` is what makes it an actual domain check. In pipe-delimited log formats I escape the pipe as `\|` for the same reason, because unescaped it means alternation."

### Key takeaway

> An unescaped metacharacter does not throw an error. It silently widens what your pattern accepts. That is the expensive kind of failure.

---

## 3. Character classes

### Theory

A character class defines **which characters are allowed** at a position.

| Class | Matches | Identity use |
|-------|---------|-------------|
| `[a-z]` | Lowercase letters | Lowercase-only SAM standards |
| `[A-Z]` | Uppercase letters | Fixed prefixes such as `EMP` |
| `[0-9]` | Digits | Employee ID numeric portion |
| `[a-zA-Z0-9]` | Alphanumeric | First/last character of a SAM name |
| `\d` | Digit, equivalent to `[0-9]` | `\d{6}` for a six-digit ID |
| `\w` | Word character: letter, digit or underscore | General identifier bodies |
| `\s` | Whitespace: space, tab, newline | Log field separators |
| `\S` | Any non-whitespace | Tokens of unknown shape |
| `[abc]` | Any one of a, b, c | A closed set of allowed values |
| `[^abc]` | Anything **except** a, b, c | `[^\|]+` — everything up to a delimiter |

### What happens internally

A class consumes **exactly one character** unless followed by a quantifier. `[a-z]` matches one lowercase letter. `[a-z]+` matches one or more.

### The `\w` trap in identity work

`\w` includes the underscore and, in .NET, matches Unicode letters by default. For a username pattern that is often too permissive:

```powershell
'user_name'  -match '^\w+$'              # True  — underscore allowed
'user.name'  -match '^\w+$'              # False — dot is NOT a word character
```

Real UPN and SAM names contain dots, which `\w` excludes, and may need to exclude underscores, which `\w` includes. That is why the patterns in this project spell the allowed set out explicitly as `[a-zA-Z0-9._-]` rather than reaching for `\w`.

### The negated class

```regex
[^|]+
```

"One or more characters that are not a pipe." This is the standard way to capture a delimited field: consume everything up to the next separator without needing to know what is in it.

### Interview answer

> "A character class defines the allowed characters at a position. I prefer to spell out the set explicitly for identity attributes — `[a-zA-Z0-9._-]` rather than `\w` — because `\w` includes the underscore and excludes the dot, which is exactly backwards for most username standards. Negated classes like `[^|]+` are useful for capturing delimited fields, since they consume everything up to the next separator."

### Key takeaway

> A shorthand class is convenient but it encodes someone else's idea of what a word is. For identity attributes, name the allowed characters yourself.

---

## 4. Quantifiers

### Theory

A quantifier defines **how many** of the preceding element are allowed.

| Quantifier | Meaning | Identity example |
|------------|---------|-----------------|
| `*` | Zero or more | `[._-]*` — optional separators |
| `+` | One or more | `[A-Za-z0-9]+` — at least one character |
| `?` | Zero or one | An optional field |
| `{n}` | Exactly n | `\d{6}` — exactly six digits |
| `{n,}` | n or more | `\d{6,}` — at least six digits |
| `{n,m}` | Between n and m | `{1,20}` — the SAM length limit |

### Where each one was used today

```regex
\d{6}                    exactly six digits — Employee ID
[A-Za-z0-9]+             one or more — username segment
{1,20}                   between 1 and 20 — SAM account name length
{0,18}                   the middle of the hardened SAM pattern
```

### `*` versus `+` — the critical difference for validation

```powershell
''  -match '^[a-z]*$'    # True  ← empty string PASSES
''  -match '^[a-z]+$'    # False ← empty string correctly rejected
```

`*` allows zero occurrences, so a pattern built entirely from `*` quantifiers matches an empty string. For a validation pattern that is almost always wrong. This is why every validation pattern in the library uses `+` or `{1,n}`, and why the empty-string test case in [section 15](#15-edge-case-testing) passes.

### Interview answer

> "Quantifiers control how many times the preceding element can repeat. The one that matters for validation is the difference between `*` and `+`: `*` allows zero, which means a pattern made of `*` quantifiers will happily match an empty string. I use `+` or a counted range like `{1,20}` in validation patterns so empty input is rejected by the pattern itself rather than needing a separate check."

### Key takeaway

> `{n}` is a business rule written in regex. `\d{6}` is not "some digits" — it is a statement that the Employee ID standard is exactly six.

---

## 5. Anchors

### Theory

Anchors tie the pattern to a position in the string. Without them, regex looks for a match **anywhere**.

| Anchor | Meaning |
|--------|---------|
| `^` | Start of the string (or of a line in multiline mode) |
| `$` | End of the string, **or immediately before a trailing newline** |
| `\z` | Absolute end of the string, .NET specific |

### What happens internally

Unanchored, the engine tries the pattern starting at position 0, then position 1, then position 2, and so on, until it finds a match or runs out of string. **Any substring match means success.** Anchoring removes that freedom: `^` forces the attempt to start at the beginning, and `$` or `\z` forces it to finish at the end.

```
Unanchored 'EMP-\d{6}' against 'ABC-EMP-123456':

  pos 0: ABC-...  no
  pos 1: BC-E...  no
  pos 2: C-EM...  no
  pos 3: -EMP...  no
  pos 4: EMP-123456  ← MATCH FOUND → returns True
```

The employee ID is invalid and the pattern says it is fine.

### The actual Employee ID pattern

```regex
^EMP-\d{6}$
```

| Value | Result | Why |
|-------|--------|-----|
| `EMP-123456` | **Valid** | Starts at `EMP-`, ends after exactly six digits |
| `ABC-EMP-123456` | Invalid | `^` prevents the match starting mid-string |
| `EMP-123456-XYZ` | Invalid | `$` prevents trailing content |
| `EMP-12345` | Invalid | Only five digits, `{6}` requires six |
| `""` | Invalid | Nothing to match |
| `"   "` | Invalid | Space is not in the pattern |

### What each anchor prevents specifically

- **`^` prevents a valid-looking value being embedded in junk.** Without it, `ABC-EMP-123456` and `garbage EMP-123456` both validate.
- **`$` prevents trailing content.** Without it, `EMP-123456-XYZ` and `EMP-1234567890` both validate — note the second one, where the extra digits make the ID wrong but the first six still match.

### `$` versus `\z` in .NET

This distinction is .NET specific and worth knowing:

```powershell
"EMP-123456`n" -match '^EMP-\d{6}$'     # True  ← trailing newline allowed
"EMP-123456`n" -match '^EMP-\d{6}\z'    # False ← absolutely the end
```

`$` matches at the end of the string **or immediately before a final newline**. `\z` matches only at the absolute end. When parsing lines read from a file, trailing newlines are exactly the sort of thing that survives into a value, which is why the log parser in [section 20](#20-daily-challenge--identity-log-parser) uses `\s*\z` rather than `$`.

### Interview answer

> "Anchors force the pattern to match the appropriate boundaries of the input rather than accepting a matching substring somewhere inside it. For example `^EMP-\d{6}$` requires the complete Employee ID to start with `EMP-` and end after exactly six digits. Without `^`, a value like `ABC-EMP-123456` would validate; without `$`, `EMP-123456-XYZ` would. In .NET I sometimes use `\z` instead of `$`, because `$` also matches just before a trailing newline, and when I'm parsing lines read from a file that newline can still be attached to the value."

### Key takeaway

> An unanchored validation pattern is not a validation pattern. It is a search.

---

## 6. Groups and non-capturing groups

### Theory

| Syntax | Purpose |
|--------|---------|
| `(...)` | Capturing group — groups elements **and** stores what matched |
| `(?:...)` | Non-capturing group — groups elements **without** storing |

Groups exist to apply a quantifier or alternation to more than one character at a time.

### The actual username pattern

```regex
[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*
```

Broken down:

```
[A-Za-z0-9]+          one or more alphanumerics        ← must START alphanumeric
(?:                   begin non-capturing group
   [._-]              exactly one separator: dot, underscore or hyphen
   [A-Za-z0-9]+       one or more alphanumerics        ← must FOLLOW the separator
)*                    the whole group, zero or more times
```

### What this actually enforces

| Value | Result | Why |
|-------|--------|-----|
| `teju` | Valid | First part only, group repeats zero times |
| `teju.thandoju` | Valid | One repetition of separator + segment |
| `teju.thandoju.k` | Valid | Two repetitions |
| `teju_thandoju-k` | Valid | Separators can be mixed |
| `.teju` | **Invalid** | Must start alphanumeric |
| `teju.` | **Invalid** | A separator must be followed by a segment |
| `teju..thandoju` | **Invalid** | Two separators in a row — no segment between |

The structure is what does the work. By requiring that every separator is **followed by** at least one alphanumeric, the pattern makes leading dots, trailing dots and doubled dots impossible without a single explicit rule about them.

### Why non-capturing

The group exists purely so `*` can apply to the whole `separator + segment` unit. Its contents are never needed separately. Using `(?:...)` says that explicitly and keeps `$Matches` clean — a capturing group here would add a numbered entry containing only the last repetition, which is meaningless and confusing.

### Interview answer

> "A capturing group both groups elements and stores what matched so I can retrieve it. A non-capturing group, written `(?:...)`, groups without storing. I use non-capturing when the group only exists to apply a quantifier. In my username pattern, `[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*` uses a non-capturing group to allow repeated separator-plus-segment units, which structurally prevents leading dots, trailing dots and doubled separators without needing a separate rule for each. Since I never need that group's contents, capturing it would just add noise to `$Matches`."

### Key takeaway

> Structure in a pattern can enforce a rule more reliably than a list of forbidden cases. Requiring a segment after every separator is stronger than banning leading and trailing dots individually.

---

## 7. Named groups

### Theory

```regex
(?<Name>...)
```

A named capturing group stores what it matched under a **name** instead of a number.

### Why this matters in automation

Numbered groups mean counting parentheses, and the numbering shifts when the pattern is edited:

```powershell
$Matches[1]    # which field is this? count the brackets
$Matches['User']   # obvious, and stable when the pattern changes
```

Named groups turn a regex from a string-slicing exercise into a structured extraction. `$Matches` becomes a hashtable with meaningful keys, which feeds directly into a `PSCustomObject`.

### The actual groups used

```regex
(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})
(?<User>[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*)
(?<Action>[A-Za-z]+)
(?<Status>Success|Failed)
```

Which produce:

```powershell
$Matches['Timestamp']
$Matches['User']
$Matches['Action']
$Matches['Status']
```

### The pipeline this creates

```
Raw log line
     ↓ regex with named groups
$Matches hashtable with meaningful keys
     ↓ projection
PSCustomObject with typed properties
     ↓
Where-Object / Sort-Object / Export-Csv
```

### Interview answer

> "A named group stores its capture under a name rather than a number, so I retrieve it as `$Matches['User']` instead of `$Matches[1]`. That matters in automation for two reasons: the code says what it means without counting brackets, and it doesn't break when I add a group to the pattern and shift all the numbering. Named groups are what make regex a structured extraction tool rather than a string-slicing one, because the capture names map straight onto the properties of the object I'm building."

### Key takeaway

> Named groups are the bridge between text and objects. They are the reason regex output can go straight into a `PSCustomObject`.

---

## 8. Alternation

### Theory

`|` means "or". It tries the left side first, then the right.

```regex
Success|Failed
```

### How it was used

In the log parser, the Status field is a **closed set**. There are two legal values and no others:

```regex
Status=(?<Status>Success|Failed)
```

### Why a closed set beats a wildcard

Compare:

```regex
Status=(?<Status>[A-Za-z]+)      # accepts Status=Banana
Status=(?<Status>Success|Failed) # accepts only the two real values
```

The second version makes a malformed or unexpected status a **rejection** rather than a silently accepted value. If a new status such as `Locked` appears in the logs, the parser fails loudly and you find out, instead of quietly emitting records with a status nothing downstream handles.

### Grouping alternation

Alternation has very low precedence, so it usually needs a group:

```regex
^Success|Failed$        # means: (^Success) OR (Failed$)  ← wrong
^(?:Success|Failed)$    # means: the whole value is one of the two  ← correct
```

This is a classic bug: the first version accepts `Successful` and `Really Failed`.

### Interview answer

> "Alternation is the `|` operator, meaning match this or that. I use it for closed sets — in my log parser the status can only be `Success` or `Failed`, so I wrote `(?<Status>Success|Failed)` rather than a general letter class. That turns an unexpected value into a rejection instead of a silently accepted record. The thing to watch is precedence: `^A|B$` doesn't mean what it looks like, because alternation binds loosely. It needs a group: `^(?:A|B)$`."

### Key takeaway

> Where the set of legal values is known and small, list them. A wildcard accepts the values you have not thought about yet.

---

## 9. Whitespace classes

### Theory

| Pattern | Meaning |
|---------|---------|
| `\s` | Exactly one whitespace character |
| `\s+` | One or more — the normal choice for separators |
| `\s*` | Zero or more — for optional whitespace |
| `\S` | Any non-whitespace character |

`\s` covers space, tab, carriage return, newline and form feed.

### How they were used in the log parser

```regex
...\d{2}:\d{2}:\d{2}\s+User=...     ← \s+ between fields
...(?<Status>Success|Failed)\s*\z   ← \s* before the absolute end
```

**`\s+` between fields** tolerates a log writer that uses one space on some lines and two on others. A literal space would make the parser brittle for no benefit.

**`\s*\z` at the end** allows trailing whitespace — which is often a stray space or a carriage return from a Windows-written file — while still refusing any actual content after the last field. This is the combination that makes `... Status=Success EXTRA` a rejection while `... Status=Success ` with a trailing space is accepted.

### The whitespace rejection this produces

```powershell
'   ' -match '^EMP-\d{6}$'    # False
```

Whitespace is rejected by every pattern in the library not because of a trim, but because **no pattern contains a whitespace character in its character classes**, and the anchors require the whole string to be consumed.

### Interview answer

> "`\s` matches a single whitespace character, and I usually want `\s+` for field separators so the parser isn't broken by an extra space. `\s*` before the end anchor is useful for tolerating trailing whitespace or a carriage return from a Windows-written file, while still rejecting actual trailing content. It's worth knowing that whitespace-only input gets rejected by my validation patterns automatically, because no pattern includes a whitespace character and the anchors force a full-string match."

### Key takeaway

> Be strict about content and tolerant about spacing. `\s+` between fields and `\s*\z` at the end is the combination that survives real log files.

---

## 10. PowerShell regex operators and commands

### `-match`

```powershell
$Value -match $Pattern
```

**Returns a Boolean** and, on success, **populates the automatic variable `$Matches`**.

Two behaviours that matter:

**1. It is case-insensitive by default.**

```powershell
'user@COMPANY.COM' -match '^[a-z]+@company\.com$'    # True
'user@COMPANY.COM' -cmatch '^[a-z]+@company\.com$'   # False
```

Use `-cmatch` / `-cnotmatch` when case is part of the rule.

**2. Against an array it does something different.**

```powershell
$Value  -match $Pattern    # scalar  → returns $true / $false, sets $Matches
$Values -match $Pattern    # array   → returns the MATCHING ELEMENTS, does not set $Matches
```

This is a real source of confusion. On a scalar it is a test; on an array it is a filter.

### `-notmatch`

```powershell
$Value -notmatch $Pattern
```

Useful for **rejection-first validation**, which is the style used in the log parser:

```powershell
if ($LogLine -cnotmatch $Pattern) {
    Write-Error "Malformed log line rejected: '$LogLine'"
    return
}
# from here on, the line is known good
```

Guard clauses like this keep the happy path unindented and make the rejection contract obvious at the top of the function. It also works as a filter:

```powershell
$Employees | Where-Object { $_.SAMAccountName -notmatch $SamRegex }
```

That single line is a non-compliant-accounts report.

### `-replace`

```powershell
$Value -replace $Pattern, $Replacement
```

Transforms text using a pattern. Identity example — migrating a legacy domain suffix in a bulk import file:

```powershell
'teju.thandoju@old-company.com' -replace '@old-company\.com$', '@company.com'
# teju.thandoju@company.com
```

Note the anchored pattern and the escaped dots: without `$`, a value containing the old domain in the middle would also be rewritten.

Captures can be referenced in the replacement with `$1`, or by name with `${Name}`:

```powershell
'Employee: 123456' -replace '^Employee: (?<Id>\d{6})$', 'EMP-${Id}'
# EMP-123456
```

### `Select-String`

Searches text and files for a pattern. Unlike `-match`, it returns **match objects** with file name, line number and the matched line.

```powershell
Select-String -Path './auth.log' -Pattern 'Status=Failed'
Select-String -Path './*.log' -Pattern '^EMP-\d{6}$'
Get-Content ./auth.log | Select-String -Pattern 'PasswordReset'
```

Useful when you need **where** the match occurred, not just whether it occurred. `-match` tells you yes or no about one string; `Select-String` searches across lines and files and tells you where.

### `$Matches`

After a **successful** scalar `-match`, `$Matches` is an automatic hashtable:

| Key | Contains |
|-----|----------|
| `0` | The **entire** matched text |
| `'Timestamp'`, `'User'`, `'Action'`, `'Status'` | Each **named** capture group |
| `1`, `2`, `3`… | Numbered capturing groups, if any |

```powershell
$Matches[0]             # the whole line that matched
$Matches['User']        # just the username
$Matches['Action']
$Matches['Status']
$Matches['Timestamp']
```

### ⚠ The `$Matches` persistence trap

This is the most important behaviour on this page.

> `$Matches` is only updated on a **successful** match. After a **failed** match it retains the values from the **previous successful** match.

```powershell
'2026-09-29 10:35:21 User=teju.thandoju ...' -match $Pattern   # True  → $Matches populated
'JUNK' -match $Pattern                                          # False → $Matches UNCHANGED
$Matches['User']                                                # still teju.thandoju
```

A function that checks `if ($Matches)` instead of checking what `-match` returned will happily return the **previous line's data** for a malformed line. No error, no warning, wrong answer.

**The rule:** always branch on the result of `-match` or `-notmatch`, never on the existence or contents of `$Matches`.

### Interview answer

> "`-match` returns a Boolean for a scalar and populates the automatic `$Matches` hashtable on success, where key `0` is the full match and named groups become keys like `$Matches['User']`. The critical detail is that `$Matches` is only updated on a successful match — after a failure it still holds the previous successful match's values. So I always test the result of `-match` itself, never `$Matches`, otherwise a malformed line silently returns the last good line's data. I also keep in mind that `-match` is case-insensitive by default and behaves as a filter rather than a test when the left side is an array."

### Key takeaway

> `$Matches` is a side effect, not a return value. Trust the Boolean.

---

# Part 2 — Validation at Scale

## 11. Identity directory dataset

### The dataset

```powershell
$Employees = 1..100000 | ForEach-Object {

    $FirstName = "User$_"
    $LastName  = "Employee$_"

    [PSCustomObject]@{
        EmployeeID     = "EMP-$('{0:D6}' -f $_)"
        UPN             = "$FirstName.$LastName@company.com"
        SAMAccountName  = "$FirstName.$LastName"
        Email           = "$FirstName.$LastName@company.com"
    }
}
```

**Confirmed:**

```powershell
$Employees.Count
# 100000
```

### Why 100,000 records

A five-record test would have passed every pattern cleanly. The dataset size is what exposed the SAM length problem in [section 13](#13-regex-vs-business-rule--the-99001-lesson) — because only at higher record numbers do the generated names grow long enough to break the rule.

> **Large datasets reveal problems that small datasets hide.** This is a recurring theme: a validation that passes on ten rows tells you almost nothing about a real directory.

### The `-f` format operator

```powershell
'{0:D6}' -f $_
```

`D6` formats an integer as decimal with a minimum of six digits, zero-padded. So `1` becomes `000001` and `123456` stays `123456`. This is what makes every generated Employee ID conform to `^EMP-\d{6}$` — and why the Employee ID column produced zero failures.

---

## 12. Directory validation script

### The final corrected script

```powershell
function Directory-Validation {
    param (
        $Employees
    )

    $EmpIdRegex = '^EMP-\d{6}$'
    $UpnRegex   = '^[a-zA-Z0-9._%+-]+@company\.com$'
    $SamRegex   = '^[a-zA-Z0-9._-]{1,20}$'
    $EmailRegex = '^[a-zA-Z0-9._%+-]+@company\.com$'

    $Report = [System.Collections.Generic.List[PSCustomObject]]::new()

    $TotalCount        = 0
    $ValidCount        = 0
    $InvalidCount      = 0
    $InvalidUpnCount   = 0
    $InvalidSamCount   = 0
    $InvalidEmpIdCount = 0
    $InvalidEmailCount = 0

    foreach ($Employee in $Employees) {

        $TotalCount++

        $EmpIdValid = $Employee.EmployeeID -match $EmpIdRegex
        $UpnValid   = $Employee.UPN -match $UpnRegex
        $SamValid   = $Employee.SAMAccountName -match $SamRegex
        $EmailValid = $Employee.Email -match $EmailRegex

        $OverallValid = $EmpIdValid -and $UpnValid -and $SamValid -and $EmailValid

        if ($OverallValid) {
            $ValidCount++
        }
        else {
            $InvalidCount++

            if (-not $EmpIdValid) {
                $InvalidEmpIdCount++
            }

            if (-not $UpnValid) {
                $InvalidUpnCount++
            }

            if (-not $SamValid) {
                $InvalidSamCount++
            }

            if (-not $EmailValid) {
                $InvalidEmailCount++
            }
        }

        $Report.Add(
            [PSCustomObject]@{
                EmployeeID      = $Employee.EmployeeID
                UPN             = $Employee.UPN
                SAMAccountName  = $Employee.SAMAccountName
                Email           = $Employee.Email
                UPNValid        = $UpnValid
                SAMValid        = $SamValid
                EmployeeIDValid = $EmpIdValid
                EmailValid      = $EmailValid
                OverallValid    = $OverallValid
            }
        )
    }

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "       DIRECTORY VALIDATION SUMMARY       " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    Write-Host "Total Records        : $TotalCount"
    Write-Host "Valid Records        : $ValidCount" -ForegroundColor Green
    Write-Host "Invalid Records      : $InvalidCount" -ForegroundColor Red

    Write-Host "------------------------------------------"

    Write-Host "Invalid Employee IDs : $InvalidEmpIdCount"
    Write-Host "Invalid UPNs         : $InvalidUpnCount"
    Write-Host "Invalid SAM Names    : $InvalidSamCount"
    Write-Host "Invalid Emails       : $InvalidEmailCount"

    Write-Host "==========================================`n" -ForegroundColor Cyan

    return $Report
}

$ValidationReport = Directory-Validation -Employees $Employees
```

### Actual result

```
==========================================
       DIRECTORY VALIDATION SUMMARY
==========================================
Total Records        : 100000
Valid Records        : 999
Invalid Records      : 99001
------------------------------------------
Invalid Employee IDs : 0
Invalid UPNs         : 0
Invalid SAM Names    : 99001
Invalid Emails       : 0
==========================================
```

### Measured performance

```
TotalMilliseconds : 1351.2545
```

Approximately **1.35 seconds** for 100,000 records with four regex evaluations each — around 400,000 pattern evaluations plus 100,000 object constructions.

### Design notes on this script

**`[System.Collections.Generic.List[PSCustomObject]]::new()`** rather than an array with `+=`. A fixed-size array would be copied on every one of the 100,000 additions. `List[T]` grows in place. This alone is the difference between seconds and minutes at this scale.

**Per-field counters, not just a pass/fail total.** `Invalid SAM Names : 99001` with zeros everywhere else is what made the root cause immediately visible. A single "99,001 invalid" would have required investigation. **Report which rule failed, not just that something did.**

**`Write-Host` for the summary, `return $Report` for the data.** The banner is presentation for a human; the report is data for the pipeline. Mixing them — emitting the report into the middle of the banner — would produce output that neither a human nor a script could use cleanly.

---

## 13. Regex vs business rule — the 99,001 lesson

This is the most valuable result of Day 5.

### The finding

```
Invalid SAM Names : 99001
```

99% of a valid directory was flagged as non-compliant. The regex was not broken. **The rule it encoded was wrong.**

### Why exactly 999 passed

The pattern was:

```regex
^[a-zA-Z0-9._-]{1,20}$
```

The generated SAM name is `User{n}.Employee{n}`. Its length is:

```
"User"     =  4
{n}        =  d digits
"."        =  1
"Employee" =  8
{n}        =  d digits
           ─────────
total      = 13 + 2d
```

| Record range | Digits (d) | SAM length | Within 20? |
|--------------|-----------|------------|-----------|
| 1–9 | 1 | 15 | ✅ |
| 10–99 | 2 | 17 | ✅ |
| 100–999 | 3 | 19 | ✅ |
| **1,000–9,999** | **4** | **21** | ❌ |
| 10,000–99,999 | 5 | 23 | ❌ |
| 100,000 | 6 | 25 | ❌ |

Records 1 to 999 pass. Everything from 1,000 upward exceeds 20 characters.

```
Valid:   999
Invalid: 100000 - 999 = 99001  ✓ matches the observed output exactly
```

The arithmetic confirms the failure is entirely explained by the length constraint. Nothing else was wrong.

### The engineering lesson

> **A regex can be syntactically valid and still encode the wrong business rule.**

The pattern did precisely what it said. The problem was upstream of the pattern:

1. **Naming standards are business rules.** "SAM account names are at most 20 characters" is a policy decision, not a regex feature.
2. **Regex only implements those rules.** It cannot tell you the rule is wrong for your data.
3. **An engineer must verify that the rule and the actual directory data agree.**

### What this looks like in real Identity work

A compliance report claiming 99% of your directory is non-compliant is almost never a directory problem. It is a **rule problem** — someone encoded a constraint that does not match how accounts are actually provisioned. Publishing that report without investigating destroys trust in every report you produce afterwards.

The correct response, in order:

1. **Check whether the rule is right** before reporting the data as wrong.
2. Sample the failures. Are they genuinely non-compliant, or does the rule not match reality?
3. If the rule is right and the data is wrong, that is a remediation project.
4. If the data is right and the rule is wrong, fix the rule.

Here, the generated data is internally consistent and the 20-character rule was applied to names that were never designed to fit it.

### Where the 20 comes from

The 20-character limit is a real Active Directory constraint on `sAMAccountName`, so the rule is not invented. The mistake was applying a real constraint to a synthetic dataset that ignores it — which is exactly the shape of the mistake you would make applying a real constraint to a directory whose provisioning process was never bound by it.

### Key takeaway

> Before reporting data as non-compliant, verify the rule. A validation result that fails 99% of production is a statement about your rule, not about production.

---

## 14. Anchor debugging test

### The test performed

```powershell
$TestEmployeeIDs = @(
    "EMP-123456"
    "ABC-EMP-123456"
    "EMP-123456-XYZ"
    "EMP-12345"
    ""
    "   "
)

$EmpIdRegex = '^EMP-\d{6}$'

foreach ($ID in $TestEmployeeIDs) {
    [PSCustomObject]@{
        Value = $ID
        Valid = $ID -match $EmpIdRegex
    }
}
```

### Actual result

| Value | Valid |
|-------|-------|
| `EMP-123456` | **True** |
| `ABC-EMP-123456` | False |
| `EMP-123456-XYZ` | False |
| `EMP-12345` | False |
| `""` (empty) | False |
| `"   "` (whitespace) | False |

### How anchoring prevented partial matches

Each rejection is caused by a specific part of the pattern:

| Value | Rejected by | Without that element |
|-------|------------|---------------------|
| `ABC-EMP-123456` | `^` | Would match starting at position 4 |
| `EMP-123456-XYZ` | `$` | Would match the first 10 characters |
| `EMP-12345` | `{6}` | Five digits, six required |
| `""` | `{6}` and the literal `EMP-` | Nothing to match |
| `"   "` | Everything | No whitespace anywhere in the pattern |

The two middle rows are the point of the test. **Both contain a perfectly valid Employee ID as a substring.** Only the anchors distinguish "contains a valid ID" from "is a valid ID".

### Key takeaway

> Test your validation pattern with a valid value **embedded in junk**, at the start and at the end. If both are rejected, your anchors work. If either passes, you have a search pattern, not a validation pattern.

---

## 15. Edge case testing

### The test structure

```powershell
$TestValues = @(
    ""
    "   "
    "EMP-"
    "EMP-123456"
    "EMP-12345678901234567890"
    "user@company.com"
    "user.user@company.com"
    "user.user@company.commmmmmmmmmmmmmmmmmmmmmmmm"
    "user.name"
    "user.name@company.com"
)

$Results = foreach ($Value in $TestValues) {
    [PSCustomObject]@{
        Value       = $Value
        Length      = $Value.Length
        EmployeeID  = $Value -match '^EMP-\d{6}$'
        UPN         = $Value -match '^[a-zA-Z0-9._%+-]+@company\.com$'
        SAM         = $Value -match '^[a-zA-Z0-9._-]{1,20}$'
        Email       = $Value -match '^[a-zA-Z0-9._%+-]+@company\.com$'
    }
}

$Results | Format-Table -AutoSize
```

### Results

| Value | Len | EmployeeID | UPN | SAM | Email |
|---|---|---|---|---|---|
| `""` | 0 | False | False | False | False |
| `"   "` | 3 | False | False | False | False |
| `EMP-` | 4 | False | False | **True** | False |
| `EMP-123456` | 10 | **True** | False | **True** | False |
| `EMP-12345678901234567890` | 24 | False | False | False | False |
| `user@company.com` | 16 | False | **True** | False | **True** |
| `user.user@company.com` | 21 | False | **True** | False | **True** |
| `user.user@company.commmm…` | 45 | False | False | False | False |
| `user.name` | 9 | False | False | **True** | False |
| `user.name@company.com` | 21 | False | **True** | False | **True** |

### What each check proved

| Check | Result |
|-------|--------|
| **Empty string rejected** | All four patterns return False. `+` and `{1,20}` both require at least one character |
| **Whitespace rejected** | All four return False. Not a trim — whitespace simply is not in any character class |
| **Valid maximum-length** | `EMP-123456` at exactly six digits passes; `user.name@company.com` at 21 chars passes UPN |
| **Over-format rejected** | The 24-char ID fails on `{6}`; the 45-char address fails on the anchored `\.com$` |
| **Valid-but-long not rejected** | 21-character UPN still passes — no accidental length ceiling on UPN or Email |

### Two results worth being able to explain

**`EMP-` returns True for SAM.** Four characters, all within the allowed class, within 1–20. The pattern is correct; a truncated Employee ID simply happens to be a structurally legal SAM name.

**`EMP-123456` returns True for both EmployeeID and SAM.** Also correct, and unavoidable at the pattern level. **A pattern cannot tell you which kind of identifier you are holding — only which shapes it is compatible with.** If downstream code says "if it matches SAM, treat it as a SAM", an Employee ID gets misrouted. Evaluation order or an explicit type field has to resolve that, not the regex.

### The purpose of boundary and negative testing

Positive tests prove a pattern **accepts** what it should. They cannot prove it **rejects** what it should — and over-acceptance is the dangerous direction for a validation pattern.

The five categories always worth testing:

1. **Empty** — catches `*` where `+` was meant
2. **Whitespace** — catches missing anchors and overly broad classes
3. **At the boundary** — exactly at the limit, must pass
4. **One past the boundary** — one over, must fail
5. **Valid value embedded in junk** — catches missing anchors

### Key takeaway

> A test set of only valid values tells you nothing. The invalid cases are where a validation pattern earns its place.

---

# Part 3 — Measurement

## 16. Measure-Command

### Theory

`Measure-Command` measures the **elapsed wall-clock time** of a script block.

```powershell
$Result = Measure-Command {
    Directory-Validation -Employees $Employees
}

$Result.TotalMilliseconds
```

### What it returns

A **TimeSpan** object, with useful properties:

```powershell
$Result.TotalMilliseconds    # 1351.2545
$Result.TotalSeconds
$Result.Ticks
```

### Actual measurement from Day 5

```
TotalMilliseconds : 1351.2545
```

Roughly 1.35 seconds to validate 100,000 records against four patterns.

### What it is good for

- Comparing **two complete implementations** of the same task
- Getting a first answer to "is this fast enough?"
- Establishing a baseline before changing anything

### Its main limitation

`Measure-Command` consumes the output of the script block by default. Anything the block emits goes into the measurement, not to you. That is why in the Day 4 CSV work `$Imported` had to be declared **before** the measured block and assigned inside it — otherwise the data was unreachable afterwards.

### Interview answer

> "`Measure-Command` runs a script block and returns a TimeSpan for how long it took. I use it to compare two complete implementations, or to get a baseline before I change anything. One thing to watch is that it swallows the script block's output, so if I need the result as well as the timing I assign it to a variable declared outside the block."

---

## 17. Stopwatch

### Theory

```powershell
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# code being measured

$Stopwatch.Stop()

$Stopwatch.ElapsedMilliseconds
```

### What it gives you that Measure-Command does not

**Manual control over the measurement boundaries.** You decide exactly where timing starts and stops, which means you can measure a **section inside** an operation rather than the whole thing.

```powershell
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ... regex evaluation ...
$RegexTime = $Stopwatch.ElapsedMilliseconds

$Stopwatch.Restart()

# ... object construction ...
$ObjectTime = $Stopwatch.ElapsedMilliseconds

$Stopwatch.Stop()
```

This is what turns "the whole thing takes 1.35 seconds" into "the regex takes X and building the objects takes Y" — the step from measuring to diagnosing.

### Useful members

| Member | Returns |
|--------|---------|
| `ElapsedMilliseconds` | Whole milliseconds, as a long integer |
| `Elapsed.TotalMilliseconds` | Fractional milliseconds, as a double |
| `Restart()` | Reset to zero and start again |
| `Stop()` / `Start()` | Pause and resume, accumulating |

> For short operations, prefer `Elapsed.TotalMilliseconds` — `ElapsedMilliseconds` truncates to whole milliseconds, so anything under 1 ms reports as 0.

### When to reach for each

| Use | Tool |
|-----|------|
| How long does this whole operation take? | `Measure-Command` |
| Which part of this operation is expensive? | `Stopwatch` |
| Comparing two implementations end to end | `Measure-Command` |
| Instrumenting a long-running job in progress | `Stopwatch` |

---

## 18. How long vs why slow

### The distinction

```
Measurement answers:   HOW LONG?
Diagnosis answers:     WHY?
```

These are different activities and require different tools. Confusing them leads to guessing at optimisations.

### The engineering workflow

```
Measure
   ↓
Identify the expensive section
   ↓
Investigate the implementation
   ↓
Change the implementation
   ↓
Measure again
   ↓
Compare
```

Every step matters. In particular the **last two**: an optimisation you did not re-measure is a guess you have grown attached to.

### What timing tools do not tell you

`TotalMilliseconds : 1351.2545` does not say whether the time went to:

- Regex evaluation — pattern complexity, backtracking
- Object creation — 100,000 `PSCustomObject` constructions
- File I/O — reading or writing
- Pipeline overhead — objects passing between stages
- Collection operations — array copying versus `List[T]` growth

All five are plausible. The number alone cannot distinguish them. Only isolating sections can.

### Applied to the Day 5 validation

The 1.35 seconds covers, per record: four regex evaluations, several Boolean operations, conditional counting, and one `PSCustomObject` construction added to a `List`. To find out where the time actually goes, you would time those groups separately with a `Stopwatch` — not stare harder at the total.

### Interview answer

> "`Measure-Command` tells me how long a script block takes to execute. It doesn't automatically tell me why it is slow. I would isolate individual sections, investigate the expensive operation, change the implementation, and measure again. `Stopwatch` is useful when I need more control over those measurement boundaries."

### Key takeaway

> Measure before optimising, and measure again after. An unmeasured optimisation is a belief, not an improvement.

---

## 19. Regex vs Split — 100,000 record benchmark

### The dataset

```powershell
$Logs = 1..100000 | ForEach-Object {
    [PSCustomObject]@{
        LogLine = "2026-09-29 10:$(('{0:D2}' -f ($_ % 60))):$(('{0:D2}' -f ($_ % 60)))|User$_.Employee$_|Login|Success"
    }
}

$Logs.Count
# 100000
```

Format: `timestamp|user|action|status` — a fixed, predictable, pipe-delimited structure.

### The regex parser

```powershell
function Parse-LogsWithRegex {
    param (
        [array]$Logs
    )

    $LogRegex = '^(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\|(?<User>[^|]+)\|(?<Action>[^|]+)\|(?<Status>[^|]+)$'

    $ParsedResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($LogLine in $Logs) {

        if ($LogLine.LogLine -match $LogRegex) {

            $ParsedResults.Add(
                [PSCustomObject]@{
                    Timestamp = $Matches['Timestamp']
                    User      = $Matches['User']
                    Action    = $Matches['Action']
                    Status    = $Matches['Status']
                }
            )
        }
    }

    return $ParsedResults
}
```

**Result:**

```powershell
$RegexResults = Parse-LogsWithRegex -Logs $Logs
$RegexResults.Count
# 100000
```

First record:

```
Timestamp : 2026-09-29 10:01:01
User      : User1.Employee1
Action    : Login
Status    : Success
```

Note the pattern details: `\|` escapes each literal delimiter, and `[^|]+` captures everything up to the next one.

### The Split parser

```powershell
function Parse-LogsWithSplit {
    param (
        [array]$Logs
    )

    $ParsedResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Log in $Logs) {

        $Parts = $Log.LogLine.Split('|')

        if ($Parts.Count -eq 4) {

            $ParsedResults.Add(
                [PSCustomObject]@{
                    Timestamp = $Parts[0]
                    User      = $Parts[1]
                    Action    = $Parts[2]
                    Status    = $Parts[3]
                }
            )
        }
    }

    return $ParsedResults
}
```

**Result:**

```powershell
$SplitResults = Parse-LogsWithSplit -Logs $Logs
$SplitResults.Count
# 100000
```

Both produced 100,000 records. **Correctness was equal; only speed differed.**

### The comparison

`Measure-Command` was used to time both functions over the same 100,000-record dataset.

**Observed result: Split completed faster than regex for this workload.**

### Why Split won here

- The input format was **fixed and predictable**
- Fields were separated by a single `|` character
- `Split` only had to **locate the delimiter and divide the string**
- Regex had to evaluate **anchors, character classes, named groups and captures** for every line

For 100,000 lines the per-line difference compounds into a visible gap.

### What Split gives up

`.Split('|')` performs **no validation**. The `if ($Parts.Count -eq 4)` check is the only guard, and it verifies the field *count* — nothing about the content. A line reading `garbage|nonsense|rubbish|junk` parses "successfully" into four fields.

The regex version validates while it parses: the timestamp must be a real timestamp shape, each field must be non-empty, and the whole line must be consumed. Those are not free, and they are what the extra time buys.

### The decision rule

```
Fixed, predictable delimiter        →  Split
Pattern matching / validation /     →  Regex
complex extraction / unreliable input
```

**Always measure when performance matters.**

### Interview answer

> "In my benchmark, I parsed 100,000 log lines using both regex and `Split`. `Split` performed faster because the log format was predictable and delimiter-based, with fields separated by `|`. `Split` only had to locate the delimiter and divide the string, whereas regex had to evaluate a pattern, including anchors, character classes, and named capture groups. I wouldn't say `Split` is always faster or always better. If the input has a fixed delimiter-based structure, I would prefer `Split` because it's simpler and efficient. If I need pattern validation, complex extraction, or the input format is less predictable, I would use regex. I would validate the choice with measurements rather than assuming which approach is faster."

### Key takeaway

> Regex and Split are not competitors. Split divides known-good text; regex validates text you do not trust. Choose by what you know about the input, then confirm with a measurement.

---

# Part 4 — Challenge, Library and Record

## 20. Daily challenge — Identity log parser

### The requirement

Parse a raw authentication log line into a typed `PSCustomObject`, using **one regex** with anchors, named groups, appropriate character classes and quantifiers, and `$Matches`. Reject a malformed line rather than producing a partially parsed object. No `Split()`.

Input format:

```
2026-09-29 10:35:21 User=teju.thandoju Action=Login Status=Success
2026-09-29 11:02:47 User=arun.kumar Action=PasswordReset Status=Failed
```

### The final function

```powershell
function ConvertFrom-IdentityLog {
    [OutputType([PSCustomObject])]
    param([Parameter(Mandatory)][string]$LogLine)

    $Pattern = '^(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+User=(?<User>[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*)\s+Action=(?<Action>[A-Za-z]+)\s+Status=(?<Status>Success|Failed)\s*\z'

    if ($LogLine -cnotmatch $Pattern) {
        Write-Error "Malformed log line rejected: '$LogLine'"
        return
    }

    [PSCustomObject]@{
        PSTypeName = 'Identity.AuthLogEntry'
        Timestamp  = [datetime]::ParseExact(
            $Matches['Timestamp'],
            'yyyy-MM-dd HH:mm:ss',
            [cultureinfo]::InvariantCulture
        )
        User       = $Matches['User'].ToLowerInvariant()
        Action     = $Matches['Action']
        Status     = $Matches['Status']
    }
}
```

### Every element explained

| Element | Purpose |
|---------|---------|
| `^` | Anchors to the start — no valid line embedded in junk |
| `(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})` | Named group with fixed-width quantifiers. Four digits, hyphen, two, hyphen, two, space, then `HH:mm:ss` |
| `\s+` | One or more whitespace between fields — tolerates inconsistent spacing |
| `User=` | Literal field label |
| `(?<User>[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*)` | Must start and end alphanumeric; separators must be followed by a segment. Structurally forbids `.user`, `user.` and `user..name` |
| `(?:...)` | Non-capturing group — exists only so `*` can apply to the whole separator-plus-segment unit |
| `(?<Action>[A-Za-z]+)` | Letters only, one or more |
| `(?<Status>Success\|Failed)` | Alternation over a closed set — an unexpected status is a rejection, not a silent pass |
| `\s*\z` | Allows trailing whitespace, then the **absolute** end. `\z` rather than `$` because `$` also matches before a trailing newline |
| `-cnotmatch` | Case-**sensitive** guard, so `Status=success` is rejected as malformed while the `[A-Za-z0-9]` username class still accepts either case |
| `$Matches['...']` | Named captures retrieved by meaningful key |
| `ParseExact` | Explicit format string, so the timestamp is parsed deterministically rather than guessed |
| `[cultureinfo]::InvariantCulture` | The parse does not depend on machine locale |
| `.ToLowerInvariant()` | Normalises the username at the parse boundary, so `Teju.Thandoju` and `teju.thandoju` do not become two different people when grouping |
| `[PSCustomObject]` | Structured, pipeline-compatible output |
| `PSTypeName` | Tags the object as `Identity.AuthLogEntry` so downstream functions can verify what they received |

### The flow

```
Raw log line
     ↓
Regex validation  (whole line must match, or reject)
     ↓
Named capture groups
     ↓
$Matches
     ↓
Type conversion   (string → datetime, username normalised)
     ↓
PSCustomObject    (typed, tagged, pipeline-ready)
```

### The rejection contract

```powershell
if ($LogLine -cnotmatch $Pattern) {
    Write-Error "Malformed log line rejected: '$LogLine'"
    return
}
```

A **non-terminating error** plus **no output**. Deliberate: one bad line in a large log must not stop a bulk parse, and the caller can collect failures with `-ErrorVariable`. The alternative — `throw` — would force the caller to handle it, which suits a single-line validation but not a batch.

Critically, the function **never returns a partially populated object**. Either the whole line matched and every field is present, or nothing is emitted.

### Why the guard tests `-cnotmatch` and not `$Matches`

Because of the `$Matches` persistence trap from [section 10](#10-powershell-regex-operators-and-commands). Had the guard been `if (-not $Matches)`, a malformed line following a successful one would have returned the **previous** line's user, action and status — silently and confidently.

### Usage

```powershell
Get-Content ./auth.log |
    ForEach-Object { ConvertFrom-IdentityLog -LogLine $_ -ErrorAction SilentlyContinue } |
    Where-Object Status -eq 'Failed' |
    Sort-Object Timestamp -Descending
```

Because `Timestamp` is a real `[datetime]`, that sort is chronological. Had it been left as a string, the sort would have been alphabetical — which happens to look correct for `yyyy-MM-dd` format and would silently break for any other.

### Naming note

`Parse-` is not an approved PowerShell verb. The approved verb for this operation is `ConvertFrom-`, which is why the final function is named `ConvertFrom-IdentityLog`.

---

## 21. Pattern library

### The library

```powershell
$Patterns = [ordered]@{
    EmployeeID = '^EMP-\d{6}$'
    UPN = '^[a-zA-Z0-9._%+-]+@company\.com$'
    SAMAccountName = '^[a-zA-Z0-9._-]{1,20}$'
    Email = '^[a-zA-Z0-9._%+-]+@company\.com$'
}
```

`[ordered]` preserves the declaration order, so the library enumerates predictably rather than in hashtable hash order.

### The test helper

```powershell
function Test-RegexPattern {
    param (
        [string]$Pattern,
        [string]$Value
    )

    [PSCustomObject]@{
        Value = $Value
        Valid = $Value -match $Pattern
    }
}
```

Returns an object rather than a raw Boolean, so results can be collected, filtered and exported.

### Valid tests — all returned True

```powershell
Test-RegexPattern -Pattern $Patterns.EmployeeID     -Value "EMP-123456"
Test-RegexPattern -Pattern $Patterns.UPN            -Value "teju.thandoju@company.com"
Test-RegexPattern -Pattern $Patterns.SAMAccountName -Value "teju.thandoju"
Test-RegexPattern -Pattern $Patterns.Email          -Value "teju.thandoju@company.com"
```

| Pattern | Value | Result |
|---------|-------|--------|
| EmployeeID | `EMP-123456` | True |
| UPN | `teju.thandoju@company.com` | True |
| SAMAccountName | `teju.thandoju` | True |
| Email | `teju.thandoju@company.com` | True |

### Invalid tests — all returned False

```powershell
Test-RegexPattern -Pattern $Patterns.EmployeeID     -Value "EMP-12345"
Test-RegexPattern -Pattern $Patterns.UPN            -Value "teju@gmail.com"
Test-RegexPattern -Pattern $Patterns.SAMAccountName -Value "teju thandoju"
Test-RegexPattern -Pattern $Patterns.Email          -Value "teju@invalid.com"
```

| Pattern | Value | Result | Rejected by |
|---------|-------|--------|------------|
| EmployeeID | `EMP-12345` | False | `{6}` — five digits |
| UPN | `teju@gmail.com` | False | Literal `@company\.com` |
| SAMAccountName | `teju thandoju` | False | Space not in the class |
| Email | `teju@invalid.com` | False | Literal `@company\.com` |

### Why a library rather than inline patterns

- **One definition per rule.** When the Employee ID standard changes, one line changes.
- **Testable in isolation**, as the tests above demonstrate.
- **Self-documenting.** The key names state what each pattern is for.
- **Reusable across functions** without copy-paste divergence.

This is the beginning of the reusable toolkit that grows across the 90 days.

---

## 22. about_Regular_Expressions

### What was attempted

```powershell
Get-Help about_Regular_Expressions
Get-Help about_Regular_Expressions -Full
```

### Actual result on this macOS PowerShell environment

```
Get-Help could not find about_Regular_Expressions in a help file in this session.
```

**The help topic was not successfully displayed locally.**

### Explanation

- PowerShell's `about_*` conceptual help topics are **local help files**, not built into the binary.
- They are not installed by default on all platforms and installation methods.
- `Update-Help` downloads help content, which would make the topic available locally.

### What was recorded instead

The reference was kept in the pattern library as a comment for future use:

```powershell
# PowerShell Regex Reference
# Get-Help about_Regular_Expressions -Full
```

---

## 23. Debugging log

Every item below is a real problem encountered on Day 5. The mistakes are part of the learning record.

---

### Directory validation script

#### Mistake 1 — Assignments stuck together

```powershell
# ❌ Incorrect
$ValidCount = 0$InvalidCount = 0

# ✅ Correct
$ValidCount = 0
$InvalidCount = 0
```

**Why it happened:** a missing newline between two statements.

**What PowerShell does:** the parser reads `0$InvalidCount` as a single expression and produces a parser error, because a variable cannot directly follow a numeric literal.

**Lesson:** PowerShell statements are newline-separated. A missing line break is a parse error, not a runtime one — which is the helpful kind.

#### Mistake 2 — Validation expressions stuck together

```powershell
# ❌ Incorrect
$EmpIdValid = $Employee.EmployeeID -match $EmpIdRegex$UpnValid

# ✅ Correct
$EmpIdValid = $Employee.EmployeeID -match $EmpIdRegex
$UpnValid   = $Employee.UPN -match $UpnRegex
```

**Why it happened:** same cause as above, in a denser region of the script.

**What PowerShell does:** `$EmpIdRegex$UpnValid` is read as two variables concatenated into one expression, so the regex becomes the pattern string plus whatever `$UpnValid` holds. Depending on state, this can either error or silently produce a wrong pattern.

**Lesson:** this one is more dangerous than Mistake 1, because variable-variable concatenation does not always error.

#### Mistake 3 — Missing spaces around operators

```powershell
# ❌ Incorrect
-match$UpnRegex

# ✅ Correct
-match $UpnRegex
```

**Why it happened:** typing speed.

**What PowerShell does:** `-match$UpnRegex` is not recognised as the `-match` operator followed by an argument. PowerShell operators require whitespace separation.

**Lesson:** PowerShell is whitespace-sensitive around operators in a way that some other languages are not.

#### Mistake 4 — Function parameter invocation

```powershell
# ❌ Incorrect
Directory-Validation -Employees$Employees

# ✅ Correct
Directory-Validation -Employees $Employees
```

**Why it happened:** same missing-space pattern, this time at the call site.

**What PowerShell does:** `-Employees$Employees` is parsed as a single token — a parameter name containing a variable expansion — not as `-Employees` with `$Employees` as its value.

**Lesson:** a parameter name and its value are separate tokens and must be separated by whitespace.

#### Mistake 5 — Regex variable scope

`$EmpIdRegex` was defined **inside** `Directory-Validation`. Testing it afterwards in the session produced a misleading result, because the variable did not exist outside the function.

**Why it happened:** the function was written first, then the pattern was tested interactively without re-declaring it.

**What PowerShell does:** variables created inside a function live in the function's scope and are discarded when it returns. Referencing `$EmpIdRegex` at the prompt afterwards yields `$null` — and `-match $null` does not behave as intended.

**Lesson:** this is the same scope principle as Day 4's `$TestObject` issue. **A variable defined inside a function does not exist outside it.** Testing a pattern separately from the function that uses it requires the pattern to be declared in a scope both can reach — which is exactly what the pattern library in [section 21](#21-pattern-library) solves.

#### Mistake 6 — Edge-case test label mismatch

A test was labelled as a "21 chars" UPN when the actual value was not 21 characters.

**Why it happened:** the label was written from intent rather than from the data.

**Why it matters:** the test still ran and still returned a result. But the result was being interpreted against a length that was not actually being tested — so the conclusion drawn from it was unsound.

**Lesson:** **test labels must describe the actual test data accurately.** A wrong label produces a test that passes for the wrong reason, which is worse than a test that fails. This is why `Length = $Value.Length` was added to the edge-case output in [section 15](#15-edge-case-testing) — the table now shows the real length rather than a claimed one.

---

### Log parser benchmark

#### Mistake 7 — Wrong regex for the dataset

The initial pattern described a format like:

```
timestamp [LEVEL] server message
```

while the actual dataset was:

```
timestamp|user|action|status
```

**Why it happened:** the pattern was written from a mental image of a log file rather than from the data in front of it.

**Result:** zero matches. The parser ran cleanly and produced nothing.

**Lesson:** **regex must describe the actual input structure.** Before writing a pattern, look at a real line. A zero-match result almost always means the pattern describes a different format, not that the data is bad.

#### Mistake 8 — Applying regex to the object instead of its property

```powershell
# ❌ Incorrect
$LogLine -match $LogRegex

# ✅ Correct
$LogLine.LogLine -match $LogRegex
```

**Why it happened:** `$Logs` is a collection of `PSCustomObject`s, each with a `LogLine` property. The loop variable is therefore the **object**, not the text.

**What PowerShell does:** `-match` on a `PSCustomObject` coerces it to a string first, which produces the type name rather than the log text, and nothing matches.

**Lesson:** know whether your loop variable is the object or the value. This is the Day 1 objects-versus-text distinction appearing again in a new shape.

#### Mistake 9 — `$ParsedResults` not initialized

```powershell
# ❌ Incorrect — .Add() called before the list exists
$ParsedResults.Add(...)

# ✅ Correct
$ParsedResults = [System.Collections.Generic.List[PSCustomObject]]::new()
```

**What PowerShell does:** `$ParsedResults` is `$null`, and calling a method on `$null` throws *"You cannot call a method on a null-valued expression."*

**Lesson:** a collection must be constructed before anything is added to it.

#### Mistake 10 — `return` inside the loop

```powershell
# ❌ Incorrect
foreach (...) {
    ...
    return
}

# ✅ Correct
foreach (...) {
    ...
}
return $ParsedResults
```

**Why it happened:** the `return` was placed inside the loop body during editing.

**What PowerShell does:** `return` exits the **entire function**, not just the current iteration. The function therefore returned after processing the **first** record — 1 result instead of 100,000.

**Lesson:** this connects directly to Day 1's lesson that `return` is an **early exit**, not an output mechanism. Inside a loop it ends the function. The equivalents that only affect the loop are `continue` (next iteration) and `break` (exit the loop).

#### Mistake 11 — Missing closing brace

```
Missing closing '}' in statement block or type definition.
```

**Why it happened:** four levels of nesting in this function:

```
function {
    foreach {
        if {
            .Add(
                [PSCustomObject]@{
                }
            )
        }
    }
}
```

Each of `foreach`, `if`, `.Add()` and the `PSCustomObject` literal opens something that must be closed, and one was missed.

**Lesson:** deeply nested blocks are where brace errors live. Consistent indentation makes the missing one visible; the parser error names the symptom, not the location.

#### Mistake 12 — Stray Split line

An accidental line:

```powershell
$LogLine.LogLine.Split('|')
```

was left **before** the `foreach` loop, producing:

```
You cannot call a method on a null-valued expression.
```

**Why it happened:** leftover from experimenting with the Split approach.

**What PowerShell does:** `$LogLine` is the **loop variable**. Outside the loop it does not exist, so it is `$null`, and calling `.LogLine` on `$null` throws.

**Lesson:** a loop variable exists only inside its loop. The error message points at a null-valued expression; the actual cause is referencing a variable before the construct that creates it.

---

### The pattern across all twelve

| Category | Mistakes |
|----------|----------|
| Whitespace and statement separation | 1, 2, 3, 4 |
| Scope | 5, 12 |
| Test discipline | 6 |
| Pattern did not match the data | 7 |
| Object versus value confusion | 8 |
| Initialization and control flow | 9, 10 |
| Nesting and syntax | 11 |

Four of the twelve were **parser errors** — caught immediately, cheap to fix. The expensive ones were 5, 6, 7 and 8, because each produced a **result** rather than an error: a misleading test, a wrongly labelled conclusion, zero matches, and no matches respectively. **A wrong answer costs more than a failure.**

---

## 24. Interview questions

### Q1. What does anchoring a pattern prevent?

> "Anchors force the pattern to match the appropriate boundaries of the input rather than accepting a matching substring somewhere inside it. For example, `^EMP-\d{6}$` requires the complete Employee ID to start with `EMP-` and end after exactly six digits."

### Q2. When is regex the wrong tool?

> "I use regex when I need pattern matching, validation, or extraction from text. If the data already has structure or a simpler operation such as `Split`, string methods, or object properties can solve the problem clearly, I prefer the simpler approach."

### Q3. How do you measure a PowerShell operation honestly?

> "I keep the workload consistent, measure the same operation, avoid including unrelated work, and use repeated measurements when necessary before comparing implementations. I use `Measure-Command` for complete operations and `Stopwatch` when I need finer measurement boundaries."

### Q4. What is in `$Matches` after a successful `-match`?

> "`$Matches` contains the captured values from the regex. Named capture groups become keys such as `$Matches['User']`, `$Matches['Action']`, and `$Matches['Status']`, while key `0` contains the complete matched text."

### Q5. Why was Split faster than regex?

> "In my benchmark, I parsed 100,000 log lines using both regex and `Split`. `Split` performed faster because the log format was predictable and delimiter-based, with fields separated by `|`. `Split` only had to locate the delimiter and divide the string, whereas regex had to evaluate a pattern, including anchors, character classes, and named capture groups. I wouldn't say `Split` is always faster or always better. If the input has a fixed delimiter-based structure, I would prefer `Split` because it's simpler and efficient. If I need pattern validation, complex extraction, or the input format is less predictable, I would use regex. I would validate the choice with measurements rather than assuming which approach is faster."

### Q6. Does Measure-Command tell you why a script is slow?

> "No. `Measure-Command` tells me how long a script block takes to execute. It doesn't automatically tell me why it is slow. I would isolate individual sections, investigate the expensive operation, change the implementation, and measure again. `Stopwatch` is useful when I need more control over those measurement boundaries."

---

## 25. Day 5 status

### Learning and practice — all completed

| Area | Status |
|---|---|
| Regex fundamentals | Completed |
| Anchors | Completed |
| Character classes | Completed |
| Quantifiers | Completed |
| Groups | Completed |
| Named groups | Completed |
| Non-capturing groups | Completed |
| Alternation | Completed |
| Escaping | Completed |
| Whitespace classes | Completed |
| `-match` | Completed |
| `-notmatch` | Completed |
| `-replace` | Completed |
| `Select-String` | Completed |
| `$Matches` | Completed |
| UPN pattern | Completed |
| SAM pattern | Completed |
| Employee ID pattern | Completed |
| Email pattern | Completed |
| 100,000-record validation | Completed |
| Regex edge-case testing | Completed |
| Unanchored pattern debugging | Completed |
| `Measure-Command` | Completed |
| `Stopwatch` | Completed |
| Measurement vs diagnosis | Completed |
| Regex vs Split benchmark | Completed |
| Identity log parser | Completed |
| Pattern library | Completed |
| Pattern tests | Completed |
| `about_Regular_Expressions` reference | Recorded (help topic not available locally) |
| Interview preparation | Completed |
| Daily challenge | Completed |

### Git tracking — not confirmed

No evidence of Git activity was provided for Day 5, so nothing below is marked complete.

- [ ] Created code
- [ ] Tested code
- [ ] Refactored code
- [ ] Committed code
- [ ] Pushed code

> Update these once the commit and push have actually been performed.

---

## 26. Final takeaways

1. Regex is a **pattern language**, not magic text matching.
2. **Anchors** prevent accidental partial validation.
3. **Character classes** define *what* characters are allowed.
4. **Quantifiers** define *how many* characters are allowed.
5. **Named groups** make regex useful for structured extraction.
6. **`$Matches`** connects regex extraction to PowerShell objects.
7. Regex must represent the **actual business rule**.
8. A technically valid regex can still implement the **wrong business constraint**.
9. **Split** is preferable for simple, predictable, delimiter-based text.
10. **Regex** is appropriate when pattern validation or complex extraction is required.
11. **`Measure-Command`** tells you how long a complete operation takes.
12. **`Stopwatch`** gives finer control over measurement boundaries.
13. Timing tells you **how long**; investigation determines **why**.
14. **Large datasets reveal problems that small datasets hide.**
15. Automation engineers should **measure before optimizing**.
16. After optimization, **measure again** to prove the change actually helped.

### The one to carry forward

> The regex was correct. The rule was wrong. 99,001 records were flagged as non-compliant by a pattern that did exactly what it said. **Before you report data as invalid, verify the rule.**

---

## 27. Technical skill summary

I can now:

**Regex construction**
- Build regex patterns
- Use anchors
- Use character classes
- Use quantifiers
- Use groups and non-capturing groups
- Use named groups
- Use alternation
- Escape regex metacharacters

**Identity validation**
- Validate Identity attributes
- Validate UPNs
- Validate SAMAccountNames
- Validate Employee IDs
- Validate Email addresses
- Build a reusable regex pattern library
- Test edge cases: empty, whitespace, boundary, over-boundary, embedded-in-junk

**PowerShell regex operators**
- Use `-match`
- Use `-notmatch`
- Use `-replace`
- Use `Select-String`
- Use `$Matches`, and avoid the persistence trap

**Parsing**
- Parse authentication logs
- Convert raw text into typed `PSCustomObject`s
- Apply a rejection contract so malformed input never produces a partial object

**Measurement**
- Use `Measure-Command`
- Use `[System.Diagnostics.Stopwatch]`
- Benchmark two implementations
- Decide between regex and `Split` based on the data format
- Distinguish measuring from diagnosing

**Engineering practice**
- Debug regex and PowerShell parser errors
- Work with 100,000-record datasets
- Recognise when a validation result indicates a rule problem rather than a data problem

---

*Day 5 of 90 · PowerShell Automation Engineer plan · Regex and measurement*
