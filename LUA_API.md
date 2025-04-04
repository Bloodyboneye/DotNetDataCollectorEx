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

**Parameters:**
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

**Parameters:**
- `domainHandle` (number): The **DomainHandle** for which to list the modules for

**Returns:**
- A table containing information about all modules in the domain
  - `ModuleHandle` (number): The Module Handle
  - `BaseAddress` (number): The Base Address of the Module (Game.exe)
  - `Name` (string): The Name of the Module

**Usage:**
```lua
local modules = collectorEx.legacy_enumModuleList(domain.DomainHandle)
for _,_module in ipairs(modules) do
  print("Module Name:" .. _module.Name)
end
```

### `legacy_enumTypeDefs(ModuleHandle)`
**Description**

Does the same as **Cheat Engine's** `DotNetDataCollector` `enumTypeDefs(ModuleHandle)`

**Parameters:**
- `ModuleHandle` (number): The **ModuleHandle** for which to list the types for

**Returns:**
- A table containing information about all types in the module
  - `TypeDefToken` (number): The Token of the Type
  - `Flags` (number): The flags of the Type
  - `Extends` (number): The Token of the Parent class if there is one
  - `Name` (string): The Name of the Type

**Usage:**
```lua
local types = collectorEx.legacy_enumTypeDefs(module.ModuleHandle)
for _,_type in ipairs(types) do
  print("Type Name:" .. _type.Name)
end
```

### `legacy_getTypeDefMethods(ModuleHandle, TypeDefToken)`
**Description**

Does the same as **Cheat Engine's** `DotNetDataCollector` `getTypeDefMethods(ModuleHandle, TypeDefToken)`

**Parameters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get the methods for

**Returns:**
- A table containing information about all methods in the type
  - `MethodToken` (number): The Token of the method
  - `Attributes` (number): The attributes of the method
  - `ImplementationFlags` (number): The implementation flags of the method
  - `Name` (string): The Name of the Method
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

**Parameters:**
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
local obj = collectorEx.legacy_getAddressData(0x123456)
print("Class Name:" .. obj.ClassName)
```

### `legacy_enumAllObjects()`
**Description**

Does the same as **Cheat Engine's** `DotNetDataCollector` `enumAllObjects()`

**Parameters:**
- None

**Returns:**
- A table containing Information about all the allocated objects
  - `TypeID` (table):
    - `token1` (number): Seems to be the MethodTable/TypeHandle
    - `token2` (number):
  - `StartAddress` (number): The Start Address of the Object
  - `Size` (number): The size of the object
  - `ClassName` (string): The types name of the object

**Usage:**
```lua
local objects = collectorEx.legacy_enumAllObjects()
for _,obj in ipairs(objects) do
  print("Object Class Name:" .. obj.ClassName)
end
```


### `legacy_getTypeDefData(ModuleHandle, TypeDefToken)`
**Description**

Does the same as **Cheat Engine's** `DotNetDataCollector` `getTypeDefData(ModuleHandle, TypeDefToken)`

**Parameters:**
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

**Parameters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the method resides
- `MethodDefToken` (number): The **Token** of the method for which to get the data for

**Returns:**
- A table containing Information about the methods parameters
  - `Name` (string): This is the name of the method parameter
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

**Parameters:**
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

**Parameters:**
- `ModuleHandle` (number): The **ModuleHandle** in which the type resides
- `TypeDefToken` (number): The **Token** of the type for which to get all the allocated objects for

**Returns:**
- A table containing the address of each object
  - `<table index>` (number): The address of the Object

**Usage:**
```lua
local objects = collectorEx.legacy_enumAllObjectsOfType(module.ModuleHandle, type.TypeDefToken)
for _,obj in ipairs(objects) do
  printf("Object Address: %X", obj)
end
```

---

All of the below functions return nil if the **DotNetDataCollectorEx** is not running!

### `DataCollectorInfo()`
**Description**

Returns information about the **DataCollectorEx**

**Parameters:**
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

**Parameters:**
- None

**Returns:**
- A table containing information about all of the loaded App Domains
  - `hDomain` (number): The handle/address of the AppDomain
  - `Id` (number): The Id of the AppDomain
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

**Parameters:**
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
for _,_module in ipairs(modules) do
  print("Module Name is " .. _module.Name)
end
```

### `EnumTypeDefs(hModule)`
**Description**

Returns a table that contains all of the loaded modules

**Parameters:**
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
for _,_type in ipairs(types) do
  print("Type Name is " .. _type.Name)
