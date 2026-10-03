## tabulator: Nim library for generating plain-text tables
##            (with Unicode and ANSI code support)
## MIT © 2026 Eryk J

const Version* = "1.0.0"
  ## For checking the current version programmatically.

import
  std/[terminal, unicode, strutils]

type
  Alignment* = enum
    ## Cell alignment within its column.
    Left,   ## Text is left-padded (default).
    Center, ## Text is centred within the column width.
    Right,  ## Text is right-padded.

  Column = object
    title: string
    width: int
    align: Alignment

  Table* = ref object
    ## A rendered table. Create with `newTable`, populate with
    ## `addColumn` and `addRow`, output with `renderTable`.
    columns: seq[Column]
    rows: seq[seq[string]]


# ---------------------------------------------------------------------------
# ANSI helpers
# ---------------------------------------------------------------------------

proc ansiEnd(s: string, i: int): int =
  ## Given that `s[i] == '\e'`, return the index one past the end of the
  ## escape sequence starting at `i`. Returns `i` if the escape is not a
  ## recognised ANSI sequence - callers must treat "returned i" as
  ## "this ESC is a single visible grapheme, not an escape".
  if i + 1 >= s.len:
    return i
  case s[i + 1]
  of '[':
    # CSI: parameter bytes 0x30..0x3F, intermediate 0x20..0x2F, final 0x40..0x7E
    var j = i + 2
    while j < s.len and (s[j] in {'0'..'?', ' '..'/'}):
      inc j
    if j < s.len and s[j] in {'@'..'~'}:
      return j + 1
    return i
  of ']':
    # OSC: terminated by BEL (0x07) or ST (ESC \)
    var j = i + 2
    while j < s.len:
      if s[j] == '\a':
        return j + 1
      if s[j] == '\e' and j + 1 < s.len and s[j + 1] == '\\':
        return j + 2
      inc j
    return s.len   # unterminated OSC: consume the rest as metadata
  else:
    # Two-character escape (ESC 7, ESC =, ESC (, ESC ), ...)
    return i + 2


# ---------------------------------------------------------------------------
# Display-width helper
# ---------------------------------------------------------------------------

proc isZeroWidth(cp: int): bool =
  if cp < 0x0300: return false
  # Combining diacritics & marks
  if cp >= 0x0300 and cp <= 0x036F: return true
  if cp >= 0x0483 and cp <= 0x0489: return true
  if cp >= 0x0591 and cp <= 0x05BD: return true
  if cp == 0x05BF: return true
  if cp >= 0x05C1 and cp <= 0x05C2: return true
  if cp >= 0x05C4 and cp <= 0x05C5: return true
  if cp == 0x05C7: return true
  if cp >= 0x0610 and cp <= 0x061A: return true
  if cp >= 0x064B and cp <= 0x065F: return true
  if cp == 0x0670: return true
  if cp >= 0x06D6 and cp <= 0x06DC: return true
  if cp >= 0x06DF and cp <= 0x06E4: return true
  if cp >= 0x06E7 and cp <= 0x06E8: return true
  if cp >= 0x06EA and cp <= 0x06ED: return true
  if cp == 0x0711: return true
  if cp >= 0x0730 and cp <= 0x074A: return true
  if cp >= 0x07A6 and cp <= 0x07B0: return true
  if cp >= 0x07EB and cp <= 0x07F3: return true
  if cp >= 0x0816 and cp <= 0x0819: return true
  if cp >= 0x081B and cp <= 0x0823: return true
  if cp >= 0x0825 and cp <= 0x0827: return true
  if cp >= 0x0829 and cp <= 0x082D: return true
  if cp >= 0x0859 and cp <= 0x085B: return true
  if cp >= 0x08E3 and cp <= 0x0903: return true
  if cp >= 0x093A and cp <= 0x093C: return true
  if cp >= 0x0941 and cp <= 0x0948: return true
  if cp == 0x094D: return true
  if cp >= 0x0951 and cp <= 0x0957: return true
  if cp >= 0x0962 and cp <= 0x0963: return true
  if cp >= 0x1AB0 and cp <= 0x1AFF: return true
  if cp >= 0x1DC0 and cp <= 0x1DFF: return true
  if cp >= 0x20D0 and cp <= 0x20FF: return true
  if cp >= 0xFE00 and cp <= 0xFE0F: return true
  if cp >= 0xFE20 and cp <= 0xFE2F: return true
  # Zero-width space, ZWJ, ZWNJ, LRM/RLM, WJ
  if cp == 0x200B or cp == 0x200C or cp == 0x200D: return true
  if cp == 0x200E or cp == 0x200F or cp == 0x2060: return true
  # Hangul Jamo medial/final
  if cp >= 0x1160 and cp <= 0x11FF: return true
  if cp >= 0xD7B0 and cp <= 0xD7FF: return true
  # Emoji skin-tone modifiers (combine with the preceding emoji)
  if cp >= 0x1F3FB and cp <= 0x1F3FF: return true
  # Tag characters used in flag sequences
  if cp >= 0xE0020 and cp <= 0xE007F: return true
  return false

