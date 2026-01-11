## tabulator: Nim library for generating plain-text tables
##            (with Unicode and ANSI code support)
## MIT © 2026 Eryk J

const
  Version* = "0.7.0"

import
  std/[terminal, unicode, strutils, math]

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
  ## Return number of graphemes in `s`, ignoring ANSI escape sequences
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

proc truncate(s: string, maxVisible: int, addReset: bool = true): string =
  ## Truncate `s` to at most `maxVisible` visible graphemes
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
  if i < s.len and addReset:
    result.add "\e[0m"

proc stripAnsi(s: string): string =
  ## Remove all ANSI escape sequences from `s`
  var i = 0
  while i < s.len:
    if s[i] == '\e':
      inc i
      while i < s.len and s[i] notin {'m', 'H', 'J', 'K', 'A'..'D', 's', 'u'}:
        inc i
      if i < s.len:
        inc i
    else:
      result.add s[i]
      inc i

proc renderToFile(t: Table, colWidths, colStarts: seq[int], borderChar: string, width: int, outFile: File) =
  let shouldTruncate = width > 0
  let maxWidth = if shouldTruncate: width else: high(int)

  proc prepareForFile(s: string): string =
    result = stripAnsi(s)
    if shouldTruncate:
      result = truncate(result, maxWidth, addReset = false)

  # Top border if borderChar is "┃"
  var topBorder: string
  if borderChar == "┃":
    topBorder.add "┏"
    for i, w in colWidths:
      topBorder.add repeat("━", w + 2)
      if i < colWidths.high:
        topBorder.add "┳"
      else:
        topBorder.add "┓"

  # Determine if there's a header
  var hasHeader = false
  for col in t.columns:
    if col.title.len > 0:
      hasHeader = true
      break

  # Header line
  var headerLine: string
  if hasHeader:
    headerLine.add borderChar & " "
    for i, col in t.columns:
      let cell = formatCell(col.title, colWidths[i], col.align)
      headerLine.add cell
      if i < t.columns.high:
        headerLine.add " " & borderChar & " "
      else:
        headerLine.add " " & borderChar

  # Header separator line
  var separatorLine: string
  if hasHeader:
    if borderChar == "┃":
      separatorLine.add "┣"
      for i, w in colWidths:
        separatorLine.add repeat("━", w + 2)
        if i < colWidths.high:
          separatorLine.add "╋"
        else:
          separatorLine.add "┫"
    else:
      separatorLine.add "  "
      for i, w in colWidths:
        separatorLine.add repeat("─", w)
        if i < colWidths.high:
          separatorLine.add "   "

  # Data rows
  var cellLines: seq[string] = @[]
  for row in t.rows:
    var line = borderChar & " "
    for i, col in t.columns:
      let cellContent = if i < row.len: row[i] else: ""
      let cell = formatCell(cellContent, colWidths[i], col.align)
      line.add cell
      if i < t.columns.high:
        line.add " " & borderChar & " "
      else:
        line.add " " & borderChar
    cellLines.add line

  # Bottom border if borderChar is "┃"
  var bottomBorder: string
  if borderChar == "┃":
    bottomBorder.add "┗"
    for i, w in colWidths:
      bottomBorder.add repeat("━", w + 2)
      if i < colWidths.high:
        bottomBorder.add "┻"
      else:
        bottomBorder.add "┛"

  # Output
  if borderChar == "┃":
    outFile.writeLine prepareForFile(topBorder)
  if hasHeader:
    outFile.writeLine prepareForFile(headerLine)
    outFile.writeLine prepareForFile(separatorLine)
  for line in cellLines:
    outFile.writeLine prepareForFile(line)
  if borderChar == "┃":
    outFile.writeLine prepareForFile(bottomBorder)