end
```

### `GetTypeDefMethods(hType)`
**Description**

Returns a table that contains all of the methods inside the type

**Parameters:**
- `hType` (number): The MethodTable/TypeHandle of the Type for which to get the methods for

**Returns:**
- A table containing information about all of the methods inside the type
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `hType` (number): The MethodTable/TypeHandle of the type the method is inside of
  - `hModule` (number): The handle/address of the Module the method is inside of
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class.methodname(...)
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

**Parameters:**
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

**Parameters:**
- `address` (number): The address to get information about. Must be inside an Object

**Returns:**
- A table containing information about the address
  - `StartAddress` (number): The start Address of the Object
  - `Size` (number): The size of the Object
  - `Type` (table): A table containing information about the Objects type
    - `TypeToken` (number): The token of the type
    - `hType` (number): The MethodTable/TypeHandle of the type
    - `hModule` (number): The handle/address of the Module the type is inside of
    - `ElementType` (number): The Element Type of the type
    - `Name` (string): The name of the Type
    - `IsArray` (boolean): True if the type is an array type
    - `IsEnum` (boolean): True if the type if an enum else false
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
      - `hType` (number): The MethodTable/TypeHandle of the fields Type
      - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
      - `hType` (number): The MethodTable/TypeHandle of the fields Type
      - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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

**Parameters:**
- None

**Returns:**
- A table containing information about the address
  - `Address` (number): The start Address of the Object
  - `Size` (number): The size of the Object
  - `Type` (table): A table containing information about the Objects type
    - `TypeToken` (number): The token of the type
    - `hType` (number): The MethodTable/TypeHandle of the type
    - `hModule` (number): The handle/address of the Module the type is inside of
    - `ElementType` (number): The Element Type of the type
    - `Name` (string): The name of the Type
    - `IsArray` (boolean): True if the type is an array type
    - `IsEnum` (boolean): True if the type if an enum else false
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
      - `hType` (number): The MethodTable/TypeHandle of the fields Type
      - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
      - `hType` (number): The MethodTable/TypeHandle of the fields Type
      - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
for _,obj in ipairs(objects) do
  print("Object Address is " .. obj.Address)
end
```

### `GetTypeDefData(hType)`
**Description**

Returns a table that contains information about the type

**Parameters:**
- `hType` (number): The MethodTable/TypeHandle of the type

**Returns:**
- A table containing information about the address
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `hModule` (number): The handle/address of the Module the type is inside of
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `IsEnum` (boolean): True if the type if an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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

**Parameters:**
- `hMethod` (number): The MethodDesc of the Method for which to get the method Parameters for

**Returns:**
- A table containing information about all of parameters inside the method
  - `Signature` (string): The Signature of the Method
  - `<parameter Index>` (table): A table that contains information about the Parameter at that index(1,2,3,4,...) inside the Method -> foo:bar(int i1, bool b1, string s1) -> int i1 is index 1, bool b1 is index 2, string s1 is index 3 ...
    - `ParameterName` (string): The name of the parameter
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

**Parameters:**
- `hType` (number): The MethodTable/TypeHandle of the Type for which to get the allocated objects for

**Returns:**
- A table containing information about all of the allocated objects of the type
  - `Address` (number): The address of the Object
  - `Size` (number): The size of the Object

**Usage:**
```lua
local objects = collectorEx.EnumAllObjectsOfType(type.hType)
for _,obj in ipairs(objects) do
  printf("Object Address: %X | Size: %d", obj.Address, obj.Size)
end
```

### `GetTypeInfo(hType)` 
**Description**

Returns a table that contains information about the type | Does the same as `GetTypeDefData(hType)`

**Parameters:**
- `hType` (number): The MethodTable/TypeHandle of the type

**Returns:**
- A table containing information about the address
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `hModule` (number): The handle/address of the Module the type is inside of
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `IsEnum` (boolean): True if the type if an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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

**Parameters:**
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

**Parameters:**
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

**Parameters:**
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
  - `DependentTypeName` (string): The name of the objects type of the dependent handle if it is a dependent handle

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

**Parameters:**
- `hMethod` (number): The MethodDesc of the method to get the information for

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `hType` (number): The MethodTable/TypeHandle of the type the method is inside of
  - `hModule` (number): The handle/address of the Module the method is inside of
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class.methodname(...)
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

**Parameters:**
- `ip` (number): The ip(Instruction Pointer) that is inside the methods compiled body

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `hType` (number): The MethodTable/TypeHandle of the type the method is inside of
  - `hModule` (number): The handle/address of the Module the method is inside of
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class.methodname(...)
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