proc isWide(cp: int): bool =
  if cp < 0x1100: return false
  if cp >= 0x1100 and cp <= 0x115F: return true
  if cp >= 0x2E80 and cp <= 0x303E: return true
  if cp >= 0x3041 and cp <= 0x33FF: return true
  if cp >= 0x3400 and cp <= 0x4DBF: return true
  if cp >= 0x4E00 and cp <= 0x9FFF: return true
  if cp >= 0xA000 and cp <= 0xA4CF: return true
  if cp >= 0xAC00 and cp <= 0xD7A3: return true
  if cp >= 0xF900 and cp <= 0xFAFF: return true
  if cp >= 0xFE10 and cp <= 0xFE19: return true
  if cp >= 0xFE30 and cp <= 0xFE6F: return true
  if cp >= 0xFF00 and cp <= 0xFF60: return true
  if cp >= 0xFFE0 and cp <= 0xFFE6: return true
  if cp >= 0x1F300 and cp <= 0x1F64F: return true
  if cp >= 0x1F680 and cp <= 0x1F6FF: return true
  if cp >= 0x1F900 and cp <= 0x1F9FF: return true
  if cp >= 0x1F1E6 and cp <= 0x1F1FF: return true
  if cp >= 0x20000 and cp <= 0x2FFFD: return true
  if cp >= 0x30000 and cp <= 0x3FFFD: return true
  return false

proc runeWidth(cp: int): int =
  if isZeroWidth(cp): return 0
  if isWide(cp): return 2
  1

proc visibleLen(s: string): int =
  ## Display width of `s`, ignoring ANSI escapes. Uses a lightweight
  ## wcwidth approximation (see `runeWidth` above).
  var i = 0
  while i < s.len:
    if s[i] == '\e':
      let stop = ansiEnd(s, i)
      if stop > i:
        i = stop
        continue
      inc result
      inc i
    else:
      let g = s.runeLenAt(i)
      let cp = s.runeAt(i).int
      result += runeWidth(cp)
      i += g

proc stripAnsi(s: string): string =
  ## Remove all ANSI escape sequences from `s`.
  ## A bare/invalid ESC is preserved (it is not a sequence).
  var i = 0
  while i < s.len:
    if s[i] == '\e':
      let stop = ansiEnd(s, i)
      if stop > i:
        i = stop
      else:
        result.add '\e'
        inc i
    else:
      let g = s.runeLenAt(i)
      result.add s[i ..< i + g]
      i += g

proc truncate(s: string, maxVisible: int, addReset: bool = true): string =
  ## Truncate `s` to at most `maxVisible` display cells.
  if maxVisible <= 0:
    return ""
  var used = 0
  var i = 0
  var sawEscape = false
  while i < s.len and used < maxVisible:
    if s[i] == '\e':
      let stop = ansiEnd(s, i)
      if stop > i:
        result.add s[i ..< stop]
        sawEscape = true
        i = stop
      else:
        result.add '\e'
        inc used
        inc i
        sawEscape = true
    else:
      let g = s.runeLenAt(i)
      let cp = s.runeAt(i).int
      let w = runeWidth(cp)
      if used + w > maxVisible:
        break
      result.add s[i ..< i + g]
      used += w
      i += g
  if i < s.len and addReset and sawEscape:
    result.add "\e[0m"