proc renderToTerminal(t: Table, colWidths, colStarts: seq[int], borderChar: string, termWidth: int, rightBorderX: int) =
  ## Render table directly to terminal using cursor positioning
  ## Each cell is printed at its precise column position for correct Unicode handling

  proc writeAt(x: int, s: string) =
    if x >= termWidth:
      return
    let visible = s.visibleLen()
    if x + visible > termWidth:
      let maxVisible = termWidth - x
      if maxVisible > 0:
        setCursorXPos(x)
        stdout.write truncate(s, maxVisible, addReset = true)
    else:
      setCursorXPos(x)
      stdout.write s

  # Top border if borderChar is "┃"
  if borderChar == "┃":
    var line = "┏"
    for i, w in colWidths:
      line.add repeat("━", w + 2)
      if i < colWidths.high:
        line.add "┳"
      else:
        line.add "┓"
    writeAt(0, line)
    stdout.write "\n"

  # Determine if there's a header
  var hasHeader = false
  for col in t.columns:
    if col.title.len > 0:
      hasHeader = true
      break

  # Header line
  if hasHeader:
    writeAt(0, borderChar)
    writeAt(1, " ")
    for i, col in t.columns:
      if colStarts[i] >= termWidth:
        continue
      let cellStr = formatCell(col.title, colWidths[i], col.align)
      writeAt(colStarts[i], cellStr)
      let sepPos = colStarts[i] + colWidths[i]
      if i < t.columns.high:
        if sepPos + 2 < termWidth:
          writeAt(sepPos, " " & borderChar & " ")
      else:
        if rightBorderX < termWidth:
          writeAt(sepPos, " " & borderChar)
    stdout.write "\n"

  # Header separator line
  if hasHeader:
    if borderChar == "┃":
      var line = "┣"
      for i, w in colWidths:
        line.add repeat("━", w + 2)
        if i < colWidths.high:
          line.add "╋"
        else:
          line.add "┫"
      writeAt(0, line)
    else:
      writeAt(0, " ")
      writeAt(1, " ")
      for i, w in colWidths:
        if colStarts[i] >= termWidth:
          continue
        writeAt(colStarts[i], repeat("─", w))
        if i < colWidths.high:
          writeAt(colStarts[i] + w, "   ")
    stdout.write "\n"

  # Data rows
  for row in t.rows:
    writeAt(0, borderChar)
    writeAt(1, " ")
    for i, col in t.columns:
      if colStarts[i] >= termWidth:
        continue
      let cellContent = if i < row.len: row[i] else: ""
      let cellStr = formatCell(cellContent, colWidths[i], col.align)
      writeAt(colStarts[i], cellStr)
      let sepPos = colStarts[i] + colWidths[i]
      if i < t.columns.high:
        if sepPos + 2 < termWidth:
          writeAt(sepPos, " " & borderChar & " ")
      else:
        if rightBorderX < termWidth:
          writeAt(sepPos, " " & borderChar)
    stdout.write "\n"

  # Bottom border if borderChar is "┃"
  if borderChar == "┃":
    var line = "┗"
    for i, w in colWidths:
      line.add repeat("━", w + 2)
      if i < colWidths.high:
        line.add "┻"
      else:
        line.add "┛"
    writeAt(0, line)
    stdout.write "\n"


# Public API

proc newTable*(): Table =
  ## Create a new empty table
  Table(columns: @[], rows: @[])

proc addColumn*(t: Table, title: string = "", width: int = 0, align: Alignment = Left) =
  ## Add a column definition
  ## - `title`: Column header (pre‑format with embedded ANSI codes)
  ##   - if ALL column titles are empty = no header
  ## - `width`: Fixed width (0 = auto‑size to content)
  ## - `align`: Cell alignment (Left, Center, Right)
  if width < 0:
    raise newException(ValueError, "Column width cannot be negative")
  t.columns.add Column(title: title, width: width, align: align)

proc addRow*(t: Table, cells: seq[string]) =
  ## Add a row of data; cells are strings (pre‑format numbers, embed ANSI codes)
  t.rows.add cells

proc renderTable*(t: Table, separator = false, width: int = 0, outFile: File = stdout) =
  ## Render the table
  ## - `separator`: If true, adds box‑drawing borders between columns
  ## - `width`: Maximum table width (0 = use terminal width for terminal, no limit for files)
  ## - `outFile`: Output file (default stdout)
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

  if width > 0:
    var currentTotal = 0
    currentTotal += 2
    for w in colWidths:
      currentTotal += w
    if t.columns.len > 1:
      currentTotal += (t.columns.len - 1) * 3
    currentTotal += 2

    if width > currentTotal:
      let extra = width - currentTotal
      var autoIndices: seq[int]
      for i, col in t.columns:
        if col.width == 0:
          autoIndices.add i
      if autoIndices.len > 0:
        let perColumn = extra div autoIndices.len
        let remainder = extra mod autoIndices.len
        for j, idx in autoIndices:
          colWidths[idx] += perColumn
          if j < remainder:
            colWidths[idx] += 1

  var colStarts = newSeq[int](t.columns.len)
  var rightBorderX = 0
  var currentX = 2
  for i, w in colWidths:
    colStarts[i] = currentX
    currentX += w
    if i < t.columns.high:
      currentX += 3
    else:
      currentX += 2
      rightBorderX = currentX - 1

  let borderChar = if separator: "┃" else: " "

  if outFile == stdout and stdout.isatty:
    let effectiveWidth = if width > 0: width else: terminalWidth()
    let termWidth = if effectiveWidth <= 0: 80 else: effectiveWidth
    renderToTerminal(t, colWidths, colStarts, borderChar, termWidth, rightBorderX)
  else:
    renderToFile(t, colWidths, colStarts, borderChar, width, outFile)