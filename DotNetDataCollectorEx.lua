local DotNetDataCollectorEx = {}
DotNetDataCollectorEx.__index = DotNetDataCollectorEx

dotnetpipeex = nil

local pipeConnectionTimeOut = 3000

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


PipeServerState = {
    Loaded = 1 << 0,
    Attached = 1 << 1,
    AttachedEx = 1 << 2,
    PipeExCreated = 1 << 3,
    LegacyDCForced = 1 << 4,
    RunningAsExtension = 1 << 5,
    NotLoaded = 1 << 6,
    TriedAttach = 1 << 7
}

local commands = DotNetDataCollectorExCommands

local function dotnetex_readString()
    local stringsize = dotnetpipeex.readDword()
    local strbt = dotnetpipeex.readBytes(stringsize)
    return byteTableToWideString(strbt)
end

local function dotnetex_I_getRunningDotNetInfoEx()
    local r = {}
    local od = DotNetDataCollectorEx.GetAddressData(0xBDBDBDBDBDBDBD01)
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
    r.ElementType = dotnetpipeex.readDword() -- This is the types element type -> See ClrElementType
    r.TypeAttributes = dotnetpipeex.readDword() -- These are the types attributes -> See <System.Reflection.TypeAttributes>
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

local function dotnetex_closePipe()
    if (dotnetpipeex) then
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
        dotnetpipeex = connectToPipe(pipename, timeout)
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
    dotnetpipeex.isLegacy = (pipeInfo.RunningState & (PipeServerState.Attached) ~= 0 and (pipeInfo.RunningState & PipeServerState.LegacyDCForced ~= 0 or pipeInfo.RunningState & (PipeServerState.AttachedEx | PipeServerState.RunningAsExtension) == 0))
    dotnetpipeex.Attached = pipeInfo.RunningState & PipeServerState.Attached ~= 0
    dotnetpipeex.AttachedEx = pipeInfo.RunningState & PipeServerState.AttachedEx ~= 0

    return true
end

-- Legacy Methods:

function DotNetDataCollectorEx.legacy_enumDomains()
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().enumDomains()
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().enumModuleList(domainHandle)
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().EnumTypeDefs(ModuleHandle)
    end
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

function DotNetDataCollectorEx.legacy_getTypeDefmethods(ModuleHandle, TypeDefToken)
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().getTypeDefMethods(ModuleHandle, TypeDefToken)
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().legacy_getAddressData(address)
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().enumAllObjects()
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().getTypeDefData()
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().getMethodParameters(ModuleHandle, MethodDefToken)
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().getTypeDefParent(ModuleHandle, TypeDefToken)
    end
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
    if (dotnetpipeex.isLegacy) then
        return getDotNetDataCollector().enumAllObjectsOfType(ModuleHandle, TypeDefToken)
    end
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
    -- More or less useless
    if (not dotnetpipeex.AttachedEx) then return nil end
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

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEDEFFIELDS)
    dotnetpipeex.writeQword(hType)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetMethodParameters(hMethod)
    if (not dotnetpipeex.AttachedEx) then return nil end
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

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETTYPEINFO)
    dotnetpipeex.writeQword(hType)

    local r = dotnetex_I_readType()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetBaseClassModule() -- Returns the Module of the BaseClassLibrary
    if (not dotnetpipeex.AttachedEx) then return nil end

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETBASECLASSMODULE)

    local r = dotnetex_I_readModule()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetAppDomainInfo(hDomain)
    if (not dotnetpipeex.AttachedEx) then return nil end
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

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_GETMETHODINFO)
    dotnetpipeex.writeQword(hMethod)

    local r = dotnetex_I_readMethod()

    dotnetpipeex.unlock()
    return r
end

function DotNetDataCollectorEx.GetMethodFromIP(ip)
    if (not dotnetpipeex.AttachedEx) then return nil end

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

    dotnetpipeex.lock()
    dotnetpipeex.writeByte(commands.CMD_FLUSHDACCACHE)
    dotnetpipeex.unlock()
end

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
        return true
    end
    print("Failed to Launch DotNetDataCollectorEx")
    return false
end

function getDotNetDataCollectorEx()
    if (dotnetpipeex == nil or tonumber(dotnetpipeex.processid) ~= getOpenedProcessID()) then
        print("Launching DotNetDataCollectorEx")

        if (not LaunchDotNetDataCollectorEx()) then
            print("Failed to launch DotNetDataCollectorEx")
            return nil
        end
    end
    return DotNetDataCollectorEx
end