proc formatCell(content: string, width: int, align: Alignment): string =
  ## Pad or truncate cell content to exactly `width` display cells.
  ## Keeps ANSI codes intact; callers strip them where appropriate.
  let visLen = content.visibleLen()
  if visLen == width:
    return content
  elif visLen > width:
    if width <= 0:
      return ""
    if width == 1:
      return "…"
    var used = 0
    var i = 0
    var buf = ""
    var sawEscape = false
    while i < content.len and used < width - 1:
      if content[i] == '\e':
        let stop = ansiEnd(content, i)
        if stop > i:
          buf.add content[i ..< stop]
          sawEscape = true
          i = stop
        else:
          buf.add '\e'
          inc used
          inc i
          sawEscape = true
      else:
        let g = content.runeLenAt(i)
        let cp = content.runeAt(i).int
        let w = runeWidth(cp)
        if used + w > width - 1:
          break
        buf.add content[i ..< i + g]
        used += w
        i += g
    buf.add "…"
    # Pad to `width` in case a wide char didn't fit and left a gap.
    if used + 1 < width:
      buf.add repeat(' ', width - used - 1)
    if sawEscape:
      buf.add "\e[0m"
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


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

proc overhead(n: int): int =
  ## Fixed horizontal overhead: leading " x", trailing " x", and
  ## " x┃x " between columns.
  result = 4
  if n > 1:
    result += (n - 1) * 3

proc computeColumnWidths(columns: seq[Column], rows: seq[seq[string]],
                         target: int): seq[int] =
  ## Return the final per-column widths, given a target total width
  ## (0 means "use natural width").
  ##
  ## Rules:
  ##   * fixed columns keep their exact width;
  ##   * auto columns start at their natural width
  ##     (max of title visible length and cell visible lengths);
  ##   * if target > 0, auto columns absorb the slack (grow) or the
  ##     shortfall (shrink) so the total width is exactly target.
  ##     Fixed columns never change.
  ##   * If fixed columns alone exceed target, target is a lower bound:
  ##     each auto column keeps its natural width.
  result = newSeq[int](columns.len)

  for i, col in columns:
    if col.width > 0:
      result[i] = col.width
    else:
      var w = col.title.visibleLen()
      for row in rows:
        if i < row.len:
          let cw = row[i].visibleLen()
          if cw > w: w = cw
      result[i] = max(1, w)

  if target <= 0:
    return

  let baseOverhead = overhead(columns.len)
  var fixedSum = 0
  var autoIndices: seq[int]
  for i, col in columns:
    if col.width > 0:
      fixedSum += result[i]
    else:
      autoIndices.add i

  var currentTotal = baseOverhead + fixedSum
  for i in autoIndices: currentTotal += result[i]

  if autoIndices.len == 0:
    return

  if fixedSum + baseOverhead >= target:
    return

  if currentTotal == target:
    return

  let autoBudget = target - baseOverhead - fixedSum
  var autoSum = 0
  for i in autoIndices: autoSum += result[i]

  if autoSum == autoBudget:
    return

  if autoSum < autoBudget:
    let extra = autoBudget - autoSum
    let per = extra div autoIndices.len
    let rem = extra mod autoIndices.len
    for j, idx in autoIndices:
      result[idx] += per
      if j < rem: inc result[idx]
  else:
    var assigned = 0
    for j, idx in autoIndices:
      if j == autoIndices.high:
        result[idx] = max(1, autoBudget - assigned)
      else:
        let share = (result[idx] * autoBudget) div autoSum
        result[idx] = max(1, share)
        assigned += result[idx]


# ---------------------------------------------------------------------------
# Rendering internals
# ---------------------------------------------------------------------------

proc prepareForFile(s: string, maxWidth: int, shouldTruncate: bool): string =
  ## Strip ANSI, optionally truncate, then strip trailing spaces (#1).
  result = stripAnsi(s)
  if shouldTruncate and result.visibleLen() > maxWidth:
    result = truncate(result, maxWidth, addReset = false)
  result = result.strip(leading = false, trailing = true)