**Parameters:**
- (OPTIONAL) `elementType` (number): The `Element Type` of the type to get
- (OPTIONAL) `specialType` (number): The `"special Type"` to get see the description for more info

**Returns:**
- A table containing information about the `elementType` or `specialType`
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `hModule` (number): The handle/address of the Module the type is inside of
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `IsEnum` (boolean): True if the type if an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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

**Parameters:**
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

**Parameters:**
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

Returns a table that contains all of the stack frames of the thread

**Parameters:**
- `threadid` (number): The **Managed** or **OS** thread id

**Returns:**
- A table containing information about all of the stack frames of the thread
  - `StackPointer` (number): The stack pointer of the Stack in this stack frame
  - `InstructionPointer` (number): The IP of the stack frame -> The return address
  - `FrameKind` (number): The King this stack frame is
  - `FrameName` (number): The Name of the stack frame if any
  - `FullName` (number): The Full Name of the stack frame
  - `Method` (table): A Table containing information about the method, if the stack frame is inside a method
    - `MethodToken` (number): The Token of the Method
    - `hMethod` (number): The MethodDesc of the Method
    - `NativeCode` (number): The address of where the compiled method body starts
    - `Name` (string); The name of the method
    - `Signature` (string): The Signature of the method

**Usage:**
```lua
local stacktrace = collectorEx.TraceStack(1) -> Managed Thread Ids seem to be 1,2,3,...
for _,frame in ipairs(stacktrace) do
  print("Frame full name is: " .. frame.FullName)
end
```

### `GetThreadFromID(threadid)`
**Description**

Returns a table that contains information about the managed thread

**Parameters:**
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

Flushes the DAC Cache - Might want to call this if new objects have been allocated or new methods jitted.
You might also want to call this if you can't find a method that you now/think should have been compiled

**Parameters:**
- None

**Returns:**
- Nothing

**Usage:**
```lua
collectorEx.FlushDACCache()
```

**Returns:**
- A boolean (true on success and false on failure)

### `DumpModule(hModule, outputFilePath)`
**Description**

Dumps the specified module `hModule` to disc `outputFilePath`.
`outputFilePath` Needs to be the **full** file path including the file name!
Can only dump modules that are not **dynamic**!

**Parameters:**
- hModule (number): The handle of the Module.
- outputFilePath (string): The full file path, where to dump the module to.

**Returns:**
- `errorMessage` (string or nil): An error message if the operation fails, otherwise nil.
- `filePath` (string or nil): The path to the dumped module file if successful, otherwise nil.

**Usage:**
```lua
local collectorEx = getDotNetDataCollectorEx()
local modules = collectorEx.EnumModules()
local err,outpath = collectorEx.DumpModule(modules[1].hModule, "C:\\Users\\UserName\\Desktop\\DUMP_"..modules[1].Name)
if (err) then
  print ("Error occured while trying to dump module: "..err)
else
  print("Module file at: "..outpath)
end
```

### `DumpModuleEx(module, outputPath)`
**Description**

Dumps the specified module `module` to disc.
Is `outputPath` is a string then it needs to be a valid directory.
Can only dump modules that are not **dynamic**!
The outputted file will look like this: `outputPath\DUMP_<ModuleName>`, without the `<>`. If the Module for some reason doesn't have a name it will look like this: `outputPath\DUMP_UNKNOWNNAME_<hModule>`, without the `<>`.

**Parameters:**
- module (table): The module Table returned by `EnumModules(hDomain)`
- (OPTIONAL) outputPath (string): The directory where to create the dumped module. If this is not a string it will dump the module to the temp directory.

**Returns:**
- `errorMessage` (string or nil): An error message if the operation fails, otherwise nil.
- `filePath` (string or nil): The path to the dumped module file if successful, otherwise nil.

**Usage:**
```lua
local collectorEx = getDotNetDataCollectorEx()
local modules = collectorEx.EnumModules()
local err,outpath = collectorEx.DumpModule(modules[1], "C:\\Users\\UserName\\Desktop\\)
if (err) then
  print ("Error occured while trying to dump module: "..err)
else
  print("Module file at: "..outpath)
end
```

### `FindMethod(hModule, fullClassName, methodName, paramCount, caseSensitive)`
**Description**

Searches for the method in the Module `hModule` or in all Modules if `hModule` is not the Handle to a valid Module!
Let's say we have the method MyNameSpace.Foo:Bar(int i, bool b).
The fullClassName should be: "MyNameSpace.Foo" and the methodName should be "Bar".

