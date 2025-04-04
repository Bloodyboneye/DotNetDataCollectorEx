# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Parsing other Metadata manually to add more functionality

## [2.4.0] - 2025-03-30
### Added
- Added Lua function [FindMethod](LUA_API.md#findmethodhmodule-fullclassname-methodname-paramcount-casesensitive)
- Added Lua function [FindMethodByDesc](LUA_API#findmethodbydeschmodule-methodsignature-casesensitive)
- Added Lua function [FindClass](LUA_API.md#findclasshmodule-fullclassname-casesensitive)
- Added Lua function [GetModuleFromType](LUA_API.md#getmodulefromtypehtype)
- Added Lua function [FindModule](LUA_API.md#findmodulemodulename-casesensitive)
- Added Lua function [GetModuleFromMethod](LUA_API.md#getmodulefrommethodhmethod)
- Added Lua function [GetModuleFromHandle](LUA_API.md#getmodulefromhandlehmodule)
- Added Lua function [InitSymbolsForStaticFields](LUA_API.md#initsymbolsforstaticfieldshmodule-htype-includetypename-includefulltypename)
- Added Lua function [InitSymbolsForInstanceFields](LUA_API.md#initsymbolsforinstancefieldshmodule-htype-includetypename-includefulltypename)
- Added Lua function [InitSymbolsForAllFields](LUA_API.md#initsymbolsforallfieldshmodule-htype-includetypename-includefulltypename)
- Added Lua function [CreateDotNetHelperScript](LUA_API.md#createdotnethelperscript)
- Added Lua function [CompileMethod](LUA_API.md#compilemethodmethod)
- Added Lua function [FindMethodAndCompile](LUA_API.md#findmethodandcompilehmodule-fullclassname-methodname-paramcount-casesensitive)
- Added Lua function [FindMethodByDescAndCompile](LUA_API.md#findmethodbydesccompilehmodule-methodsignature-casesensitive)
- Added Lua function [RegisterAutoAssemblerCommands](LUA_API.md#registerautoassemblercommandsunregister)

- Added Auto Assembler Command [DotNetDefineMethod](LUA_API.md#dotnetdefinemethod)

- Added Assembly Function [RunInDomain](LUA_API.md#stdcall-int-runindomainvoid-functorun-void-userarg)
- Added Assembly Function [CreateManagedThread](LUA_API.md#stdcall-handle-createmanagedthreadvoid-lpstartaddress-void-lpparameter)
- Added Assembly Function [MAllocateString](LUA_API.md#stdcall-systemstring-mallocatestringint-length)
- Added Assembly Function [MCreateString](LUA_API.md#stdcall-systemstring-mcreatestringconst-char-str)

- Added hType under most Lua functions that return method information
- Added hModule under most Lua functions that return method information and type information

### Fixes
- Fixed rare case where getting the field size would crash the DataCollector

---

## [2.3.0] - 2025-03-14
### Changed
- Added Symbol cache on lua side for caching symbols used by cheat engine.
- Added validity checks for method names, namespaces and class names in methods that use those to find them for faster symbol lookup in case the symbol is not valid.

### Fixes
- Fixes Crash when getting method parameters that for methods in parent classes that are in other modules.

---

## [2.2.0] - 2025-03-10
### Added
- Added `ParameterName` field for Lua function [`GetMethodParameters`](LUA_API.md#getmethodparametershmethod)

### Changed
- The Lua function [`legacy_getMethodParameters`](LUA_API.md#legacy_getmethodparametersmodulehandle-methoddeftoken) will now correctly return the parameter name instead of the type name. This will also fix it when replacing the legacy DataCollector.
- The Lua function [`legacy_getTypeDefMethods`](LUA_API.md#legacy_gettypedefmethodsmodulehandle-typedeftoken) will now correcly return the full ImplementationFlags.

---

## [2.1.0] - 2025-03-09
### Added
- New Lua function [`FindMethod`](LUA_API.md#findmethodhmodule-fullclassname-methodname-paramcount-casesensitive) for finding methods.
- New Lua function [`FindMethodByDesc`](LUA_API.md#findmethodbydeschmodule-methodsignature-casesensitive) for finding methods.
- New Lua function [`FindClass`](LUA_API.md#findclasshmodule-fullclassname-casesensitive) for finding classes.
- New Lua function [`RegisterCallbacks`](LUA_API.md#registercallbacksunregister)
- Added `IsEnum` field to most tables that return type info
- Added `hType` field to all tables that return instance and static fields
- Added `TypeIsEnum ` field to all tables that return instance and static fields

### Changed
- `pipeReadTimeout` is now it's own value in the `DotNetDataCollectorEx.lua` file which tells the pipe when to timeout. Before it was the same as `pipeConnectionTimeOut`

### Fixed
- Field Offsets in types/classes are now correct.
- All Methods will now fail if the pipe is not Valid. -> DotNetDataCollectorEx is attached to wrong process.

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