proc renderToFile(t: Table, colWidths: seq[int], borderChar: string,
                  outFile: File) =
  ## File output: full table, no clipping, ANSI stripped, no trailing
  ## whitespace. `colWidths` already reflects any target width chosen by
  ## the caller; file output never re-clips.
  var hasHeader = false
  for col in t.columns:
    if col.title.len > 0:
      hasHeader = true
      break

  if borderChar == "┃":
    var topBorder = "┏"
    for i, w in colWidths:
      topBorder.add repeat("━", w + 2)
      topBorder.add (if i < colWidths.high: "┳" else: "┓")
    outFile.writeLine prepareForFile(topBorder, high(int), false)

  if hasHeader:
    var headerLine = borderChar & " "
    for i, col in t.columns:
      headerLine.add formatCell(col.title, colWidths[i], col.align)
      headerLine.add (if i < t.columns.high: " " & borderChar & " "
                      else: " " & borderChar)
    outFile.writeLine prepareForFile(headerLine, high(int), false)

    if borderChar == "┃":
      var sep = "┣"
      for i, w in colWidths:
        sep.add repeat("━", w + 2)
        sep.add (if i < colWidths.high: "╋" else: "┫")
      outFile.writeLine prepareForFile(sep, high(int), false)
    else:
      var sep = "  "
      for i, w in colWidths:
        sep.add repeat("─", w)
        if i < colWidths.high:
          sep.add "   "
      outFile.writeLine prepareForFile(sep, high(int), false)

  for row in t.rows:
    var line = borderChar & " "
    for i, col in t.columns:
      let cellContent = if i < row.len: row[i] else: ""
      line.add formatCell(cellContent, colWidths[i], col.align)
      line.add (if i < t.columns.high: " " & borderChar & " "
                else: " " & borderChar)
    outFile.writeLine prepareForFile(line, high(int), false)

  if borderChar == "┃":
    var bot = "┗"
    for i, w in colWidths:
      bot.add repeat("━", w + 2)
      bot.add (if i < colWidths.high: "┻" else: "┛")
    outFile.writeLine prepareForFile(bot, high(int), false)

proc renderToTerminal(t: Table, colWidths, colStarts: seq[int],
                      borderChar: string, clipWidth: int) =
  ## Terminal output: clip every line at `clipWidth` display cells.
  ## Clip is applied cell-by-cell; a cell that would exceed the boundary
  ## is truncated with `…`, and cells starting past the boundary are
  ## dropped along with their separators.
  proc writeAt(x: int, s: string) =
    if x >= clipWidth or s.len == 0:
      return
    let visible = s.visibleLen()
    if x + visible > clipWidth:
      let maxVisible = clipWidth - x
      if maxVisible > 0:
        setCursorXPos(x)
        stdout.write truncate(s, maxVisible, addReset = true)
    else:
      setCursorXPos(x)
      stdout.write s

  if borderChar == "┃":
    var line = "┏"
    for i, w in colWidths:
      line.add repeat("━", w + 2)
      line.add (if i < colWidths.high: "┳" else: "┓")
    writeAt(0, line)
    stdout.write "\n"

  var hasHeader = false
  for col in t.columns:
    if col.title.len > 0:
      hasHeader = true
      break

  if hasHeader:
    writeAt(0, borderChar)
    writeAt(1, " ")
    for i, col in t.columns:
      let borderX = colStarts[i] + colWidths[i]
      if colStarts[i] >= clipWidth: continue
      let cellStr = formatCell(col.title, colWidths[i], col.align)
      writeAt(colStarts[i], cellStr)
      if i < t.columns.high:
        if borderX + 2 < clipWidth:
          writeAt(borderX, " " & borderChar & " ")
      else:
        if borderX + 1 < clipWidth:
          writeAt(borderX, " " & borderChar)
    stdout.write "\n"

    if borderChar == "┃":
      var line = "┣"
      for i, w in colWidths:
        line.add repeat("━", w + 2)
        line.add (if i < colWidths.high: "╋" else: "┫")
      writeAt(0, line)
    else:
      writeAt(0, " ")
      writeAt(1, " ")
      for i, w in colWidths:
        if colStarts[i] >= clipWidth: continue
        writeAt(colStarts[i], repeat("─", w))
        if i < colWidths.high:
          writeAt(colStarts[i] + w, "   ")
    stdout.write "\n"

  for row in t.rows:
    writeAt(0, borderChar)
    writeAt(1, " ")
    for i, col in t.columns:
      let borderX = colStarts[i] + colWidths[i]
      if colStarts[i] >= clipWidth: continue
      let cellContent = if i < row.len: row[i] else: ""
      let cellStr = formatCell(cellContent, colWidths[i], col.align)
      writeAt(colStarts[i], cellStr)
      if i < t.columns.high:
        if borderX + 2 < clipWidth:
          writeAt(borderX, " " & borderChar & " ")
      else:
        if borderX + 1 < clipWidth:
          writeAt(borderX, " " & borderChar)
    stdout.write "\n"

  if borderChar == "┃":
    var line = "┗"
    for i, w in colWidths:
      line.add repeat("━", w + 2)
      line.add (if i < colWidths.high: "┻" else: "┛")
    writeAt(0, line)
    stdout.write "\n"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