**Parameters:**
- (OPTIONAL) hModule (number): The Handle of the Module to search for the method in.
- fullClassName (string): The full class name for which the method resides inside of -> "namespace.classname"
- methodName (string): The method name to searh for
- (OPTIONAL) paramCount (number): The parameter Count the method should have. If this is not a number or -1 then it will ignore the parameter Count. MyNameSpace.Foo:Bar(int i, bool b) -> paramCount = 2
- (OPTIONAL) caseSensitive (boolean): If this is true `fullClassName` and `methodName` are case sensitive.

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `hType` (number): The MethodTable/TypeHandle of the type the method is inside of
  - `hModule` (number): The handle/address of the Module the method is inside of
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class.methodname(...)
  - `ILAddress` (number): The address of where the methods IL Code is located
  - `ILSize` (number): The size of the methods IL Code
  - `ILFlags` (number): The Flags of the methods IL
  - `MethodRegions` (table): Table containing the methods compiled code regions if any
    - `StartAddress` (number): The start adddress if this code region
    - `Size` (number): The size of this code region

**Usage:**
```lua
local methodInfo = collectorEx.FindMethod(nil, 'mynamespace.foo', 'bar', 2, false)
print("Method Signature is " .. methodInfo.Signature)
```

### `FindMethodByDesc(hModule, methodSignature, caseSensitive)`
**Description**

Searches for the method in the Module `hModule` or in all Modules if `hModule` is not the Handle to a valid Module!
Let's say we have the method MyNameSpace.Foo:Bar(int i, bool b).
The `methodSignature` should look something like this: "MyNameSpace.Foo.Bar(System.Int32, System.Boolean)" or "MyNameSpace.Foo:Bar(System.Int32, System.Boolean)"

**Parameters:**
- (OPTIONAL) hModule (number): The Handle of the Module to search for the method in.
- methodSignature (string): The method signature of the method to search for
- (OPTIONAL) caseSensitive (boolean): If this is true `methodSignature` is case sensitive.

**Returns:**
- A table containing information about the method
  - `MethodToken` (number): The token of the Method
  - `hMethod` (number): The MethodDesc of the Method
  - `hType` (number): The MethodTable/TypeHandle of the type the method is inside of
  - `hModule` (number): The handle/address of the Module the method is inside of
  - `Name` (string): The name of the Method
  - `Attributes` (number): The attributes of the Method
  - `NativeCode` (number): The address of where the compiled code of the method is located. Or 0 if it hasn't been compiled yet
  - `Signature` (string): The Signature of the method -> namespace.class.methodname(...)
  - `ILAddress` (number): The address of where the methods IL Code is located
  - `ILSize` (number): The size of the methods IL Code
  - `ILFlags` (number): The Flags of the methods IL
  - `MethodRegions` (table): Table containing the methods compiled code regions if any
    - `StartAddress` (number): The start adddress if this code region
    - `Size` (number): The size of this code region

**Usage:**
```lua
local methodInfo = collectorEx.FindMethodByDesc(nil, 'MyNameSpace.Foo.Bar(System.Int32, System.Boolean)', true)
print("Method MethodToken is " .. methodInfo.MethodToken)
```

### `FindClass(hModule, fullClassName, caseSensitive)`
**Description**

Searches for the class in the Module `hModule` or in all Modules if `hModule` is not the Handle to a valid Module!
Let's say we have the class MyNameSpace.Foo
The `fullClassName` should look like this: "MyNameSpace.Foo" if it is a nested class: "MyNameSpace.Foo+Bar" where "Bar" is the nested class

**Parameters:**
- (OPTIONAL) hModule (number): The Handle of the Module to search for the method in.
- fullClassName (string): The full class name of the class to search for
- (OPTIONAL) caseSensitive (boolean): If this is true `fullClassName` is case sensitive.

**Returns:**
- A table containing information about the class
  - `TypeToken` (number): The token of the type
  - `hType` (number): The MethodTable/TypeHandle of the type
  - `hModule` (number): The handle/address of the Module the type is inside of
  - `ElementType` (number): The Element Type of the type
  - `Name` (string): The name of the Type
  - `IsArray` (boolean): True if the type is an array type
  - `IsEnum` (boolean): True if the type if an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
    - `hType` (number): The MethodTable/TypeHandle of the fields Type
    - `TypeIsEnum` (boolean): True if the fields type is an enum else false
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
local typeData = collectorEx.FindClass(nil, 'MyNameSpace.Foo', true)
print("Type Token is " .. typeData.TypeToken)
```

### `GetModuleFromType(hType)`
**Description**

Returns a table that contains information about the module the type is inside of

**Parameters:**
- `hType` (number): The MethodTable/TypeHandle of the type

**Returns:**
- A table containing information about the module the type is loaded inside of
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
local m = collectorEx.GetModuleFromType(myType.hType)
print("Module Name is " .. m.Name)
```

