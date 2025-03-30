local DotNetDataCollectorEx = {}
DotNetDataCollectorEx.__index = DotNetDataCollectorEx

dotnetpipeex = nil

local pipeConnectionTimeOut = 3000
local pipeReadTimeout = 10000
local StructureDefaultArrayCount = 9
local pointerSize = targetIs64Bit() and 8 or 4

local symbolCache = {}
local symbolCacheNames = {}

registerLuaFunctionHighlight("getDotNetDataCollectorEx")

DotNetDataCollectorExCommands = {
    -- L_ Legacy Commands
    L_CMD_TARGETPROCESS = 0,
    L_CMD_CLOSEPROCESSANDQUIT = 1,
    L_CMD_RELEASEOBJECTHANDLE = 2,
    L_CMD_ENUMDOMAINS = 3,
    L_CMD_ENUMMODULELIST = 4,
    L_CMD_ENUMTYPEDEFS = 5,
    L_CMD_GETTYPEDEFMETHODS = 6,
    L_CMD_GETADDRESSDATA = 7,
    L_CMD_GETALLOBJECTS = 8,
    L_CMD_GETTYPEDEFFIELDS = 9,
    L_CMD_GETMETHODPARAMETERS = 10,
    L_CMD_GETTYPEDEFPARENT = 11,
    L_CMD_GETALLOBJECTSOFTYPE = 12,
    -- Commands 13-20 Reserved
    CMD_TEST = 21,
    CMD_DATACOLLECTORINFO = 22,
    CMD_ENUMDOMAINS = 23,
    CMD_ENUMMODULELIST = 24,
    CMD_ENUMTYPEDEFS = 25,
    CMD_ENUMTYPEDEFMETHODS = 26,
    CMD_GETADDRESSDATA = 27,
    CMD_GETALLOBJECTS = 28,
    CMD_GETTYPEDEFFIELDS = 29,
    CMD_GETMETHODPARAMETERS = 30,
    CMD_GETTYPEDEFPARENT = 31,
    CMD_GETALLOBJECTSOFTYPE = 32,
    CMD_GETTYPEINFO = 33,
    CMD_GETBASECLASSMODULE = 34,
    CMD_GETAPPDOMAININFO = 35,
    CMD_ENUMGCHANDLES = 36,
    CMD_GETMETHODINFO = 37,
    CMD_GETMETHODBYIP = 38,
    CMD_GETTYPEFROMELEMENTTYPE = 39,
    CMD_CLRINFO = 40,
    CMD_ENUMTHREADS = 41,
    CMD_TRACESTACK = 42,
    CMD_GETTHREAD = 43,
    CMD_FLUSHDACCACHE = 44,
    CMD_DUMPMODULE = 45,
    CMD_METHODGETTYPE = 46,
    CMD_FINDMETHOD = 47,
    CMD_FINDMETHODBYDESC = 48,
    CMD_FINDCLASS = 49,
    CMD_CLASSGETMODULE = 50,
    CMD_FINDMODULE = 51,
    CMD_METHODGETMODULE = 52,
    CMD_GETMODULEBYHANDLE = 53
}

ClrElementType = {
    Unknown = 0x0,
    Void = 0x1,
    Boolean = 0x2,
    Char = 0x3,
    Int8 = 0x4,
    UInt8 = 0x5,
    Int16 = 0x6,
    UInt16 = 0x7,
    Int32 = 0x8,
    UInt32 = 0x9,
    Int64 = 0xA,
    UInt64 = 0xB,
    Float = 0xC,
    Double = 0xD,
    String = 0xE,
    Pointer = 0xF,
    ByRef = 0x10,
    Struct = 0x11,
    Class = 0x12,
    Var = 0x13,
    Array = 0x14,
    GenericInstantiation = 0x15,
    NativeInt = 0x18,
    NativeUInt = 0x19,
    FunctionPointer = 0x1B,
    Object = 0x1C,
    SZArray = 0x1D,
    MVar = 0x1E
}

ClrTypeToVarTypeLookup = {}
ClrTypeToVarTypeLookup[ClrElementType.Boolean] = vtByte
ClrTypeToVarTypeLookup[ClrElementType.Char] = vtUnicodeString
ClrTypeToVarTypeLookup[ClrElementType.Int8] = vtByte
ClrTypeToVarTypeLookup[ClrElementType.UInt8] = vtByte
ClrTypeToVarTypeLookup[ClrElementType.Int16] = vtWord
ClrTypeToVarTypeLookup[ClrElementType.UInt16] = vtWord
ClrTypeToVarTypeLookup[ClrElementType.Int32] = vtDword
ClrTypeToVarTypeLookup[ClrElementType.UInt32] = vtDword
ClrTypeToVarTypeLookup[ClrElementType.Int64] = vtQword
ClrTypeToVarTypeLookup[ClrElementType.UInt64] = vtQword
ClrTypeToVarTypeLookup[ClrElementType.Float] = vtSingle
ClrTypeToVarTypeLookup[ClrElementType.Double] = vtDouble
ClrTypeToVarTypeLookup[ClrElementType.String] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.Pointer] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.ByRef] = vtPointer
--ClrTypeToVarTypeLookup[ClrElementType.Stuct] = ?
ClrTypeToVarTypeLookup[ClrElementType.Class] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.Var] = vtPointer -- ?
ClrTypeToVarTypeLookup[ClrElementType.Array] = vtPointer
--ClrTypeToVarTypeLookup[ClrElementType.GenericInstantiation] = ?
ClrTypeToVarTypeLookup[ClrElementType.NativeInt] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.NativeUInt] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.FunctionPointer] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.Object] = vtPointer
ClrTypeToVarTypeLookup[ClrElementType.SZArray] = vtPointer
--ClrTypeToVarTypeLookup[ClrElementType.MVar] = ?

PipeServerState = {
    Loaded = 1 << 0,
    Attached = 1 << 1,
    AttachedEx = 1 << 2,
    PipeExCreated = 1 << 3,
    LegacyDataCollectorRunning = 1 << 4,
    RunningAsExtension = 1 << 5,
    NotLoaded = 1 << 6,
    TriedAttach = 1 << 7
}

local commands = DotNetDataCollectorExCommands

local function isValidNamespaceClassName(name)
    if not name or name == "" then return false end

    local first, last = name:byte(1), name:byte(-1)
    if first == 46 or last == 46 then -- 46 is ASCII for '.'
        return false
    end

    if name:find("[@#$%^&*()%=/\\,;:%%[%]{}|?]") then
        return false
    end

    for part in name:gmatch("[^.]+") do
        if not part:match("^[A-Za-z_][A-Za-z0-9_+<>]*$") then
            return false
        end
    end

    return true
end

local function isValidMethodName(name)
    if not name or name == "" then return false end

    if name:find("[@#$%^&*()%+=/\\,;:%%[%]{}|?.]") then
        return false
    end

    return name:match("^[A-Za-z_<][A-Za-z0-9_<>]*$") ~= nil
end

local function splitAndCaptureHex(str)
    local beforeHex, hexValue = str:match("^(.-)%+0?x?([0-9A-Fa-f]+)$")
    return beforeHex, hexValue
end

local function dotnetex_readString()
    local stringsize = dotnetpipeex.readDword()
    local strbt = dotnetpipeex.readBytes(stringsize)
    return byteTableToWideString(strbt)
end

