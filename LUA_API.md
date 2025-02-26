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
local types = collectorEx.legacy_enumTypeDefs(module.ModuleHandle)
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
local methods = collectorEx.legacy_getTypeDefMethods(module.ModuleHandle, type.TypeDefToken)
for _,method in ipairs(methods) do
  print("Method Name:" .. Method.Name)
end
```

### `legacy_getAddressData(address)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `getAddressData(address)`

**Paramters:**
- `address` (number): The **Address** for which to get the data for

**Returns:**
- A table containing information about the address
  - `StartAddress` (number): The Start Address of the Object
  - `ObjectType` (number): The TypeDefToken of the Object Type
  - `ClassName` (string): The name of the Type that the Object is
  - `fields` (table): A Table containing all of the Fields of the Type, this is only filled if the type is **NOT** an array type
    - `Token` (number): The FieldToken of the field
    - `Offset` (number): The offset of the field inside the Object
    - `FieldType` (number): The Element Type of the field's type
    - `Attribs` (number): The Attributes of the field
    - `IsStatic` (boolean): True if the field is static otherwise false
    - `Name` (string): The name of the field
    - `FieldTypeClassName` (string): The name of the field's type
  - `ElementType` (number) If the Type is an array type this is the TypeDefToken of the Element Type -> int[] -> int is the Element Type
  - `CountOffset` (number) If the Type is an array type this is the Offset of where the `Count` of the Array is stored
  - `ElementSize` (number) If the Type is an array type this is the Size of the element -> int -> 4, long -> 8, byte -> 1 ...
  - `FirstElementOffset` (number) If the Type is an array type this is the offset of the first element inside the array

**Usage:**
```lua
local object = collectorEx.legacy_getAddressData(0x123456)
print("Class Name:" .. object.ClassName)
```

### `legacy_enumAllObjects()`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `enumAllObjects()`

**Paramters:**
- None

**Returns:**
- A table containing Information about all the allocated objects
  - `TypeID` (table):
    - `token1` (number):
    - `token2` (number):
  - `StartAddress` (number): The Start Address of the Object
  - `Size` (number): The size of the object
  - `ClassName` (string): The types name of the object

**Usage:**
```lua
local objects = collectorEx.legacy_enumAllObjects()
for _,object in ipairs(objects) do
  print("Object Class Name:" .. object.ClassName)
end
```


### `legacy_getTypeDefData(ModuleHandle, TypeDefToken)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `getTypeDefData(ModuleHandle, TypeDefToken)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get the data for

**Returns:**
- A table containing information about the type
  - `ObjectType` (number): The Element Type of the type
  - `ClassName` (string): The name of the Type
  - `fields` (table): A Table containing all of the Fields of the Type, this is only filled if the type is **NOT** an array type
    - `Token` (number): The FieldToken of the field
    - `Offset` (number): The offset of the field inside an object
    - `FieldType` (number): The Element Type of the field's type
    - `Attribs` (number): The Attributes of the field
    - `IsStatic` (boolean): True if the field is static otherwise false
    - `Name` (string): The name of the field
    - `FieldTypeClassName` (string): The name of the field's type
  - `ElementType` (number) If the Type is an array type this is the TypeDefToken of the Element Type -> int[] -> int is the Element Type
  - `CountOffset` (number) If the Type is an array type this is the Offset of where the `Count` of the Array is stored
  - `ElementSize` (number) If the Type is an array type this is the Size of the element -> int -> 4, long -> 8, byte -> 1 ...
  - `FirstElementOffset` (number) If the Type is an array type this is the offset of the first element inside the array

**Usage:**
```lua
local typeinfo = collectorEx.legacy_getTypeDefData(module.ModuleHandle, type.TypeDefToken)
print("Class Name:" .. typeinfo.ClassName)
```

### `legacy_getMethodParameters(ModuleHandle, MethodDefToken)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `legacy_getMethodParameters(ModuleHandle, MethodDefToken)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the method resides
- `MethodDefToken` (number): The **Token** of the method for which to get the data for