### `FindModule(moduleName, caseSensitive)`
**Description**

Returns a table that contains information about the found module

**Parameters:**
- moduleName (string): The modules name, can in some cases be the full file path. But will always work with the modules name and file name
- (OPTIONAL) caseSensitive (boolean): If this is true `moduleName` is case sensitive.

**Returns:**
- A table containing information about the found module
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
local m = collectorEx.FindModule('mymodule', false)
print("Module Assembly Name is " .. m.AssemblyName)
```

### `GetModuleFromMethod(hMethod)`
**Description**

Returns a table that contains information about the module the method is inside of

**Parameters:**
- `hMethod` (number): The MethodDesc of the Method

**Returns:**
- A table containing information about the module the module is loaded inside of
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
local m = collectorEx.GetModuleFromType(myMethod.hMethod)
print("Module Name is " .. m.Name)
```

### `GetModuleFromHandle(hModule)`
**Description**

Returns a table that contains information about the module

**Parameters:**
- `hModule` (number): The handle/address of the Module

**Returns:**
- A table containing information about the module the module
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
local m = collectorEx.GetModuleFromHandle(myType.hModule)
print("Module Name is " .. m.Name)
```

### `ReplaceLegacyDataCollector(restore)`
**Description:**

Replaces the legacy `DotNetDataCollector` with `DotNetDataCollectorEx`.
This is recommended for debugging **.NET 8+ applications**, as the legacy collector does not support those versions.
Only needed if `DotNetDataCollectorEx` is run in **extension mode** and not **replacement mode**.

**Parameters:**
- `restore` (boolean): Should restore the old DotNetDataCollector?

**Usage:**
```lua
local collectorEx = getDotNetDataCollectorEx()
collectorEx.ReplaceLegacyDataCollector(false)
```

### `RegisterCallbacks(unregister)`
**Description:**

- Can only be used if DotNetDataCollectorEx is running in `Extension Mode`, meaning it is running as it's own process. -> **.net 8+** Targets for example
- This should be used if the LegacyDotNetDataCollector is not running and you are running in `Extension Mode` and not `Replacement Mode`
- This will register 4 callbacks:
 - 'AddressLookupCallback': This is used by **Cheat Engine** to search for symbols in the Memory View window. Meaning Symbols for methods will be displayed!
 - 'SymbolLookupCallback': This is used by **Cheat Engine** to search for symbols in general. This means that If you for example use "Goto Address" or try to refernce the symbol somewhere. This is used for Methods so you can do -> GotoAddress(MyNameSpace.Foo:Bar)
 - 'StructureNameLookupCallback': This is used by **Cheat Engine's** Disscet data/structures. This will give structures the Class Name when dissecting a Managed Object like "Game.Player" for example
 - 'StructureDissectOverride': This is used by **Cheat Engine's** Disscet data/structures. This will create the strucuture for Managed Objects meaning it will fill the structure with all of the fields inside the Object's class.
 
**Parameters:**
- `unregister` (boolean): Should unregister all callbacks?

**Usage:**
```lua
local collectorEx = getDotNetDataCollectorEx()
collectorEx.RegisterCallbacks(false)
```

### `InitSymbolsForStaticFields(hModule, hType, includeTypeName, includeFullTypeName)`
**Description**

- Registers symbols for all static Fields inside of the Class(`hType`) or Module(`hModule`) if `hType` is null
- If `includeTypeName` is true and `includeFullTypeName` is not then it will put the Class name in front of the static fields name as the symbols name
- If `includeFullTypeName` is true then it will put the Full Class Name (NameSpace.ClassName) in front of the static fields name as the symbols name
- Example: `MyNameSpace.MyClass` -> Has a Static Field called `MyPlayer`
- `includeTypeName` = **true** and `includeFullTypeName` = **false** -> `Symbol: MyClass.MyPlayer`
- `includeTypeName` = **false** and `includeFullTypeName` = **false** -> `Symbol: MyPlayer`
- `includeFullTypeName` = **true** -> `Symbol: MyNameSpace.MyClass.MyPlayer`

**Parameters:**
- (OPTIONAL) `hModule` (number): The handle/address of the Module
- (OPTIONAL) `hType` (number): The MethodTable/TypeHandle of the type
- (OPTIONAL) `includeTypeName` (boolean): Include the Type Name in the Symbol
- (OPTIONAL) `includeFullTypeName` (boolean): Include the Full Type Name in the Symbol

**Returns:**
- Returns true on success, false on failure

**Usage:**
```lua
local success = collectorEx.InitSymbolsForStaticFields(nil, myType.hType, nil, true)
if (success) then
  print('Success')
  printf("Address: 0x%X",getAddressSafe('MyNameSpace.MyClass.MyPlayer'))
