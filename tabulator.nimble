# Package
version       = "0.5.0"
author        = "Eryk J."
description   = "A Nim library for generating plain-text tables (with Unicode and ANSI code support)"
license       = "Infiniti Noncommercial License (https://github.com/erykjj/tabulator/blob/main/LICENSE.md)"

# Dependencies
requires "nim >= 1.6.0"

# Installation
srcDir = "src"
skipDirs = @["tests", "examples"]
skipFiles = @["test.nim"]

# Tasks
task test, "Run tests":
  exec "nim c -r tests/test.nim"
