# Package
version       = "1.0.0"
author        = "Eryk J."
description   = "Nim library for generating plain-text tables (with Unicode and ANSI code support)"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"

# Installation
srcDir = "src"
skipDirs = @["tests", "examples"]
skipFiles = @["test.nim"]

# Tasks
task test, "Run tests":
  exec "nim c -r tests/test.nim"