local function dotnetex_writeString(str)
    local strbt = wideStringToByteTable(str)
    dotnetpipeex.writeDword(#strbt)
    dotnetpipeex.writeBytes(strbt)
end

local function dotnetex_I_splitSymbol(symbol)
    local result = nil
  
    local parts = {}
    -- Split the symbol by '.' or ':' to get parts
    for x in string.gmatch(symbol, "[^:.]+") do
      table.insert(parts, x)
    end
  
    local methodname = ''
    local classname = ''
    local namespace = ''
  
    if (#parts > 0) then
      -- Check if the last part is a constructor and adjust method name
      -- Check if the symbol ends with `.ctor` or `.cctor` to handle constructors
      methodname = (symbol:find("[:.]%.cc?tor$") ~= nil and '.' or '') .. parts[#parts] -- methodname = parts[#parts]
  
      -- Assign classname if there is more than one part
      if (#parts > 1) then
        classname = parts[#parts - 1]
  
        -- If there are more than two parts, construct the namespace
        if (#parts > 2) then
          for x = 1, #parts - 2 do
            if x == 1 then
              namespace = parts[x]
            else
              namespace = namespace .. '.' .. parts[x]
            end
          end
        end
      end
    end
  
    -- Return the result with methodname, classname, and namespace
    result = {}
    result.methodname = methodname
    result.classname = classname
    result.namespace = namespace
  
    return result
end

local function dotnetex_I_splitFullClassName(fullClassName)
    local result = {}

    local parts = {}

    for x in string.gmatch(fullClassName, "[^.]+") do
        table.insert(parts, x)
    end

    local namespace = ''
    local classname = ''

    if (#parts > 0) then
        classname = parts[#parts]

        if (#parts > 1) then
            for x = 1, #parts - 1 do
                if (x == 1) then
                    namespace = parts[x]
                else
                    namespace = namespace..'.'..parts[x]
                end
            end
        end
    end
    result.classname = classname
    result.namespace = namespace

    return result
end

function dotnetex_ClrTypeToVarType(clrType)
    local result = ClrTypeToVarTypeLookup[clrType]

    if (result == nil) then
        result = vtDword
    end
    return result
end

function dotnetex_ClrTypeIsSigned(clrType)
    return clrType == ClrElementType.Int8 or clrType == ClrElementType.Int16 or clrType == ClrElementType.Int32 or clrType == ClrElementType.Int64
end

local function dotnetex_I_getRunningDotNetInfoEx()
    local r = {}
    local od = DotNetDataCollectorEx.legacy_getAddressData(0xBDBDBDBDBDBDBD01)
    if (od) then
        local c = od.StartAddress
        r.RunningState = (c >> 32) & 0xFFFFFFFF
        r.PipeVersion = c & 0xFFFFFFFF
        r.PipeName = od.ClassName
    else
        r.RunningState = PipeServerState.NotLoaded
    end
    return r
end

local function dotnetex_I_getRunningDotNetInfo()
    local dc = getDotNetDataCollector()
    if (not dc or not dc.Attached or (dotnetpipeex and dotnetpipeex.isValid() and dotnetpipeex.AttachedEx)) then
        dc = {getAddressData = DotNetDataCollectorEx.legacy_getAddressData} -- Use Ex instead because the normal one isn't running or new pipe is already running
    end
    if (not dc) then return nil end
    local r = {}
    local od = dc.getAddressData(0xBDBDBDBDBDBDBD01)
    if (od) then
        local c = od.StartAddress
        r.RunningState = (c >> 32) & 0xFFFFFFFF
        r.PipeVersion = c & 0xFFFFFFFF
        r.PipeName = od.ClassName
    else
        r.RunningState = PipeServerState.NotLoaded
    end
    return r
end

local function dotnetex_I_CreateNewExPipe()
    local dc = getDotNetDataCollector()
    if not dc or not dc.Attached then return nil end
    local od = dc.getAddressData(0xBDBDBDBDBDBDBD00)
    if (not od) then return nil end
    if ((od.StartAddress >> 32) & PipeServerState.PipeExCreated == 0) then
        print("Something went wrong while trying to create ex pipe")
        return nil
    end
    return od.ClassName -- return pipe name
end

local processlocations = {
    getCheatEngineDir(),
    getAutorunPath(),
    getAutorunPath() .. "dlls\\"
}

local function dotnetex_I_FindDataCollectorExProcess()
    local function file_exists(path)
        local file = io.open(path, "r")
        if file then
            file:close()
            return true
        else
            return false
        end
    end

    local fileName = string.format("DotNetDataCollectorEx%s.exe", (targetIs64Bit() and "64" or "32"))

    for _,v in ipairs(processlocations) do
        if (file_exists(v..fileName)) then
            return v..fileName
        end
    end
    return nil
end

local function dotnetex_I_CreateProcess(pipeName)
    local processFilePath = dotnetex_I_FindDataCollectorExProcess()
    if (not processFilePath) then
        return false
    end
    shellExecute(processFilePath, pipeName.." ".."-nldc")
    return true
end

local function dotnetex_I_L_readType(o)
    local objType = dotnetpipeex.readDword()
    if (objType == 0xFFFFFFFF) then return nil end
    local r = (o or {})
    r.ObjectType = objType
    r.ElementType = 0
    r.CountOffset = 0
    r.ElementSize = 0
    r.FirstElementOffset = 0
    -- Check if object Type is Array
    if (objType == ClrElementType.Array or objType == ClrElementType.SZArray) then
        -- Handle Array types
        r.ClassName = "Array"
        r.ElementType = dotnetpipeex.readDword()
        r.CountOffset = dotnetpipeex.readDword()
        r.ElementSize = dotnetpipeex.readDword()
        r.FirstElementOffset = dotnetpipeex.readDword()
        if (r.ElementType == 0xFFFFFFFF) then
            r.ElementType = ClrElementType.Void
            r.ElementSize = 0
        end
    else
        -- Handle other types
        r.ClassName = dotnetex_readString()

        local fieldsCount = dotnetpipeex.readDword()
        local fields = {}
        for i = 1, fieldsCount do
            local f = {}
            f.Token = dotnetpipeex.readDword()
            f.Offset = dotnetpipeex.readDword()
            f.FieldType = dotnetpipeex.readDword()
            local attribs = dotnetpipeex.readDword()
            f.Attribs = attribs
            f.IsStatic = (attribs & 0x10 ~= 0)
            f.Name = dotnetex_readString()
            f.FieldTypeClassName = dotnetex_readString()
            fields[#fields + 1] = f
        end
        r.Fields = fields
    end
    return r
end

local function dotnetex_I_readType()
    local r = {}
    local token = dotnetpipeex.readDword()
    if (not token or token == 0xFFFFFFFF) then
        return {}
    end
    r.TypeToken = token
    r.hType = dotnetpipeex.readQword() -- This is either A: The MethodTable or B: The TypeHandle if the Type doesn't have a MethodTable
    r.hModule = dotnetpipeex.readQword()
    r.ElementType = dotnetpipeex.readDword() -- This is the types element type -> See ClrElementType
    r.TypeAttributes = dotnetpipeex.readDword() -- These are the types attributes -> See <System.Reflection.TypeAttributes>
    r.IsEnum = dotnetpipeex.readByte() ~= 0
    r.Name = dotnetex_readString() -- Name of the Type

    if (r.ElementType == ClrElementType.Array or r.ElementType == ClrElementType.SZArray) then
        -- Type is array Type
        r.IsArray = true
        local componentType = {} -- component type -> int[] -> component type is int
        componentType.ElementType = dotnetpipeex.readDword() -- Element type of the component type
        componentType.TypeToken = dotnetpipeex.readDword() -- TypeDefToken of the component Type
        componentType.hType = dotnetpipeex.readQword() -- Same as normal type but for component type
        componentType.Name = dotnetex_readString() -- Name of the component Type
        if (componentType.TypeToken ~= 0xFFFFFFFF) then
            r.ComponentType = componentType
        else
            r.ComponentType = {}
        end
        r.CountOffset = dotnetpipeex.readDword() -- Offset of the 'count' field for the array
        r.ComponentSize = dotnetpipeex.readDword() -- Size of each element inside the array
        r.FirstElementOffset = dotnetpipeex.readDword() -- Offset of the first element
        return r
    end
    r.IsArray = false
    local instanceFields = {}
    local staticFields = {}
    local allFields = {}

    local count = dotnetpipeex.readDword()
    for i = 1, count do
        local iField = {}
        iField.TypeToken = dotnetpipeex.readDword() -- TypeDefToken of the Fields type
        iField.Size = dotnetpipeex.readDword() -- Size of the Field
        iField.Offset = dotnetpipeex.readDword() -- Offset of the Field inside the object
        iField.ElementType = dotnetpipeex.readDword()
        iField.Attributes = dotnetpipeex.readDword() -- The Attributes of the Field -> see <System.Reflection.FieldAttributes>
        iField.Name = dotnetex_readString() -- The Name of the Field
        iField.TypeName = dotnetex_readString() -- The Name of the Type of the Field
        iField.hType = dotnetpipeex.readQword() -- The MethodTable or TypeHandle of the Fields Type
        iField.TypeIsEnum = dotnetpipeex.readByte() ~= 0
        iField.Address = dotnetpipeex.readQword() -- The address of the field -> Will only be valid if this was called with a ClrObject and not ClrType
        iField.IsStatic = false
        instanceFields[#instanceFields+1] = iField
        allFields[#allFields+1] = iField
    end

    count = dotnetpipeex.readDword()
    for i = 1, count do
        local sField = {}
        sField.TypeToken = dotnetpipeex.readDword() -- TypeDefToken of the Fields type
        sField.Size = dotnetpipeex.readDword() -- Size of the Field
        sField.Offset = dotnetpipeex.readDword() -- Offset of the Field from the Start of all Static Fields
        sField.ElementType = dotnetpipeex.readDword()
        sField.Attributes = dotnetpipeex.readDword() -- The Attributes of the Field -> see <System.Reflection.FieldAttributes>
        sField.Name = dotnetex_readString() -- The Name of the Field
        sField.TypeName = dotnetex_readString() -- The Name of the Type of the Field
        sField.hType = dotnetpipeex.readQword() -- The MethodTable or TypeHandle of the Fields Type
        sField.TypeIsEnum = dotnetpipeex.readByte() ~= 0
        sField.Address = dotnetpipeex.readQword() -- The address of the field
        sField.IsStatic = true
        staticFields[#staticFields+1] = sField
        allFields[#allFields+1] = sField
    end
    r.InstanceFields = instanceFields
    r.StaticFields = staticFields
    r.AllFields = allFields

    return r
end

local function dotnetex_I_readMethod()
    local r = {}
    r.MethodToken = dotnetpipeex.readDword() -- The metadata token of the method
    if (not r.MethodToken or r.MethodToken == 0xFFFFFFFF) then return {} end
    r.hMethod = dotnetpipeex.readQword() -- The MethodDesc of the method
    r.hType = dotnetpipeex.readQword() -- This is either A: The MethodTable or B: The TypeHandle if the Type doesn't have a MethodTable
    r.hModule = dotnetpipeex.readQword()
    r.Name = dotnetex_readString() -- The Name of the Method
    r.Attributes = dotnetpipeex.readDword() -- The Attributes of the Method -> see <System.Reflection.MethodAttributes>
    r.NativeCode = dotnetpipeex.readQword() -- The Address of where the Compiled Code is located
    r.Signature = dotnetex_readString() -- The full Method Signature of the Method
    r.ILAddress = dotnetpipeex.readQword() -- The Address of where the IL of the method is stored
    r.ILSize = dotnetpipeex.readDword() -- The size of the IL method body
    r.ILFlags = dotnetpipeex.readDword() -- The flags of the IL -> MethodImplAttributes?

    local methodRegions = {}
    local count = dotnetpipeex.readDword()
    for i = 1, count do
        local t = {}
        t.StartAddress = dotnetpipeex.readQword()
        t.Size = dotnetpipeex.readDword()
        methodRegions[#methodRegions+1] = t
    end
    r.MethodRegions = methodRegions -- Same as 'SecondaryNativeCode' in legacy versions -> Hot and Cold(if there is one) regions of the method

    return r
end

local function dotnetex_I_readModule()
    local r = {}
    r.hModule = dotnetpipeex.readQword() -- Module Handle / Address of Managed Module Object
    if (not r.hModule or r.hModule == 0xFFFFFFFFFFFFFFFF) then return {} end
    r.hAppDomain = dotnetpipeex.readQword() -- App Domain Handle to the AppDomain the Module is loaded in
    r.ImageBase = dotnetpipeex.readQword() -- The Address of where the Module is loaded in memory at, might be 0 when it is not a Module loaded from Disc?
    r.Size = dotnetpipeex.readQword() -- Size of the Module in Memory
    r.MetaDataAddress = dotnetpipeex.readQword() -- Address of the MetaData -> This is the address of the .net MetaData Header inside the module
    r.MetaDataLength = dotnetpipeex.readQword() -- Size of the MetaData
    r.Name = dotnetex_readString() -- Name of the Module
    r.AssemblyAddress = dotnetpipeex.readQword() -- Address of the Assembly
    r.AssemblyName = dotnetex_readString() -- Name of the Assembly
    r.Layout = dotnetpipeex.readDword() -- Layout of the Module see <Microsoft.Diagnostics.Runtime.ModuleLayout>
    r.IsDynamic = dotnetpipeex.readByte() ~= 0 -- true if the module is dynamic
    return r
end

local function dotnetex_targetProcess(processid)
    if (type(processid) ~= "number") then return false end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_TARGETPROCESS)
    dotnetpipeex.writeDword(processid)
    local result = dotnetpipeex.readByte()
    dotnetpipeex.readByte() -- Ignore "supports structure type lookups"
    return (result and result > 0)
end

local function dotnetex_I_getFQClassName(atype)
    if (atype == nil or atype == 0 or atype.Name == nil) then return nil end
    local fqClass = atype.Name:gsub("([^A-Za-z0-9%+%.,_$`<>%[%]])", "")
    if (fqClass == nil or #fqClass == 0) then return nil end
    return fqClass
end

local function dotnetex_I_exportArrayStruct(structure, atype, elementType, structmap, makeglobal, reload)
    --print("dotnetex_I_exportArrayStruct")
    if (structure ~= nil and atype~= nil and elementType ~= nil) then
        --print("dotnetex_I_exportArrayStruct_2")
        local elementStruct = dotnetex_exportStruct(elementType, nil, structmap, makeglobal, pointerSize)
        if (elementStruct ~= nil and reload) then
            --print("dotnetex_I_exportArrayStruct_3")
            structure_beginUpdate(structure)
            local ae = structure.addElement()
            ae.Name = 'Count'
            ae.Offset = atype.CountOffset
            ae.VarType = vtDword
            ae.setChildStruct(elementStruct)

            local psize = atype.ComponentSize
            local start = atype.FirstElementOffset

            local arrayCount = StructureDefaultArrayCount or 9
            for j = 0, arrayCount do
                ae = structure.addElement()
                ae.Name = string.format("[%d]%s", j, elementType.Name)
                ae.Offset = j*psize+start
                ae.VarType = dotnetex_ClrTypeToVarType(elementType.ElementType)
                if (dotnetex_ClrTypeIsSigned(elementType.ElementType)) then
                    ae.DisplayMethod = 'dtSignedInteger'
                end
            end
            structure_endUpdate(structure)
        end
    end
    return structure
end

local function dotnetex_I_exportStructure(structure, atype, structmap, makeglobal)
    if (dotnetpipeex == nil or dotnetpipeex.pipeInfo == nil) then return nil end

    if (not dotnetpipeex.isValid()) then return nil end

    if (atype == 0 or atype == nil) then return nil end

    --print(atype.Name)
    if (atype.IsArray and atype.ComponentType and atype.ComponentType.hType) then
        local elementType = DotNetDataCollectorEx.GetTypeDefData(atype.ComponentType.hType)
        return dotnetex_I_exportArrayStruct(structure, atype, elementType, structmap, makeglobal, true)
    end

    if (atype.InstanceFields == nil) then return nil end

    structure_beginUpdate(structure)

    local fields = atype.InstanceFields

    for i=1, #fields do
        local e = structure.addElement()
        local ft = fields[i].ElementType
        local fieldname = fields[i].Name:gsub("([^A-Za-z0-9%+%.,_$`<>%[%]])", "")
        if (fieldname ~= nil) then
            e.Name = fieldname
        end
        e.Offset = fields[i].Offset
        e.VarType = fields[i].TypeIsEnum and vtDword or dotnetex_ClrTypeToVarType(ft)
        if (dotnetex_ClrTypeIsSigned(ft)) then
            e.DisplayMethod = 'dtSignedInteger' -- make it signed if it is an integer
        end

        if (ft == ClrElementType.String or ft == ClrElementType.Char) then
            e.ByteSize = 999
        end
    end
    structure_endUpdate(structure)
    return structure
end

function dotnetex_exportStruct(atype, typeName, structmap, makeglobal, reload)
    local fqClass = dotnetex_I_getFQClassName(atype)
    if (typeName == nil) then
        typeName = fqClass
    end
    if (typeName == nil) then return nil end
    local s = structmap[typeName]
    if (s == nil) then
        s = createStructure(typeName)
        structmap[typeName] = s
        if (makeglobal) then
            structure_addToGlobalStructureList(s)
        end
    else
        if (not reload) then
            return s
        end
    end
    makeglobal = false
    return dotnetex_I_exportStructure(s, atype, structmap, makeglobal)
end

local function dotnetex_AddressLoopupCallback(address)
    if (address == 0) then return nil end -- Because of the cache table
    if (dotnetpipeex == nil or dotnetpipeex.pipeInfo == nil) then return nil end

    if (not dotnetpipeex.isValid()) then return nil end

    if (dotnetpipeex.pipeInfo.RunningState & PipeServerState.RunningAsExtension == 0) then return nil end

    local sce = symbolCache[address]

    if (sce ~= nil) then
        -- Check cache for symbol
        if (sce.e) then return nil end -- Invalid address/method already cached
        if (sce.s) then return sce.s end -- Start of Method, just return name
        if (sce.o) then
            -- Handle offsets
            local sce2 = symbolCache[address - sce.o] -- Get Base Symbol
            if (sce2 and sce2.s) then
                return string.format("%s+%x", sce2.s, sce.o)
            end
        end
    end

    if (readByte(address) == nil) then
        symbolCache[address] = { e = true } -- Ignore Invalid addresses, these might be offsets / other stuff
        return nil
    end

    --print(type(sce))
    --printf("%X",address)

    if (debug_isBroken()) then return nil end -- Will timeout pipe without this

    local result = ''

    local method = DotNetDataCollectorEx.GetMethodFromIP(address)

    if (method and method.Signature and method.NativeCode and method.MethodRegions and method.MethodRegions[1] and method.MethodRegions[1].StartAddress and method.MethodRegions[1].Size) then
        if (address < method.NativeCode) then
            symbolCache[address] = { e = true } -- Cache invalid methods
            return nil -- For some reason GetMethodFromIP will also return methods that are not within the actual method range but maybe a sort of copy of the method??? Or does it return the wrong method?
        end
        
        -- Handle the case in which the method lies outside of the "Hot" Region
        if (address > method.MethodRegions[1].StartAddress + method.MethodRegions[1].Size - 1) then
            symbolCache[address] = { e = true}
            return nil
        end -- Ignore if outside of Hot Region
        --local class = DotNetDataCollectorEx.GetTypeFromMethod(method.hMethod)
        local name = string.match(method.Signature, "^%s*([^%s%(]+)%s*%(")
        if (name) then
            name = name:match("%.cc?tor$") and name:gsub("%.%.(c?ctor)$", "::.%1") or name:gsub("(.*)%.", "%1::") -- Replace class.methodname with class::methodname
            result = result..name
        end
        if (not name or #name == 0) then -- Ignore empty names
            symbolCache[address] = {e = true}
            return nil
        end

        -- Add method to cache
        local baseaddr = method.MethodRegions[1].StartAddress
        for i = 0, method.MethodRegions[1].Size -1 do
            local ce = {}
            if (i == 0) then
                ce.s = name
            else
                ce.o = i
            end
            
            symbolCache[baseaddr + i] = ce
        end

        if (address ~= method.NativeCode) then
            result = result..string.format("+%x",address - method.NativeCode)
        end
    else
        symbolCache[address] = { e = true } -- Cache invalid addresses
    end

    return result
end

local function dotnetex_SymbolLookupCallback(symbol, recursive)
    --print(symbol)
    if (dotnetpipeex == nil or dotnetpipeex.pipeInfo == nil) then return nil end

    if (not dotnetpipeex.isValid()) then return nil end

    if (symbolCacheNames[symbol]) then
        if (symbolCacheNames[symbol] == -1) then return nil end -- Used for Invalid Symbols that were cached
        return symbolCacheNames[symbol]
    end

    if (not dotnetpipeex.SymbolLookupEnabled) then return nil end -- Only handle other symbols if RegisterCallbacks is active

    if symbol:match('[()%[%]]')~=nil then return nil end --no formulas/indexer
    --print(symbol)
    if (#symbol == 0) then return nil end

    local ss=dotnetex_I_splitSymbol(symbol)
    --print(ss.methodname)
    --print(ss.classname)
    --print(ss.namespace)
    --print(symbol)

    -- handle possible hex offset at the end
    local mname, offset = splitAndCaptureHex(ss.methodname)
    if (mname) then ss.methodname = mname end
    offset = offset and tonumber(offset, 16) or 0

    if (isValidMethodName(ss.methodname)) and (isValidNamespaceClassName(ss.namespace..'.'..ss.classname)) then
        local method=DotNetDataCollectorEx.FindMethod(nil, ss.namespace..'.'..ss.classname, ss.methodname)
        if (method == nil or method.NativeCode == nil) then
            if (recursive) then
                return nil
            end
            if (DotNetDataCollectorEx.FindClass(nil, symbol)) then
                symbolCacheNames[symbol] = -1 -- cache only class as invalid
                return nil -- Fail if the symbol is only the class name and not a method name
            end
            DotNetDataCollectorEx.FlushDACCache() -- Flush Cache Because maybe the method hadn't been jitted when collecting info, but has now
            return dotnetex_SymbolLookupCallback(symbol, true)
        end
        --[[]
        if (#method.MethodRegions > 0) then
            -- Add complete method to symbolCacheNames
            local baseaddr = method.MethodRegions[1].StartAddress
            local bsymbol = ss.namespace..'.'..ss.classname..'::'..ss.methodname
            for i = 0, method.MethodRegions[1].Size -1 do
                symbolCacheNames[string.format('%s+%X',bsymbol, i)] = baseaddr + i
            end
        end
        ]]
        symbolCacheNames[symbol] = method.NativeCode + offset
        return method.NativeCode + offset
    end
    symbolCacheNames[symbol] = -1
    return nil
end

local function dotnetex_StructureNameLookupCallback(address)
    if (dotnetpipeex == nil or dotnetpipeex.pipeInfo == nil) then return nil end

    if (not dotnetpipeex.isValid()) then return nil end

    local data = DotNetDataCollectorEx.GetAddressData(address)

    if (data ~= nil and data.StartAddress ~= nil and data.Type ~= nil) then
        return data.Type.Name, data.StartAddress -- data.StartAddress points to the MethodTable Pointer
    end
    return nil
end

local function dotnetex_StructureDissectOverride(structure, baseAddress)
    if (dotnetpipeex == nil or dotnetpipeex.pipeInfo == nil) then return nil end

    if (not dotnetpipeex.isValid()) then return nil end

    local addrData = DotNetDataCollectorEx.GetAddressData(baseAddress)

    if (addrData ~= nil and addrData.Type) then
        --print(addrData.Type.Name)
        --printf("%X",addrData.StartAddress)
        --printf("%X",baseAddress)
        local smap = {}
        local s
        if(addrData.StartAddress == baseAddress) then
            s = dotnetex_I_exportStructure(structure, addrData.Type, smap, false)
        end
        return s ~= nil
    end
    return nil
end

local function dotnetex_registerCallbacks(unregister)
    if (not dotnetpipeex or not dotnetpipeex.pipeInfo) then return false end
    if (dotnetpipeex.pipeInfo.RunningState & PipeServerState.RunningAsExtension ~= 0) then
        if (unregister) then
            if (dotnetpipeex.AddressLookupID ~= nil) then
                unregisterAddressLookupCallback(dotnetpipeex.AddressLookupID)
                dotnetpipeex.AddressLookupID = nil
            end
            dotnetpipeex.SymbolLookupEnabled = false
            --if (dotnetpipeex.SymbolLookupID ~= nil) then
            --    unregisterSymbolLookupCallback(dotnetpipeex.SymbolLookupID)
            --    dotnetpipeex.SymbolLookupID = nil
            --end
            if (dotnetpipeex.StructureNameLookupID ~= nil) then
                unregisterStructureNameLookup(dotnetpipeex.StructureNameLookupID)
                dotnetpipeex.StructureNameLookupID = nil
            end
            if (dotnetpipeex.StructureDissectOverrideID ~= nil) then
                unregisterStructureDissectOverride(dotnetpipeex.StructureDissectOverrideID)
                dotnetpipeex.StructureDissectOverrideID = nil
            end
            return true
        end
        -- Register callbacks if running as extension
        if (dotnetpipeex.AddressLookupID == nil) then
            dotnetpipeex.AddressLookupID = registerAddressLookupCallback(dotnetex_AddressLoopupCallback)
        end
        dotnetpipeex.SymbolLookupEnabled = true
        --if (dotnetpipeex.SymbolLookupID == nil) then
        --    dotnetpipeex.SymbolLookupID = registerSymbolLookupCallback(dotnetex_SymbolLookupCallback, slNotSymbol)
        --end
        if (dotnetpipeex.StructureNameLookupID == nil) then
            dotnetpipeex.StructureNameLookupID = registerStructureNameLookup(dotnetex_StructureNameLookupCallback)
        end
        if (dotnetpipeex.StructureDissectOverrideID == nil) then
            dotnetpipeex.StructureDissectOverrideID = registerStructureDissectOverride(dotnetex_StructureDissectOverride)
        end
        return true
    end
    return false
end

local function dotnetex_initSymbolsForFields(hModule, hType, includeTypeName, includeFullTypeName, includeStaticFields, includeInstanceFields)
    if (not dotnetpipeex.AttachedEx) then return false end
    if (not dotnetpipeex.isValid()) then return false end
    if (not includeStaticFields and not includeInstanceFields) then return false end
    local baseName = ''
    local sname
    local typeinfo
    if (hType) then
        typeinfo = DotNetDataCollectorEx.GetTypeDefData(hType)
        if (typeinfo) then
            sname = dotnetex_I_splitFullClassName(typeinfo.Name)
            if (includeFullTypeName) then
                baseName = sname.namespace .. '.' .. sname.classname .. '.'
            elseif (includeTypeName) then
                baseName = sname.classname .. '.'
            end

            if (includeStaticFields and typeinfo.StaticFields) then
                for _,v in ipairs(typeinfo.StaticFields) do
                    if (v.Address and v.Address ~= 0) then
                        symbolCache[v.Address] = {s = baseName..v.Name}
                        symbolCacheNames[baseName..v.Name] = v.Address
                        symbolCacheNames[typeinfo.Name..'.'..'StaticFields'] = v.Address - v.Offset
                        --print('Symbol added: '..baseName..v.Name)
                    end
                end
            end
            if (includeInstanceFields and typeinfo.InstanceFields) then
                for _,v in ipairs(typeinfo.InstanceFields) do
                    if (v.Offset) then
                        -- Don't add it to the symbolCache because we don't want offsets to be used in memory view or other places only by the Symbol lookup
                        symbolCacheNames[baseName..v.Name] = v.Offset
                    end
                end
            end
            return true
        end
        return false
    end

    local types = DotNetDataCollectorEx.EnumTypeDefs(hModule) -- Get all Types in Module or all modules
    if (not types) then return false end

    for _,v in ipairs(types) do
        typeinfo = DotNetDataCollectorEx.GetTypeDefData(v.hType)
        if (typeinfo) then
            baseName = ''
            sname = dotnetex_I_splitFullClassName(typeinfo.Name)
            if (includeFullTypeName) then
                baseName = sname.namespace .. '.' .. sname.classname .. '.'
            elseif (includeTypeName) then
                baseName = sname.classname .. '.'
            end

            if (includeStaticFields and typeinfo.StaticFields) then
                for _,k in ipairs(typeinfo.StaticFields) do
                    if (k.Address and k.Address ~= 0) then
                        symbolCache[k.Address] = {s = baseName..k.Name}
                        symbolCacheNames[baseName..k.Name] = k.Address
                        --print('Symbol added: '..baseName..k.Name)
                        symbolCacheNames[typeinfo.Name..'.'..'StaticFields'] = k.Address - k.Offset
                    end
                end
            end
            if (includeInstanceFields and typeinfo.InstanceFields) then
                for _,k in ipairs(typeinfo.InstanceFields) do
                    if (k.Offset) then
                        symbolCacheNames[baseName..k.Name] = k.Offset
                    end
                end
            end
        end
    end
    return true
end

local function dotnetex_closePipe()
    if (dotnetpipeex) then
        dotnetex_registerCallbacks(true)
        dotnetpipeex.lock()
        dotnetpipeex.writeByte(commands.L_CMD_CLOSEPROCESSANDQUIT)
        dotnetpipeex.unlock()
        dotnetpipeex.destroy()
        dotnetpipeex = nil
        DotNetDataCollectorEx.pipe = nil
    end
end

local function dotnetex_initPipe(timeout, pipeInfo)
    local pid = getOpenedProcessID()
    local expipecreated = false
    local processcreated = false
    if (dotnetpipeex and tonumber(dotnetpipeex.processid) == pid) then
        if (pipeInfo & PipeServerState.TriedAttach ~= 0 and pipeInfo & PipeServerState.Attached == 0) then
            print("Already tried to attach to process but it failed!")
            return false
        end
        return true
    end
    if (dotnetpipeex and pipeInfo.RunningState & (PipeServerState.AttachedEx | PipeServerState.Attached) ~= 0) then
        -- Handle connecting to new process
        --dotnetex_closePipe()
        return dotnetex_targetProcess(getOpenedProcessID())
    end

    local pipename

    if (pipeInfo.RunningState & PipeServerState.AttachedEx ~= 0) then
        if (pipeInfo.RunningState & (PipeServerState.PipeExCreated | PipeServerState.RunningAsExtension) ~= 0) then
            -- Pipe ex has already been created or it is already running as an extension in which case we don't need to create a new pipe
            return true
        end
        -- Tell process to create new pipe and send name
        pipename = dotnetex_I_CreateNewExPipe()
        if (not pipename) then
            print("Error while trying to create DotNetDataCollectorEx pipe")
            return false
        end
        expipecreated = true
    elseif (pipeInfo.RunningState & PipeServerState.NotLoaded ~= 0) then
        -- Load the process and create pipe
        pipename = string.format('cedotnetpipeex_%d_%d',getOpenedProcessID(),getTickCount())
        if (not dotnetex_I_CreateProcess(pipename)) then
            print("Failed to create DotNetDataCollectorEx process")
            return false
        end
        processcreated = true
    else
        --print("dotnetex_initPipe: Pipe running no dotnetpipeex")
        -- Pipe is running but dotnetpipeex is nil?
        -- Try to reconnect with pipe
        pipename = pipeInfo.PipeName
    end
    local targettk = getTickCount() + timeout
    while (targettk > getTickCount()) do
        dotnetpipeex = connectToPipe(pipename, pipeReadTimeout)
        if (dotnetpipeex) then break end
    end
    if (dotnetpipeex == nil) then
        print("DotNetDataCollectorEx Pipe connection Timeout!")
        return false
    end

    dotnetpipeex.OnError = function (self)
        dotnetpipeex = nil
        DotNetDataCollectorEx.pipe = nil
    end

    dotnetpipeex.OnTimeout = function (self)
        dotnetpipeex = nil
        DotNetDataCollectorEx.pipe = nil
        print("DotNetPipeEx timeout")
    end

    if (not expipecreated) then
        local result = dotnetex_targetProcess(pid)

        if (not result) then
            dotnetpipeex.destroy()
            dotnetpipeex = nil
            return false
        end
    end

    if (processcreated) then
        -- Get New PipeInfo because old is invalid now
        pipeInfo = dotnetex_I_getRunningDotNetInfoEx()
    end

    pipeInfo.RunningState = pipeInfo.RunningState & ~PipeServerState.NotLoaded -- Remove NotLoaded if it was set
    dotnetpipeex.processid = pid
    dotnetpipeex.pipeInfo = pipeInfo
    dotnetpipeex.isValid = function() return getOpenedProcessID()==tonumber(dotnetpipeex.processid) end
    dotnetpipeex.isLegacy = ((pipeInfo.RunningState & PipeServerState.Attached) ~= 0 and (pipeInfo.RunningState & PipeServerState.LegacyDataCollectorRunning) ~= 0)
    dotnetpipeex.Attached = pipeInfo.RunningState & PipeServerState.Attached ~= 0
    dotnetpipeex.AttachedEx = pipeInfo.RunningState & PipeServerState.AttachedEx ~= 0

    return true
end

-- Legacy Methods:

function DotNetDataCollectorEx.legacy_enumDomains()
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().enumDomains()
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_ENUMDOMAINS)
    local count = dotnetpipeex.readDword()
    local result = {}
    for i = 1, count do
        local t = {}
        t.DomainHandle = dotnetpipeex.readQword()
        t.Name = dotnetex_readString()
        result[#result+1] = t
    end
    dotnetpipeex.unlock()
    return result
end

function DotNetDataCollectorEx.legacy_enumModuleList(domainHandle)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().enumModuleList(domainHandle)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_ENUMMODULELIST)
    dotnetpipeex.writeQword(domainHandle)
    local count = dotnetpipeex.readDword()
    local result = {}
    for i = 1, count do
        local t = {}
        t.ModuleHandle = dotnetpipeex.readQword()
        t.BaseAddress = dotnetpipeex.readQword()
        t.Name = dotnetex_readString()
        result[#result+1] = t
    end
    dotnetpipeex.unlock()
    return result
end

function DotNetDataCollectorEx.legacy_enumTypeDefs(ModuleHandle)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().EnumTypeDefs(ModuleHandle)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_ENUMTYPEDEFS)
    dotnetpipeex.writeQword(ModuleHandle)
    local count = dotnetpipeex.readDword()
    local result =  {}
    for i = 1, count do
        local t = {}
        t.TypeDefToken = dotnetpipeex.readDword()
        t.Name = dotnetex_readString()
        t.Flags = dotnetpipeex.readDword()
        t.Extends = dotnetpipeex.readDword()
        result[#result+1] = t
    end
    dotnetpipeex.unlock()
    return result
end

function DotNetDataCollectorEx.legacy_getTypeDefMethods(ModuleHandle, TypeDefToken)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().getTypeDefMethods(ModuleHandle, TypeDefToken)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETTYPEDEFMETHODS)
    dotnetpipeex.writeQword(ModuleHandle)
    dotnetpipeex.writeDword(TypeDefToken)
    local count = dotnetpipeex.readDword()
    local result = {}
    for i = 1, count do
        local t = {}
        t.MethodToken = dotnetpipeex.readDword()
        t.Name = dotnetex_readString()
        t.Attributes = dotnetpipeex.readDword()
        t.ImplementationFlags = dotnetpipeex.readDword()
        t.ILCode = dotnetpipeex.readQword()
        t.NativeCode = dotnetpipeex.readQword()
        local count2 = dotnetpipeex.readDword()
        local t2 = {}
        for j = 1, count2 do
            -- secondaryCodeBlocks
            t2[j] = dotnetpipeex.readQword()
            dotnetpipeex.readDword()
        end
        t.SecondaryNativeCode = t2
        result[#result+1] = t
    end
    dotnetpipeex.unlock()
    return result
end

function DotNetDataCollectorEx.legacy_getAddressData(address)
    if (not dotnetpipeex) then return nil end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().legacy_getAddressData(address)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETADDRESSDATA)
    dotnetpipeex.writeQword(address)
    local r = {}
    local startaddr = dotnetpipeex.readQword()

    if startaddr ~= 0 then
        r.StartAddress = startaddr
        r = (dotnetex_I_L_readType(r) or {})
    end
    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.legacy_enumAllObjects()
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().enumAllObjects()
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETALLOBJECTS)
    local r = {}

    local objAddr
    local objSize
    local typeid
    repeat
        local o = {}
        typeid = {}
        objAddr = dotnetpipeex.readQword()
        objSize = dotnetpipeex.readDword()
        local typeBT = dotnetpipeex.readBytes(8*2)
        typeid.token1 = byteTableToQword(typeBT, 1) or 0
        typeid.token2 = byteTableToQword(typeBT, 9) or 0
        o.TypeID = typeid
        o.StartAddress = objAddr
        o.Size = objSize
        o.ClassName =dotnetex_readString()
        if (o.StartAddress and o.Size and o.TypeID and (o.StartAddress ~= 0 or o.Size ~= 0 or o.TypeID.token1 ~= 0 or o.TypeID.token2 ~= 0)) then
            r[#r + 1] = o
        end
    until ((objAddr == nil or objSize == nil or typeid == nil) or (objAddr == 0 and objSize == 0 and typeid.token1 == 0 and typeid.token2 == 0))
    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.legacy_getTypeDefData(ModuleHandle, TypeDefToken)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().getTypeDefData()
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETTYPEDEFFIELDS)
    dotnetpipeex.writeQword(ModuleHandle)
    dotnetpipeex.writeDword(TypeDefToken)

    local r = {}
    r = (dotnetex_I_L_readType() or {})
    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.legacy_getMethodParameters(ModuleHandle, MethodDefToken)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().getMethodParameters(ModuleHandle, MethodDefToken)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETMETHODPARAMETERS)
    dotnetpipeex.writeQword(ModuleHandle)
    dotnetpipeex.writeDword(MethodDefToken)
    local r = {}
    local count = dotnetpipeex.readDword()
    for i = 1, count do
        local t = {}
        t.Name = dotnetex_readString()
        t.CType = dotnetpipeex.readDword()
        local j = dotnetpipeex.readDword()
        r[j] = t
    end
    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.legacy_getTypeDefParent(ModuleHandle, TypeDefToken)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().getTypeDefParent(ModuleHandle, TypeDefToken)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETTYPEDEFPARENT)
    dotnetpipeex.writeQword(ModuleHandle)
    dotnetpipeex.writeDword(TypeDefToken)
    local r = {}
    r.ModuleHandle = dotnetpipeex.readQword()
    r.TypedefToken = dotnetpipeex.readDword()
    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.legacy_enumAllObjectsOfType(ModuleHandle, TypeDefToken)
    if (not dotnetpipeex) then return {} end
    --if (dotnetpipeex.isLegacy) then
    --    return getDotNetDataCollector().enumAllObjectsOfType(ModuleHandle, TypeDefToken)
    --end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.L_CMD_GETALLOBJECTSOFTYPE)
    dotnetpipeex.writeQword(ModuleHandle)
    dotnetpipeex.writeDword(TypeDefToken)

    local r = {}
    local addr
    repeat
        addr = dotnetpipeex.readQword()
        r[#r + 1] = addr
    until (addr == nil or addr == 0)

    dotnetpipeex.unlock()
    return r
end

-- New Methods

function DotNetDataCollectorEx.DataCollectorInfo()
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_DATACOLLECTORINFO)

    r.DataCollectorExRunning = dotnetpipeex.readByte() ~= 0
    r.LegacyDataCollectorRunning = dotnetpipeex.readByte() ~= 0
    r.PipeVersion = dotnetpipeex.readDword()
    r.PipeName = dotnetex_readString()
    r.PipeNameEx = dotnetex_readString()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumDomains()
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMDOMAINS)

    local count = dotnetpipeex.readDword()
    for i = 1, count do
        local t = {}
        t.hDomain = dotnetpipeex.readQword() -- Domain Handle / Address of Managed Domain Object
        t.Id = dotnetpipeex.readDword() -- Domain ID
        t.Name = dotnetex_readString()
        r[#r+1] = t
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumModules(hDomain) -- hDomain can be 0 or nil in which case it will get the modules in *ALL* Domains
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}
    if (type(hDomain) ~= "number") then hDomain = 0 end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMMODULELIST)
    dotnetpipeex.writeQword(hDomain)

    local count = dotnetpipeex.readDword()
    for i = 1, count do
        r[#r+1] = dotnetex_I_readModule()
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumTypeDefs(hModule) -- hModule can be 0 or nil in which case it will get *ALL* Types
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}
    if (type(hModule) ~= "number") then hModule = 0 end
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMTYPEDEFS)
    dotnetpipeex.writeQword(hModule)

    local count = dotnetpipeex.readDword()
    for i=1,count do
        local t = {}
        t.TypeToken = dotnetpipeex.readDword()
        t.hType = dotnetpipeex.readQword()
        t.ElementType = dotnetpipeex.readDword()
        t.TypeAttributes = dotnetpipeex.readDword()
        t.hModule = dotnetpipeex.readQword()
        t.StaticSize = dotnetpipeex.readDword() -- static size of objects of this type when created on the CLR heap
        t.Name = dotnetex_readString()
        t.StaticFieldsAddress = dotnetpipeex.readQword() -- Base Address of all Static Fields
        t.BaseTypeToken = dotnetpipeex.readDword() -- TypeToken of the parent class if any
        t.BasehType = dotnetpipeex.readQword()
        t.BaseName = dotnetex_readString()
        r[#r+1] = t
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetTypeDefMethods(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMTYPEDEFMETHODS)
    dotnetpipeex.writeQword(hType)

    local count = dotnetpipeex.readDword()
    for i=1, count do
        local t = dotnetex_I_readMethod()
        if (next(t) ~= nil) then
            r[#r+1] = t
        end
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetTypeDefParent(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEDEFPARENT)
    dotnetpipeex.writeQword(hType)

    r.TypeToken = dotnetpipeex.readDword()
    r.hType = dotnetpipeex.readQword()
    r.Name = dotnetex_readString()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetAddressData(address)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETADDRESSDATA)
    dotnetpipeex.writeQword(address)

    local startaddr = dotnetpipeex.readQword()
    if (not startaddr or startaddr == 0) then
        dotnetpipeex.unlock()
        return {}
    end

    r.StartAddress = startaddr -- The start Address of the Object
    r.Size = dotnetpipeex.readQword() -- Size of the Object
    r.Type = dotnetex_I_readType() -- The Type of the object

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumAllObjects()
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETALLOBJECTS)

    local addr
    local size

    repeat
        local o = {}
        addr = dotnetpipeex.readQword()
        size = dotnetpipeex.readQword()
        o.Address = addr
        o.Size = size
        if (addr and size and (addr ~= 0 or size ~= 0)) then
            o.Type = dotnetex_I_readType()
            r[#r+1] = o
        end
    until (addr == nil or size == nil or (addr == 0 and size == 0))

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetTypeDefData(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEDEFFIELDS)
    dotnetpipeex.writeQword(hType)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetMethodParameters(hMethod)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETMETHODPARAMETERS)
    dotnetpipeex.writeQword(hMethod)

    local count = dotnetpipeex.readDword()
    if (not count or count == 0xFFFFFFFF) then
        dotnetpipeex.unlock()
        return {}
    end
    
    r.Signature = dotnetex_readString()

    for i=1,count do
        local t = {}
        t.ParameterName = dotnetex_readString()
        t.ParameterTypeName = dotnetex_readString()
        t.ElementType = dotnetpipeex.readDword()
        t.Location = dotnetpipeex.readDword() -- The placement where the Parameter is inside the signature
        r[#r+1] = t
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumAllObjectsOfType(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETALLOBJECTSOFTYPE)
    dotnetpipeex.writeQword(hType)

    local addr = dotnetpipeex.readQword()

    if (not addr or addr == 0xFFFFFFFFFFFFFFFF) then
        dotnetpipeex.unlock()
        return {}
    end

    local size = dotnetpipeex.readQword()

    r[1] = {}
    r[1].Address = addr
    r[1].Size = size

    repeat
        local o = {}
        addr = dotnetpipeex.readQword()
        size = dotnetpipeex.readQword()
        o.Address = addr
        o.Size = size
        if (addr and size and (addr ~= 0 or size ~= 0)) then
            r[#r+1] = o
        end
    until (addr == nil or size == nil or (addr == 0 and size == 0))

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetTypeInfo(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEINFO)
    dotnetpipeex.writeQword(hType)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetBaseClassModule() -- Returns the Module of the BaseClassLibrary
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETBASECLASSMODULE)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetAppDomainInfo(hDomain)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETAPPDOMAININFO)
    dotnetpipeex.writeQword(hDomain)

    local addr = dotnetpipeex.readQword()
    if (addr == 0xFFFFFFFFFFFFFFFF) then return {} end

    r.hDomain = addr
    r.Id = dotnetpipeex.readDword()
    r.LoaderAllocator = dotnetpipeex.readQword()
    r.Name = dotnetex_readString()
    r.ApplicationBase = dotnetex_readString() -- base directory of the app domain
    r.ConfigurationFile = dotnetex_readString() -- config file of the app domain

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumGCHandes() -- Returns all GC Handles + Info
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMGCHANDLES)
    
    while(true) do
        local addr = dotnetpipeex.readQword()
        if (not addr or addr == 0xFFFFFFFFFFFFFFFF) then
            break
        end
        local o = {}
        o.HandleAddress = addr -- Gets the address of the root
        o.HandleKind = dotnetpipeex.readDword() -- Handle Kind -> see <Microsoft.Diagnostics.Runtime.ClrHandleKind>
        o.ReferenceCount = dotnetpipeex.readDword() -- Reference Count of the Handle
        o.RootKind = dotnetpipeex.readDword() -- gets the type of root this is -> see <Microsoft.Diagnostics.Runtime.ClrRootKind>
        o.hAppDomain = dotnetpipeex.readQword() -- Handle of the AppDomain
        o.ObjectAddress = dotnetpipeex.readQword() -- Address of the Object this handle references
        o.ObjectSize = dotnetpipeex.readQword()
        o.TypeToken = dotnetpipeex.readDword() -- The TypeToken of the Objects type
        o.hType = dotnetpipeex.readQword()
        o.TypeName = dotnetex_readString()
        o.DependentObjectAddress = dotnetpipeex.readQword() -- gets the address of the object of the dependent handle if it is a dependent handle
        o.DependentObjectSize = dotnetpipeex.readQword()
        o.DependentTypeToken = dotnetpipeex.readDword()
        o.DependenthType = dotnetpipeex.readQword()
        o.DependentTypeName = dotnetex_readString()
        r[#r+1] = o
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetMethodInfo(hMethod)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETMETHODINFO)
    dotnetpipeex.writeQword(hMethod)

    local r = dotnetex_I_readMethod()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetMethodFromIP(ip)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETMETHODBYIP)
    dotnetpipeex.writeQword(ip)

    local r = dotnetex_I_readMethod()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetTypeFromElementType(elementType, specialType)
    -- elementType: see ClrElementType
    -- specialType: 1->Heap.FreeType | 2-> ExceptionType -Either option is optional -> though special type gets prioritized
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    if (type(specialType) ~= "number") then specialType = 0 end
    if (type(elementType) ~= "number") then elementType = 0 end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEFROMELEMENTTYPE)
    dotnetpipeex.writeDword(elementType)
    dotnetpipeex.writeDword(specialType)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetCLRInfo()
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_CLRINFO)

    local flavor = dotnetpipeex.readDword()
    if (not flavor or flavor == 0xFFFFFFFF) then
        dotnetpipeex.unlock()
        return {}
    end
    r.Flavor = flavor -- -> see <Microsoft.Diagnostics.Runtime.ClrFlavor>
    r.Version = dotnetex_readString()
    r.ModuleImageBase = dotnetpipeex.readQword()
    r.ModuleImageSize = dotnetpipeex.readQword()
    r.ModuleIsManaged = dotnetpipeex.readByte() ~= 0
    r.ModuleFileName = dotnetex_readString()
    r.ModuleVersion = dotnetex_readString()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.EnumThreads()
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_ENUMTHREADS)

    local count = dotnetpipeex.readDword()
    if (not count or count == 0xFFFFFFFF) then count = 0 end

    for i=1,count do
        local t = {}
        t.hThread = dotnetpipeex.readQword() -- address of the managed thread object
        t.ManagedThreadId = dotnetpipeex.readDword() -- id of the managed thread
        t.NativeThreadId = dotnetpipeex.readDword() -- the thread id of the native(os) thread
        t.StackBase = dotnetpipeex.readQword()
        t.StackLimit = dotnetpipeex.readQword()
        t.GCMode = dotnetpipeex.readDword() -- the GC Mode -> see <Microsoft.Diagnostics.Runtime.GCMode>
        t.State = dotnetpipeex.readDword() -- the state of the thread -> see <Microsoft.Diagnostics.Runtime.ClrThreadState>
        t.IsAlive = dotnetpipeex.readByte() ~= 0
        t.IsGCThread = dotnetpipeex.readByte() ~= 0 -- true if the thread is a GC thread
        t.IsFinalizer = dotnetpipeex.readByte() ~= 0
        t.hCurrentAppDomain = dotnetpipeex.readQword()
        t.hCurrentException = dotnetpipeex.readQword()
        t.CurrentExceptionMessage = dotnetex_readString()
        r[#r+1] = t
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.TraceStack(threadid) -- Thread ID can either be the native/os or managed id. It will check for the native/os id first though
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_TRACESTACK)
    dotnetpipeex.writeDword(threadid)

    local count = dotnetpipeex.readDword()

    for i=1,count do
        local t = {}
        t.StackPointer = dotnetpipeex.readQword()
        t.InstructionPointer = dotnetpipeex.readQword()
        t.FrameKind = dotnetpipeex.readDword() -- The kind of frame this is -> see <Microsoft.Diagnostics.Runtime.ClrStackFrameKind>
        t.FrameName = dotnetex_readString()
        t.FullName = dotnetex_readString() -- See <Microsoft.Diagnostics.Runtime.ClrStackFrame.ToString()>
        local m = {}
        local mt = dotnetpipeex.readDword()
        if (mt and mt ~= 0xFFFFFFFF) then
            m.MethodToken = mt
            m.hMethod = dotnetpipeex.readQword()
            m.NativeCode = dotnetpipeex.readQword()
            m.Name = dotnetex_readString()
            m.Signature = dotnetex_readString()
        end
        t.Method = m
        r[#r+1] = t
    end

    dotnetpipeex.unlock()

    return r
end

function DotNetDataCollectorEx.GetThreadFromID(threadid) -- Returns info about the managed thread given its native/os or managed id
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end
    local r = {}

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTHREAD)
    dotnetpipeex.writeDword(threadid)

    local addr = dotnetpipeex.readQword()
    if (addr and addr ~= 0xFFFFFFFFFFFFFFFF) then
        r.hThread = addr
        r.ManagedThreadId = dotnetpipeex.readDword()
        r.NativeThreadId = dotnetpipeex.readDword()
        r.StackBase = dotnetpipeex.readQword()
        r.StackLimit = dotnetpipeex.readQword()
        r.GCMode = dotnetpipeex.readDword()
        r.State = dotnetpipeex.readDword()
        r.IsAlive = dotnetpipeex.readByte() ~= 0
        r.IsGCThread = dotnetpipeex.readByte() ~= 0
        r.IsFinalizer = dotnetpipeex.readByte() ~= 0
        r.hCurrentAppDomain = dotnetpipeex.readQword()
        r.hCurrentException = dotnetpipeex.readQword()
        r.CurrentExceptionMessage = dotnetex_readString()
    end

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.FlushDACCache() -- Flushes the DAC Cache
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return nil end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FLUSHDACCACHE)
    dotnetpipeex.unlock()
end

function DotNetDataCollectorEx.DumpModule(hModule, outputFilePath)
    if (not dotnetpipeex.AttachedEx) then return "No DotNetDataCollectorEx running" end
    if (not dotnetpipeex.isValid()) then return "DotNetDataCollectorEx is attached to wrong process" end
    
    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_DUMPMODULE)
    dotnetpipeex.writeQword(hModule)
    dotnetex_writeString(outputFilePath)

    local err = dotnetex_readString()
    local o = #err == 0 and outputFilePath or nil

    dotnetpipeex.unlock()
    return err,o
end

function DotNetDataCollectorEx.DumpModuleEx(module, outputPath)
    if (not dotnetpipeex.AttachedEx) then return "No DotNetDataCollectorEx running" end
    if (not dotnetpipeex.isValid()) then return "DotNetDataCollectorEx is attached to wrong process" end
    if (type(outputPath) ~= "string") then outputPath = getTempFolder() end
    
    outputPath = outputPath:match("\\$") and outputPath or outputPath .. "\\"
    local fileName = "DUMP_" .. (module.Name ~= "" and extractFileName(module.Name) or ("UNKNOWNNAME_" .. module.hModule))
    return DotNetDataCollectorEx.DumpModule(module.hModule, outputPath .. fileName)
end

function DotNetDataCollectorEx.GetTypeFromMethod(hMethod)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_METHODGETTYPE)
    dotnetpipeex.writeQword(hMethod)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.FindMethod(hModule, fullClassName, methodName, paramCount, caseSensitive)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    if (type(hModule) ~= "number") then hModule = 0 end
    if (type(paramCount) ~= "number") then paramCount = -1 end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FINDMETHOD)
    dotnetpipeex.writeQword(hModule)
    dotnetex_writeString(fullClassName)
    dotnetex_writeString(methodName)
    dotnetpipeex.writeDword(paramCount)
    dotnetpipeex.writeByte(caseSensitive and 1 or 0)

    local r = dotnetex_I_readMethod()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.FindMethodByDesc(hModule, methodSignature, caseSensitive)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    if (type(hModule) ~= "number") then hModule = 0 end
    if (type(paramCount) ~= "number") then paramCount = -1 end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FINDMETHODBYDESC)
    dotnetpipeex.writeQword(hModule)
    dotnetex_writeString(methodSignature)
    dotnetpipeex.writeByte(caseSensitive and 1 or 0)

    local r = dotnetex_I_readMethod()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.FindClass(hModule, fullClassName, caseSensitive)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    if (type(hModule) ~= "number") then hModule = 0 end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FINDCLASS)
    dotnetpipeex.writeQword(hModule)
    dotnetex_writeString(fullClassName)
    dotnetpipeex.writeByte(caseSensitive and 1 or 0)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetModuleFromType(hType)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_CLASSGETMODULE)
    dotnetpipeex.writeQword(hType)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.FindModule(moduleName, caseSensitive)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    if (type(moduleName) ~= "string") then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FINDMODULE)
    dotnetex_writeString(moduleName)
    dotnetpipeex.writeByte(caseSensitive and 1 or 0)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetModuleFromMethod(hMethod)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_METHODGETMODULE)
    dotnetpipeex.writeQword(hMethod)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetModuleFromHandle(hModule)
    if (not dotnetpipeex.AttachedEx) then return nil end
    if (not dotnetpipeex.isValid()) then return {} end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETMODULEBYHANDLE)
    dotnetpipeex.writeQword(hModule)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.ReplaceLegacyDataCollector(restore) -- Will replace the getDotNetDataCollector() function with a new one - if restore is set then it will restore the function instead
    if (restore) then
        if (DotNetDataCollectorEx.IsLegacyOverwritten) then
            getDotNetDataCollector = DotNetDataCollectorEx.legacyDataCollectorFunction
            DotNetDataCollectorEx.IsLegacyOverwritten = false
            return true
        end
        return false
    end
    if (DotNetDataCollectorEx.IsLegacyOverwritten) then
        return true
    end
    if (not dotnetpipeex.AttachedEx) then
        return false
    end
    DotNetDataCollectorEx.IsLegacyOverwritten = true
    DotNetDataCollectorEx.legacyDataCollectorFunction = getDotNetDataCollector
    local l_datacollector = {}
    l_datacollector.__index = l_datacollector
    l_datacollector.EnumDomains = DotNetDataCollectorEx.legacy_enumDomains
    l_datacollector.FieldAddress = function() return 0 end
    l_datacollector.getClassName = function() return "TDotNetPipe" end
    l_datacollector.MethodAddress = function() return 0 end
    l_datacollector.GetTypeDefData = DotNetDataCollectorEx.legacy_getTypeDefData
    l_datacollector.EnumAllObjectsOfType = DotNetDataCollectorEx.legacy_enumAllObjectsOfType
    l_datacollector.GetTypeDefParent = DotNetDataCollectorEx.legacy_getTypeDefParent
    l_datacollector.enumAllObjects = DotNetDataCollectorEx.legacy_enumAllObjects
    l_datacollector.ClassName = "TDotNetPipe"
    l_datacollector.enumDomains = DotNetDataCollectorEx.legacy_enumDomains
    l_datacollector.fieldAddress = l_datacollector.FieldAddress
    l_datacollector.GetAddressData = DotNetDataCollectorEx.legacy_getAddressData
    l_datacollector.GetClassName = l_datacollector.getClassName
    l_datacollector.enumModuleList = DotNetDataCollectorEx.legacy_enumModuleList
    l_datacollector.EnumTypeDefs = DotNetDataCollectorEx.legacy_enumTypeDefs
    l_datacollector.getTypeDefData = DotNetDataCollectorEx.legacy_getTypeDefData
    l_datacollector.enumAllObjectsOfType = DotNetDataCollectorEx.legacy_enumAllObjectsOfType
    l_datacollector.getAddressData = DotNetDataCollectorEx.legacy_getAddressData
    l_datacollector.GetMethodParameters = DotNetDataCollectorEx.legacy_getMethodParameters
    l_datacollector.getMethodParameters = DotNetDataCollectorEx.legacy_getMethodParameters
    l_datacollector.getTypeDefParent = DotNetDataCollectorEx.legacy_getTypeDefParent
    l_datacollector.EnumAllObjects = DotNetDataCollectorEx.legacy_enumAllObjects
    l_datacollector.getTypeDefMethods = DotNetDataCollectorEx.legacy_getTypeDefMethods
    l_datacollector.GetTypeDefMethods = DotNetDataCollectorEx.legacy_getTypeDefMethods
    l_datacollector.methodAddress = l_datacollector.MethodAddress
    l_datacollector.enumTypeDefs = DotNetDataCollectorEx.legacy_enumTypeDefs
    l_datacollector.className = "TDotNetPipe"
    l_datacollector.EnumModuleList = DotNetDataCollectorEx.legacy_enumModuleList
    l_datacollector.MethodName = function () end
    l_datacollector.methodName = l_datacollector.MethodName
    l_datacollector.Attached = true
    getDotNetDataCollector = function () return l_datacollector end
    return true
