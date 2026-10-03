## test.nim — comprehensive exercise of tabulator.
##
## Each test prints:
##   ── TEST N: short title ──
##   WHAT:   what is being tested
##   EXPECT: what you should see if it works
## Then it runs the check and prints PASS or raises AssertionDefect.
##
## Visual tests additionally render their table to your terminal so you
## can confirm the description matches what you see.

import ../src/tabulator
import std/[terminal, strutils, os]

block:
  let f = open("tabulator_test.txt", fmWrite)
  defer: f.close()

  echo "Terminal width: ", terminalWidth()

  # -------------------------------------------------------------------
  # Capture helper (used by the assertion tests) — writes to a temp
  # file and reads the bytes back, so we test the file-output path.
  # -------------------------------------------------------------------
  var captureCounter = 0
  proc capture(t: Table, separator: bool, width = 0): string =
    inc captureCounter
    let tmp = "tabulator_capture_" & $captureCounter & ".tmp"
    let h = open(tmp, fmWrite)
    t.renderTable(separator = separator, width = width, outFile = h)
    h.close()
    result = readFile(tmp)
    removeFile(tmp)

  proc show(id, what, expect: string) =
    echo ""
    echo "── ", id, " ──"
    echo "WHAT:   ", what
    echo "EXPECT: ", expect

  # ===================================================================
  # ANSI SCANNER
  # ===================================================================

  show("TEST 1: SGR escape sequences",
       "visibleLen of a red-styled 'red' string.",
       "3 — only the letters r, e, d count; the escapes are invisible.")
  doAssert visibleLen("\e[31mred\e[0m") == 3
  echo "PASS"

  show("TEST 2: Cursor-movement escapes",
       "visibleLen of 'a' + cursor-up escape + 'b'.",
       "2 — the escape contributes zero visible width.")
  doAssert visibleLen("a\e[2Ab") == 2
  echo "PASS"

  show("TEST 3: OSC hyperlink, ST terminator",
       "visibleLen of an OSC 8 hyperlink around the word 'link'.",
       "4 — the word 'link'. OSC wrappers are invisible.")
  doAssert visibleLen("\e]8;;http://x\e\\link\e]8;;\e\\") == 4
  echo "PASS"

  show("TEST 4: OSC hyperlink, BEL terminator",
       "Same as test 3 but terminated with BEL (0x07).",
       "4 — same result as ST-terminated OSC.")
  doAssert visibleLen("\e]8;;http://x\alink\e]8;;\a") == 4
  echo "PASS"

  show("TEST 5: Bare ESC byte",
       "A lone ESC with no following sequence.",
       "1 — a malformed ESC counts as one visible cell, not zero.")
  doAssert visibleLen("\e") == 1
  echo "PASS"

  show("TEST 6: Multiple SGRs in a row",
       "Two escapes (bold, red) then 'boldred', then reset.",
       "7 — the visible text is 7 letters.")
  doAssert visibleLen("\e[1m\e[31mboldred\e[0m") == 7
  echo "PASS"

  show("TEST 7: stripAnsi removes SGR",
       "stripAnsi on bold 'Bold' plus ' plain'.",
       "'Bold plain' — no escapes left.")
  doAssert stripAnsi("\e[1mBold\e[0m plain") == "Bold plain"
  echo "PASS"

  show("TEST 8: stripAnsi removes OSC",
       "stripAnsi on text with a hyperlink-wrapped 'x'.",
       "'before x after' — OSC bytes removed.")
  doAssert stripAnsi("before \e]8;;url\e\\x\e]8;;\e\\ after") == "before x after"
  echo "PASS"

  show("TEST 9: stripAnsi removes mid-string SGR",
       "The letters 'ab' with bold-red applied only to 'b'.",
       "'ab'.")
  doAssert stripAnsi("a\e[1m\e[31mb\e[0m") == "ab"
  echo "PASS"

  # ===================================================================
  # DISPLAY WIDTH
  # ===================================================================

  show("TEST 10: CJK width",
       "visibleLen of '中文'.",
       "4 — each Han character is 2 cells wide.")
  doAssert visibleLen("中文") == 4
  echo "PASS"

  show("TEST 11: Fullwidth Latin width",
       "visibleLen of 'ＡＢ' (fullwidth forms).",
       "4 — fullwidth ASCII is 2 cells per character.")
  doAssert visibleLen("ＡＢ") == 4
  echo "PASS"

  show("TEST 12: Emoji width",
       "visibleLen of a grinning emoji.",
       "2 — most terminals render emoji at double width.")
  doAssert visibleLen("😀") == 2
  echo "PASS"

  show("TEST 13: Combining mark width",
       "'e' followed by a combining acute accent.",
       "1 — the accent adds no width.")
  doAssert visibleLen("e\u0301") == 1
  echo "PASS"

  show("TEST 14: Zero-width joiner",
       "'a' + ZWJ + 'b'.",
       "2 — the ZWJ is invisible.")
  doAssert visibleLen("a\u200Db") == 2
  echo "PASS"

  show("TEST 15: ANSI + CJK combined",
       "Red-styled '中文'.",
       "4 — the escapes add nothing.")
  doAssert visibleLen("\e[31m中文\e[0m") == 4
  echo "PASS"

  # ===================================================================
  # ALIGNMENT — visual + assertion
  # ===================================================================

  show("TEST 16: Left / Center / Right alignment",
       "Three 5-wide columns, each holding a single 'x', with Left, " &
       "Center, Right alignment respectively.",
       "Below: 'x' is at the LEFT of col 1, CENTER of col 2, RIGHT of col 3.")
  block:
    var ta = newTable()
    ta.addColumn("L", width = 5, align = Alignment.Left)
    ta.addColumn("C", width = 5, align = Alignment.Center)
    ta.addColumn("R", width = 5, align = Alignment.Right)
    ta.addRow(@["x", "x", "x"])
    ta.renderTable(separator = true)
    let s = capture(ta, separator = true)
    let data = s.strip().splitLines()[3]
    let parts = data.split("┃")
    let leftCell  = parts[1][1 .. ^2]
    let centCell  = parts[2][1 .. ^2]
    let rightCell = parts[3][1 .. ^2]
    doAssert leftCell == "x    ", "left:  [" & leftCell & "]"
    doAssert centCell == "  x  ", "center:[" & centCell & "]"
    doAssert rightCell == "    x", "right: [" & rightCell & "]"
    echo "PASS"

  # ===================================================================
  # separator = false
  # ===================================================================

  show("TEST 17: separator=false rendering",
       "Two-column table with separator=false: right-aligned '1', " &
       "left-aligned 'hello'. Header is 'A' (right) and 'B' (left).",
       "Below: no box glyphs. Data row contains 'hello'. No trailing " &
       "whitespace. Header and data are NOT asserted to have equal width, " &
       "because with no right border, the line width depends on the " &
       "last cell's content.")
  block:
    var tb = newTable()
    tb.addColumn("A", width = 6, align = Alignment.Right)
    tb.addColumn("B", width = 8)
    tb.addRow(@["1", "hello"])
    tb.renderTable(separator = false)
    let s = capture(tb, separator = false)
    let lines = s.strip().splitLines()
    doAssert lines.len == 3, "expected 3 lines, got " & $lines.len
    doAssert lines[2].contains("hello")
    # No trailing whitespace on any line.
    for line in lines:
      if line.len > 0:
        doAssert line[^1] != ' ', "trailing space: [" & line & "]"
    echo "PASS"

  # ===================================================================
  # TRUNCATION
  # ===================================================================

  show("TEST 18: Truncation marker in file output",
       "A 5-wide column with 'hello world' (styled red) and a 6-wide " &
       "column with 'short'.",
       "Below: ellipsis appears in the truncated cell. No ANSI codes in " &
       "the file output. Header and data rows have equal display width.")
  block:
    var tc = newTable()
    tc.addColumn("A", width = 5)
    tc.addColumn("B", width = 6)
    tc.addRow(@["\e[31mhello world", "short"])
    tc.renderTable(separator = true)
    let s = capture(tc, separator = true)
    doAssert s.contains("…")
    doAssert not s.contains("\e[")
    let lines = s.strip().splitLines()
    doAssert visibleLen(lines[1]) == visibleLen(lines[3])
    echo "PASS"

  show("TEST 19+20: Extremely narrow columns",
       "Column A is 1 wide with 'hello'. Column B is 2 wide with 'world'.",
       "Below: column A shows just '…'. Column B shows 'w…'.")
  block:
    var tt = newTable()
    tt.addColumn("A", width = 1)
    tt.addColumn("B", width = 2)
    tt.addRow(@["hello", "world"])
    tt.renderTable(separator = true)
    let s = capture(tt, separator = true)
    let data = s.strip().splitLines()[3]
    doAssert data.contains("┃ … ┃"), "got: [" & data & "]"
    doAssert data.contains("w…"),    "got: [" & data & "]"
    echo "PASS"

  show("TEST 21: Compound SGR stripped in file output",
       "Bold-red 'hello' in a 4-wide column.",
       "Below: output contains 'hel…'. No ESC bytes.")
  block:
    var tm = newTable()
    tm.addColumn("A", width = 4)
    tm.addRow(@["\e[1m\e[31mhello\e[0m"])
    tm.renderTable(separator = true)
    let s = capture(tm, separator = true)
    doAssert not s.contains("\e[")
    doAssert s.contains("hel…"), "got: " & s
    echo "PASS"

  # ===================================================================
  # SHORT AND LONG ROWS
  # ===================================================================

  show("TEST 22: Short rows pad with blanks",
       "3-column table. Row 1 supplies only 1 cell; row 2 supplies 5 cells.",
       "Below: row 1 shows 'only-one' in col 1, blanks in cols 2-3. " &
       "Row 2 shows a, b, c but NOT d or e (extras dropped).")
  block:
    var ts = newTable()
    ts.addColumn("A")
    ts.addColumn("B")
    ts.addColumn("C")
    ts.addRow(@["only-one"])
    ts.addRow(@["a", "b", "c", "d", "e"])
    ts.renderTable(separator = true)
    let s = capture(ts, separator = true)
    let lines = s.strip().splitLines()
    doAssert lines.len == 6
    doAssert lines[3].contains("only-one")
    doAssert lines[4].contains("c")
    doAssert not lines[4].contains("d")
    doAssert not lines[4].contains("e")
    echo "PASS"

  # ===================================================================
  # EMPTY CELLS
  # ===================================================================

  show("TEST 23: All-empty row",
       "2-column table, one row of two empty strings.",
       "Below: renders without crash. Column widths fall back to header " &
       "width or minimum 1. Exactly 5 lines.")
  block:
    var te = newTable()
    te.addColumn("A")
    te.addColumn("B")
    te.addRow(@["", ""])
    te.renderTable(separator = true)
    let s = capture(te, separator = true)
    doAssert s.len > 0
    let lines = s.strip().splitLines()
    doAssert lines.len == 5, "expected 5 lines, got " & $lines.len
    echo "PASS"

  # ===================================================================
  # CJK
  # ===================================================================

  show("TEST 24: CJK truncation never splits a glyph",
       "A 4-wide column with '中文字符' (8 display cells of CJK).",
       "Below: the cell contains '中' (2 cells) + '…' + padding = 4 cells. " &
       "No half-glyph. Ellipsis present.")
  block:
    var tj = newTable()
    tj.addColumn("A", width = 4)
    tj.addRow(@["中文字符"])
    tj.renderTable(separator = true)
    let s = capture(tj, separator = true)
    let data = s.strip().splitLines()[3]
    let cell = data.split("┃")[1][1 .. ^2]
    doAssert visibleLen(cell) == 4, "cell width " & $visibleLen(cell)
    doAssert cell.contains("中"), "missing 中: [" & cell & "]"
    doAssert cell.contains("…"), "missing ellipsis: [" & cell & "]"
    # Confirm no half-glyph: cell content should not start with a byte
    # fragment of 中 or 文.
    doAssert cell.startsWith("中"), "cell doesn't start cleanly: [" & cell & "]"
    echo "PASS"

  show("TEST 25: Wide-char header truncation",
       "A 4-wide column whose header is '中文名字长' (5 CJK chars = 10 cells).",
       "Below: header is truncated with an ellipsis.")
  block:
    var th = newTable()
    th.addColumn("中文名字长", width = 4)
    th.addRow(@["x"])
    th.renderTable(separator = true)
    let s = capture(th, separator = true)
    doAssert s.contains("…"), "no ellipsis in output"
    echo "PASS"

  show("TEST 26: CJK row alignment",
       "Two rows: one with '中文名', one with 'ab'. Same right-aligned Qty.",
       "Below: both data rows have identical display width.")
  block:
    var tcj = newTable()
    tcj.addColumn("Name")
    tcj.addColumn("Qty", align = Alignment.Right)
    tcj.addRow(@["中文名", "1"])
    tcj.addRow(@["ab", "22"])
    tcj.renderTable(separator = true)
    let s = capture(tcj, separator = true)
    let lines = s.strip().splitLines()
    doAssert visibleLen(lines[3]) == visibleLen(lines[4])
    echo "PASS"

  # ===================================================================
  # EDGE CASES
  # ===================================================================

  show("TEST 27: Negative column width raises",
       "addColumn(width = -1).",
       "ValueError raised. No table produced.")
  block:
    var tn = newTable()
    var raised = false
    try:
      tn.addColumn("X", width = -1)
    except ValueError:
      raised = true
    doAssert raised
    echo "PASS"

  show("TEST 28: Fully empty table",
       "A table with no columns and no rows.",
       "renderTable returns without output; captured string is empty.")
  block:
    var t0 = newTable()
    let s = capture(t0, separator = true)
    doAssert s.len == 0
    echo "PASS"

  show("TEST 29: Table with headers but no rows",
       "Two columns, no data rows.",
       "Below: renders header, separator, and borders. No data rows.")
  block:
    var t4 = newTable()
    t4.addColumn("Empty", width = 10)
    t4.addColumn("Table")
    t4.renderTable(separator = true)
    t4.renderTable(separator = false)
    echo "PASS"

  show("TEST 30: Bare ESC doesn't loop",
       "A cell containing just a bare ESC byte, plus a normal row.",
       "Below: renders without hanging. The bare-ESC cell may appear blank.")
  block:
    var t10 = newTable()
    t10.addColumn("X")
    t10.addRow(@["\e"])
    t10.addRow(@["after"])
    t10.renderTable(separator = true)
    discard capture(t10, separator = true)
    echo "PASS"

  # ===================================================================
  # WIDTH TARGETS
  # ===================================================================

  show("TEST 31: File output width is exact",
       "Two auto columns; render to file with width = 30, 47, 60, 100.",
       "File width equals the target exactly. 47 is the natural width.")
  block:
    var tw = newTable()
    tw.addColumn("Auto A")
    tw.addColumn("Auto B")
    tw.addRow(@["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb"])
    let natural = capture(tw, separator = true, width = 0)
    doAssert visibleLen(natural.splitLines()[0]) == 47,
      "natural width " & $visibleLen(natural.splitLines()[0])
    for target in [30, 60, 100]:
      let s = capture(tw, separator = true, width = target)
      doAssert visibleLen(s.splitLines()[0]) == target,
        "width=" & $target & " gave " & $visibleLen(s.splitLines()[0])
    echo "PASS"

  show("TEST 32: Fixed columns keep their width; auto columns absorb slack",
       "Column 0 fixed at 10, column 1 auto. Render to file with width = 40.",
       "File width is exactly 40. Column 0 is exactly 10 cells ('hello' " &
       "padded to 10). Auto column absorbs the remaining 23 cells.")
  block:
    var tf = newTable()
    tf.addColumn("Fixed", width = 10)
    tf.addColumn("Auto")
    tf.addRow(@["hello", "world"])
    let s40 = capture(tf, separator = true, width = 40)
    doAssert visibleLen(s40.splitLines()[0]) == 40
    let data = s40.strip().splitLines()[3]
    let fixedCell = data.split("┃")[1][1 .. ^2]
    doAssert fixedCell == "hello     ", "[" & fixedCell & "]"
    echo "PASS"

  show("TEST 33: All-fixed table doesn't stretch",
       "Two fixed 5-wide columns. Render to file with width = 0.",
       "File width is natural (17 cells): 1 + 7 + 1 + 7 + 1. Not stretched.")
  block:
    var tfx = newTable()
    tfx.addColumn("A", width = 5)
    tfx.addColumn("B", width = 5)
    tfx.addRow(@["x", "y"])
    let s = capture(tfx, separator = true, width = 0)
    doAssert visibleLen(s.splitLines()[0]) == 17,
      "got " & $visibleLen(s.splitLines()[0])
    echo "PASS"

  show("TEST 34: Fixed columns over target overflow",
       "Two fixed 20-wide columns. Render to file with width = 10.",
       "File width is 47 (fixed widths win). Target 10 is ignored.")
  block:
    var tov = newTable()
    tov.addColumn("A", width = 20)
    tov.addColumn("B", width = 20)
    tov.addRow(@["x", "y"])
    let s = capture(tov, separator = true, width = 10)
    doAssert visibleLen(s.splitLines()[0]) == 47,
      "got " & $visibleLen(s.splitLines()[0])
    echo "PASS"

  show("TEST 35: width < overhead doesn't crash",
       "Three auto columns, render to file with width = 4 (below overhead).",
       "Produces output. No crash. Exact width is whatever the fallback " &
       "produces; we only check it's non-empty.")
  block:
    var to = newTable()
    to.addColumn("A")
    to.addColumn("B")
    to.addColumn("C")
    to.addRow(@["x", "y", "z"])
    let s = capture(to, separator = true, width = 4)
    doAssert s.len > 0
    echo "PASS (observed width: ", visibleLen(s.splitLines()[0]), ")"

  # ===================================================================
  # NON-MUTATION
  # ===================================================================

  show("TEST 36: Column inference is non-mutating and stable",
       "A table with rows but no columns, rendered twice, then a real " &
       "column added.",
       "First two renders are byte-identical. After addColumn('Late'), " &
       "the output contains 'Late' and no ghost columns.")
  block:
    var t6 = newTable()
    t6.addRow(@["Works", "without", "columns", "defined"])
    t6.addRow(@["Columns", "created", "automatically"])
    let a = capture(t6, separator = true, width = 40)
    let b = capture(t6, separator = true, width = 40)
    doAssert a == b
    t6.addColumn("Late")
    let c = capture(t6, separator = true, width = 40)
    doAssert c.contains("Late")
    doAssert not c.contains("defined")
    echo "PASS"

  # ===================================================================
  # TRAILING WHITESPACE
  # ===================================================================

  show("TEST 37: File output has no trailing whitespace",
       "A 2-column table with separator=false.",
       "Every non-empty line ends with a non-space character.")
  block:
    var t1 = newTable()
    t1.addColumn("A")
    t1.addColumn("B")
    t1.addRow(@["x", "y"])
    let s = capture(t1, separator = false)
    for line in s.splitLines():
      if line.len > 0:
        doAssert line[^1] != ' '
    echo "PASS"

  # ===================================================================
  # SEPARATOR LINE COUNTS
  # ===================================================================

  show("TEST 38: Line counts with/without box",
       "Two rows, two columns, rendered with separator=true then false.",
       "With box: 6 lines (top, header, sep, 2 data, bottom). Without: " &
       "4 lines (header, sep, 2 data).")
  block:
    var tsep = newTable()
    tsep.addColumn("A")
    tsep.addColumn("B")
    tsep.addRow(@["1", "2"])
    tsep.addRow(@["3", "4"])
    let withBox = capture(tsep, separator = true)
    let noBox   = capture(tsep, separator = false)
    doAssert withBox.strip().splitLines().len == 6
    doAssert noBox.strip().splitLines().len == 4
    echo "PASS"

  # ===================================================================
  # EMOJI MODIFIER — INFORMATIONAL
  # ===================================================================

  show("TEST 39: Emoji with skin-tone modifier",
       "visibleLen of a single thumbs-up emoji + skin-tone modifier " &
       "(two code points, one grapheme).",
       "2 — the skin tone combines with the emoji, adding no width.")
  block:
    doAssert visibleLen("👍🏽") == 2,
      "got " & $visibleLen("👍🏽")
    # Sanity: without the modifier, still 2.
    doAssert visibleLen("👍") == 2
    # Sanity: ZWJ sequence (e.g. family emoji) — count as one or more
    # graphemes, but visibleLen should be at least 2 and not wildly off.
    # Not asserted precisely here.
    echo "PASS"

  show("TEST 40: Tag-character flag sequence",
       "visibleLen of the Scotland flag emoji (base + tag characters).",
       "2 — the tag characters are zero-width, only the base flag counts.")
  block:
    # 🏴 + U+E0067 U+E0062 U+E0073 U+E0063 U+E0074 U+E007F
    let scotland = "🏴\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}"
    doAssert visibleLen(scotland) == 2,
      "got " & $visibleLen(scotland)
    echo "PASS"

  # ===================================================================
  # VISUAL: FULL TABLE
  # ===================================================================

  show("VISUAL 1: Full 10-column table, natural width, terminal",
       "Ten columns including fixed, auto, CJK-shaped stars, styled cells.",
       "Borders contiguous. Header centered. Right-aligned numerics line " &
       "up. 'In Stock' green, 'Out of Stock' red, 'Limited' yellow. " &
       "Stars render as ★ or ☆. Right border present.")
  var t = newTable()
  t.addColumn("ID", width = 4, align = Alignment.Right)
  t.addColumn("\e[1mProduct Name\e[0m", width = 20)
  t.addColumn("Category", width = 12)
  t.addColumn("Supplier")
  t.addColumn("Price USD", align = Alignment.Right)
  t.addColumn("Qty", align = Alignment.Center)
  t.addColumn("Weight (kg)", align = Alignment.Right)
  t.addColumn("Last Updated")
  t.addColumn("Status")
  t.addColumn("Rating", align = Alignment.Center)
  t.addRow(@["001", "Organic Apples", "Fruit", "Fresh Farms Inc.", "2.50", "150", "1.2", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★★☆"])
  t.addRow(@["002", "Bananas Fair Trade", "Fruit", "Tropical Imports", "1.20", "75", "0.8", "2024-03-14", "\e[32mIn Stock\e[0m", "★★★☆☆"])
  t.addRow(@["003", "Artisanal Bread", "Bakery", "Local Bakery Co.", "5.99", "23", "0.5", "2024-03-15", "\e[33mLimited\e[0m", "★★★★★"])
  t.addRow(@["004", "Extra Virgin Olive Oil", "Condiments", "Mediterranean Goods", "12.99", "42", "0.75", "2024-03-13", "\e[32mIn Stock\e[0m", "★★★★☆"])
  t.addRow(@["005", "Greek Yogurt", "Dairy", "Dairy Fresh Ltd.", "3.49", "89", "0.45", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★☆☆"])
  t.addRow(@["006", "Free-Range Eggs (12)", "Dairy", "Happy Hens Farm", "4.99", "34", "0.7", "2024-03-14", "\e[31mOut of Stock\e[0m", "★★★★☆"])
  t.addRow(@["007", "Dark Chocolate 85%", "Snacks", "Choco Deluxe", "8.50", "56", "0.1", "2024-03-12", "\e[32mIn Stock\e[0m", "★★★★★"])
  t.addRow(@["008", "Quinoa Organic", "Grains", "Health Foods Intl.", "6.75", "28", "0.9", "2024-03-11", "\e[33mLimited\e[0m", "★★★☆☆"])
  t.addRow(@["009", "Maple Syrup Grade A", "Condiments", "Canadian Harvest", "15.25", "19", "0.5", "2024-03-10", "\e[32mIn Stock\e[0m", "★★★★☆"])
  t.addRow(@["010", "Almond Milk Unsweetened", "Beverages", "Nutty Goodness", "3.99", "67", "0.95", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★☆☆"])
  t.renderTable(separator = true)
  t.renderTable(separator = false)
  t.renderTable(separator = true,  outFile = f)
  t.renderTable(separator = false, outFile = f)
  t.renderTable(separator = true, width = 80,  outFile = f)
  t.renderTable(separator = true, width = 200, outFile = f)

  # ===================================================================
  # VISUAL: WIDTH SWEEP
  # ===================================================================

  show("VISUAL 2: width sweep on terminal",
       "One fixed 5-wide column, one auto, one fixed 8-wide, one auto " &
       "right-aligned. Rendered with width = 40, 80, 120, 160, 200.",
       "At width = 40/80: fits within your terminal, right border present. " &
       "At width = 160/200: laid out for that target but clipped at your " &
       "terminal width; alignment of visible columns still holds.")
  var t2 = newTable()
  t2.addColumn("Short", width = 5)
  t2.addColumn("Auto Width Test")
  t2.addColumn("Fixed Truncate", width = 8)
  t2.addColumn("Right Aligned", align = Alignment.Right)
  t2.addRow(@["A", "This is a moderately long piece of text that will force auto-width", "This should be truncated with ellipsis because it's too long", "42"])
  t2.addRow(@["B", "Short", "1234567890", "\e[31m-15\e[0m"])
  t2.addRow(@["", "Another test with \e[1mANSI\e[0m codes that don't affect width", "Hi", "9999"])
  for w in [40, 80, 120, 160, 200]:
    echo "\n  --- width = ", w, " ---"
    t2.renderTable(separator = true, width = w)
    t2.renderTable(separator = true, width = w, outFile = f)

  # ===================================================================
  # VISUAL: QUICK START
  # ===================================================================

  show("VISUAL 3: Quick start table",
       "Three columns: Product (fixed 20), Price (right-aligned), " &
       "In Stock (centered, styled).",
       "Prices line up on the right. 'yes' green, 'no' plain, 'low' red. " &
       "Product column 20 cells wide.")
  var t7 = newTable()
  t7.addColumn("Product", width = 20)
  t7.addColumn("Price", align = Alignment.Right)
  t7.addColumn("In Stock", align = Alignment.Center)
  t7.addRow(@["Apple", "$2.50", "\e[32myes\e[0m"])
  t7.addRow(@["Banana", "$1.20", "no"])
  t7.addRow(@["Cherry", "$15.00", "\e[31mlow\e[0m"])
  t7.renderTable(separator = true)
  t7.renderTable(separator = false)

  # ===================================================================
  # VISUAL: OSC HYPERLINK
  # ===================================================================

  show("VISUAL 4: OSC hyperlink",
       "A two-column table where the first cell contains an OSC 8 " &
       "hyperlink to nim-lang.org and example.com.",
       "If your terminal supports OSC 8 and has it enabled, 'Nim' and " &
       "'Example' will be underlined and clickable. If not, they render " &
       "as plain text — that is the correct fallback.")
  var t8 = newTable()
  t8.addColumn("Site")
  t8.addColumn("Visits", align = Alignment.Right)
  t8.addRow(@["\e]8;;https://nim-lang.org\e\\Nim\e]8;;\e\\", "1"])
  t8.addRow(@["\e]8;;https://example.com\e\\Example\e]8;;\e\\", "2"])
  t8.renderTable(separator = true)
  doAssert stripAnsi("\e]8;;u\e\\X\e]8;;\e\\") == "X"
  echo "PASS (byte-level strip check)"

  echo "\n─────────────────────────────────────────────────────────────"
  echo "All assertion tests passed. Review the VISUAL sections above."