**Returns:**
- A table containing Information about the methods parameters
  - `Name` (string): This would normally be the name of the `Parameter` but in the current implementation this is the `Types name` of the `parameter`
  - `CType` (number): The Element Type of the method parameter

**Usage:**
```lua
local methodparams = collectorEx.legacy_getMethodParameters(module.ModuleHandle, method.MethodToken)
for _,mparam in ipairs(methodparams) do
  print("Param Name:" .. mparam.Name)
end
```


### `legacy_getTypeDefParent(ModuleHandle, TypeDefToken)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `getTypeDefParent(ModuleHandle, TypeDefToken)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get the parent type for

**Returns:**
- A table containing information about the types parent type
  - `ModuleHandle` (number): The Module Handle the Parent type resides in
  - `TypedefToken ` (number): The **Token** of the Parent type -> the small 'def' is not a typo

**Usage:**
```lua
local parentType = collectorEx.legacy_getTypeDefParent(module.ModuleHandle, type.TypeDefToken)
print("Parent Token:" .. typeinfo.TypedefToken)
```

### `legacy_enumAllObjectsOfType(ModuleHandle, TypeDefToken)`
**Description**
Does the same as **Cheat Engine's** `DotNetDataCollector` `enumAllObjectsOfType(ModuleHandle, TypeDefToken)`

**Paramters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get all the allocated objects for

**Returns:**
- A table containing the address of each object
  - `<table index>` (number): The address of the Object

**Usage:**
```lua
local objects = collectorEx.legacy_enumAllObjectsOfType(module.ModuleHandle, type.TypeDefToken)
for _,object in ipairs(objects) do
  printf("Object Address: %X", object)
end
```

---

All of the below functions return nil if the **DotNetDataCollectorEx** is not running!

### `DataCollectorInfo()`
**Description**
Returns information about the **DataCollectorEx**

**Paramters:**
- None

**Returns:**
- A table containing the info about **DataCollectorEx**
  - `DataCollectorExRunning` (boolean): Is the `DataCollectorEx` running
  - `LegacyDataCollectorRunning ` (boolean): Is the `LegacyDataCollector` running
  - `PipeVersion` (number): The Pipe Version
  - `PipeName` (string): The name of the Pipe
  - `PipeNameEx` (string): The name of the ex Pipe if it is running

**Usage:**
```lua
local info = collectorEx.DataCollectorInfo()
print("Pipe Name is " .. info.PipeName)
```

### `EnumDomains()`
**Description**
Returns a table that contains all of the loaded App Domains

**Paramters:**
- None

**Returns:**
- A table containing information about all of the loaded App Domains
  - `hDomain` (number): The handle/address of the AppDomain
  - `Id ` (number): The Id of the AppDomain
  - `Name` (string): The name of the AppDomain

**Usage:**
```lua
local domains = collectorEx.EnumDomains()
for _,domain in ipairs(domains) do
  print("Domain Name is " .. domain.Name)
end
```

### `EnumModules(hDomain)`
**Description**
Returns a table that contains all of the loaded modules

**Paramters:**
- (OPTIONAL) `hDomain` (number): The handle/address of the domain for which to get the modules for, if this is nil or 0 then it will get all loaded modules in all appdomains

**Returns:**
- A table containing information about all of the loaded modules
  - `hModule` (number): The handle/address of the Module
  - `hAppDomain` (number): The handle/address of the AppDomain the Module is loaded in
  - `ImageBase` (number): The address of where the Module is loaded in memory at, might be 0 when it is not a Module loaded from Disc?
  - `Size` (number): The size of the Module in Memory
  - `MetaDataAddress` (number): The address of the MetaData -> This is the address of the .net MetaData Header inside the Module
  - `MetaDataLength` (number): The size of the MetaData
  - `Name` (string): The name of the Module
  - `AssemblyAddress` (number): The address of the Assembly the Module is inside of
  - `AssemblyName` (string): The name of the Assembly
  - `Layout` (number): The `layout` of the Module
  - `IsDynamic` (boolean): True if the module is dynamic

**Usage:**
```lua
local modules = collectorEx.EnumModules()
for _,module in ipairs(modules) do
  print("Module Name is " .. module.Name)
end
```