end

function DotNetDataCollectorEx.RegisterCallbacks(unregister)
    return dotnetex_registerCallbacks(unregister)
end

function DotNetDataCollectorEx.InitSymbolsForStaticFields(hModule, hType, includeTypeName, includeFullTypeName)
    return dotnetex_initSymbolsForFields(hModule, hType, includeTypeName, includeFullTypeName, true, false)
end

function DotNetDataCollectorEx.InitSymbolsForInstanceFields(hModule, hType, includeTypeName, includeFullTypeName)
    return dotnetex_initSymbolsForFields(hModule, hType, includeTypeName, includeFullTypeName, false, true)
end

function DotNetDataCollectorEx.InitSymbolsForAllFields(hModule, hType, includeTypeName, includeFullTypeName)
    return dotnetex_initSymbolsForFields(hModule, hType, includeTypeName, includeFullTypeName, true, true)
end

-- Extensions
local extensions_unloadDIAU = false -- 'unloadDotNetInteraceAfterUse'
local extensions_hideDIAU = true
local extensions_dotnetpipe
local extensions_dotnetpipeWasOn

local function dotnet_disconnectex(onlyHide)
    if dotnetpipe and not onlyHide then
        extensions_dotnetpipe = nil
        dotnetpipe.lock()
        dotnetpipe.writeByte(DOTNETCMD_EXIT)
        dotnetpipe.unlock()
  
        dotnetpipe.destroy()
    end
    dotnetpipe = nil
