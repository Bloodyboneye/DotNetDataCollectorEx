using Microsoft.Diagnostics.Runtime;
using System.Diagnostics;
using System.IO.Pipes;
using System.Reflection;
using System.Reflection.Metadata;
using System.Runtime.InteropServices;
using System.Text;

namespace DotNetDataCollectorEx
{
    public class PipeServer(string pipeName, bool noLegacyDataCollector = false, bool isExPipe = false)
    {
        private const ushort PipeMajorVersion = 3; // Newer versions mean possibly breaking changes.

        private const ushort PipeMinorVersion = 2; // Newer versions might be new functions for example, but no breaking changes to older Versions.

        private const uint PipeVersion = (uint)PipeMajorVersion << 16 | PipeMinorVersion;

        private const int LegacyPipeConnectionTimeout = 5000;

        internal static readonly ClrMDInspector inspector = new();

        private PipeServer? _pipeServerEx; // Reference to the PipeServer used for extended Commands. See LegacyGetAddressData() or InternalCreateNewPipeServer() for more info

        private string? _pipeNameEx; // Same as _pipeServerEx;

        public readonly NamedPipeServerStream pipe = new(pipeName, PipeDirection.InOut, NamedPipeServerStream.MaxAllowedServerInstances, PipeTransmissionMode.Byte);

        private readonly string pipeName = pipeName;

        private string? legacyDotNetDataCollectorPipeName;

        private const string legacyDotNetDataCollectorFileName = "LegacyDotNetDataCollector";

        internal Process? legacyDotNetDataCollectorProcess;

        private NamedPipeClientStream? forwarderPipe;

        private readonly bool _noLegacyDataCollector = noLegacyDataCollector;

        private PipeServerState state = PipeServerState.Loaded;

        private uint _processID;

        private readonly bool _isExPipe = isExPipe;

        private readonly Dictionary<ulong, ModuleMetadataReader> moduleMetadataReaders = [];

        private readonly HashSet<ulong> moduleMetaDataReadersCreationFailed = [];

        private enum Commands : byte
        {
            // L_ Legacy Commands
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
            // Commands 13-20 Reserved
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
            CMD_GETMODULEBYHANDLE = 53,
        }

        [Flags]
        public enum PipeServerState : uint
        {
            Loaded = 1 << 0, // Pipe Server Process has been loaded but isn't attached/running/...
            Attached = 1 << 1, // Is attached to the process -> If AttachedEx is not set then it is only forwading to the legacy DC. -> Maybe failed to attach / Legacy DC is forced
            AttachedEx = 1 << 2, // Is attached and running the DataCollectorEx Pipe -> Not just forwarding to the legacy DataCollector
            PipeExCreated = 1 << 3, // The Ex Pipe has been created
            LegacyDataCollectorRunning = 1 << 4, // Legacy DC is running
            RunningAsExtension = 1 << 5, // Is running as an extension to the legacy DC. Meaning Cheat Engine started the legacy DC and we created the new process
            NotLoaded = 1 << 6, // DCEx has not been loaded (this process not running) only checked by the Lua Script internally as when this process is running it is already loaded
            TriedAttach = 1 << 7, // Has tried to attach to the process, this can be used to check if it has already tried and maybe failed to actually attach
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct CodeChunkInfo
        {
            public ulong startAddr;
            public uint length;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct COR_TYPEID
        {
            public ulong token1;
            public ulong token2;
        }

        #region PipeReadWrite
        public void WriteByte(byte v)
        {
            pipe.WriteByte(v);
        }

        public byte ReadByte()
        {
            byte[] array = new byte[1];
            if (pipe.Read(array, 0, 1) == -1)
                throw new Exception("Error while reading from Pipe");
            return array[0];
        }

        public void WriteWord(ushort v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 2);
        }

        public ushort ReadWord()
        {
            byte[] array = new byte[2];
            _ = pipe.Read(array, 0, 2);
            return BitConverter.ToUInt16(array, 0);
        }

        public void WriteDword(uint v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 4);
        }

        public uint ReadDword()
        {
            byte[] array = new byte[4];
            _= pipe.Read(array, 0, 4);
            return BitConverter.ToUInt32(array, 0);
        }

        public void WriteQword(ulong v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 8);
        }

        public ulong ReadQword()
        {
            byte[] array = new byte[8];
            _= pipe.Read(array, 0, 8);
            return BitConverter.ToUInt64(array, 0);
        }

