using System.Reflection.Metadata;
using Microsoft.Diagnostics.Runtime;
using System.Reflection.PortableExecutable;
using System.Collections.Immutable;
using System.Reflection.Metadata.Ecma335;
using System.Runtime.InteropServices;

namespace DotNetDataCollectorEx
{
    public class ModuleMetadataReader : IDisposable
    {
        private readonly MetadataReader _metadataReader;
        private readonly PEReader _peReader;
        public readonly ulong hModule;

        public ModuleMetadataReader(ClrModule module)
        {
            if (!string.IsNullOrEmpty(module.Name) && Path.IsPathFullyQualified(module.Name) && File.Exists(module.Name))
            {
                try
                {
                    ImmutableArray<byte> fileBytes = [.. File.ReadAllBytes(module.Name)];
                    _peReader = new(fileBytes);
                }
                catch (Exception ex)
                {
#if DEBUG
                    Logger.LogException(ex);
#endif
                }
            }
            if (_peReader == null)
            {
                ImmutableArray<byte> moduleBytes = ReadModuleFromProcess(module);
                _peReader = new(moduleBytes);
            }

            _metadataReader = _peReader.GetMetadataReader();
            hModule = module.Address;
        }

        private static ImmutableArray<byte> ReadModuleFromProcess(ClrModule module)
        {
            if (module.IsDynamic)
                throw new InvalidOperationException("Module cannot be dynamic.");
            if (module.ImageBase == 0 || module.Size == 0)
                throw new InvalidOperationException("Module ImageBase and Size cannot be 0.");

            int processId = module.AppDomain.Runtime.DataTarget.DataReader.ProcessId;
            nint hProc = NativeMethods.OpenProcess(NativeMethods.PROCESS_VM_READ | NativeMethods.PROCESS_QUERY_INFORMATION, false, processId);

            if (hProc == IntPtr.Zero)
            {
                throw new InvalidOperationException("Failed to open process.");
            }

            using MemoryStream memoryStream = new();
            ulong currentLocation = 0;
            bool success = true;

            while (currentLocation < module.Size)
            {
                if (NativeMethods.VirtualQueryEx(hProc, (nint)(module.ImageBase + currentLocation), out NativeMethods.MEMORY_BASIC_INFORMATION memoryInfo, (uint)Marshal.SizeOf<NativeMethods.MEMORY_BASIC_INFORMATION>()) == 0)
                {
                    success = false;
                    break;
                }

                // Determine the read size (ensuring we don't read beyond module.Size)
                ulong readSize = Math.Min((ulong)memoryInfo.RegionSize, module.Size - currentLocation);
                byte[] buffer = new byte[readSize];

                if ((memoryInfo.State & 0x1000) == 0x1000 && // MEM_COMMIT
                    ((memoryInfo.Protect & 0x02) == 0x02 || // PAGE_READWRITE
                    (memoryInfo.Protect & 0x04) == 0x04 || // PAGE_READONLY
                    (memoryInfo.Protect & 0x20) == 0x20 || // PAGE_EXECUTE_READ
                    (memoryInfo.Protect & 0x40) == 0x40)) // PAGE_EXECUTE_READWRITE
                {
                    if (!NativeMethods.ReadProcessMemory(hProc, (nint)(module.ImageBase + currentLocation), buffer, (int)readSize, out nint bytesRead) || (ulong)bytesRead != readSize)
                    {
                        success = false;
                        break;
                    }
                }
                else if (currentLocation == 0)
                {
                    // We can't ignore the first part being Invalid!
                    success = false;
                    break;
                }

                memoryStream.Write(buffer); // Write bytes, if we couldn't read the memory the buffer array will just be zeros

                currentLocation += readSize;
            }

            _ = NativeMethods.CloseHandle(hProc);

            return success
                ? [.. memoryStream.ToArray()]
                : throw new InvalidOperationException("Failed to read the module's memory correctly.");
        }

        public T? GetMetaData<T>(int token) where T : struct
        {
            EntityHandle handle = MetadataTokens.EntityHandle(token);

            return handle.Kind switch
            {
                HandleKind.TypeDefinition when typeof(T) == typeof(TypeDefinition) =>
                    (T)(object)_metadataReader.GetTypeDefinition((TypeDefinitionHandle)handle),
                HandleKind.MethodDefinition when typeof(T) == typeof(MethodDefinition) =>
                    (T)(object)_metadataReader.GetMethodDefinition((MethodDefinitionHandle)handle),
                _ => null
            };
        }

        public T? GetDefinitionFromHandle<T>(EntityHandle handle) where T : struct
        {
            return handle.Kind switch
            {
                HandleKind.TypeDefinition when typeof(T) == typeof(TypeDefinition) =>
                    (T)(object)_metadataReader.GetTypeDefinition((TypeDefinitionHandle)handle),
                HandleKind.MethodDefinition when typeof(T) == typeof(MethodDefinition) =>
                    (T)(object)_metadataReader.GetMethodDefinition((MethodDefinitionHandle)handle),
                HandleKind.FieldDefinition when typeof(T) == typeof(FieldDefinition) =>
                    (T)(object)_metadataReader.GetFieldDefinition((FieldDefinitionHandle)handle),
                HandleKind.Parameter when typeof(T) == typeof(Parameter) =>
                    (T)(object)_metadataReader.GetParameter((ParameterHandle)handle),
                _ => null
            };
        }

        public bool TryGetMetaData<T>(int token, out T? metadata) where T : struct
        {
            try
            {
                metadata = GetMetaData<T>(token);
                return metadata.HasValue;
            }
            catch (Exception ex)
            {
#if DEBUG
                Logger.LogInfo("Exception occurred in TryGetMetaData");
                Logger.LogException(ex);
#endif
                metadata = null;
                return false;
            }
        }

        public string GetStringFromHandle(StringHandle handle)
        {
            try
            {
                if (!handle.IsNil)
                {
                    return _metadataReader.GetString(handle);
                }
            }
            catch (Exception ex)
            {
#if DEBUG
                Logger.LogException(ex);
#endif
            }

            return string.Empty;
        }

        ~ModuleMetadataReader()
        {
            Dispose(false);
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        private void Dispose(bool _)
        {
            _peReader?.Dispose();
        }
    }
}
