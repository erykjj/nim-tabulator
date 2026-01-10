## tabulator: A Nim library for generating plain‑text tables
##
## Features:
## - Auto‑column creation
## - Unicode and ANSI code support
## - Configurable alignment and widths
## - Terminal‑width aware truncation
##
## License: Infiniti Noncommercial License (see LICENSE for full terms)

import
  std/[terminal, unicode, strutils, math]

const
  Version* = "0.1.0"

type
  Alignment* = enum
    Left, Center, Right

  Column = object
    title: string
    width: int
    align: Alignment

  Table* = ref object
    columns: seq[Column]
    rows: seq[seq[string]]


# Helper procs

proc visibleLen(s: string): int =
  ## Returns number of graphemes in `s`, ignoring ANSI escape sequences
  ## If a malformed ANSI sequence is found (no terminator), it is ignored
  ## For scripts with ambiguous width (Hindi, Arabic, etc.), column alignment may be off by ±1 depending on terminal
  var i = 0
  while i < s.len:
    if s[i] == '\e':
      let start = i
      inc i
      var foundTerminator = false
      while i < s.len and s[i] notin {'m', 'H', 'J', 'K', 'A'..'D', 's', 'u'}:
        inc i
      if i < s.len:
        inc i
        foundTerminator = true
      if not foundTerminator:
        i = start + 1
        inc result
    else:
      let g = s.runeLenAt(i)
      inc result
      i += g

proc formatCell(content: string, width: int, align: Alignment): string =
  ## Pad/truncate cell content
  let visLen = content.visibleLen()
  if visLen == width:
    return content
  elif visLen > width:
    if width <= 1:
      return "…"
    var taken = 0
    var i = 0
    var buf = ""
    while i < content.len and taken < width - 1:
      if content[i] == '\e':
        let start = i
        inc i
        while i < content.len and content[i] notin {'m', 'H', 'J', 'K', 'A'..'D', 's', 'u'}:
          inc i
        if i < content.len:
          inc i
        buf.add content[start..<i]
      else:
        let g = content.runeLenAt(i)
        buf.add content[i..<i+g]
        i += g
        inc taken
    buf.add "…"
    return buf
  else:
    let pad = width - visLen
    case align
    of Left:
      result = content & repeat(' ', pad)
    of Right:
      result = repeat(' ', pad) & content
    of Center:
      let leftPad = pad div 2
      let rightPad = pad - leftPad
      result = repeat(' ', leftPad) & content & repeat(' ', rightPad)

proc truncateToVisibleWidth(s: string, maxVisible: int): string =
  ## Truncate `s` to at most `maxVisible` visible graphemes
  ## Preserves ANSI sequences in the kept part
  if maxVisible <= 0:
    return ""
  var visibleCount = 0
  var i = 0
  while i < s.len and visibleCount < maxVisible:
    if s[i] == '\e':
      let start = i
      inc i
      var foundTerminator = false
      while i < s.len and s[i] notin {'m', 'H', 'J', 'K', 'A'..'D', 's', 'u'}:
        inc i
      if i < s.len:
        inc i
        foundTerminator = true
      if foundTerminator:
        result.add s[start..<i]
      else:
        i = start + 1
        result.add '\e'
        inc visibleCount
    else:
      let g = s.runeLenAt(i)
      result.add s[i..<i+g]
      i += g
      inc visibleCount
  if i < s.len:
    result.add "\e[0m"


# Public API

proc newTable*(): Table =
  ## Creates a new empty table
  Table(columns: @[], rows: @[])

proc addColumn*(t: Table, title: string = "", width: int = 0, align: Alignment = Left) =
  ## Adds a column definition
  ## - `title`: Column header (empty = no header)
  ## - `width`: Fixed width (0 = auto‑size to content)
  ## - `align`: Cell alignment (Left, Center, Right)
  if width < 0:
    raise newException(ValueError, "Column width cannot be negative")
  t.columns.add Column(title: title, width: width, align: align)

proc addRow*(t: Table, cells: seq[string]) =
  ## Adds a row of data. Cells are strings (pre‑format numbers, embed ANSI codes)
  t.rows.add cells

proc renderTable*(t: Table, separator = false, width: int = 0, outFile: File = stdout) =
  ## Renders the table to `outFile`
  ## If `width` > 0, it is used as maximum line width; otherwise terminal width is used
  ## If no columns were defined, they are automatically created based on the data
  let rawWidth = if width > 0: width else: terminalWidth()
  let termWidth = if rawWidth <= 0: 80 else: rawWidth

  # Auto‑create columns if none defined
  if t.columns.len == 0:
    if t.rows.len == 0:
      return
    var maxCols = 0
    for row in t.rows:
      if row.len > maxCols:
        maxCols = row.len
    if maxCols == 0:
      return
    for i in 0..<maxCols:
      t.columns.add Column(title: "", width: 0, align: Left)

  # 1. Determine effective column widths
  var colWidths = newSeq[int](t.columns.len)
  for i, col in t.columns:
    if col.width > 0:
      colWidths[i] = col.width
    else:
      var w = col.title.visibleLen()
      for row in t.rows:
        if i < row.len:
          let cellw = row[i].visibleLen()
          if cellw > w: w = cellw
      colWidths[i] = w

  # 2. Build separator strings
  let pipe = if separator: "|" else: ""
  let space = " "

  # 3. Compute line components
  var headerLine: string
  var separatorLine: string
  var cellLines: seq[string] = @[]

  # Build header line (only if any column has a title)
  var hasHeader = false
  for col in t.columns:
    if col.title.len > 0:
      hasHeader = true
      break

  if hasHeader:
    if separator:
      headerLine.add pipe & space
    for i, col in t.columns:
      let cell = formatCell(col.title, colWidths[i], col.align)
      headerLine.add cell
      if i < t.columns.high:
        headerLine.add space
        if separator:
          headerLine.add pipe & space
      else:
        if separator:
          headerLine.add space & pipe

  # Build header separator line if there is a header
  if hasHeader:
    if separator:
      separatorLine.add pipe
      for i, w in colWidths:
        separatorLine.add repeat('-', w + 2)
        if i < colWidths.high:
          separatorLine.add pipe
        else:
          separatorLine.add pipe
    else:
      for i, w in colWidths:
        separatorLine.add repeat('-', w)
        if i < colWidths.high:
          separatorLine.add " "

  # Build each data row line
  for row in t.rows:
    var line: string
    if separator:
      line.add pipe & space
    for i, col in t.columns:
      let cellContent = if i < row.len: row[i] else: ""
      let cell = formatCell(cellContent, colWidths[i], col.align)
      line.add cell
      if i < t.columns.high:
        line.add space
        if separator:
          line.add pipe & space
      else:
        if separator:
          line.add space & pipe
    cellLines.add line

  # 4. Truncate lines to terminal width
  proc truncateToTerminal(s: string): string =
    truncateToVisibleWidth(s, termWidth)

  # 5. Output
  if hasHeader:
    outFile.writeLine truncateToTerminal(headerLine)
    outFile.writeLine truncateToTerminal(separatorLine)
  for line in cellLines:
    outFile.writeLine truncateToTerminal(line)