else
  print('Failure')
end
```

### `InitSymbolsForInstanceFields(hModule, hType, includeTypeName, includeFullTypeName)`
**Description**

- Registers symbols for all instance Fields inside of the Class(`hType`) or Module(`hModule`) if `hType` is null
- If `includeTypeName` is true and `includeFullTypeName` is not then it will put the Class name in front of the instance fields name as the symbols name
- If `includeFullTypeName` is true then it will put the Full Class Name (NameSpace.ClassName) in front of the instance fields name as the symbols name
- Example: `MyNameSpace.MyPlayer` -> Has a instance Field called `Health`
- `includeTypeName` = **true** and `includeFullTypeName` = **false** -> `Symbol: MyPlayer.Health`
- `includeTypeName` = **false** and `includeFullTypeName` = **false** -> `Symbol: Health`
- `includeFullTypeName` = **true** -> `Symbol: MyNameSpace.MyPlayer.Health`

**Parameters:**
- (OPTIONAL) `hModule` (number): The handle/address of the Module
- (OPTIONAL) `hType` (number): The MethodTable/TypeHandle of the type
- (OPTIONAL) `includeTypeName` (boolean): Include the Type Name in the Symbol
- (OPTIONAL) `includeFullTypeName` (boolean): Include the Full Type Name in the Symbol

**Returns:**
- Returns true on success, false on failure

**Usage:**
```lua
local success = collectorEx.InitSymbolsForInstanceFields(nil, myPlayer.hType, nil, true)
if (success) then
  print('Success')
  printf("Health offset inside Player Object: 0x%X",getAddressSafe('MyNameSpace.MyPlayer.Health'))
else
  print('Failure')
end
```

### `InitSymbolsForAllFields(hModule, hType, includeTypeName, includeFullTypeName)`
**Description**

- Registers symbols for all Fields inside of the Class(`hType`) or Module(`hModule`) if `hType` is null
- If `includeTypeName` is true and `includeFullTypeName` is not then it will put the Class name in front of the all fields name as the symbols name
- If `includeFullTypeName` is true then it will put the Full Class Name (NameSpace.ClassName) in front of the all fields name as the symbols name
- Example: `MyNameSpace.MyPlayer` -> Has a instance Field called `Health` and a static Field called `CurrentInstance`
- `includeTypeName` = **true** and `includeFullTypeName` = **false** -> `Symbol: MyPlayer.Health` | `Symbol: MyPlayer.CurrentInstance`
- `includeTypeName` = **false** and `includeFullTypeName` = **false** -> `Symbol: Health` | `Symbol: CurrentInstance`
- `includeFullTypeName` = **true** -> `Symbol: MyNameSpace.MyPlayer.Health` | `Symbol: MyNameSpace.MyPlayer.CurrentInstance`

**Parameters:**
- (OPTIONAL) `hModule` (number): The handle/address of the Module
- (OPTIONAL) `hType` (number): The MethodTable/TypeHandle of the type
- (OPTIONAL) `includeTypeName` (boolean): Include the Type Name in the Symbol
- (OPTIONAL) `includeFullTypeName` (boolean): Include the Full Type Name in the Symbol

**Returns:**
- Returns true on success, false on failure

**Usage:**
```lua
local success = collectorEx.InitSymbolsForAllFields(nil, myPlayer.hType, nil, true)
if (success) then
  print('Success')
  printf("Health offset inside Player Object: 0x%X",getAddressSafe('MyNameSpace.MyPlayer.Health'))
  printf("Player Current Instance Address: 0x%X", getAddressSafe('MyNameSpace.MyPlayer.CurrentInstance'))
else
  print('Failure')