end

local function dotnet_getModuleIDEx(modulename)
    if dotnetmodulelist==nil then
      dotnet_initModuleList()
      
      if dotnetmodulelist==nil then return end
    end
    
    local m=dotnetmodulelist[modulename]
    if m then
      return m.Index-1
    else
      for i=1,#dotnetmodulelist do
        if dotnetmodulelist[i].ScopeName==modulename then
          return i-1
        end
      
        if extractFileNameWithoutExt(dotnetmodulelist[i].ScopeName)==modulename then
          return i-1
        end
        
        if extractFileNameWithoutExt(modulename)==dotnetmodulelist[i].ScopeName then
          return i-1
        end
      end
    end
end

local function dotnet_usingpipe(state)
    if (state) then
        dotnetpipeex.lock()
        extensions_dotnetpipeWasOn = false
        if (not dotentpipe and extensions_dotnetpipe) then
            dotnetpipe = extensions_dotnetpipe
            if (not dotnetpipe.isValid()) then LaunchDotNetInterface() end
        elseif (dotnetpipe and dotnetpipe.isValid()) then extensions_dotnetpipeWasOn = true else LaunchDotNetInterface() end
        extensions_dotnetpipe = dotnetpipe
    else
        if (not extensions_dotnetpipeWasOn and (extensions_unloadDIAU or extensions_hideDIAU)) then dotnet_disconnectex(extensions_hideDIAU) end
        dotnetpipeex.unlock()
    end
