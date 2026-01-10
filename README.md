# tabulator

A Nim library for generating plain‑text tables (with Unicode and ANSI code support)

## Features

- **Auto‑column creation** – Define columns explicitly or let the library infer them from your data
- **Unicode‑aware** – Proper grapheme counting for international text[^*]
- **ANSI code support** – Colors and styling preserved (ignored for width calculation)
- **Configurable columns** – Fixed or auto‑width, left/center/right alignment
- **Terminal‑width aware** – Automatically truncates to fit terminal (or custom width)
- **Clean output** – Optional column separators with proper spacing
- **No external dependencies** – Uses only Nim standard library

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

Output:
```
| Product              | Price | In Stock |
|----------------------|-------|----------|
| Apple                | $2.50 |   yes    |
| Banana               | $1.20 |    no    |
| Cherry               | $15.00|   low    |
```

## API Reference

### Types
```nim
type Alignment* = enum Left, Center, Right
type Table* = ref object  # Opaque, create with newTable()
```

### Procedures
```nim
proc newTable*(): Table
  ## Creates a new empty table.

proc addColumn*(t: Table, title: string = "", width: int = 0, align: Alignment = Left)
  ## Adds a column definition.
  ## - `title`: Column header (empty = no header)
  ## - `width`: Fixed width (0 = auto‑size to content)
  ## - `align`: Cell alignment (Left, Center, Right)

proc addRow*(t: Table, cells: seq[string])
  ## Adds a row of data. Cells are strings (pre‑format numbers, embed ANSI codes).

proc renderTable*(t: Table, separator = false, width: int = 0, outFile: File = stdout)
  ## Renders the table.
  ## - `separator`: If true, adds `|` between columns
  ## - `width`: Maximum line width (0 = use terminal width)
  ## - `outFile`: Output file (default stdout)
```

## Examples

### Auto‑columns (no header)
```nim
var t = newTable()
t.addRow(@["A", "Short text", "42"])
t.addRow(@["B", "Longer piece of content here", "-15"])
t.addRow(@["", "Another row", "9999"])
t.renderTable()
```

### Custom width and no separators
```nim
t.renderTable(separator = false, width = 80)
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

### Handling wide tables
When table width exceeds terminal width, it's cleanly truncated at the right edge:
```nim
# With many/wide columns, output will be cut at terminal boundary
t.renderTable(width = 120)  # Specify custom width for non‑terminal output
```

### Cell truncation
Fixed‑width columns truncate with ellipsis:
```nim
t.addColumn("Description", width = 10)
t.addRow(@["This is too long and will show as 'This is t…'"])
```

### No columns defined
The library creates columns automatically based on data:
```nim
var t = newTable()
t.addRow(@["Auto", "column", "creation"])
t.addRow(@["Works", "without", "explicit", "columns"])
t.renderTable()  # Creates 4 left‑aligned auto‑width columns
```
____
[^*] For scripts with ambiguous width (Hindi, Arabic, etc.), column alignment may be off (depending on terminal)