### `EnumTypeDefs(hModule)`
**Description**
Returns a table that contains all of the loaded modules

**Paramters:**
- (OPTIONAL) `hModule` (number): The handle/address of the Module for which to get the types for, if this is nil or 0 then it will get all loaded types in all modules

**Returns:**
- A table containing information about all of the loaded types
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `ElementType` (number): The Element Type of the type
  - `TypeAttributes` (number): The attributes of the type
  - `hModule` (number): The handle/address of the Module the type is inside of
  - `StaticSize` (number): The static size of objects of this type when created on the CLR heap
  - `Name` (string): The name of the Type
  - `StaticFieldsAddress` (number): The base address of where the static fields of the type are 
  - `BaseTypeToken` (number): The token of the parent type if any
  - `BasehType` (number): The MethodTable/TypeHandle of the parent type if any
  - `BaseName` (string): The name of the parent Type if any

**Usage:**
```lua
local types = collectorEx.EnumTypeDefs(module.hModule)
for _,type in ipairs(types) do
  print("Type Name is " .. type.Name)
end
```

### `GetTypeDefMethods(hType)`
**Description**
Returns a table that contains all of the methods inside the type

**Paramters:**
- `hType` (number): The MethodTable/TypeHandle of the Type for which to get the methods for

**Returns:**
- A table containing information about all of the methods inside the type
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class:methodname(...)
  - `ILAddress` (number): The address of where the methods IL Code is located
  - `ILSize` (number): The size of the methods IL Code
  - `ILFlags` (number): The Flags of the methods IL
  - `MethodRegions` (table): Table containing the methods compiled code regions if any
    - `StartAddress` (number): The start adddress if this code region
    - `Size` (number): The size of this code region

**Usage:**
```lua
local methods = collectorEx.GetTypeDefMethods(type.hType)
for _,method in ipairs(methods) do
  print("Method Name is " .. method.Name)
end
```

### `GetTypeDefParent(hType)`
**Description**
Returns a table containing information about the parent type

**Paramters:**
- `hType` (number): The MethodTable/TypeHandle of the Type for which to get the parent for

**Returns:**
- A table containing information about all of the methods inside the type
  - `TypeToken` (number): The token of the parent Type
  - `hType` (number): The MethodTable/TypeHandle of the parent Type
  - `Name` (string): The name of the parent Type

**Usage:**
```lua
local parentType = collectorEx.GetTypeDefParent(type.hType)
print("Parent Type Name is " .. parentType.Name)
```

### `GetAddressData(address)`
**Description**
Returns a table that contains information about the Object if the address is inside an Object

**Paramters:**
- `address` (number): The address to get information about. Must be inside an Object

**Returns:**
- A table containing information about the address
  - `StartAddress` (number): The start Address of the Object
  - `Size` (number): The size of the Object
  - `Type` (table): A table containing information about the Objects type
    - `TypeToken` (number): The token of the type
    - `hType` (number): The MethodTable/TypeHandle of the type
    - `ElementType` (number): The Element Type of the type
    - `Name` (string): The name of the Type
    - `IsArray` (boolean): True if the type is an array type
    - `ComponentType` (table): Information about the component type int[] -> int. (**Only valid if the Type is an array type!**)
      - `ElementType` (number): The element type of the component type.
      - `TypeToken` (number): The token of the component type
      - `hType` (number) The MethodTable/TypeHandle of the component type
      - `Name` (string) The name of the component type
    - `CountOffset` (number): The offset of where the Count is stored inside the Array Object. (**Only valid if the Type is an array type!**)
    - `ComponentSize` (number): The size of each element inside the Array Object. (**Only valid if the Type is an array type!**)
    - `FirstElementOffset` (number): The offset of the first element inside the Array Object. (**Only valid if the Type is an array type!**)
    **Below fields are only valid if the Type is NOT an array type!**
    - `InstanceFields` (table): Table containing all of the `instance` Fields
      - `TypeToken` (number): Token of the type of the field
      - `Size` (number): The size of the field
      - `Offset` (number): The offset of the field inside an Object
      - `ElementType` (number): The element type of the type
      - `Attributes` (number): The attributes of the field
      - `Name` (string): The name of the field
      - `TypeName` (string): The name of the fields type
      - `Address` (number): The address of the field (inside the Object)
      - `IsStatic` (boolean): Will always be false for instance fields
    - `StaticFields` (table): Table containing all of the `static` Fields
      - `TypeToken` (number): Token of the type of the field
      - `Size` (number): The size of the field
      - `Offset` (number): The offset of the field taken from the StaticFieldBaseAddress
      - `ElementType` (number): The element type of the type
      - `Attributes` (number): The attributes of the field
      - `Name` (string): The name of the field
      - `TypeName` (string): The name of the fields type
      - `Address` (number): The address of the field
      - `IsStatic` (boolean): Will always be true for static fields
    - `AllFields` (table): Same as the above two but contains both `instance` and `static fields`
      - `see above two tables`
      