        public void WriteUTF8String(string str)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(str);
            WriteDword((uint)bytes.Length);
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
        }

        public string ReadUTF8String()
        {
            int length = (int)ReadDword();
            if (length == 0) 
                return string.Empty;
            byte[] bytes = new byte[length];
            _= pipe.Read(bytes, 0, length);
            return Encoding.UTF8.GetString(bytes);
        }

        public void WriteUTF16String(string str)
        {
            byte[] bytes = Encoding.Unicode.GetBytes(str);
            //Logger.LogInfo($"Bytes in SendString: {BitConverter.ToString(bytes)}:{bytes.Length}");
            WriteDword((uint)bytes.Length);
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
        }

        public string ReadUTF16String()
        {
            int length = (int)ReadDword();
            if (length == 0)
                return string.Empty;
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.Unicode.GetString(bytes);
        }

        public void WriteASCIIString(string str)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(str);
            WriteDword((uint)bytes.Length);
            //Logger.LogInfo($"Length: {bytes.Length} | Bytes: {BitConverter.ToString(bytes)}");
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
        }

        public string ReadASCIIString()
        {
            int length = (int)ReadDword();
            if (length == 0)
                return string.Empty;
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.ASCII.GetString(bytes);
        }

        public void WriteByteArray(byte[] v)
        {
            WriteDword((uint)v.Length);
            pipe.Write(v, 0, v.Length);
        }

        public byte[] ReadByteArray()
        {
            int length = (int)ReadDword();
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return bytes;
        }

        public void WriteBool(bool v)
        {
            pipe.WriteByte((byte)(v ? 1 : 0));
        }

        public bool ReadBool()
        {
            return pipe.ReadByte() != 0;
        }

        #endregion

        #region Helpers

        public static bool OpenOrAttachToProcess(int processId)
        {
            return inspector.AttachToProcess(processId);
        }

        private void InternalCreateNewPipeServer(byte flags)
        {
#if DEBUG
            Logger.LogInfo($"InternalCreateNewPipeServer called with flags {flags}");
#endif
            // Create new PipeServer and send info over dotnetpipe.
            // This is because TDotNetPipe doesn't expose its pipe and attaching to the exisiting one is problematic because we can't synchronize with it!
            if ((flags & 0x1) != 0)
            {
                // Only get Info without creating Pipe
                Logger.LogInfo($"InternalCreateNewPipeServer: state: {state}|{(uint)state} | PipeVersion: {PipeVersion}");
                WriteQword(((ulong)state << 32) | PipeVersion); // "StartAddress" // Send over State and send over PipeVersion -> See PipeServerState and PipeMajorVersion and PipeMinorVersion for more Info
                WriteDword((uint)ClrElementType.Class); // "ElementType" -> Should just need to make sure it is not "ELEMENT_TYPE_ARRAY"(0x14) or "ELEMENT_TYPE_SZARRAY"(0x1D) but to be safe say it's a Class
                WriteUTF16String((state & PipeServerState.PipeExCreated) == 0 || (flags & 2) != 0 ? this.pipeName : _pipeNameEx ?? string.Empty); // "className" -> If the ex pipe was created or bit 2 in flags was set send the original pipename else send the ex pipe name
                WriteDword(0); // "fieldcount" -> Say we don't have any fields
                return;
            }
            if ((state & (PipeServerState.PipeExCreated | PipeServerState.RunningAsExtension)) != 0)
            {
                Logger.LogInfo($"PipeServer already running state: {state}");
                // Pipe Server is already running
                WriteQword(((ulong)state << 32) | PipeVersion); // "StartAddress" // Send over State and send over PipeVersion -> See PipeServerState and PipeMajorVersion and PipeMinorVersion for more Info
                WriteDword((uint)ClrElementType.Class); // "ElementType" -> Should just need to make sure it is not "ELEMENT_TYPE_ARRAY"(0x14) or "ELEMENT_TYPE_SZARRAY"(0x1D) but to be safe say it's a Class
                WriteUTF16String((state & PipeServerState.RunningAsExtension) != 0 ? this.pipeName : _pipeNameEx ?? string.Empty); // "className" -> Send original pipename if is running as extension else send the ex pipename
                WriteDword(0); // "fieldcount" -> Say we don't have any fields
                return;

            }
            Logger.LogInfo("Creating new PipeServer!");
            // Create new Pipename
            string pipeName = $"exdotnetpipe_{_processID}_{Environment.TickCount}";
            state |= PipeServerState.PipeExCreated;
            _pipeNameEx = pipeName;
            _pipeServerEx = new(pipeName, true, true)
            {
                state = state,
                _pipeServerEx = this,
                _pipeNameEx = this.pipeName
            };

            Logger.LogInfo($"New Pipe Server Name: '{pipeName}'");

            WriteQword(((ulong)state << 32) | PipeVersion); // "StartAddress" // Send over State and send over PipeVersion -> See PipeServerState and PipeMajorVersion and PipeMinorVersion for more Info
            WriteDword((uint)ClrElementType.Class); // "ElementType" -> Should just need to make sure it is not "ELEMENT_TYPE_ARRAY"(0x14) or "ELEMENT_TYPE_SZARRAY"(0x1D) but to be safe tell say it's a Class
            WriteUTF16String(_pipeNameEx ?? string.Empty); // "className" -> Send pipename instead
            WriteDword(0); // "fieldcount" -> Say we don't have any fields

            new Thread(_pipeServerEx.RunExLoopStub) { IsBackground = true }.Start();
        }

        private void SendType(ClrType type, ClrObject? obj)
        {
            WriteDword((uint)type.MetadataToken);
            WriteQword(type.MethodTable);
            WriteQword(type.Module.Address);
            WriteDword((uint)type.ElementType);
            WriteDword((uint)type.TypeAttributes);
            WriteBool(type.IsEnum);
            WriteUTF16String(type.Name ?? string.Empty);
            if (type.IsArray)
            {
                // Handle Array Types
                ClrType? componentType = type.ComponentType;
                if (componentType == null)
                {
                    WriteDword(uint.MaxValue);
                    WriteDword(uint.MaxValue);
                    WriteQword(ulong.MaxValue);
                    WriteUTF16String(string.Empty);
                }
                else
                {
                    WriteDword((uint)componentType.ElementType);
                    WriteDword((uint)componentType.MetadataToken);
                    WriteQword(componentType.MethodTable);
                    WriteUTF16String(componentType.Name ?? string.Empty);
                }
                ulong firstElementOffset = obj.HasValue ? type.GetArrayElementAddress(obj.Value.Address, 0) - obj.Value.Address : (uint)(nint.Size * 2); // Calculate offset to first element
                uint countOffset = (uint)(nint.Size);
                WriteDword(countOffset);
                WriteDword((uint)type.ComponentSize); // element Size
                WriteDword((uint)firstElementOffset);
                return;
            }
            // Handle non Array Types
            ClrInstanceField[] instanceFields = [.. ClrExtensions.EnumerateInstanceFields(type)];
            ClrStaticField[] staticFields = [.. ClrExtensions.EnumerateStaticFields(type)];

            WriteDword((uint)instanceFields.Length);

            foreach (ClrInstanceField iField in instanceFields)
            {
                WriteDword((uint)iField.Token); // fieldToken
                try
                {
                    WriteDword((uint)iField.Size);
                } catch (Exception ex)
                {
#if DEBUG
                    Logger.LogException(ex);
#endif
                    WriteDword(0); // Seems to fail for nullable types...
                }

                WriteDword((uint)iField.Offset + (uint)nint.Size); // fieldOffset / Add Pointer Size because of Method Table Pointer
                WriteDword((uint)iField.ElementType); // fieldType
                WriteDword((uint)iField.Attributes); // fieldAttributes
                WriteUTF16String(iField.Name ?? string.Empty); // fieldName
                WriteUTF16String(iField.Type?.Name ?? string.Empty); // className
                WriteQword(iField.Type?.MethodTable ?? 0);
                WriteBool(iField.Type?.IsEnum ?? false); // Is enum
                WriteQword(obj.HasValue ? iField.GetAddress(obj.Value) : 0);
            }

            WriteDword((uint)staticFields.Length);

            foreach (ClrStaticField sField in staticFields)
            {
                WriteDword((uint)sField.Token); // fieldToken
                try
                {
                    WriteDword((uint)sField.Size);
                }
                catch (Exception ex)
                {
#if DEBUG
                    Logger.LogException(ex);
#endif
                    WriteDword(0); // Seems to fail for nullable types...
                }
                WriteDword((uint)sField.Offset); // fieldOffset
                WriteDword((uint)sField.ElementType); // fieldType
                WriteDword((uint)sField.Attributes); // fieldAttributes
                WriteUTF16String(sField.Name ?? string.Empty); // fieldName
                WriteUTF16String(sField.Type?.Name ?? string.Empty); // className
                WriteQword(sField.Type?.MethodTable ?? 0);
                WriteBool(sField.Type?.IsEnum ?? false); // Is enum
                ClrAppDomain domain = sField.Type != null ? sField.Type.Module.AppDomain : type.Module.AppDomain;
                WriteQword(sField.GetAddress(domain));
            }
        }

        private void SendType(ClrObject obj)
        {
            ClrType? objType = obj.Type;
            if (objType == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendType(objType, obj);
        }

        private void SendType(ClrType type)
        {
            SendType(type, null);
        }

        private void SendMethod(ClrMethod method)
        {
            ILInfo? ilInfo = method.GetILInfo();
            WriteDword((uint)method.MetadataToken);
            WriteQword(method.MethodDesc); // MethodDesc/MethodHandle
            WriteQword(method.Type.MethodTable);
            WriteQword(method.Type.Module.Address);
            WriteUTF16String(method.Name ?? string.Empty);
            WriteDword((uint)method.Attributes);
            WriteQword(method.NativeCode != ulong.MaxValue ? method.NativeCode : 0);
            WriteUTF16String(method.Signature ?? string.Empty);
            WriteQword(ilInfo?.Address ?? 0);
            WriteDword((uint)(ilInfo?.Length ?? 0));
            WriteDword(ilInfo?.Flags ?? 0);

            HotColdRegions methodRegions = method.HotColdInfo;
            List<CodeChunkInfo> codeChunks = [];
            if (methodRegions.HotSize > 0)
            {
                codeChunks.Add(new CodeChunkInfo()
                {
                    startAddr = methodRegions.HotStart,
                    length = methodRegions.HotSize
                });
            }
            if (methodRegions.ColdSize > 0)
            {
                codeChunks.Add(new CodeChunkInfo()
                {
                    startAddr = methodRegions.ColdStart,
                    length = methodRegions.ColdSize
                });
            }

            WriteDword((uint)codeChunks.Count);
            foreach (CodeChunkInfo cki in codeChunks)
            {
                WriteQword(cki.startAddr);
                WriteDword(cki.length);
            }
        }

        private void SendModule(ClrModule module)
        {
            WriteQword(module.Address);
            WriteQword(module.AppDomain.Address);
            WriteQword(module.ImageBase);
            WriteQword(module.Size);
            WriteQword(module.MetadataAddress);
            WriteQword(module.MetadataLength);
            string modulename = Path.GetFileName(module.Name?.Split(',')[0]) ?? string.Empty;
            WriteUTF16String(module.IsDynamic ? string.IsNullOrEmpty(modulename) ? "<Dynamic>" : modulename : modulename); // Only send the name and not the fully qualified name / file path
            WriteQword(module.AssemblyAddress);
            WriteUTF16String(module.AssemblyName ?? string.Empty);
            WriteDword((uint)module.Layout);
            WriteBool(module.IsDynamic);
        }

        private void CloseForwarderPipe()
        {
            Logger.LogWarning("Legacy DotNetDataCollector Pipe closed!");
            forwarderPipe?.Close();
            forwarderPipe = null;
            state &= ~PipeServerState.LegacyDataCollectorRunning; // Tell state that Legacy DataCollector is not running anymore
            if (_pipeServerEx != null)
                _pipeServerEx.state &= ~PipeServerState.LegacyDataCollectorRunning; // Also tell the other pipe if it is running
            legacyDotNetDataCollectorProcess?.Kill();
        }

        private ModuleMetadataReader? TryGetOrCreateModuleMetaDataReader(ClrModule module)
        {
            if (moduleMetadataReaders.TryGetValue(module.Address, out ModuleMetadataReader? value))
                return value;
            if (moduleMetaDataReadersCreationFailed.Contains(module.Address))
                return null; // Failed to create in the beginning, don't try again!
            if (module.IsDynamic || module.ImageBase == 0 || module.Size == 0)
                return null;
            try
            {
                value = new(module);
                moduleMetadataReaders.Add(module.Address, value);
                Logger.LogInfo($"ModuleMetadataReader created for Module: {Path.GetFileName(module.Name)}");
            }
            catch (Exception ex)
            {
#if DEBUG
                Logger.LogException(ex);
#endif
            }
            return value;
        }

        #endregion

        #region LegacyCommands

        private void LegacyEnumDomains()
        {
            if (forwarderPipe != null)
            {            
                if (!PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_ENUMDOMAINS))
                    CloseForwarderPipe();
                else
                {
                    uint domainCount = PipeHelper.ReadDword(forwarderPipe);
                    WriteDword(domainCount);
                    for (uint i = 0; i < domainCount; i++)
                    {
                        ulong hDomain = PipeHelper.ReadQword(forwarderPipe);
                        WriteQword(hDomain);
                        string domainName = PipeHelper.ReadUTF16String(forwarderPipe);
                        WriteUTF16String(domainName);
                    }
                    return;
                } // Skip forwarder section if pipe has already been closed
            }
            ClrAppDomain[] appDomains = [.. inspector.EnumerateAppDomains()];
            WriteDword((uint)appDomains.Length);
            foreach (ClrAppDomain appDomain in appDomains)
            {
                WriteQword(appDomain.Address);
                //Logger.LogInfo($"Domain Name to send: {appDomain.Name}");
                WriteUTF16String(appDomain.Name ?? string.Empty);
            }
        }

        private void LegacyEnumModules()
        {
            ulong hDomain = ReadQword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_ENUMMODULELIST);
                if (!PipeHelper.WriteQword(forwarderPipe, hDomain))
                    CloseForwarderPipe();
                else
                {
                    uint moduleCount = PipeHelper.ReadDword(forwarderPipe);
                    WriteDword(moduleCount);

                    for (uint i = 0; i < moduleCount; i++)
                    {
                        ulong hModule = PipeHelper.ReadQword(forwarderPipe);
                        ulong baseAddress = PipeHelper.ReadQword(forwarderPipe);
                        string moduleName = PipeHelper.ReadUTF16String(forwarderPipe);
                        WriteQword(hModule);
                        WriteQword(baseAddress);
                        WriteUTF16String(moduleName);
                    }
                    return;
                } // Skip forwarder section if pipe has already been closed
            }

            ClrModule[] modules;
            if (hDomain != 0)
                modules = [.. inspector.EnumerateModules(hDomain)];
            else
                modules = [.. inspector.EnumerateModules()];

            WriteDword((uint)modules.Length);
            foreach (ClrModule module in modules)
            {
                WriteQword(module.Address);
                WriteQword(module.ImageBase);
                string modulename = module.Name?.Split(',')[0] ?? string.Empty; // Only send the name and not the fully qualified name
                WriteUTF16String(module.IsDynamic ? string.IsNullOrEmpty(modulename) ? "<Dynamic>" : modulename : modulename);
            }
        }

        private void LegacyEnumTypeDefs()
        {
            ulong hModule = ReadQword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_ENUMTYPEDEFS);
                if (!PipeHelper.WriteQword(forwarderPipe, hModule))
                    CloseForwarderPipe();
                else
                {
                    uint typeCount = PipeHelper.ReadDword(forwarderPipe);
                    WriteDword(typeCount);

                    for (uint i = 0; i < typeCount; i++)
                    {
                        uint typeToken = PipeHelper.ReadDword(forwarderPipe);
                        string typeName = PipeHelper.ReadUTF16String(forwarderPipe);
                        uint flags = PipeHelper.ReadDword(forwarderPipe);
                        uint extends = PipeHelper.ReadDword(forwarderPipe);

                        WriteDword(typeToken);
                        WriteUTF16String(typeName);
                        WriteDword(flags);
                        WriteDword(extends);
                    }
                    return;
                }
            }
            ClrType[] types = [.. inspector.EnumerateTypes(hModule)];
            WriteDword((uint)types.Length);

            foreach (ClrType type in types)
            {
                WriteDword((uint)type.MetadataToken);
                WriteUTF16String(type.Name ?? string.Empty);
                WriteDword((uint)type.TypeAttributes);
                int extendsToken = type.BaseType?.MetadataToken ?? 0;
                WriteDword((uint)extendsToken);
            }
        }

        private void LegacyEnumTypeDefMethods()
        {
            ulong hModule = ReadQword();
            uint typeDefToken = ReadDword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETTYPEDEFMETHODS);
                _ = PipeHelper.WriteQword(forwarderPipe, hModule);
                if (!PipeHelper.WriteDword(forwarderPipe, typeDefToken))
                    CloseForwarderPipe();
                else
                {
                    uint methodCount = PipeHelper.ReadDword(forwarderPipe);
                    WriteDword(methodCount);

                    for (uint i = 0; i < methodCount; i++)
                    {
                        uint methodToken = PipeHelper.ReadDword(forwarderPipe);
                        string methodName = PipeHelper.ReadUTF16String(forwarderPipe);
                        uint attributes = PipeHelper.ReadDword(forwarderPipe);
                        uint implFlags = PipeHelper.ReadDword(forwarderPipe);
                        ulong ILCode = PipeHelper.ReadQword(forwarderPipe);
                        ulong nativeCode = PipeHelper.ReadQword(forwarderPipe);
                        uint secondaryCodeBlocks = PipeHelper.ReadDword(forwarderPipe);

                        WriteDword(methodToken);
                        WriteUTF16String(methodName);
                        WriteDword(attributes);
                        WriteDword(implFlags);
                        WriteQword(ILCode);
                        WriteQword(nativeCode);

                        WriteDword(secondaryCodeBlocks);

                        for (uint j = 0; j < secondaryCodeBlocks; j++)
                        {
                            byte[] codeChunkInfo = new byte[0x10];
                            //byte[] codeChunkInfo = new byte[Marshal.SizeOf<CodeChunkInfo>()];
                            //_ = forwarderPipe.Read(codeChunkInfo); // Should read 0x10!!!
                            _ = forwarderPipe.Read(codeChunkInfo);
                            pipe.Write(codeChunkInfo);
                        }
                    }
                    return;
                }
            }

            ClrMethod[] methods = [.. inspector.EnumerateMethods(hModule, (int)typeDefToken)];
            WriteDword((uint)methods.Length);

            if (methods.Length == 0)
                return;

            foreach (ClrMethod method in methods)
            {
                ILInfo? ilInfo = method.GetILInfo();
                uint implAttribs = ilInfo?.Flags ?? 0;
                ClrType? methodType = ClrExtensions.GetRealClrTypeFromMethod(method);
                if (methodType != null)
                {
                    try
                    {
                        ModuleMetadataReader? metadataReader = TryGetOrCreateModuleMetaDataReader(methodType.Module);

                        MethodDefinition? methoddef = null;
                        _ = metadataReader?.TryGetMetaData(method.MetadataToken, out methoddef);

                        if (methoddef.HasValue)
                        {
                            implAttribs = (uint)methoddef.Value.ImplAttributes;
                        }
                    }
                    catch (Exception ex)
                    {
#if DEBUG
                        Logger.LogException(ex);
#endif
                    }
                }

                WriteDword((uint)method.MetadataToken);
                WriteUTF16String(method.Name ?? string.Empty);
                WriteDword((uint)method.Attributes);
                WriteDword(implAttribs);
                WriteQword(ilInfo?.Address ?? 0);
                WriteQword(method.NativeCode != ulong.MaxValue ? method.NativeCode : 0);

                // Create code chunk/s
                HotColdRegions methodRegions = method.HotColdInfo;
                List<CodeChunkInfo> codeChunks = [];
                if (methodRegions.HotSize > 0)
                {
                    codeChunks.Add(new CodeChunkInfo()
                    {
                        startAddr = methodRegions.HotStart,
                        length = methodRegions.HotSize
                    });

                }
                if (methodRegions.ColdSize > 0)
                {
                    codeChunks.Add(new CodeChunkInfo()
                    {
                        startAddr = methodRegions.ColdStart,
                        length = methodRegions.ColdSize
                    });
                }

                WriteDword((uint)codeChunks.Count);
                foreach (CodeChunkInfo cki in codeChunks)
                {
                    //Logger.LogInfo($"Code Chucks Count: {codeChunks.Count} | SR: {cki.startAddr:X} | Length: {cki.length} | Size of Struct: {Marshal.SizeOf<CodeChunkInfo>()}");
                    byte[] structBytes = PipeHelper.StructToBytes(cki);
                    pipe.Write(structBytes, 0, structBytes.Length); // TODO: CE Seems to excpect 16 bytes and not 12 but this seems to still work... weird
                    //WriteQword(cki.startAddr);
                    //WriteDword(cki.length);
                }

                //WriteDword(0); // Ignore Code Chunks
            }
        }

        private void LegacyPipeForwardType()
        {
            if (forwarderPipe == null)
                throw new InvalidOperationException("forwarderPipe is null inside LegacyPipeForwardType?");
            uint objectType = PipeHelper.ReadDword(forwarderPipe);
            WriteDword(objectType);

            if (objectType == uint.MaxValue)
                return;

            // Check if type is array
            if (objectType is ((uint)ClrElementType.Array) or ((uint)ClrElementType.SZArray))
            {
                uint componentType = PipeHelper.ReadDword(forwarderPipe);
                uint countOffset = PipeHelper.ReadDword(forwarderPipe);
                uint elementSize = PipeHelper.ReadDword(forwarderPipe);
                uint firstElementOffset = PipeHelper.ReadDword(forwarderPipe);

                WriteDword(componentType);
                WriteDword(countOffset);
                WriteDword(elementSize);
                WriteDword(firstElementOffset);
                return;
            }
            // Handle non Array types
            string typeName = PipeHelper.ReadUTF16String(forwarderPipe);
            WriteUTF16String(typeName);

            uint fieldCount = PipeHelper.ReadDword(forwarderPipe);
            WriteDword(fieldCount);

            for (uint i = 0; i < fieldCount; i++)
            {
                uint fieldToken = PipeHelper.ReadDword(forwarderPipe);
                uint fieldOffset = PipeHelper.ReadDword(forwarderPipe);
                uint fieldType = PipeHelper.ReadDword(forwarderPipe);
                uint fieldattributes = PipeHelper.ReadDword(forwarderPipe);
                string fieldName = PipeHelper.ReadUTF16String(forwarderPipe);
                string className = PipeHelper.ReadUTF16String(forwarderPipe);

                WriteDword(fieldToken);
                WriteDword(fieldOffset);
                WriteDword(fieldType);
                WriteDword(fieldattributes);
                WriteUTF16String(fieldName);
                WriteUTF16String(className);
            }
            return;
        }

        private void LegacySendType(ClrObject obj)
        {
            ClrType? objType = obj.Type;
            if (objType == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            WriteDword((uint)objType.ElementType);
            if (objType.IsArray)
            {
                // Handle Array Type
                ClrType? componentType = objType.ComponentType;
                if (componentType == null)
                    WriteDword(uint.MaxValue);
                else
                    WriteDword((uint)componentType.ElementType);
                ulong firstElementOffset = objType.GetArrayElementAddress(obj.Address, 0) - obj.Address; // Calculate offset to first element
                //ulong countOffset = firstElementOffset - 4; // Calculate Offset to count
                ulong countOffset = (ulong)(nint.Size);
                WriteDword((uint)countOffset);
                WriteDword((uint)objType.ComponentSize); // element Size
                WriteDword((uint)firstElementOffset);
                return;                
            }
            // Handle non Array types
            WriteUTF16String(objType.Name ?? string.Empty);

            ClrField[] fields = [.. ClrExtensions.EnumerateAllFields(objType)];

            WriteDword((uint)fields.Length); // field Count

            foreach (ClrField field in fields)
            {
                uint offset = (uint)((field.Attributes & FieldAttributes.Static) == 0 ? nint.Size : 0);
                WriteDword((uint)field.Token); // fieldToken
                WriteDword((uint)field.Offset + offset); // fieldOffset // Add offset to Instance Fields because of the Method Table Pointer
                WriteDword((uint)field.ElementType); // fieldType
                WriteDword((uint)field.Attributes); // fieldAttributes
                WriteUTF16String(field.Name ?? string.Empty); // fieldName
                WriteUTF16String(field.Type?.Name ?? string.Empty); // className
            }
        }

        private void LegacySendType(ClrType type)
        {
            WriteDword((uint)type.ElementType);
            if (type.IsArray)
            {
                // Handle Array Tyoe
                ClrType? componentType = type.ComponentType;
                if (componentType == null)
                    WriteDword(uint.MaxValue);
                else
                    WriteDword((uint)componentType.ElementType);
                WriteDword((uint)(nint.Size)); // countOffset
                WriteDword((uint)type.ComponentSize); // element Size
                WriteDword((uint)(nint.Size * 2)); // firstElementOffset
                return;
            }
            // Handle non Array Types
            WriteUTF16String(type.Name ?? string.Empty);

            ClrField[] fields = [.. ClrExtensions.EnumerateAllFields(type)];

            WriteDword((uint)fields.Length); // field Count

            foreach (ClrField field in fields)
            {
                uint offset = (uint)((field.Attributes & FieldAttributes.Static) == 0 ? nint.Size : 0);
                WriteDword((uint)field.Token); // fieldToken
                WriteDword((uint)field.Offset + offset); // fieldOffset // Add offset to Instance Fields because of the Method Table Pointer
                WriteDword((uint)field.ElementType); // fieldType
                WriteDword((uint)field.Attributes); // fieldAttributes
                WriteUTF16String(field.Name ?? string.Empty); // fieldName
                WriteUTF16String(field.Type?.Name ?? string.Empty); // className
            }
        }

        private void LegacyGetAddressData()
        {
            ulong address = ReadQword();

#if DEBUG
            Logger.LogInfo($"GetAddressData called on Address: {address:X}");
#endif

            if ((address & 0xFFFFFFFFFFFFFF00) == 0xBDBDBDBDBDBDBD00) // Check magic
            {
                // Create new PipeServer and send info over dotnetpipe.
                // This is because the TDotNetPipe doesn't expose its pipe and attaching to the exisiting one is problematic because we can't synchronize with it!
                InternalCreateNewPipeServer((byte)(address & 0xFF));
                return;
            }

            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETADDRESSDATA);
                if (!PipeHelper.WriteQword(forwarderPipe, address))
                    CloseForwarderPipe();
                else
                {
                    ulong startAddress = PipeHelper.ReadQword(forwarderPipe);


                    WriteQword(startAddress);

                    if (startAddress == 0)
                        return;

                    LegacyPipeForwardType();
                    return;
                }
            }
            // Handle new Version
            ClrObject? obj = inspector.GetObjectForAddress(address);

            if (obj == null)
            {
                WriteQword(0);
                return;
            }

            WriteQword(obj.Value.Address); // StartAddress
            // Send Type

            LegacySendType(obj.Value);
        }

        private void LegacyGetAllObjects()
        {
            if (forwarderPipe != null)
            {
                ulong objAddress;
                uint objSize;
                byte[] typeidBytes;
                string objName;
                COR_TYPEID typeid;
                if (!PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETALLOBJECTS))
                    CloseForwarderPipe();
                else
                {
                    do
                    {
                        objAddress = PipeHelper.ReadQword(forwarderPipe);
                        objSize = PipeHelper.ReadDword(forwarderPipe);
                        typeidBytes = new byte[Marshal.SizeOf<COR_TYPEID>()];
                        _ = forwarderPipe.Read(typeidBytes);
                        objName = PipeHelper.ReadUTF16String(forwarderPipe);
                        typeid = PipeHelper.ByteArrayToStructure<COR_TYPEID>(typeidBytes);

                        WriteQword(objAddress);
                        WriteDword(objSize);
                        pipe.Write(typeidBytes);
                        //forwarderPipe.Write(typeidBytes);
                        WriteUTF16String(objName);
                    } while (objAddress != 0 || objSize != 0 || typeid.token1 != 0 || typeid.token2 != 0); //  && !string.IsNullOrEmpty(objName)

                    return;
                }
            }
            foreach (ClrObject obj in inspector.EnumerateObjects())
            {
                if (!obj.IsValid || obj.IsFree)
                    continue; // Ignore Invalid and Free Objects
                WriteQword(obj.Address);
                WriteDword((uint)obj.Size);
                ClrType objType = obj.Type!; // Type will not be null because obj.IsValid checks for that
                byte[] typeidBytes = PipeHelper.StructToBytes(new COR_TYPEID()
                {
                    token1 = objType.MethodTable // don't know if this is correct but seems so
                    // token2 seems to always be 0...
                });
                pipe.Write(typeidBytes);
                WriteUTF16String(objType.Name ?? string.Empty);
            }
            // Send end of List
            WriteQword(0);
            WriteDword(0);
            pipe.Write(new byte[Marshal.SizeOf<COR_TYPEID>()]);
            WriteUTF16String(string.Empty);
        }

        private void LegacyGetTypeDefFields() // GetTypeDefData
        {
            ulong hModule = ReadQword();
            uint typeDef = ReadDword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETTYPEDEFFIELDS);
                _ = PipeHelper.WriteQword(forwarderPipe, hModule);
                if (!PipeHelper.WriteDword(forwarderPipe, typeDef))
                    CloseForwarderPipe();
                else
                {
                    LegacyPipeForwardType();
                    return;
                }
            }
            ClrType? type = inspector.GetType(hModule, (int)typeDef);
            if (type == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            LegacySendType(type);
        }

        private void LegacyGetMethodParameters()
        {
            ulong hModule = ReadQword();
            uint methodDef = ReadDword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETMETHODPARAMETERS);
                _ = PipeHelper.WriteQword(forwarderPipe, hModule);
                if (!PipeHelper.WriteDword(forwarderPipe, methodDef))
                    CloseForwarderPipe();
                else
                {
                    uint count = PipeHelper.ReadDword(forwarderPipe);
                    WriteDword(count);

                    for (uint i = 0; i < count; i++)
                    {
                        string name = PipeHelper.ReadUTF16String(forwarderPipe);
                        uint cplusTypeFlag = PipeHelper.ReadDword(forwarderPipe);
                        uint sequence = PipeHelper.ReadDword(forwarderPipe);

                        WriteUTF16String(name);
                        WriteDword(cplusTypeFlag);
                        WriteDword(sequence);
                    }
                    return;
                }
            }
            ClrMethod? method = inspector.GetMethod(hModule, (int)methodDef);
            if (method == null)
            {
                WriteDword(0);
                return;
            }

            ClrType? methodType = ClrExtensions.GetRealClrTypeFromMethod(method);

            ModuleMetadataReader? metadataReader = null;

            if (methodType != null)
            {
                metadataReader = TryGetOrCreateModuleMetaDataReader(methodType.Module);
            }
            MethodDefinition? methodDefinition = null;
            _ = metadataReader?.TryGetMetaData((int)methodDef, out methodDefinition);
            List<string> paramNames = [];

            try
            {
                if (methodDefinition.HasValue && metadataReader != null)
                {
                    // Handle method Parameters Correctly
                    foreach (ParameterHandle mparam in methodDefinition.Value.GetParameters())
                    {
                        Parameter? _param = metadataReader.GetDefinitionFromHandle<Parameter>(mparam);
                        if (_param.HasValue)
                        {
                            string paramName = metadataReader.GetStringFromHandle(_param.Value.Name);
                            int index = _param.Value.SequenceNumber - 1;
                            if (index < 0)
                                break; // Failed to get parameters

                            if (!string.IsNullOrEmpty(paramName))
                                paramNames.Insert(index, paramName);
                            else
                                paramNames.Insert(index, "<Unknown>");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
#if DEBUG
                Logger.LogException(ex);
#endif
            }

            
            var methodParams = MethodSignatureParser.ParseSignature(method.Signature ?? string.Empty);

            WriteDword((uint)methodParams.Count);

            for (int i = 0; i < methodParams.Count; i++)
            {
                WriteUTF16String(paramNames.ElementAtOrDefault(i) ?? methodParams[i].paramName); // Send type name instead of param name if the param name couldn't be gotten
                WriteDword((uint)methodParams[i].cPlusTypeFlag);
                WriteDword((uint)i + 1);
            }
        }

        private void LegacyGetTypeDefParent()
        {
            ulong hModule = ReadQword();
            uint typeDef = ReadDword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETTYPEDEFPARENT);
                _ = PipeHelper.WriteQword(forwarderPipe, hModule);
                if (!PipeHelper.WriteDword(forwarderPipe, typeDef))
                    CloseForwarderPipe();
                else
                {
                    ulong phModule = PipeHelper.ReadQword(forwarderPipe);
                    uint ptypeDef = PipeHelper.ReadDword(forwarderPipe);

                    WriteQword(phModule);
                    WriteDword(ptypeDef);
                    return;
                }
            }
            ClrType? type = inspector.GetType(hModule, (int)typeDef);
            if (type == null)
            {
                WriteQword(0);
                WriteDword(0);
                return;
            }
            ClrType? parentType = type.BaseType;
            if (parentType == null)
            {
                WriteQword(0);
                WriteDword(0);
                return;
            }
            WriteQword(parentType.Module.Address);
            WriteDword((uint)parentType.MetadataToken);
        }

        private void LegacyGetAllObjectsOfType()
        {
            ulong hModule = ReadQword();
            uint typeDef = ReadDword();
            if (forwarderPipe != null)
            {
                _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_GETALLOBJECTSOFTYPE);
                _ = PipeHelper.WriteQword(forwarderPipe, hModule);
                if (!PipeHelper.WriteDword(forwarderPipe, typeDef))
                    CloseForwarderPipe();
                else
                {
                    ulong objAddr;

                    do
                    {
                        objAddr = PipeHelper.ReadQword(forwarderPipe);
                        WriteQword(objAddr);
                    } while (objAddr != 0);
                    return;
                }
            }

            if (inspector.GetType(hModule, (int)typeDef) == null) // Check if type exists before going through heap
            {
                WriteQword(0);
                return;
            }

            foreach (ClrObject obj in inspector.EnumerateObjectsOfType(hModule, (int)typeDef))
            {
                if (obj.IsValid && !obj.IsFree)
                    WriteQword(obj.Address);
            }
            WriteQword(0);
        }

        #endregion

        #region NewCommands

        private void Test()
        {
            Logger.LogInfo("test");
        }

        private void DataCollectorInfo()
        {
            // Is DataCollector running
            if (forwarderPipe != null || inspector.ClrRuntime != null)
                WriteBool(true);
            else
                WriteBool(false);

            // Is Legacy DataCollector running
            if ((state & PipeServerState.LegacyDataCollectorRunning) != 0)
                WriteBool(false);
            else
                WriteBool(true);

            WriteDword(PipeVersion);

            WriteUTF16String(pipeName);
            WriteUTF16String(_pipeNameEx ?? string.Empty);
        }

        private void EnumDomains()
        {
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                return;
            }
            ClrAppDomain[] appDomains = [.. inspector.EnumerateAppDomains()];
            WriteDword((uint)appDomains.Length);
            foreach (ClrAppDomain appDomain in appDomains)
            {
                WriteQword(appDomain.Address);
                WriteDword((uint)appDomain.Id);
                //Logger.LogInfo($"AppDomain Name: {appDomain.Name}");
                WriteUTF16String(appDomain.Name ?? string.Empty);
            }
        }

        private void EnumModuleList()
        {
            ulong hDomain = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                return;
            }
            ClrModule[] modules;
            if (hDomain != 0)
                modules = [.. inspector.EnumerateModules(hDomain)];
            else
                modules = [.. inspector.EnumerateModules()];

            WriteDword((uint)modules.Length);
            foreach (ClrModule module in modules)
            {
                SendModule(module);
            }
        }

        private void EnumTypeDefs()
        {
            ulong hModule = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                return;
            }
            ClrType[] types;
            if (hModule != 0)
                types = [.. inspector.EnumerateTypes(hModule)];
            else
                types = [.. inspector.EnumerateTypes()];

            WriteDword((uint)types.Length);
            foreach (ClrType type in types)
            {
                WriteDword((uint)type.MetadataToken);
                WriteQword(type.MethodTable);
                WriteDword((uint)type.ElementType);
                WriteDword((uint)type.TypeAttributes);
                WriteQword(type.Module.Address);
                WriteDword((uint)type.StaticSize);
                WriteUTF16String(type.Name ?? string.Empty);
                ulong staticFieldAddress = 0;
                var staticFields = type.StaticFields;
                if (staticFields.Length > 0)
                    staticFieldAddress = staticFields[0].GetAddress(type.Module.AppDomain) - (ulong)staticFields[0].Offset;
                WriteQword(staticFieldAddress);
                ClrType? baseType = type.BaseType;
                WriteDword((uint)(baseType?.MetadataToken ?? 0));
                WriteQword(baseType?.MethodTable ?? 0);
                WriteUTF16String(baseType?.Name ?? string.Empty);
            }
        }

        private void EnumTypeDefMethods()
        {
            ulong methodTable = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                return;
            }
            ClrMethod[] methods = [.. inspector.EnumerateMethods(methodTable)];

            WriteDword((uint)methods.Length);
            foreach (ClrMethod method in methods)
            {
                SendMethod(method);
            }
        }

        private void GetTypeDefParent()
        {
            ulong methodTable = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                WriteQword(0);
                WriteUTF16String(string.Empty);
                return;
            }
            ClrType? baseType = inspector.GetParentType(methodTable);
            WriteDword((uint)(baseType?.MetadataToken ?? 0));
            WriteQword(baseType?.MethodTable ?? 0);
            WriteUTF16String(baseType?.Name ?? string.Empty);
        }

        private void GetAddressData()
        {
            ulong address = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteQword(0);
                return;
            }
            ClrObject? obj = inspector.GetObjectForAddress(address);
            
            if (obj == null)
            {
                WriteQword(0);
                return;
            }
            WriteQword(obj.Value.Address); // StartAddress
            WriteQword(obj.Value.Size); // Size

            SendType(obj.Value);
        }

        private void GetAllObjects()
        {
            if (inspector.ClrRuntime != null)
            {
                foreach (ClrObject obj in inspector.EnumerateObjects())
                {
                    if (!obj.IsValid || obj.IsFree)
                        continue;
                    WriteQword(obj.Address);
                    WriteQword(obj.Size);
                    ClrType? type = obj.Type;
                    if (type != null)
                        SendType(type);
                    else
                        WriteDword(uint.MaxValue);
                }
            }
            WriteQword(0);
            WriteQword(0);
        }

        private void GetTypeDefFields()
        {
            ulong methodTable = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrType? type = inspector.GetType(methodTable);
            if (type == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendType(type);
        }

        private void GetMethodParameters()
        {
            ulong methodHandle = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrMethod? method = inspector.GetMethod(methodHandle);
            if (method == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }

            ModuleMetadataReader? metadataReader = null;

            ClrType? methodType = ClrExtensions.GetRealClrTypeFromMethod(method);

            if (methodType != null)
                metadataReader = TryGetOrCreateModuleMetaDataReader(methodType.Module);
            MethodDefinition? methodDefinition = null;

            _ = metadataReader?.TryGetMetaData(method.MetadataToken, out methodDefinition);
            List<string> paramNames = [];

            try
            {
                if (methodDefinition.HasValue && metadataReader != null)
                {
                    // Handle method Parameters Correctly
                    foreach (ParameterHandle mparam in methodDefinition.Value.GetParameters())
                    {
                        Parameter? _param = metadataReader.GetDefinitionFromHandle<Parameter>(mparam);
                        if (_param.HasValue)
                        {
                            string paramName = metadataReader.GetStringFromHandle(_param.Value.Name);
                            int index = _param.Value.SequenceNumber - 1;
                            if (index < 0)
                                break; // Failed to get parameters

                            if (!string.IsNullOrEmpty(paramName))
                                paramNames.Insert(index, paramName);
                            else
                                paramNames.Insert(index, "<Unknown>");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
#if DEBUG
                Logger.LogException(ex);
#endif
            }

            var methodParams = MethodSignatureParser.ParseSignature(method.Signature ?? string.Empty);

            WriteDword((uint)methodParams.Count);

            WriteUTF16String(method.Signature ?? string.Empty);

            for (int i = 0; i < methodParams.Count; i++)
            {
                WriteUTF16String(paramNames.ElementAtOrDefault(i) ?? string.Empty); // param name
                WriteUTF16String(methodParams[i].paramName); // type name
                WriteDword((uint)methodParams[i].cPlusTypeFlag);
                WriteDword((uint)i + 1);
            }
        }

        private void GetAllObjectsOfType()
        {
            ulong methodTable = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            ClrType? type = inspector.GetType(methodTable);
            if (type == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            foreach (ClrObject obj in inspector.EnumerateObjectsOfType(type))
            {
                if (obj.IsFree || !obj.IsValid)
                    continue;
                WriteQword(obj.Address);
                WriteQword(obj.Size);
            }
            WriteQword(0);
            WriteQword(0);
        }

        private void GetTypeInfo()
        {
            ulong methodTable = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrType? type = inspector.GetType(methodTable);
            if (type == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendType(type);
        }

        private void GetBaseClassModule()
        {
            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            ClrModule baseModule = inspector.GetBaseClassModule();

            SendModule(baseModule);
        }

        private void GetAppDomainInfo()
        {
            ulong address = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            ClrAppDomain? appDomain = inspector.GetAppDomainByAddress(address);
            if (appDomain == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            WriteQword(appDomain.Address);
            WriteDword((uint)appDomain.Id);
            WriteQword(appDomain.LoaderAllocator);
            WriteUTF16String(appDomain.Name ?? string.Empty);
            WriteUTF16String(appDomain.ApplicationBase ?? string.Empty);
            WriteUTF16String(appDomain.ConfigurationFile ?? string.Empty);
        }

        private void EnumGCHandles()
        {
            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            foreach (ClrHandle handle in inspector.EnumerateGCHandles())
            {
                WriteQword(handle.Address);
                WriteDword((uint)handle.HandleKind);
                WriteDword(handle.ReferenceCount);
                WriteDword((uint)handle.RootKind);
                WriteQword(handle.AppDomain.Address);
                WriteQword(handle.Object.Address);
                WriteQword(handle.Object.IsValid ? handle.Object.Size : ulong.MaxValue);
                WriteDword((uint)(handle.Object.Type?.MetadataToken ?? 0));
                WriteQword(handle.Object.Type?.MethodTable ?? 0);
                WriteUTF16String(handle.Object.Type?.Name ?? string.Empty);
                WriteQword(handle.Dependent.Address);
                WriteQword(handle.Dependent.IsValid ? handle.Dependent.Size : ulong.MaxValue);
                WriteDword((uint)(handle.Dependent.Type?.MetadataToken ?? 0));
                WriteQword(handle.Dependent.Type?.MethodTable ?? 0);
                WriteUTF16String(handle.Dependent.Type?.Name ?? string.Empty);
            }
            WriteQword(ulong.MaxValue); // End
        }

        private void GetMethodInfo()
        {
            ulong methodHandle = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrMethod? method = inspector.GetMethod(methodHandle);
            if (method == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendMethod(method);
        }

        private void GetMethodByIP()
        {
            ulong ip = ReadQword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrMethod? method = inspector.GetMethodByInstructionPointer(ip);
            if (method == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendMethod(method);
        }

        private void GetTypeFromElementType()
        {
            ClrElementType clrElementType = ClrElementType.Unknown;
            uint elementType = ReadDword();
            uint specialType = ReadDword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            if (Enum.IsDefined(typeof(ClrElementType), (int)elementType))
            {
                clrElementType = (ClrElementType)(int)elementType;
            }
            ClrType? type = inspector.ClrTypeFromElementType(clrElementType, specialType);
            if (type == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendType(type);
        }

        private void GetClrInfo()
        {
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrInfo info = inspector.ClrRuntime.ClrInfo;
            WriteDword((uint)info.Flavor);
            WriteUTF16String(info.Version.ToString());
            ModuleInfo moduleInfo = info.ModuleInfo;
            WriteQword(moduleInfo.ImageBase);
            WriteQword((ulong)moduleInfo.ImageSize);
            WriteBool(moduleInfo.IsManaged);
            WriteUTF16String(moduleInfo.FileName);
            WriteUTF16String(moduleInfo.Version.ToString());
        }

        private void EnumThreads()
        {
            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrThread[] threads = [.. inspector.EnumerateThreads()];

            WriteDword((uint)threads.Length);

            foreach (ClrThread thread in threads)
            {
                WriteQword(thread.Address);
                WriteDword((uint)thread.ManagedThreadId);
                WriteDword(thread.OSThreadId);
                WriteQword(thread.StackBase);
                WriteQword(thread.StackLimit);
                WriteDword((uint)thread.GCMode);
                WriteDword((uint)thread.State);
                WriteBool(thread.IsAlive);
                WriteBool(thread.IsGc);
                WriteBool(thread.IsFinalizer);
                WriteQword(thread.CurrentAppDomain?.Address ?? 0);
                WriteQword(thread.CurrentException?.Address ?? 0);
                WriteUTF16String(thread.CurrentException?.Message ?? string.Empty);
            }
        }

        private void TraceStack()
        {
            uint threadid = ReadDword();
            if (inspector.ClrRuntime == null)
            {
                WriteDword(0);
                return;
            }

            ClrThread? thread = inspector.EnumerateThreads().FirstOrDefault(t => t.OSThreadId == threadid)
                                ?? inspector.EnumerateThreads().FirstOrDefault(t => t.ManagedThreadId == threadid);

            if (thread == null)
            {
                WriteDword(0);
                return;
            }

            ClrStackFrame[] frames = [.. ClrExtensions.EnumerateStackTrace(thread, false)];

            WriteDword((uint)frames.Length);

            foreach (ClrStackFrame frame in frames)
            {
                WriteQword(frame.StackPointer);
                WriteQword(frame.InstructionPointer);
                WriteDword((uint)frame.Kind);
                WriteUTF16String(frame.FrameName ?? string.Empty);
                WriteUTF16String(frame.ToString() ?? string.Empty);
                ClrMethod? method = frame.Method;
                if (method != null)
                {
                    WriteDword((uint)method.MetadataToken);
                    WriteQword(method.MethodDesc);
                    WriteQword(method.NativeCode != ulong.MaxValue ? method.NativeCode : 0);
                    WriteUTF16String(method.Name ?? string.Empty);
                    WriteUTF16String(method.Signature ?? string.Empty);
                }
                else
                {
                    WriteDword(uint.MaxValue);
                }
            }
        }

        private void GetThreadFromThreadID()
        {
            uint threadid = ReadDword();
            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            ClrThread? thread = inspector.EnumerateThreads().FirstOrDefault(t => t.OSThreadId == threadid)
                                ?? inspector.EnumerateThreads().FirstOrDefault(t => t.ManagedThreadId == threadid);

            if (thread == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            WriteQword(thread.Address);
            WriteDword((uint)thread.ManagedThreadId);
            WriteDword(thread.OSThreadId);
            WriteQword(thread.StackBase);
            WriteQword(thread.StackLimit);
            WriteDword((uint)thread.GCMode);
            WriteDword((uint)thread.State);
            WriteBool(thread.IsAlive);
            WriteBool(thread.IsGc);
            WriteBool(thread.IsFinalizer);
            WriteQword(thread.CurrentAppDomain?.Address ?? 0);
            WriteQword(thread.CurrentException?.Address ?? 0);
            WriteUTF16String(thread.CurrentException?.Message ?? string.Empty);
        }

        private void FlushDACCache()
        {
            if (inspector.ClrRuntime == null)
                return;
            inspector.FlushDACCache();
        }

        private void DumpModule()
        {
            ulong hModule = ReadQword();
            string filePath = ReadUTF16String();
            if (inspector.ClrRuntime == null)
            {
                WriteUTF16String("No ClrRuntime!");
                return;
            }

            ClrModule? module = inspector.EnumerateModules().FirstOrDefault(m => m.Address == hModule);

            if (module == null)
            {
                WriteUTF16String("Failed to find module!");
                return;
            }
            string? error = inspector.DumpModule(module, filePath);
            WriteUTF16String(error ?? string.Empty);
        }

        private void MethodGetType()
        {
            ulong hMethod = ReadQword();

            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            ClrMethod? method = inspector.GetMethod(hMethod);
            if (method == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            SendType(method.Type);
        }

        private void FindMethod()
        {
            // Search for a method by its (optional) module, full Class name, methodname, (optional)method parameter count
            ulong hModule = ReadQword();
            string fullClassName = ReadUTF16String(); // namespace.classname
            string methodName = ReadUTF16String();
            uint paramCount = ReadDword();
            bool caseSensitiveSearch = ReadBool();

            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            if (!MethodSignatureParser.IsValidNamespaceClassName(fullClassName))
            {
                WriteDword(uint.MaxValue);
                return;
            }
            if (!MethodSignatureParser.IsValidMethodName(methodName))
            {
                WriteDword(uint.MaxValue);
                return;
            }

            ClrType[] types = inspector.GetModule(hModule) != null ? [.. inspector.EnumerateTypes(hModule)] : [.. inspector.EnumerateTypes()];
            ClrType? foundType = null;

            foreach (ClrType type in types)
            {
                if (type.Name?.Equals(fullClassName, caseSensitiveSearch ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase) ?? false)
                {
                    foundType = type;
                    break;
                }
            }

            if (foundType == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            foreach (ClrMethod method in foundType.Methods)
            {
                if (method.Name?.Equals(methodName, caseSensitiveSearch ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase) ?? false) 
                {
                    if (paramCount == uint.MaxValue || MethodSignatureParser.MethodSignatureGetParameters(method.Signature ?? string.Empty).Length == paramCount)
                    {
                        SendMethod(method);
                        return;
                    }
                }
            }
            WriteDword(uint.MaxValue);
        }

        private void FindMethodByDesc()
        {
            ulong hModule = ReadQword();
            string methodSignature = ReadUTF16String();
            bool caseSensitiveSearch = ReadBool();

            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }

            ClrType[] types = inspector.GetModule(hModule) != null ? [.. inspector.EnumerateTypes(hModule)] : [.. inspector.EnumerateTypes()];
            ClrType? foundType = null;

            string fullTypeName = MethodSignatureParser.MethodSignatureGetFullTypeName(methodSignature);

            if (!MethodSignatureParser.IsValidNamespaceClassName(fullTypeName))
            {
                WriteDword(uint.MaxValue);
                return;
            }

            foreach (ClrType type in types)
            {
                if (type.Name?.Equals(fullTypeName, caseSensitiveSearch ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase) ?? false)
                {
                    foundType = type;
                    break;
                }
            }
            if (foundType == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }
            foreach (ClrMethod method in foundType.Methods)
            {
                if (MethodSignatureParser.AreMethodSignaturesEqual(method.Signature ?? string.Empty, methodSignature, caseSensitiveSearch)) 
                {
                    SendMethod(method);
                    return;
                }
            }
            WriteDword(uint.MaxValue);
        }

        private void FindClass()
        {
            ulong hModule = ReadQword();
            string fullClassName = ReadUTF16String();
            bool caseSensitiveSearch = ReadBool();

            if (inspector.ClrRuntime == null)
            {
                WriteDword(uint.MaxValue);
                return;
            }

            if (!MethodSignatureParser.IsValidNamespaceClassName(fullClassName))
            {
                WriteDword(uint.MaxValue);
                return;
            }

            ClrType[] types = inspector.GetModule(hModule) != null ? [.. inspector.EnumerateTypes(hModule)] : [.. inspector.EnumerateTypes()];

            foreach (ClrType type in types)
            {
                if (type.Name?.Equals(fullClassName, caseSensitiveSearch ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase) ?? false)
                {
                    SendType(type);
                    return;
                }
            }
            WriteDword(uint.MaxValue);
        }

        private void ClassGetModule()
        {
            ulong hType = ReadQword();

            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            ClrType? type = inspector.GetType(hType);

            if (type == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }
            SendModule(type.Module);
        }

        private void FindModule()
        {
            string moduleName = ReadUTF16String();
            bool caseSensitive = ReadBool();

            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            ClrModule? module = inspector.FindModule(null, moduleName, caseSensitive);

            if (module == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            SendModule(module);
        }

        private void MethodGetModule()
        {
            ulong hMethod = ReadQword();

            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            ClrMethod? method = inspector.GetMethod(hMethod);

            if (method == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            SendModule(method.Type.Module);
        }

        private void GetModuleByHandle()
        {
            ulong hModule = ReadQword();

            if (inspector.ClrRuntime == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            ClrModule? module = inspector.GetModule(hModule);

            if (module == null)
            {
                WriteQword(ulong.MaxValue);
                return;
            }

            SendModule(module);
        }

        #endregion

        private void RunExLoopStub()
        {
            RunLoop();
            //state &= ~PipeServerState.PipeExCreated;

            Logger.LogInfo("PipeServer Ex closing!");
            if (_pipeServerEx != null)
            {
                // Tell the base pipe that the Pipe has closed and remove the reference
                _pipeServerEx.state &= ~PipeServerState.PipeExCreated;
                _pipeServerEx._pipeServerEx = null;
            }
        }

        public void RunLoop()
        {
            if (_noLegacyDataCollector)
                state |= PipeServerState.RunningAsExtension;
            pipe.WaitForConnection();
            while (true)
            {
                byte command = ReadByte();
#if DEBUG
                Logger.LogInfo($"Command Received: {Enum.GetName(typeof(Commands), command)}");
#endif
                switch (command)
                {
                    case (byte)Commands.L_CMD_TARGETPROCESS:
                        uint processId = ReadDword();
                        if (processId == 0)
                        {
                            if (forwarderPipe != null)
                            {
                                PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_CLOSEPROCESSANDQUIT);
                            }
                            if (pipe.IsConnected)
                                Logger.LogInfo("Process ID is 0 -> Close DataCollector");
                            else if (!_isExPipe)
                                Logger.LogInfo("Pipe was closed -> Close DataCollector");
                            else
                                Logger.LogInfo("PipeEx was closed");
                            return;
                        }
                        state |= PipeServerState.TriedAttach;
                        _processID = processId;
                        bool result = OpenOrAttachToProcess((int)processId);
                        if (result) // Check if ex successfully attached
                        {
                            state |= PipeServerState.AttachedEx;
                            ClrExtensions.ClearClrElementTypeCache(); // Clear the Type cache if we changed the process!
                            foreach (ModuleMetadataReader moduleMetadata in moduleMetadataReaders.Values)
                            {
                                moduleMetadata.Dispose(); // Dispose of all old ModuleMetaDataReaders
                            }
                            moduleMetadataReaders.Clear(); // Clear ModuleMetaDataDictonaries
                            moduleMetaDataReadersCreationFailed.Clear(); // Clear failed to create Modules

                            foreach (ClrModule module in inspector.EnumerateModules())
                            {
                                if (module.IsDynamic)
                                    continue;
                                    
                                try
                                {
                                    ModuleMetadataReader moduleMetadata = new(module);
                                    moduleMetadataReaders.Add(module.Address, moduleMetadata);
                                    Logger.LogInfo($"MetaDataReader created for Module: {Path.GetFileName(module.Name)}");
                                }
                                catch (Exception ex) 
                                {
                                    Logger.LogWarning($"Failed to create MetaDataReader for Module: {Path.GetFileName(module.Name)} Message: {ex.Message}");
#if DEBUG
                                    Logger.LogException(ex);
#endif
                                    moduleMetaDataReadersCreationFailed.Add(module.Address); // Add failed to parse modules for faster later check
                                }
                            }
                        }
                        else
                            Logger.LogWarning("Failed to attach to Process with DataCollectorEx");

                        if ((state & PipeServerState.RunningAsExtension) == 0)
                        {
                            //Logger.LogWarning("Failed to attach to Process trying to start Legacy DataCollector!");
                            try
                            {
                                legacyDotNetDataCollectorPipeName = $"legacycedotnetpipe_{processId}_{Environment.TickCount}";
                                legacyDotNetDataCollectorProcess = Process.Start(new ProcessStartInfo()
                                {
                                    FileName = nint.Size == 8 ? legacyDotNetDataCollectorFileName + "64" : legacyDotNetDataCollectorFileName + "32",
                                    Arguments = legacyDotNetDataCollectorPipeName,
                                    CreateNoWindow = true
                                });
                                forwarderPipe = new NamedPipeClientStream(".", legacyDotNetDataCollectorPipeName, PipeDirection.InOut);
                                forwarderPipe.Connect(LegacyPipeConnectionTimeout);
                                Logger.LogInfo("Legacy DotNetDataCollector started!");

                                PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_TARGETPROCESS);
                                // Forward command/result
                                PipeHelper.WriteDword(forwarderPipe, processId);
                                result = PipeHelper.ReadDword(forwarderPipe) != 0; // DataCollector seems to send 4 bytes -> bool...
                                //result = PipeHelper.ReadBool(forwarderPipe);
                                if (result)
                                {
                                    state |= PipeServerState.LegacyDataCollectorRunning; // Set Legacy DataCollector as Running
                                }
                                else
                                {
                                    Logger.LogWarning("Legacy DataCollector says can't connect!");
                                    forwarderPipe.Dispose();
                                    forwarderPipe = null;
                                }
                            }
                            catch (Exception ex)
                            {
                                if (ex is TimeoutException)
                                {
                                    Logger.LogError("Legacy pipe connection timeout!");
                                }
                                else
                                {
                                    Logger.LogException(ex);
                                    Logger.LogError("Failed to create legacy DotNetDataCollector!");
                                }

                                forwarderPipe?.Dispose();
                                forwarderPipe = null;

                                if (!result)
                                {
                                    WriteBool(false);
                                    WriteBool(false);
                                    return;
                                }
                            }
                        }
                        if ((state & PipeServerState.AttachedEx) != 0)
                            result = true;
                        if (result) // Check if it attached to either DCEx, legacy DC or both
                            state |= PipeServerState.Attached;
                        WriteBool(result); // Sucessfully attached TODO: DotNetDataCollector seems to send 4 bytes and not 1?

                        if (forwarderPipe != null)
                        {
                            result = PipeHelper.ReadDword(forwarderPipe) != 0; // DataCollector seems to send 4 bytes -> bool...
                            //Console.WriteLine(result);
                            //result = PipeHelper.ReadBool(forwarderPipe);
                        }
                        WriteBool(result); // supports structure type lookups TODO: DotNetDataCollector seems to send 4 bytes and not 1?

                        break;
                    case (byte)Commands.L_CMD_CLOSEPROCESSANDQUIT:
                        if (forwarderPipe != null)
                            PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_CLOSEPROCESSANDQUIT); // Close Legacy Data Collector if is running
                        Logger.LogInfo("DotNetDataCollector closing!");
                        return;
                    case (byte)Commands.L_CMD_RELEASEOBJECTHANDLE:
                        ulong hObject = ReadQword();
#if DEBUG
                        Logger.LogInfo($"L_CMD_RELEASEOBJECTHANDLE called for hObject: 0x{hObject:X}");
#endif
                        if (forwarderPipe != null)
                        {
                            _ = PipeHelper.WriteByte(forwarderPipe, (byte)Commands.L_CMD_RELEASEOBJECTHANDLE);
                            if (!PipeHelper.WriteQword(forwarderPipe, hObject))
                                CloseForwarderPipe();
                        }
                        break;
                    case (byte)Commands.L_CMD_ENUMDOMAINS:
                        LegacyEnumDomains();
                        break;
                    case (byte)Commands.L_CMD_ENUMMODULELIST:
                        LegacyEnumModules();
                        break;
                    case (byte)Commands.L_CMD_ENUMTYPEDEFS:
                        LegacyEnumTypeDefs();
                        break;
                    case (byte)Commands.L_CMD_GETTYPEDEFMETHODS:
                        LegacyEnumTypeDefMethods();
                        break;
                    case (byte)Commands.L_CMD_GETADDRESSDATA:
                        LegacyGetAddressData();
                        break;
                    case (byte)Commands.L_CMD_GETALLOBJECTS:
                        LegacyGetAllObjects();
                        break;
                    case (byte)Commands.L_CMD_GETTYPEDEFFIELDS:
                        LegacyGetTypeDefFields();
                        break;
                    case (byte)Commands.L_CMD_GETMETHODPARAMETERS:
                        LegacyGetMethodParameters();
                        break;
                    case (byte)Commands.L_CMD_GETTYPEDEFPARENT:
                        LegacyGetTypeDefParent();
                        break;
                    case (byte)Commands.L_CMD_GETALLOBJECTSOFTYPE:
                        LegacyGetAllObjectsOfType();
                        break;
                    case (byte)Commands.CMD_TEST:
                        Test();
                        break;
                    case (byte)Commands.CMD_DATACOLLECTORINFO:
                        DataCollectorInfo();
                        break;
                    case (byte)Commands.CMD_ENUMDOMAINS:
                        EnumDomains();
                        break;
                    case (byte)Commands.CMD_ENUMMODULELIST:
                        EnumModuleList();
                        break;
                    case (byte)Commands.CMD_ENUMTYPEDEFS:
                        EnumTypeDefs();
                        break;
                    case (byte)Commands.CMD_ENUMTYPEDEFMETHODS:
                        EnumTypeDefMethods();
                        break;
                    case (byte)Commands.CMD_GETTYPEDEFPARENT:
                        GetTypeDefParent();
                        break;
                    case (byte)Commands.CMD_GETADDRESSDATA:
                        GetAddressData();
                        break;
                    case (byte)Commands.CMD_GETALLOBJECTS:
                        GetAllObjects();
                        break;
                    case (byte)Commands.CMD_GETTYPEDEFFIELDS:
                        GetTypeDefFields();
                        break;
                    case (byte)Commands.CMD_GETMETHODPARAMETERS:
                        GetMethodParameters();
                        break;
                    case (byte)Commands.CMD_GETALLOBJECTSOFTYPE:
                        GetAllObjectsOfType();
                        break;
                    case (byte)Commands.CMD_GETTYPEINFO:
                        GetTypeInfo();
                        break;
                    case (byte)Commands.CMD_GETBASECLASSMODULE:
                        GetBaseClassModule();
                        break;
                    case (byte)Commands.CMD_GETAPPDOMAININFO:
                        GetAppDomainInfo();
                        break;
                    case (byte)Commands.CMD_ENUMGCHANDLES:
                        EnumGCHandles();
                        break;
                    case (byte)Commands.CMD_GETMETHODINFO:
                        GetMethodInfo();
                        break;
                    case (byte)Commands.CMD_GETMETHODBYIP:
                        GetMethodByIP();
                        break;
                    case (byte)Commands.CMD_GETTYPEFROMELEMENTTYPE:
                        GetTypeFromElementType();
                        break;
                    case (byte)Commands.CMD_CLRINFO:
                        GetClrInfo();
                        break;
                    case (byte)Commands.CMD_ENUMTHREADS:
                        EnumThreads();
                        break;
                    case (byte)Commands.CMD_TRACESTACK:
                        TraceStack();
                        break;
                    case (byte)Commands.CMD_GETTHREAD:
                        GetThreadFromThreadID();
                        break;
                    case (byte)Commands.CMD_FLUSHDACCACHE:
                        FlushDACCache();
                        break;
                    case (byte)Commands.CMD_DUMPMODULE:
                        DumpModule();
                        break;
                    case (byte)Commands.CMD_METHODGETTYPE:
                        MethodGetType();
                        break;
                    case (byte)Commands.CMD_FINDMETHOD:
                        FindMethod();
                        break;
                    case (byte)Commands.CMD_FINDMETHODBYDESC:
                        FindMethodByDesc();
                        break;
                    case (byte)Commands.CMD_FINDCLASS:
                        FindClass();
                        break;
                    case (byte)Commands.CMD_CLASSGETMODULE:
                        ClassGetModule();
                        break;
                    case (byte)Commands.CMD_FINDMODULE:
                        FindModule();
                        break;
                    case (byte)Commands.CMD_METHODGETMODULE:
                        MethodGetModule();
                        break;
                    case (byte)Commands.CMD_GETMODULEBYHANDLE:
                        GetModuleByHandle();
                        break;
                    default:
                        Logger.LogWarning($"Invalid Command send over pipe: '{command}'");
                        break;
                }
            }
        }

        ~PipeServer()
        {
            pipe.Dispose();
            if (!_isExPipe)
                inspector.Dispose();
        }
    }
}