end
```

### `CreateDotNetHelperScript()`
**Description**

- Creates(Allocates) an Auto Assembler section which adds methods that can be called from assembly
- See [`DotNetHelper Script`](LUA_API.md#dotnethelper-script) for more details and methods to call

**Parameters:**
- **NONE**

**Returns:**
- On Success: true
- On Failure: <1>(boolean) false | <2> (string) The error Message

**Usage:**
```lua
local success, err = collectorEx.CreateDotNetHelperScript()

if (success) then
  print('Success')
else
  print('Failure, error: '..err)
end
```

---

## Extension Functions:
- These functions use **Cheat Engine's** `DotNetInterface`
- Using the functions below will inject the `DotNetInterface` dll into the target!

### `CompileMethod(method)`
**Description**

- Will try and compile the method and returns its entry point

**Parameters:**
- method (number or table) This can either be the Method Object returned by methods like `FindMethod` or just the hMethod Handle. It is recommended to pase the method object if available though


**Returns:**
- On Success: <1>(number) The Entry of the Method | If was first compile <2>(number) The address returned when compiling the method, might be different than the actual entry of the method (stub code)
- On Failure: <1>(nil) | <2> (string) The error Message

**Usage:**
```lua
local r1,r2 = collectorEx.CompileMethod(myMethod)
if (r1) then
  print('Success')
  printf('Method Entry Point is: 0x%X',r1)
  if (r2) then
    print('Was compiled!')
    printf('Method Compiled Address is: 0x%X', r2)
  end
else
  print('Failure, Error Message: '..r2)
end
```

### `FindMethodAndCompile(hModule, fullClassName, methodName, paramCount, caseSensitive)`
**Description**

- A combination of [`FindMethod`](LUA_API.md#findmethodhmodule-fullclassname-methodname-paramcount-casesensitive) and [`FindMethod`](LUA_API.md#CompileMethodmethod)

**Parameters:**
See [`FindMethod`](LUA_API.md#findmethodhmodule-fullclassname-methodname-paramcount-casesensitive)

**Returns:**
- On Success: <1>(number) The Entry of the Method | If was first compile <2>(number) The address returned when compiling the method, might be different than the actual entry of the method (stub code)
- On Failure: <1>(nil) | <2> (string) The error Message

**Usage:**
```lua
local r1,r2 = collectorEx.FindMethodAndCompileMethod(nil, 'MyNameSpace.MyClass', 'MyMethod', nil, false)
if (r1) then
  print('Success')
  printf('Method Entry Point is: 0x%X',r1)
  if (r2) then
    print('Was compiled!')
    printf('Method Compiled Address is: 0x%X', r2)
  end
else
  print('Failure, Error Message: '..r2)
end
```

### `FindMethodByDescCompile(hModule, methodSignature, caseSensitive)`
**Description**

- A combination of [`FindMethodByDesc`](LUA_API.md#findmethodbydeschmodule-methodsignature-casesensitive) and [`FindMethod`](LUA_API.md#CompileMethodmethod)

**Parameters:**
See [`FindMethodByDesc`](LUA_API.md#findmethodbydeschmodule-methodsignature-casesensitive)

**Returns:**
- On Success: <1>(number) The Entry of the Method | If was first compile <2>(number) The address returned when compiling the method, might be different than the actual entry of the method (stub code)
- On Failure: <1>(nil) | <2> (string) The error Message

**Usage:**
```lua
local r1,r2 = collectorEx.FindMethodByDescAndCompileMethod(nil, 'MyNameSpace.MyClass.MyMethod()', false)
if (r1) then
  print('Success')
  printf('Method Entry Point is: 0x%X',r1)
  if (r2) then
    print('Was compiled!')
    printf('Method Compiled Address is: 0x%X', r2)
  end
else
  print('Failure, Error Message: '..r2)