end

function DotNetDataCollectorEx.CompileMethod(method) --dontTraverseJumps
    if (not dotnetpipeex.AttachedEx) then return nil, 'DotNetDataCollectorEx not attached in EX Mode' end
    if (not dotnetpipeex.isValid()) then return nil, 'DotNetDataCollectorEx not Valid' end
    -- method can be the method or the hMethod
    if (not method) then return nil, 'Invalid Method' end
    if (type(method) ~= "table") then
        method = DotNetDataCollectorEx.GetMethodInfo(method)
        if (not method) then return nil, 'Invalid Method' end
    end
    if (method.NativeCode and method.NativeCode ~= 0) then return method.NativeCode end -- Method has already been compiled

    if (not method.hMethod or not method.MethodToken) then return nil, 'Invalid Method' end

    local module = DotNetDataCollectorEx.GetModuleFromMethod(method.hMethod)
    if (not module or not module.Name) then
        -- GetModuleFromMethod seems to sometimes fail
        module = DotNetDataCollectorEx.GetModuleFromHandle(method.hModule)
    end
    if (not module or not module.Name) then return nil, 'Invalid Module' end

    dotnet_usingpipe(true)
    local moduleid = dotnet_getModuleIDEx(module.Name)
    if (not moduleid) then
        dotnet_usingpipe(false)
        return nil, 'Failed to get Module ID'
    end
    local result = dotnet_getMethodEntryPoint(moduleid,method.MethodToken)
    dotnet_usingpipe(false)
    if (result == nil) then return nil,'Failed to compile Method' end
    --if (not dontTraverseJumps) then
    --    while(readBytes(result,1,false) == 0xE9) do
    --        -- Compiled method starts with a Jump to said method, define the right method - This will be the wrong one if the method has been hooked, which is unlikly if it hasn't been compiled yet
    --        local jmpoffset = signExtend(readInteger(result+1),31)
    --        result = result+jmpoffset+5
    --    end
    --end
    DotNetDataCollectorEx.FlushDACCache()
    local result2
    local m = DotNetDataCollectorEx.GetMethodInfo(method.hMethod)
    if (m and m.NativeCode) then
        result2 = result
        result = m.NativeCode
    end
    return result, result2
