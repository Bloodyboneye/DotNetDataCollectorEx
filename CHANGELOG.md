# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Parsing Method/Parameter Metadata to be in line with the legacy data collector and add stuff like parameter names instead of only parameter **type** names
- Parsing other Metadata manually to add more functionality

---

## [2.0.0] - 2025-03-04
### Added
- New Lua function [`DumpModule`](LUA_API.md#dumpmodulehmodule-outputfilepath) for dumping modules.
- New Lua function [`DumpModuleEx`](LUA_API.md#dumpmoduleexmodule-outputpath) for dumping modules.

### Changed
- DotNetDataCollectorEx will now, when used in **replacement mode**, use the **legacy** `DotNetDataCollector` by default. And will only fall back on the Ex Version if the **legacy** `DotNetDataCollector` isn't able to analyse the Process or if it breaks.

### Fixed
- Interop between the `DotNetDataCollectorEx` and the **legacy** `DotNetDataCollector` is fixed now.

---

## [1.0.0] - 2025-02-26
### Added
- Initial release of **DotNetDataCollectorEx**.
- Supports **.NET Framework 4.5+** and **.NET 8+**.
- Provides a **getDotNetDataCollectorEx** function for Cheat Engine.
- Allows replacing the legacy data collector with `ReplaceLegacyDataCollector`.
- Includes additional memory analysis and debugging functions.
- Offers both **replacement mode** and **extension mode**.

---

## Format Guide
- **[Version] - YYYY-MM-DD** (e.g., `[1.0.0] - 2025-02-26`)
- **Added**: New features or functionality.
- **Changed**: Modifications or improvements.
- **Fixed**: Bug fixes and stability improvements.
- **Removed**: Deprecated or removed features.