**Usage:**
```lua
local addrData = collectorEx.GetAddressData(0x123456)
print("Start Address is " .. addrData.StartAddress)
```

### `EnumAllObjects()`
**Description**
Returns a table that contains information about all of the allocated Objects

**Paramters:**
- None

**Returns:**
- A table containing information about the address
  - `Address` (number): The start Address of the Object
  - `Size` (number): The size of the Object
  - `Type` (table): A table containing information about the Objects type
    - `TypeToken` (number): The token of the type
    - `hType` (number): The MethodTable/TypeHandle of the type
    - `ElementType` (number): The Element Type of the type
    - `Name` (string): The name of the Type
    - `IsArray` (boolean): True if the type is an array type
    - `ComponentType` (table): Information about the component type int[] -> int. (**Only valid if the Type is an array type!**)
      - `ElementType` (number): The element type of the component type.
      - `TypeToken` (number): The token of the component type
      - `hType` (number) The MethodTable/TypeHandle of the component type
      - `Name` (string) The name of the component type
    - `CountOffset` (number): The offset of where the Count is stored inside the Array Object. (**Only valid if the Type is an array type!**)
    - `ComponentSize` (number): The size of each element inside the Array Object. (**Only valid if the Type is an array type!**)
    - `FirstElementOffset` (number): The offset of the first element inside the Array Object. (**Only valid if the Type is an array type!**)
    **Below fields are only valid if the Type is NOT an array type!**
    - `InstanceFields` (table): Table containing all of the `instance` Fields
      - `TypeToken` (number): Token of the type of the field
      - `Size` (number): The size of the field
      - `Offset` (number): The offset of the field inside an Object
      - `ElementType` (number): The element type of the type
      - `Attributes` (number): The attributes of the field
      - `Name` (string): The name of the field
      - `TypeName` (string): The name of the fields type
      - `Address` (number): The address of the field (inside the Object)
      - `IsStatic` (boolean): Will always be false for instance fields
    - `StaticFields` (table): Table containing all of the `static` Fields
      - `TypeToken` (number): Token of the type of the field
      - `Size` (number): The size of the field
      - `Offset` (number): The offset of the field taken from the StaticFieldBaseAddress
      - `ElementType` (number): The element type of the type
      - `Attributes` (number): The attributes of the field
      - `Name` (string): The name of the field
      - `TypeName` (string): The name of the fields type
      - `Address` (number): The address of the field
      - `IsStatic` (boolean): Will always be true for static fields
    - `AllFields` (table): Same as the above two but contains both `instance` and `static fields`
      - `see above two tables`
      
**Usage:**
```lua
local objects = collectorEx.EnumAllObjects()
for _,object in ipairs(objects) do
  print("Object Address is " .. object.Address)
end
```

### `GetTypeDefData(hType)`
**Description**
Returns a table that contains information about the type

**Paramters:**
- `hType` (number): The MethodTable/TypeHandle of the type