end

function DotNetDataCollectorEx.FindMethodAndCompile(hModule, fullClassName, methodName, paramCount, caseSensitive)
    local method = DotNetDataCollectorEx.FindMethod(hModule, fullClassName, methodName, paramCount, caseSensitive)
    if (not method or not method.MethodToken) then return nil, 'Failed to find Method' end
    return DotNetDataCollectorEx.CompileMethod(method)
end

function DotNetDataCollectorEx.FindMethodByDescAndCompile(hModule, methodSignature, caseSensitive)
    local method = DotNetDataCollectorEx.FindMethodByDesc(hModule, methodSignature, caseSensitive)
    if (not method or not method.MethodToken) then return nil, 'Failed to find Method' end
    return DotNetDataCollectorEx.CompileMethod(method)
end

local function DotNetDefineMethodAA(parameters,syntaxcheckonly)
    if (not dotnetpipeex.AttachedEx) then return nil, 'DotNetDataCollectorEx not being used' end
    if (not dotnetpipeex.isValid()) then return nil, 'DotNetDataCollectorEx pipe invalid' end
    local label,addrstring = string.split(parameters,',')
    label = label:trim()
    addrstring = addrstring:trim()
    local code,err = DotNetDataCollectorEx.FindMethodByDescAndCompile(nil, addrstring, false)
    if (code == nil) then return nil,err end
    return string.format('define(%s,%X)',label,code)
