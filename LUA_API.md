# DotNetDataCollectorEx Lua API Reference

This document provides a reference for the Lua functions available when using **DotNetDataCollectorEx** inside **Cheat Engine**.

## Getting the DotNetDataCollectorEx Object

To access the new DotNetDataCollector, use:

```lua
local collectorEx = getDotNetDataCollectorEx()
```

---

## API Functions

### `legacy_enumDomains()`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `enumDomains()`

**Paramters:**
- None

**Returns:**
- A table containing information about all loaded domains
  - `DomainHandle` (number): The Domains Handle
  - `Name` (string): The Name of the Domain

**Usage:**
```lua
local domains = collectorEx.legacy_enumDomains()
for _,domain in ipairs(domains) do
  print("Domain Name:" .. domain.Name)
end
```

### `legacy_enumModuleList(domainHandle)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `enumModuleList(domainHandle)`

**Paramters:**
- `domainHandle` (number): The **DomainHandle** for which to list the modules for

**Returns:**
- A table containing information about all modules in the domain
  - `ModuleHandle` (number): The Module Handle
  - `BaseAddress` (number): The Base Address of the Module (Game.exe)
  - `Name` (string): The Name of the Domain

**Usage:**
```lua
local modules = collectorEx.legacy_enumModuleList(domain.DomainHandle)
for _,module in ipairs(modules) do
  print("Module Name:" .. module.Name)
end
```

### `legacy_enumTypeDefs(ModuleHandle)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `enumTypeDefs(ModuleHandle)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** for which to list the types for

**Returns:**
- A table containing information about all types in the module
  - `TypeDefToken` (number): The Token of the type
  - `Flags` (number): The flags of the Type
  - `Extends` (number): The Token of the Parent class if there is one
  - `Name` (string): The Name of the Domain

**Usage:**
```lua
local types = collectorEx.legacy_enumModuleList(module.ModuleHandle)
for _,type in ipairs(types) do
  print("Type Name:" .. type.Name)
end
```

### `legacy_getTypeDefMethods(ModuleHandle, TypeDefToken)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `getTypeDefMethods(ModuleHandle, TypeDefToken)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get the methods for

**Returns:**
- A table containing information about all methods in the type
  - `MethodToken` (number): The Token of the method
  - `Attributes` (number): The attributes of the method
  - `ImplementationFlags` (number): The implementation flags of the method
  - `Name` (string): The Name of the Domain
  - `ILCode` (number): The address of where the ILCode of the method resides
  - `NativeCode` (number) The address of where the compiled code of the method resides if it has been compiled
  - `SecondaryNativeCode` (table) A table containing the addresses of all code blocks usually only 1 but could be 2

**Usage:**
```lua
local methods = collectorEx.legacy_enumModuleList(module.ModuleHandle)
for _,method in ipairs(method) do
  print("Method Name:" .. Method.Name)
end
```

### `ReplaceLegacyDataCollector(restore)`
**Description:**  
Replaces the legacy `DotNetDataCollector` with `DotNetDataCollectorEx`.  
This is recommended for debugging **.NET 8+ applications**, as the legacy collector does not support those versions.

**Parameters:**
- `restore` (boolean): Should restore the old DotNetDataCollector?

**Usage:**
```lua
local collectorEx = getDotNetDataCollectorEx()
collectorEx.ReplaceLegacyDataCollector(false)
```

**Returns:**
- A boolean (true on success and false on failure)

---

## Notes:
- `DotNetDataCollectorEx` provides additional functionality that the legacy collector does not.
- When debugging **.NET 8+**, calling `ReplaceLegacyDataCollector()` ensures full Cheat Engine compatibility.
