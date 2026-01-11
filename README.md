# tabulator

A Nim library for generating plain-text tables (with Unicode and ANSI code support)

## Features

- **Auto‑column creation** – Define columns explicitly or let the library infer them from your data
- **Unicode‑aware** – Proper grapheme counting for international text
- **ANSI code support** – Colors and styling preserved[^*]
- **Configurable columns** – Fixed or auto‑width, left/center/right alignment
- **Terminal‑width aware** – Automatically truncates to fit terminal (or custom width)
- **Clean output** – Optional box‑drawing borders with proper spacing[^#]
- **No external dependencies** – Uses only Nim standard library

  <img src="screenshots/file.png" width=350><br />

  <img src="screenshots/terminal.png" width=350>

## Installation

Copy `tabulator.nim` into your project.

## Quick Start

```nim
import tabulator

var t = newTable()

t.addColumn("Product", width = 20)
t.addColumn("Price", align = Right)
t.addColumn("In Stock", align = Center)

t.addRow(@["Apple", "$2.50", "\e[32myes\e[0m"])
t.addRow(@["Banana", "$1.20", "no"])
t.addRow(@["Cherry", "$15.00", "\e[31mlow\e[0m"])

t.renderTable(separator = true)
```

Output (colors not visible here):
```
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━┓
┃ Product              ┃  Price ┃ In Stock ┃
┣━━━━━━━━━━━━━━━━━━━━━━╋━━━━━━━━╋━━━━━━━━━━┫
┃ Apple                ┃  $2.50 ┃   yes    ┃
┃ Banana               ┃  $1.20 ┃    no    ┃
┃ Cherry               ┃ $15.00 ┃   low    ┃
┗━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━┻━━━━━━━━━━┛
```

## API Reference

### Types
```nim
type Alignment* = enum Left, Center, Right
type Table* = ref object  # Opaque, create with newTable()
```

### Procedures
```nim
proc newTable(): Table
  ## Create a new empty table

proc addColumn(t: Table, title: string = "", width: int = 0, align: Alignment = Left)
  ## Add a column definition
  ## - `title`: Column header (pre‑format with embedded ANSI codes)
  ##   - if ALL column titles are empty = no header
  ## - `width`: Fixed width (0 = auto‑size to content)
  ## - `align`: Cell alignment (Left, Center, Right)

proc addRow(t: Table, cells: seq[string])
  ## Add a row of data; cells are strings (pre‑format numbers, embed ANSI codes)

proc renderTable(t: Table, separator = false, width: int = 0, outFile: File = stdout)
  ## Render the table
  ## - `separator`: If true, adds box‑drawing borders between columns
  ## - `width`: Maximum line width (0 = use terminal width for terminal, no limit for files)
  ## - `outFile`: Output file (default stdout)
```

## Examples

### Auto‑columns (no header)
Automatically creates columns based on data:
```nim
var t = newTable()
t.addRow(@["A", "Short text", "42"])
t.addRow(@["B", "Longer piece of content here", "-15"])
t.addRow(@["", "Another row", "9999"])
t.renderTable()
```

### Styled headers and cells
```nim
var t = newTable()
t.addColumn("\e[1;4mImportant\e[0m", width = 15)
t.addColumn("\e[33mValue\e[0m", align = Right)
t.addRow(@["Normal text", "\e[32m✓\e[0m"])
t.renderTable(separator = true)
```

## Advanced Usage

### Position‑based terminal rendering vs whole-line rendering for text-file output
When outputting to a terminal, `tabulator` uses cursor positioning for accurate display of all Unicode scripts (including East‑Asian and complex scripts like Hindi, Arabic)
```nim
# Terminal gets cursor‑based output
t.renderTable()
```

Provide a file name for text-file output:
```nim
# Files get clean text output (ANSI stripped)
let f = open("table.txt", fmWrite)
t.renderTable(outFile = f)
close(f)
```

### Width handling
- **Terminal output:** If `width=0`, uses terminal width; truncates if too wide
- **File output:** If `width=0`, no truncation; if `width>0`, truncates to that width
- **Column expansion:** If specified `width` > natural table width, auto‑sized columns expand evenly

```nim
# Expands auto‑width columns to fill total table width of 120
t.renderTable(width = 120)

# Uses terminal width, truncates if needed
t.renderTable()

# File with no width limit
let f = open("wide.txt", fmWrite)
t.renderTable(outFile = f)  # No truncation
close(f)
```

### Cell truncation
Fixed‑width columns truncate with ellipsis:
```nim
t.addColumn("Description", width = 10)
t.addRow(@["This is too long and will show as 'This is t…'"])
```

### No row-separator borders
These don't help and take up space, IMHO

### No cell-overflow/text wrapping
If necessary, handle this yourself by splitting the text and adding extra rows

____
[^*] On Windows 10/11, ANSI escape sequences must be enabled in the console (see [here](https://ss64.com/nt/syntax-ansi.html))
[^#] For proper display of box‑drawing characters (┏, ┃, ┗, etc.), ensure your terminal/console font supports the Unicode box-drawing block characters (U+2500‑U+257F)