**Returns:**
- A table containing information about the address
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `ComponentType` (table): Information about the component type int[] -> int. (**Only valid if the Type is an array type!**)
    - `ElementType` (number): The element type of the component type.
    - `TypeToken` (number): The token of the component type
    - `hType` (number) The MethodTable/TypeHandle of the component type
    - `Name` (string) The name of the component type
  - `CountOffset` (number): The offset of where the Count is stored inside the Array Object. (**Only valid if the Type is an array type!**)
  - `ComponentSize` (number): The size of each element inside the Array Object. (**Only valid if the Type is an array type!**)
  - `FirstElementOffset` (number): The offset of the first element inside the Array Object. (**Only valid if the Type is an array type!**)
  **Below fields are only valid if the Type is NOT an array type!**
  - `InstanceFields` (table): Table containing all of the `instance` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field inside an Object
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): Will always be 0 here
    - `IsStatic` (boolean): Will always be false for instance fields
  - `StaticFields` (table): Table containing all of the `static` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field taken from the StaticFieldBaseAddress
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): The address of the field
    - `IsStatic` (boolean): Will always be true for static fields
  - `AllFields` (table): Same as the above two but contains both `instance` and `static fields`
      - `see above two tables`
      
**Usage:**
```lua
local typeData = collectorEx.GetTypeDefData(type.hType)
print("Type Name is " .. typeData.Name)
```

### `GetMethodParameters(hMethod)`
**Description**
Returns a table containing information about the methods parameters

**Paramters:**
- `hMethod` (number): The MethodDesc of the Method for which to get the method paramters for

**Returns:**
- A table containing information about all of parameters inside the method
  - `Signature` (string): The Signature of the Method
  - `<parameter Index>` (table): A table that contains information about the Parameter at that index(1,2,3,4,...) inside the Method -> foo:bar(int i1, bool b1, string s1) -> int i1 is index 1, bool b1 is index 2, string s1 is index 3 ...
    - `ParameterTypeName` (string): The Name of the parameters Type
    - `ElementType` (number): The Element Type of the parameters Type
    - `Location` (number): The index of the parameter inside the method, kind of useless...

**Usage:**
```lua
local methodParams = collectorEx.GetMethodParameters(Method.hMethod)
for i,mParam in ipairs(methodParams) do
  print("Parameter Index: " .. i .. "Parameter Type Name: " .. mParam.ParameterTypeName)
end
```

### `EnumAllObjectsOfType(hType)`
**Description**
Returns a table containing information about all of the allocated objects of the type

**Paramters:**
- `hType` (number): The MethodTable/TypeHandle of the Type for which to get the allocated objects for

**Returns:**
- A table containing information about all of the allocated objects of the type
  - `Address` (number): The address of the Object
  - `Size` (number): The size of the Object

**Usage:**
```lua
local objects = collectorEx.EnumAllObjectsOfType(type.hType)
for _,object in ipairs(objects) do
  printf("Object Address: %X | Size: %d", object.Address, object.Size)
end
```

### `GetTypeInfo(hType)` 
**Description**
Returns a table that contains information about the type | Obsolete as it does the same as `GetTypeDefData(hType)`

**Paramters:**
- `hType` (number): The MethodTable/TypeHandle of the type

**Returns:**
- A table containing information about the address
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `ComponentType` (table): Information about the component type int[] -> int. (**Only valid if the Type is an array type!**)
    - `ElementType` (number): The element type of the component type.
    - `TypeToken` (number): The token of the component type
    - `hType` (number) The MethodTable/TypeHandle of the component type
    - `Name` (string) The name of the component type
  - `CountOffset` (number): The offset of where the Count is stored inside the Array Object. (**Only valid if the Type is an array type!**)
  - `ComponentSize` (number): The size of each element inside the Array Object. (**Only valid if the Type is an array type!**)
  - `FirstElementOffset` (number): The offset of the first element inside the Array Object. (**Only valid if the Type is an array type!**)
  **Below fields are only valid if the Type is NOT an array type!**
  - `InstanceFields` (table): Table containing all of the `instance` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field inside an Object
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): Will always be 0 here
    - `IsStatic` (boolean): Will always be false for instance fields
  - `StaticFields` (table): Table containing all of the `static` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field taken from the StaticFieldBaseAddress
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): The address of the field
    - `IsStatic` (boolean): Will always be true for static fields
  - `AllFields` (table): Same as the above two but contains both `instance` and `static fields`
      - `see above two tables`
      