end

function DotNetDataCollectorEx.RegisterAutoAssemblerCommands(unregister)
    if (unregister) then
        unregisterAutoAssemblerCommand('DotNetDefineMethod')
    else
        registerAutoAssemblerCommand('DotNetDefineMethod', DotNetDefineMethodAA)
    end
end

local dotnetHelperScriptProcId

function DotNetDataCollectorEx.CreateDotNetHelperScript()
    if (dotnetHelperScriptProcId and dotnetHelperScriptProcId == getOpenedProcessID()) then return true end -- Already loaded
    local DotNetHelperScriptTemp = [==[
// Any Function that starts with a M should be run inside the AppDomain // RunInDomain or CreateManagedThread
// Example: DotNetHelper.MAllocateString
// All other functions should(?) be run outside the AppDomain
[64-bit]
alloc(DotNetHelper,0x1000,$process)
[/64-bit]
[32-bit]
alloc(DotNetHelper,0x1000)
[/32-bit]
registersymbol(DotNetHelper)

label(DotNetHelper.RunInDomain)
registersymbol(DotNetHelper.RunInDomain)

label(DotNetHelper.CreateManagedThread)
registersymbol(DotNetHelper.CreateManagedThread)

label(DotNetHelper.MAllocateString)
registersymbol(DotNetHelper.MAllocateString)

label(DotNetHelper.MCreateString)
registersymbol(DotNetHelper.MCreateString)

label(DotNetHelper.IThreadStub)

label(DotNetHelper.ICLRRuntimeHost)

label(DotNetHelper.IGetRuntimeHost)
registersymbol(DotNetHelper.IGetRuntimeHost)

label(DotNetHelper.IMethodTable)

DotNetHelper:

DotNetHelper.RunInDomain: // stdcall int RunInDomain(void* funcToRun, void* userarg)
// Runs 'funcToRun' in the Main AppDomain and passes 'userarg' in rcx(first argument) // [esp+4]
// If the process is 32-bit then 'funcToRun' has to be a function that uses the stdcall-ing convention('userarg' is passed in [esp+4] and should use ret 4)
[64-bit]
test rcx,rcx
jnz short @f
  mov eax,-1
  ret
@@:
sub rsp,38
mov [rsp+20],rcx
mov [rsp+28],rdx
call DotNetHelper.IGetRuntimeHost
test rax,rax
jnz short @f
  mov eax,-2
  add rsp,38
  ret
@@:
mov rcx,rax // ICLRRuntimeHost * This
mov edx,1 // dwAppDomainId
mov r8,[rsp+20] // FExecuteInAppDomainCallback pCallback
mov r9,[rsp+28] // void *cookie
mov rax,[rcx]
call [rax+8*8] // ExecuteInAppDomain // +40
add rsp,38
ret
[/64-bit]

[32-bit]
cmp [esp+4],0
jne short @f
  mov eax,-1
  ret 8
@@:
call DotNetHelper.IGetRuntimeHost
test eax,eax
jnz short @f
  mov eax,-2
  ret 8
@@:
push [esp+8] // *cookie
push [esp+8] // FExecuteInAppDomainCallback pCallback
push 1 // dwAppDomainId
push eax // ICLRRuntimeHost * This
mov eax,[eax]
call [eax+8*4] // ExecuteInAppDomain // +20
ret 8
[/32-bit]

align 4 CC

DotNetHelper.CreateManagedThread: // stdcall HANDLE CreateManagedThread(void* lpStartAddress, void* lpParameter)
// Creates a Thread and makes it run in the Main Domain.
// Thread has to return and should not call ExitThread without returning first!
[64-bit]
test rcx,rcx
jnz short @f
  xor eax,eax
  ret
@@:
sub rsp,38
mov [rsp+20],rcx
mov [rsp+28],rdx
mov rcx,gs:[60]
mov rcx,[rcx+30]
xor edx,edx
mov r8d,10
call ntdll.RtlAllocateHeap
test rax,rax
jnz short @f
  add rsp,38
  ret
@@:
movups xmm0,[rsp+20]
movups [rax],xmm0
xor rcx,rcx
xor edx,edx
lea r8,[DotNetHelper.IThreadStub]
mov r9,rax
xorps xmm0,xmm0
movups [rsp+20],xmm0
call KernelBase.CreateThread
add rsp,38
ret
[/64-bit]

[32-bit]
cmp [esp+4],0
jne short @f
  xor eax,eax
  ret 8
@@:
push 8
push 0
mov eax,fs:[30]
push [eax+18]
call ntdll.RtlAllocateHeap
test eax,eax
jnz short @f
  ret 8
@@:
movq xmm0,[esp+4]
movq [eax],xmm0
push 0
push 0
push eax
push DotNetHelper.IThreadStub
push 0
push 0
call KernelBase.CreateThread
ret 8
[/32-bit]

align 4 CC

DotNetHelper.MAllocateString: // stdcall System.String MAllocateString(int length)
[64-bit]
mov rax,[DotNetHelper.IMethodTable]
test rax,rax
jz short @f
jmp rax
@@:
ret
[/64-bit]
[32-bit]
push ebp
mov ebp,esp
mov eax,[DotNetHelper.IMethodTable]
test eax,eax
jz short @f
mov ecx,[ebp+8]
push [ebp+8]
call eax
@@:
mov esp,ebp
pop ebp
ret
[/32-bit]

align 4 CC

DotNetHelper.MCreateString: // stdcall System.String MCreateString(const char* str)
[64-bit]
sub rsp,28
test rcx,rcx
jz @f
mov [rsp+20],rcx
call ntdll.strlen
mov edx,eax
mov rcx,[rsp+20]
mov rax,[DotNetHelper.IMethodTable+8]
test rax,rax
jz short @f
call rax
@@:
add rsp,28
ret
[/64-bit]

[32-bit]
push ebp
mov ebp,esp
cmp dword ptr [ebp+8],0
je @f
push [ebp+8]
call ntdll.strlen
mov edx,eax
mov ecx,[ebp+8]
push eax
push [ebp+8]
mov eax,[DotNetHelper.IMethodTable+8]
test eax,eax
jz short @f
call eax
@@:
mov esp,ebp
pop ebp
ret 4
[/32-bit]

align 4 CC

DotNetHelper.IThreadStub:
[64-bit]
sub rsp,38
movups xmm0,[rcx]
movups [rsp+20],xmm0
mov r8,rcx
mov rcx,gs:[60]
mov rcx,[rcx+30]
xor edx,edx
call ntdll.RtlFreeHeap
mov rcx,[rsp+20]
mov rdx,[rsp+28]
call DotNetHelper.RunInDomain
add rsp,38
ret
[/64-bit]

[32-bit]
mov eax,[esp+4]
push [eax+4]
push [eax]
push eax
push 0
mov eax,fs:[30]
push [eax+18]
call ntdll.RtlFreeHeap
call DotNetHelper.RunInDomain
ret 4
[/32-bit]

align 4 CC

[64-bit]
DotNetHelper.ICLRRuntimeHost:
dq 0
[/64-bit]
[32-bit]
DotNetHelper.ICLRRuntimeHost:
dd 0
[/32-bit]

DotNetHelper.IMethodTable:
dq %x
dq %x

%s
]==]

    local DotNetCoreHelperStub = [==[
label(IID_ICLRRuntimeHost4)

IID_ICLRRuntimeHost4:
db 66 d3 f6 64 c2 d7 1f 4f b4 b2 e8 16 0c ac 43 af

[64-bit]
DotNetHelper.IGetRuntimeHost:
mov rax,[DotNetHelper.ICLRRuntimeHost]
test rax,rax
jz short @f
  ret
@@:
sub rsp,28
mov rcx,IID_ICLRRuntimeHost4
mov rdx,DotNetHelper.ICLRRuntimeHost
call GetCLRRuntimeHost
add rsp,28
test eax,eax
jnz short @f
  mov rax,[DotNetHelper.ICLRRuntimeHost]
  ret
@@:
xor eax,eax
ret
[/64-bit]

[32-bit]
DotNetHelper.IGetRuntimeHost:
mov eax,[DotNetHelper.ICLRRuntimeHost]
test eax,eax
jz short @f
  ret
@@:
push ebp
mov ebp,esp
push DotNetHelper.ICLRRuntimeHost
push IID_ICLRRuntimeHost4
call GetCLRRuntimeHost
mov esp,ebp
pop ebp
test eax,eax
jnz short @f
  mov eax,[DotNetHelper.ICLRRuntimeHost]
  ret
@@:
xor eax,eax
ret
[/32-bit]
]==]

    local DotNetFrameworkHelperStub = [==[
label(RuntimeEnumLoop)

label(IID_ICLRMetaHost)
IID_ICLRMetaHost:
db 9E DB 32 D3 B3 B9 25 41 82 07 A1 48 84 F5 32 16

label(CLSID_CLRMetaHost)
CLSID_CLRMetaHost:
db 8D 18 80 92 8E 0E 67 48 B3 0C 7F A8 38 84 E8 DE

label(IID_ICLRRuntimeHost)
IID_ICLRRuntimeHost:
db 22 67 2F CB 3A AB D2 11 9C 40 00 C0 4F A3 0A 3E

label(CLSID_CLRRuntimeHost)
CLSID_CLRRuntimeHost:
db 23 67 2F CB 3A AB D2 11 9C 40 00 C0 4F A3 0A 3E

[64-bit]
DotNetHelper.IGetRuntimeHost:
mov rax,[DotNetHelper.ICLRRuntimeHost]
test rax,rax
jz short @f
  ret
@@:
sub rsp,68
lea rcx,[CLSID_CLRMetaHost]
lea rdx,[IID_ICLRMetaHost]
lea r8,[rsp+30] // metahost
call MSCOREE.CLRCreateInstance
test eax,eax
jz short @f
  xor eax,eax
  add rsp,68
  ret
@@:
mov rcx,[rsp+30] // metahost
mov rax,[rcx]
mov rdx,-1
lea r8,[rsp+38] // RuntimeEnum
call [rax+6*8] // EnumerateLoadedRuntimes
test eax,eax
jz short @f
  xor eax,eax
  add rsp,68
  ret
RuntimeEnumLoop:
mov rcx,[rsp+38] // RuntimeEnum
mov rax,[rcx]
mov edx,1
lea r8,[rsp+40] // RuntimeInfo
lea r9,[rsp+48] // Count
call [rax+3*8] // RuntimeEnum->Next
test eax,eax
jz short @f
  xor eax,eax
  add rsp,68
  ret
@@:
mov rcx,[rsp+40] // RuntimeInfo
mov rax,[rcx]
lea rdx,[rsp+50] // rti_started
lea r8,[rsp+58] // rti_flags
call [rax+e*8] // RuntimeInfo->isStarted(started,flags)
test eax,eax
jnz RuntimeEnumLoop
cmp dword ptr [rsp+58],0
je RuntimeEnumLoop
// started
mov rcx,[rsp+40] // RuntimeInfo
mov rax,[rcx]
lea rdx,[CLSID_CLRRuntimeHost]
lea r8,[IID_ICLRRuntimeHost]
lea r9,[DotNetHelper.ICLRRuntimeHost]
call [rax+9*8] // GetInterface
test eax,eax
jnz RuntimeEnumLoop
mov rax,[DotNetHelper.ICLRRuntimeHost]
ret

[/64-bit]
[32-bit]
DotNetHelper.IGetRuntimeHost:
mov eax,[DotNetHelper.ICLRRuntimeHost]
test eax,eax
jz short @f
  ret
@@:
push ebp
mov ebp,esp
sub esp,18
lea eax,[ebp-4] // metahost
push eax
push IID_ICLRMetaHost
push CLSID_CLRMetaHost
call MSCOREE.CLRCreateInstance
test eax,eax
jz short @f
  xor eax,eax
  mov esp,ebp
  pop ebp
  ret
@@:
mov ecx,[ebp-4] // metahost
mov eax,[ecx]
lea edx,[ebp-8] // RuntimeEnum
push edx
push -1
push ecx
call [eax+6*4] // EnumerateLoadedRuntimes
test eax,eax
jz short @f
  xor eax,eax
  mov esp,ebp
  pop ebp
  ret
RuntimeEnumLoop:
mov ecx,[ebp-8] // RuntimeEnum
mov eax,[ecx]
lea edx,[ebp-C] // Count
push edx
lea edx,[ebp-10] // RuntimeInfo
push edx
push 1
push ecx
call [eax+3*4] // RuntimeEnum->Next
test eax,eax
jz short @f
  xor eax,eax
  mov esp,ebp
  pop ebp
  ret
@@:
mov ecx,[ebp-10] // RuntimeInfo
mov eax,[ecx]
lea edx,[ebp-14] // rti_flags
push edx
lea edx,[ebp-18] // rti_started
push edx
push ecx
call [eax+e*4] // RuntimeInfo->isStarted(started,flags)
test eax,eax
jne RuntimeEnumLoop
cmp dword ptr [ebp-14],0 // rti_flags
je RuntimeEnumLoop
// started
mov ecx,[ebp-10] // RuntimeInfo
mov eax,[ecx]
push DotNetHelper.ICLRRuntimeHost
push IID_ICLRRuntimeHost
push CLSID_CLRRuntimeHost
push ecx
call [eax+9*4] // GetInterface
test eax,eax
jne RuntimeEnumLoop
mov eax,[DotNetHelper.ICLRRuntimeHost]
mov esp,ebp
pop ebp
ret
[/32-bit]
]==]

    local DotNetHelperScript

    local scriptStub

    if (getAddressSafe('CORECLR.GetCLRRuntimeHost')) then
        scriptStub = DotNetCoreHelperStub
    elseif (getAddressSafe('MSCOREE.CLRCreateInstance')) then
        scriptStub = DotNetFrameworkHelperStub
    else
        return false,'Invalid Dotnet Architecture'
    end

    local baseModule = DotNetDataCollectorEx.GetBaseClassModule()
    if (baseModule) then baseModule = baseModule.hModule end
    
    local m2 = DotNetDataCollectorEx.FindMethodByDescAndCompile(baseModule, 'System.String.CreateStringForSByteConstructor(Byte*, Int32)') or 0
    local m1 = DotNetDataCollectorEx.FindMethodByDescAndCompile(baseModule, 'System.String.FastAllocateString(Int32)') or 0

    DotNetHelperScript = DotNetHelperScriptTemp:format(m1, m2, scriptStub)

    local status, disableInfo = autoAssemble(DotNetHelperScript)

    if (not status) then return false,'Failed to assemble DotNetHelper Script!' end
    dotnetHelperScriptProcId = getOpenedProcessID() -- Set Process ID
    return true
