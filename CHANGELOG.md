# tabulator Changelog

## Unreleased

### Added

### Changed

### Fixed

### Removed

____
## [v2.0.0] - 2026-10-22
### Added

- `SortOrder` enum, `SortKey` object, `sortRows` proc, `numericCompare` proc
- `rowCount` and `columnCount` procs

### Changed

- **Breaking changes**
  - `addColumn` renamed to `defineColumn`
  - `defineColumn` returns `int` instead of `void`
  - `defineColumn` fills the first undefined column slot rather than always
    appending; slots are created implicitly by `addRow` when a row has more
    cells than the current column set; `defineColumn` fills the lowest such
    slot, or appends if none exist; this makes column definition order-
    independent of row insertion order
  - column indices are stable for the lifetime of the table (no shifting)

## [v1.0.0] - 2026-10-03
### Changed

- Various improvements and minor fixes

## [v0.7.0] - 2026-01-11
### Changed

- Changed to MIT license for distribution

## [v0.5.0] - 2026-01-11
### Changed

- Various refinements and additional tests

## [v0.3.0] - 2026-01-10
### Changed

- Made tables with and without separator align equally
  - Separator only for visuals

## [v0.2.0] - 2026-01-10
### Added

- Position-based terminal output
  - Much better Unicode handling (especially for complicated scripts)
- Expand auto-sized columns to reach table width (if defined)

### Changed

- Improved file output
  - Strip out any embedded ANSI codes
- Use pipe characters for borders

## [v0.1.0] - 2026-01-10

- Initial release

____
[v2.0.0]:https://github.com/erykjj/tabulator/releases/tag/v2.0.0
[v1.0.0]:https://github.com/erykjj/tabulator/releases/tag/v1.0.0
[v0.7.0]:https://github.com/erykjj/tabulator/releases/tag/v0.7.0
[v0.5.0]:https://github.com/erykjj/tabulator/releases/tag/v0.5.0
[v0.3.0]:https://github.com/erykjj/tabulator/releases/tag/v0.3.0
[v0.2.0]:https://github.com/erykjj/tabulator/releases/tag/v0.2.0
[v0.1.0]:https://github.com/erykjj/tabulator/releases/tag/v0.1.0
