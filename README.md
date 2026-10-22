# tabulator

Nim library for generating plain-text tables (with Unicode and ANSI code support)

## Features

- **Auto‑column creation** – Define columns explicitly or let the library create them from your row data
- **Unicode‑aware** – Correct display width for CJK, fullwidth forms, emoji, skin‑tone modifiers, combining marks, and zero‑width joiners
- **ANSI code support** – Colors and styling preserved in terminal output; stripped cleanly for file output[^*]
- **Configurable columns** – Fixed or auto‑width, left/center/right alignment
- **Terminal‑aware output** – Natural width by default; shrinks only if the table would exceed the terminal
- **Clean output** – Optional box‑drawing borders, no trailing whitespace in file output[^#]
- **Hyperlinks** – Passes through OSC 8 hyperlink sequences for terminals that support them
- **Sorting** – Sort rows by one or more columns, ascending or descending, with optional custom comparators
- **No external dependencies** – Uses only Nim standard library

  <img src="screenshots/file.png" width=350><br />

  <img src="screenshots/terminal.png" width=350>

## Installation

```bash
nimble install tabulator
```

Or, copy `tabulator.nim` into your project.

## Quick Start

```nim
import tabulator

var t = newTable()

discard t.defineColumn("Product", width = 20)
discard t.defineColumn("Price", align = Right)
discard t.defineColumn("In Stock", align = Center)

t.addRow(@["Apple", "$2.50", "\e[32myes\e[0m"])
t.addRow(@["Banana", "$1.20", "no"])
t.addRow(@["Cherry", "$15.00", "\e[31mlow\e[0m"])

t.renderTable(separator = true)
```

## API Reference

### Types
```nim
type Alignment* = enum
  Left    ## Text is left-padded (default)
  Center  ## Text is centred within the column width
  Right   ## Text is right-padded

type SortOrder* = enum
  Ascending   ## Smallest first
  Descending  ## Largest first

type SortKey* = object
  column*: int                          ## 0-based column index
  order*: SortOrder                     ## Ascending or Descending
  compare*: proc(a, b: string): int     ## Optional custom comparator

type Table* = ref object  # Opaque, create with newTable()
```

### Consts
```nim
const Version* = "2.0.0"
  ## For checking the current version programmatically
```

### Procedures
```nim
proc newTable(): Table
  ## Create a new empty table

proc defineColumn(t: Table, title: string = "", width: int = 0, align: Alignment = Left): int
  ## Define a column slot
  ## - `title`: Column header (pre‑format with embedded ANSI codes)
  ##   - if ALL column titles are empty = no header
  ## - `width`: Fixed width in display cells (0 = auto‑size to content)
  ##   - `1` produces "…" when content is longer; `2` produces "x…"; etc.
  ## - `align`: Cell alignment (Left, Center, Right)
  ##
  ## If an undefined slot already exists (created implicitly by `addRow`
  ## when a row had more cells than the current column set), that slot is
  ## filled in. Otherwise a new slot is appended. This makes the order of
  ## `defineColumn` and `addRow` calls independent.
  ##
  ## Returns the 0-based index of the slot that was defined. Column
  ## indices are stable for the lifetime of the table, so this value can
  ## be captured and reused as `SortKey.column`.

proc addRow(t: Table, cells: seq[string])
  ## Add a row of data; cells are strings (pre‑format numbers, embed ANSI codes)
  ##
  ## If `cells.len` exceeds the current column count, new undefined slots
  ## are created to hold the extra cells. They can be defined later by
  ## `defineColumn`.

proc rowCount(t: Table): int
  ## Number of rows in the table

proc columnCount(t: Table): int
  ## Number of columns in the table (defined and undefined)

proc sortRows(t: Table, keys: openArray[SortKey]): Table
  ## Return a new table with rows sorted by `keys` (first key is primary,
  ## later keys are tie-breakers). `t` is not modified.
  ##
  ## Rows are always sorted by their raw cell content, not by the
  ## formatted/truncated display output.

proc numericCompare(a, b: string): int
  ## Convenience comparator: parses both strings as floats.
  ## Anything else raises `ValueError`.

proc renderTable(t: Table, separator = false, width: int = 0, outFile: File = stdout)
  ## Render the table
  ## - `separator`: If true, adds box‑drawing borders between columns
  ## - `width`: Table width target
  ##   - `0` (default) → natural width. On a terminal, shrinks if natural
  ##     exceeds terminal width; never stretches.
  ##   - `> 0` → table is exactly that width (auto columns grow or shrink).
  ##     Fixed columns never resize.
  ## - `outFile`: Output file (default stdout)
```

### Internal helpers (exported for tests, not part of the stable API)
```nim
proc visibleLen(s: string): int
  ## Display width of s, ignoring ANSI escapes

proc stripAnsi(s: string): string
  ## Remove all ANSI escape sequences from s
```

## Examples

### Auto‑columns (no header)
Automatically creates columns based on data. `addRow` extends the column set as needed; no `defineColumn` calls are required:
```nim
var t = newTable()
t.addRow(@["A", "Short text", "42"])
t.addRow(@["B", "Longer piece of content here", "-15"])
t.addRow(@["", "Another row", "9999"])
t.renderTable()
```

### Rows first, columns later
Because `defineColumn` fills the next undefined slot, you can add data before deciding what to call the columns. The result is the same as if you had defined columns first:
```nim
var t = newTable()
t.addRow(@["Apple", "$2.50", "yes"])
t.addRow(@["Banana", "$1.20", "no"])
# t now has three undefined columns.
discard t.defineColumn("Product", width = 20)
discard t.defineColumn("Price", align = Right)
discard t.defineColumn("In Stock", align = Center)
# Same shape as defining columns before adding rows.
t.renderTable(separator = true)
```

### Styled headers and cells
```nim
var t = newTable()
discard t.defineColumn("\e[1;4mImportant\e[0m", width = 15)
discard t.defineColumn("\e[33mValue\e[0m", align = Right)
t.addRow(@["Normal text", "\e[32m✓\e[0m"])
t.renderTable(separator = true)
```

### Sorting
`defineColumn` returns the column's index, so you can capture it and reuse it in `SortKey`. Indices are stable for the lifetime of the table:

```nim
var t = newTable()
let colProduct = t.defineColumn("Product", width = 20)
let colPrice   = t.defineColumn("Price", align = Right)
let colStock   = t.defineColumn("In Stock", align = Center)

t.addRow(@["Apple",  "$2.50",  "\e[32myes\e[0m"])
t.addRow(@["Banana", "$1.20",  "no"])
t.addRow(@["Cherry", "$15.00", "\e[31mlow\e[0m"])

# Sort by price ascending, numerically
t.sortRows(@[
  SortKey(column: colPrice, order: Ascending, compare: numericCompare),
]).renderTable(separator = true)

# Multi-column: sort by stock status, then by price descending
t.sortRows(@[
  SortKey(column: colStock, order: Ascending),
  SortKey(column: colPrice, order: Descending, compare: numericCompare),
]).renderTable(separator = true)
```

Without a `compare` proc, cells are compared lexicographically after stripping ANSI escapes. Provide your own comparator for case-insensitive, date, or semantic sorting:

```nim
proc caseInsensitiveCmp(a, b: string): int =
  cmp(stripAnsi(a).toLowerAscii, stripAnsi(b).toLowerAscii)

t.sortRows(@[
  SortKey(column: colProduct, order: Ascending, compare: caseInsensitiveCmp),
]).renderTable(separator = true)
```

## Advanced Usage

### Position‑based terminal rendering vs whole-line rendering for text-file output
When outputting to a terminal, `tabulator` uses cursor positioning for accurate display of all Unicode scripts (including East‑Asian and complex scripts like Hindi, Arabic)
```nim
# Terminal gets cursor‑based output
t.renderTable()
```

Provide a file handle for text-file output:
```nim
# Files get clean text output (ANSI stripped)
let f = open("table.txt", fmWrite)
t.renderTable(outFile = f)
close(f)
```

### Width handling

- **Terminal output:**
  - `width = 0` → natural width; shrinks only if the table would exceed the terminal
  - `width > 0` → laid out for exactly that width, then clipped at the terminal
  - Never stretched to fill the terminal
- **File output:**
  - `width = 0` → natural width
  - `width > 0` → exactly that width; the file contains the whole table, no clipping
- **Fixed columns** (set via `defineColumn(width = N)`) are never resized; if
  fixed columns alone exceed the target, the table overflows

```nim
# Expands auto‑width columns to exactly 120 display cells
t.renderTable(width = 120)

# Natural width, shrunk to fit if the terminal is narrower
t.renderTable()

# File with no width limit
let f = open("wide.txt", fmWrite)
t.renderTable(outFile = f)  # No truncation
close(f)
```

### Cell truncation
Fixed‑width columns truncate with ellipsis:
```nim
discard t.defineColumn("Description", width = 10)
t.addRow(@["This is too long and will show as 'This is t…'"])
```

Wide characters are never split mid‑glyph:
```nim
discard t.defineColumn("Name", width = 4)
t.addRow(@["中文字符"])  # Shows "中…" — never half a glyph
```

### Without borders
Pass `separator = false` (the default) to omit box‑drawing borders between columns.

### No cell-overflow/text wrapping
If necessary, handle this yourself by splitting the text and adding extra rows

[![Static Badge](https://img.shields.io/badge/releases-orange?style=plastic&logo=rss&logoColor=orange&color=black)](https://github.com/erykjj/nim-tabulator/releases.atom)

[^*]: On Windows 10/11, ANSI escape sequences must be enabled in the console (see [here](https://ss64.com/nt/syntax-ansi.html))
[^#]: For proper display of box‑drawing characters (┏, ┃, ┗, etc.), ensure your terminal/console font supports the Unicode box-drawing block characters (U+2500‑U+257F)