**Usage:**
```lua
local typeData = collectorEx.GetTypeInfo(type.hType)
print("Type Name is " .. typeData.Name)
```

### `GetBaseClassModule()`
**Description**
Returns a table that contains information about the Base Class Module ex: mscorlib.dll

**Paramters:**
- None

**Returns:**
- A table containing information about the Base Class Module
  - `hModule` (number): The handle/address of the Module
  - `hAppDomain` (number): The handle/address of the AppDomain the Module is loaded in
  - `ImageBase` (number): The address of where the Module is loaded in memory at
  - `Size` (number): The size of the Module in Memory
  - `MetaDataAddress` (number): The address of the MetaData -> This is the address of the .net MetaData Header inside the Module
  - `MetaDataLength` (number): The size of the MetaData
  - `Name` (string): The name of the Module
  - `AssemblyAddress` (number): The address of the Assembly the Module is inside of
  - `AssemblyName` (string): The name of the Assembly
  - `Layout` (number): The `layout` of the Module
  - `IsDynamic` (boolean): True if the module is dynamic

**Usage:**
```lua
local basemodule = collectorEx.GetBaseClassModule()
print("Module Name is " .. basemodule.Name)
```

### `GetAppDomainInfo(hDomain)`
**Description**
Returns a table that contains information about the AppDomain

**Paramters:**
- `hDomain` (number): The address of the AppDomain

**Returns:**
- A table containing information about the AppDomain
  - `hDomain` (number): The address of the AppDomain
  - `Id` (number): The Id of the AppDomain
  - `LoaderAllocator` (number): The `LoaderAllocator` of the AppDomain. Only used in **.net 8+** Otherwise seems to be the same as `hDomain`
  - `Name` (string): The name of the AppDomain
  - `ApplicationBase` (string): The base directory of the app domain
  - `ConfigurationFile` (string): The config file path of the app domain

**Usage:**
```lua
local appdomainInfo = collectorEx.GetAppDomainInfo(domain.hDomain)
print("AppDomain Name is " .. appdomainInfo.Name)
```

### `EnumGCHandes()`
**Description**
Returns a table that contains all of the allocated GC handles

**Paramters:**
- None

**Returns:**
- A table containing information about all of the allocated GC handles
  - `HandleAddress` (number): The address of the handle
  - `HandleKind` (number): The Kind of handle this is
  - `ReferenceCount` (number): The reference count
  - `RootKind` (number): The Root Kind of the handle
  - `hAppDomain` (number): The address of the handles AppDomain
  - `ObjectAddress` (number): The address of the Object this handle references
  - `ObjectSize` (number): The size of the Object this handle references
  - `TypeToken` (number): The Token of the referenced Objects type
  - `hType` (number): The MethodTable/TypeHandle of the referenced Objects type
  - `TypeName` (string): The name of the referenced Objects type
  - `DependentObjectAddress` (number): The address of the object of the dependent handle if it is a dependent handle
  - `DependentObjectSize` (number): The size of the object of the dependent handle if it is a dependent handle
  - `DependentTypeToken` (number): The Token of the objects type of the dependent handle if it is a dependent handle
  - `DependenthType` (number): The MethodTable/TypeHandle of the objects type of the dependent handle if it is a dependent handle
  - `DependentTypeName` (number): The name of the objects type of the dependent handle if it is a dependent handle

**Usage:**
```lua
local handles = collectorEx.EnumGCHandes()
for _,handle in ipairs(handles) do
  printf("Handle Address is %X", handle.Address)
end
```

### `GetMethodInfo(hMethod)`
**Description**
Returns a table that contains information about the method

**Paramters:**
- `hMethod` (number): The MethodDesc of the method to get the information for

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class:methodname(...)
  - `ILAddress` (number): The address of where the methods IL Code is located
  - `ILSize` (number): The size of the methods IL Code
  - `ILFlags` (number): The Flags of the methods IL
  - `MethodRegions` (table): Table containing the methods compiled code regions if any
    - `StartAddress` (number): The start adddress if this code region
    - `Size` (number): The size of this code region