proc newTable*(): Table =
  ## Create a new empty table.
  Table(columns: @[], rows: @[])

proc addColumn*(t: Table, title: string = "", width: int = 0,
                align: Alignment = Left) =
  ## Add a column definition.
  ## - `title`: Column header (may contain ANSI codes).
  ##   If ALL column titles are empty, no header row is printed.
  ## - `width`: Fixed width in display cells, or 0 for auto-size.
  ##   `1` produces "…" when content is longer; `2` produces "x…"; etc.
  ## - `align`: Cell alignment within the column.
  if width < 0:
    raise newException(ValueError, "Column width cannot be negative")
  t.columns.add Column(title: title, width: width, align: align)

proc addRow*(t: Table, cells: seq[string]) =
  ## Append a row of data. Cells may contain ANSI escape sequences.
  t.rows.add cells

proc renderTable*(t: Table, separator = false, width: int = 0,
                  outFile: File = stdout) =
  ## Render the table.
  ##
  ## - `separator`: if true, draw box-drawing borders between columns.
  ##
  ## - `width`: table width target.
  ##   * `0` (default) → natural width. Fixed columns keep their width;
  ##     auto columns size to content. On a terminal, if the natural
  ##     width exceeds the terminal width, auto columns are shrunk so
  ##     the table fits. A table is never stretched to fill the terminal.
  ##   * `> 0` → table is exactly that width (auto columns absorb slack
  ##     or shortfall). Fixed columns are never resized. If fixed
  ##     columns alone exceed `width`, the table overflows; terminal
  ##     output clips the overflow, file output keeps it.
  ##
  ## - `outFile`: destination (default `stdout`).
  ##
  ## Terminal vs. file:
  ##   * Terminal output is clipped at the terminal width, and never
  ##     exceeds `min(width, terminalWidth())` when `width > 0`.
  ##   * File output is not clipped; the file contains the whole table
  ##     at its laid-out width.

  let isTerminal = outFile == stdout and stdout.isatty

  var columns: seq[Column]
  if t.columns.len == 0:
    if t.rows.len == 0:
      return
    var maxCols = 0
    for row in t.rows:
      if row.len > maxCols: maxCols = row.len
    if maxCols == 0:
      return
    columns = newSeq[Column](maxCols)
    for i in 0 ..< maxCols:
      columns[i] = Column(title: "", width: 0, align: Left)
  else:
    columns = t.columns

  # -- Pick the layout target.
  #  target == 0 means "natural width".
  #  On a terminal, if `width` is not set and the natural layout would
  #  exceed the terminal, cap at the terminal width so the table fits.
  #  We never stretch a table to fill the terminal: natural width wins
  #  unless the terminal forces a shrink.
  var target = width
  var clipWidth = 0
  if isTerminal:
    let tw = terminalWidth()
    let term = if tw > 0: tw else: 80
    clipWidth = term
    if target == 0:
      var natural = 4
      for i, col in columns:
        if col.width > 0:
          natural += col.width
        else:
          var w = col.title.visibleLen()
          for row in t.rows:
            if i < row.len:
              let cw = row[i].visibleLen()
              if cw > w: w = cw
          natural += max(1, w)
        if i < columns.high:
          natural += 3
      if natural > term:
        target = term

  let colWidths = computeColumnWidths(columns, t.rows, target)

  var colStarts = newSeq[int](columns.len)
  var currentX = 2
  for i, w in colWidths:
    colStarts[i] = currentX
    currentX += w
    if i < columns.high:
      currentX += 3
    else:
      currentX += 2

  let borderChar = if separator: "┃" else: " "
  let view = Table(columns: columns, rows: t.rows)

  if isTerminal:
    renderToTerminal(view, colWidths, colStarts, borderChar, clipWidth)
  else:
    renderToFile(view, colWidths, borderChar, outFile)