end
```

### `RegisterAutoAssemblerCommands(unregister)`
**Description**

- Will Register Auto Assembler Commands see [`Auto Assembler Commands`](LUA_API.md#Auto-Assembler-Commands)

**Parameters:**
- (OPTIONAL) `unregister` (boolean): If true it will unregister the auto assembler commands instead

**Returns:**
- **Nothing**

**Usage:**
```lua
collectorEx.RegisterAutoAssemblerCommands()
```

---

## Auto Assembler Commands:

### `DotNetDefineMethod`

**Description**
- Works the same a define(symbol,value) but replaces the value passed with the address of the compiled method.
- Meaning that the value argument must be the Method Description String of the method.

**Usage:**
```
DotNetDefineMethod(mydefine,MyNameSpace.MyClass.MyMethod())
```

---

## DotNetHelper Script:
- This Script will export (Register) Methods that can be called from assembly
- All Functions that start with an **M** like `MAllocateString` have to be called from a managed thread!
 - Use `RunInDomain` or `CreateManagedThread` to call these from unmaged code

### `stdcall int RunInDomain(void* funcToRun, void* userarg)`
**Description**

- Will run the `funcToRun` address inside of the Default AppDomain.
- This is useful if you want to call Managed methods from assembly without hooking managed threads.
- This will also catch managed exceptions and return if it encounters one

**Parameters:**
- `funcToRun` (void*): The Address of the Method to run the function in
- `userarg` (void*): The Argument to pass to the `funcToRun` function

**Returns:**
- (int): [See](https://learn.microsoft.com/en-us/dotnet/framework/unmanaged-api/hosting/iclrruntimehost-executeinappdomain-method#return-value)

**Usage:**
```
label(myFunc)
label(main)
createthread(main)
<x64>:
main:
sub rsp,28
mov rcx,myFunc
mov rdx,0x12345678
call DotNetHelper.RunInDomain
add rsp,28
ret

myFunc:
sub rsp,28
<...>
add rsp,28
ret

<x86>
main:
push 0x12345678
push myFunc
call DotNetHelper.RunInDomain
ret 4

myFunc:
<...>
ret 4
```

### `stdcall HANDLE CreateManagedThread(void* lpStartAddress, void* lpParameter)`
**Description**

- Will create a new Thread and will run `lpStartAddress` in the Default App Domain
- **DO NOT** call Exit Thread inside there! Only return from it.
- This will also catch Managed exceptions and terminate the thread in the case one is thrown

**Parameters:**
- `lpStartAddress` (void*): The Address of where the thread should be created at
- `lpParameter` (void*): The Argument passed to `lpStartAddress`

**Returns:**
- (HANDLE): The handle of the unmanaged thread

**Usage:**
```
label(myThradFunc)
label(main)
createthread(main)
<x64>:
main:
sub rsp,28
mov rcx,myThradFunc
mov rdx,0x12345678
call DotNetHelper.CreateManagedThread
add rsp,28
ret

myThradFunc: // Runs in new Managed Thread
sub rsp,28
<...>
add rsp,28
ret

<x86>
main:
push 0x12345678
push myThradFunc
call DotNetHelper.CreateManagedThread
ret 4

myThradFunc: // Runs in new Managed Thread
<...>
ret 4
```

### `stdcall System.String MAllocateString(int length)`
**Description**

- Will allocate an empty System.String Object with the specified `length`

**Parameters:**
- `length` (int): The size of the to string to be allocated

**Returns:**
- (System.String): The new String object or 0 on failure

**Usage:**
```
label(myFunc)
label(main)
createthread(main)
<x64>:
main:
sub rsp,28
mov rcx,myFunc
mov rdx,0
call DotNetHelper.RunInDomain
add rsp,28
ret

myFunc:
sub rsp,28
mov ecx,#100
call DotNetHelper.MAllocateString
<...>
add rsp,28
ret

<x86>
main:
push 0
push myFunc
call DotNetHelper.RunInDomain
ret 4

myFunc:
push #100
call DotNetHelper.MAllocateString
<...>
ret 4
```

### `stdcall System.String MCreateString(const char* str)`
**Description**

- Will allocate a System.String Object from the ansi string `str`

**Parameters:**
- `str` (const char*): The Address of the 0-Terminated Ansi string to create a System.String Object from

**Returns:**
- (System.String): The new String object or 0 on failure

**Usage:**
```
label(myFunc)
label(main)
label(mystring)
createthread(main)

mystring:
db 'ThisIsMyString',0

<x64>:
main:
sub rsp,28
mov rcx,myFunc
mov rdx,0
call DotNetHelper.RunInDomain
add rsp,28
ret

myFunc:
sub rsp,28
lea rcx,[mystring]
call DotNetHelper.MCreateString
<...>
add rsp,28
ret

<x86>
main:
push 0
push myFunc
call DotNetHelper.RunInDomain
ret 4

myFunc:
push mystring
call DotNetHelper.MCreateString
<...>
ret 4
```

---

## Notes:
- `DotNetDataCollectorEx` provides additional functionality that the legacy collector does not.
- When debugging **.NET 8+**, calling `ReplaceLegacyDataCollector()` and `RegisterCallbacks()` ensures **almost** full Cheat Engine compatibility.