**Usage:**
```lua
local methodInfo = collectorEx.GetTypeDefMethods(method.hMethod)
print("Method Name is " .. methodInfo.Name)
```

### `GetMethodFromIP(ip)`
**Description**
Returns a table that contains information about the method that the ip(Instruction Pointer) is inside of.
This can be anywhere inside a method in memory. But must be inside a method and not in some other part of memory

**Paramters:**
- `ip` (number): The ip(Instruction Pointer) that is inside the methods compiled body

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class:methodname(...)
  - `ILAddress` (number): The address of where the methods IL Code is located
  - `ILSize` (number): The size of the methods IL Code
  - `ILFlags` (number): The Flags of the methods IL
  - `MethodRegions` (table): Table containing the methods compiled code regions if any
    - `StartAddress` (number): The start adddress if this code region
    - `Size` (number): The size of this code region

**Usage:**
```lua
local methodInfo = collectorEx.GetMethodFromIP(0x123456)
print("Method Name is " .. methodInfo.Name)
```

### `GetTypeFromElementType(elementType, specialType)` 
**Description**
Returns a table that contains information about the type
Valid values for `specialType` are: 1 -> HeapFree Type, 2 -> Exception Type
If special type is not any of those it will check for the `elementType`
For valid **Element Types** see the `ClrElementType` Table at the Top of the `DotNetDataCollector.lua` file

**Paramters:**
- (OPTIONAL) `elementType` (number): The `Element Type` of the type to get
- (OPTIONAL) `specialType` (number): The `"special Type"` to get see the description for more info

**Returns:**
- A table containing information about the `elementType` or `specialType`
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `ComponentType` (table): Information about the component type int[] -> int. (**Only valid if the Type is an array type!**)
    - `ElementType` (number): The element type of the component type.
    - `TypeToken` (number): The token of the component type
    - `hType` (number) The MethodTable/TypeHandle of the component type
    - `Name` (string) The name of the component type
  - `CountOffset` (number): The offset of where the Count is stored inside the Array Object. (**Only valid if the Type is an array type!**)
  - `ComponentSize` (number): The size of each element inside the Array Object. (**Only valid if the Type is an array type!**)
  - `FirstElementOffset` (number): The offset of the first element inside the Array Object. (**Only valid if the Type is an array type!**)
  **Below fields are only valid if the Type is NOT an array type!**
  - `InstanceFields` (table): Table containing all of the `instance` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field inside an Object
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): Will always be 0 here
    - `IsStatic` (boolean): Will always be false for instance fields
  - `StaticFields` (table): Table containing all of the `static` Fields
    - `TypeToken` (number): Token of the type of the field
    - `Size` (number): The size of the field
    - `Offset` (number): The offset of the field taken from the StaticFieldBaseAddress
    - `ElementType` (number): The element type of the type
    - `Attributes` (number): The attributes of the field
    - `Name` (string): The name of the field
    - `TypeName` (string): The name of the fields type
    - `Address` (number): The address of the field
    - `IsStatic` (boolean): Will always be true for static fields
  - `AllFields` (table): Same as the above two but contains both `instance` and `static fields`
      - `see above two tables`
      
**Usage:**
```lua
local typeData = collectorEx.GetTypeFromElementType(0x8, nil) -> 0x8 = ElementType.int
print("Type Name is " .. typeData.Name)
```

### `GetCLRInfo()`
**Description**
Returns a table that contains information about the clr

**Paramters:**
- None

**Returns:**
- A table containing information about the clr
  - `Flavor` (number): The clr flavor
  - `Version` (string): The clr version
  - `ModuleImageBase` (number): The CLRInfo Module Image Base address
  - `ModuleImageSize` (number): The CLRInfo Module Image size
  - `ModuleIsManaged` (boolean): Is the CLRInfo a managed module
  - `ModuleFileName` (string): The CLRInfo Module file name
  - `ModuleVersion` (string): The CLRInfo Module version