end

-- End of Extensions

local function LaunchDotNetDataCollectorEx()
    local pipeInfo = dotnetex_I_getRunningDotNetInfo()
    if (not pipeInfo) then
        print("No DotNetDataCollector")
        pipeInfo = {RunningState = PipeServerState.NotLoaded} -- legacy and new versions are not running
    end
    --if (pipeInfo.RunningState == PipeServerRunningState_Running) then
        -- print(DotNetDataCollectorEx running)
    --    return true
    --end
    if (dotnetex_initPipe(pipeConnectionTimeOut, pipeInfo)) then
        DotNetDataCollectorEx.pipe = dotnetpipeex
        symbolCache = {} -- Clear and create new symbol cache
        symbolCacheNames = {}
        -- Register Symbol Lookup here and not in RegisterCallbacks because some symbols are created by other exported lua functions
        if (dotnetpipeex.SymbolLookupID == nil) then
            dotnetpipeex.SymbolLookupID = registerSymbolLookupCallback(dotnetex_SymbolLookupCallback, slNotSymbol)
        end
        return true
    end
    print("Failed to Launch DotNetDataCollectorEx")
    return false
end

function getDotNetDataCollectorEx()
    if (dotnetpipeex == nil or tonumber(dotnetpipeex.processid) ~= getOpenedProcessID()) then
        --print("Launching DotNetDataCollectorEx")
        if (not LaunchDotNetDataCollectorEx()) then
            print("Failed to launch DotNetDataCollectorEx")
            return nil
        end
    end
    return DotNetDataCollectorEx
end