**Usage:**
```lua
local clrInfo = collectorEx.GetCLRInfo()
print("CLR Version is " .. clrInfo.Version)
```

### `EnumThreads()`
**Description**
Returns a table that contains all of the managed threads

**Paramters:**
- None

**Returns:**
- A table containing information about all of the managed threads
  - `hThread` (number): The address of the managed thread object
  - `ManagedThreadId` (number): The id of the managed thread
  - `NativeThreadId` (number): The id of the underlying os thread
  - `StackBase` (number): The Stack base of the thread
  - `StackLimit` (number): The Stack limit of the thread
  - `GCMode` (number): The `GCMode` of the thread
  - `State` (number): The state of the thread
  - `IsAlive` (boolean): True if the thread is still alive
  - `IsGCThread` (boolean): True if the thread is a GC thread
  - `IsFinalizer` (boolean): True if the thread is a finalizer thread
  - `hCurrentAppDomain` (number): The address of the AppDomain the thread started inside of
  - `hCurrentException` (number): The address of the current Exception object if any
  - `CurrentExceptionMessage` (string) The Message of the current Exception if any

**Usage:**
```lua
local threads = collectorEx.EnumThreads()
for _,thread in ipairs(thread) do
  print("Thread Managed Id: " .. thread.ManagedThreadId)
end
```

### `TraceStack(threadid)`
**Description**
Returns a table that contains all of stack frames of the thread

**Paramters:**
- `threadid` (number): The **Managed** or **OS** thread id

**Returns:**
- A table containing information about all stack frames of the thread
  - `StackPointer` (number): The stack pointer of the Stack in this stack frame
  - `InstructionPointer` (number): The IP of the stack frame -> The return address
  - `FrameKind` (number): The King this stack frame is
  - `FrameName` (number): The Name of the stack frame if any
  - `FullName` (number): The Full Name of the stack frame
  - `Method` (table): A Table containing information about the method, if the stack frame is inside a method
    - `MethodToken` (number): The Token of the Method
    - `hMethod` (number): The MethodDesc of the Method
    - `NativeCode` (number): The address of where the compiled metod body starts
    - `Name` (string); The name of the method
    - `Signature` (string): The Signature of the method

**Usage:**
```lua
local stacktrace = collectorEx.TraceStack(1) -> Managed Thread Ids seem to be 1,2,3,...
for _,frame in ipairs(stacktrace) do
  print("Frame full name is: " .. frame.FrameName)
end
```

### `GetThreadFromID(threadid)`
**Description**
Returns a table that contains information about the managed thread

**Paramters:**
- `threadid` (number): The **Managed** or **OS** thread id

**Returns:**
- A table containing information about the managed thread
  - `hThread` (number): The address of the managed thread object
  - `ManagedThreadId` (number): The id of the managed thread
  - `NativeThreadId` (number): The id of the underlying os thread
  - `StackBase` (number): The Stack base of the thread
  - `StackLimit` (number): The Stack limit of the thread
  - `GCMode` (number): The `GCMode` of the thread
  - `State` (number): The state of the thread
  - `IsAlive` (boolean): True if the thread is still alive
  - `IsGCThread` (boolean): True if the thread is a GC thread
  - `IsFinalizer` (boolean): True if the thread is a finalizer thread
  - `hCurrentAppDomain` (number): The address of the AppDomain the thread started inside of
  - `hCurrentException` (number): The address of the current Exception object if any
  - `CurrentExceptionMessage` (string) The Message of the current Exception if any

**Usage:**
```lua
local thread = collectorEx.GetThreadFromID(1)
print("Thread Managed Id: " .. thread.ManagedThreadId)
```

### `FlushDACCache()`
**Description**
Flushes the DAC Cache - Might want to call this if new objects have been allocated and you want to search for them.

**Paramters:**
- None

**Returns:**
- Nothing

**Usage:**
```lua
collectorEx.FlushDACCache()
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
- When debugging **.NET 8+**, calling `ReplaceLegacyDataCollector()` ensures **almost** full Cheat Engine compatibility.
