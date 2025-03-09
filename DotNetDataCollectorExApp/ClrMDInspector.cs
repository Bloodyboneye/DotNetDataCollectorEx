using Microsoft.Diagnostics.Runtime;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;

namespace DotNetDataCollectorEx
{
    public class ClrMDInspector : IDisposable
    {
        private DataTarget? _dataTarget;
        private ClrRuntime? _clrRuntime;

        private int _processId;

        public ClrRuntime? ClrRuntime => _clrRuntime;

        private void EnsureClrRuntimeInitializedOrThrow()
        {
            if (_clrRuntime == null)
                throw new InvalidOperationException("CLR runtime is not initialized. Cannot perform operation without a valid CLR runtime instance.");
        }

        private static string[] TryFindDACsInProcessDir(int processId)
        {
            try
            {
                using Process process = Process.GetProcessById(processId);

                string processDirectory = Path.GetDirectoryName(process.MainModule?.FileName ?? string.Empty) ?? string.Empty;

                if (string.IsNullOrEmpty(processDirectory))
                    return [];

                string[] DACFiles = ["mscordaccore.dll", "mscordacwks.dll"];

                List<string> foundFiles = [.. Directory.EnumerateFiles(processDirectory, "*.dll", SearchOption.AllDirectories).Where(file => DACFiles.Contains(Path.GetFileName(file), StringComparer.OrdinalIgnoreCase))];

                return [.. foundFiles.OrderBy(file => Path.GetFileName(file) == "mscordaccore.dll" ? 0 : 1)]; // Sort to first use coreclr runtime and then framework

            }
            catch (Exception ex)
            {
                Logger.LogException(ex);
            }

            return [];
        }

        public bool AttachToProcess(int processId)
        {
            if (_clrRuntime != null && _processId == processId)
                return true;
            try
            {
                _processId = processId;
                _dataTarget = DataTarget.AttachToProcess(processId, false);
                _clrRuntime = _dataTarget.ClrVersions.FirstOrDefault()?.CreateRuntime();
                if (_clrRuntime == null)
                {
                    Logger.LogInfo("Failed to create runtime -> trying to find DAC in Process Directory");
                    // try and create the Runtime using the dac located in the process directory if any
                    string[] paths = TryFindDACsInProcessDir(processId);
                    foreach (string path in paths)
                    {
                        try
                        {
                            _clrRuntime = _dataTarget.ClrVersions.FirstOrDefault()?.CreateRuntime(path);
                        }
                        catch (Exception ex)
                        {
                            Logger.LogWarning($"Exception occured while trying to create runtime from path\nPath:{path}\nException:{ex.Message}");
                        }
                        if (_clrRuntime != null)
                        {
                            Logger.LogInfo($"Runtime loaded from '{path}'");
                            break;
                        }
                    }
                }
                return _clrRuntime != null;
            }
            catch (Exception ex)
            {
                Logger.LogException(ex);
                return false;
            }
        }

        public void DetachFromProcess()
        {
            _dataTarget?.Dispose();
            _clrRuntime?.Dispose();
            _dataTarget = null;
            _clrRuntime = null;
        }

        public void SetChacheOptions(CacheOptions cacheOptions)
        {
            if (_dataTarget == null)
                throw new InvalidOperationException(nameof(_dataTarget));
            CacheOptions dtCacheOptions = _dataTarget.CacheOptions;
            dtCacheOptions.CacheFieldNames = cacheOptions.CacheFieldNames;
            dtCacheOptions.CacheFields = cacheOptions.CacheFields;
            dtCacheOptions.CacheMethodNames = cacheOptions.CacheMethodNames;
            dtCacheOptions.CacheMethods = cacheOptions.CacheMethods;
            dtCacheOptions.CacheStackRoots = cacheOptions.CacheStackRoots;
            dtCacheOptions.CacheStackTraces = cacheOptions.CacheStackTraces;
            dtCacheOptions.CacheTypeNames = cacheOptions.CacheTypeNames;
            dtCacheOptions.CacheTypes = cacheOptions.CacheTypes;
        }

        public void FlushDACCache()
        {
            EnsureClrRuntimeInitializedOrThrow();
            _clrRuntime!.FlushCachedData();
            ClrExtensions.ClearClrElementTypeCache();
        }

        public IEnumerable<ClrAppDomain> EnumerateAppDomains()
        {
            EnsureClrRuntimeInitializedOrThrow();

            return _clrRuntime!.AppDomains;
        }

        public IEnumerable<ClrModule> EnumerateModules()
        {
            EnsureClrRuntimeInitializedOrThrow();

            return _clrRuntime!.EnumerateModules();
        }

        public IEnumerable<ClrModule> EnumerateModules(ulong appDomainAddress)
        {
            EnsureClrRuntimeInitializedOrThrow();

            ClrAppDomain? clrAppDomain = _clrRuntime!.GetAppDomainByAddress(appDomainAddress);
            return clrAppDomain == null ? [] : clrAppDomain.Modules;
        }

        public IEnumerable<ClrType> EnumerateTypes()
        {
            EnsureClrRuntimeInitializedOrThrow();

            foreach (ClrModule module in _clrRuntime!.EnumerateModules())
            {
                foreach ((ulong mt, int _) in module.EnumerateTypeDefToMethodTableMap())
                {
                    ClrType? type = _clrRuntime.GetTypeByMethodTable(mt);
                    if (type != null)
                        yield return type;
                }
            }
        }

        public IEnumerable<ClrType> EnumerateTypes(ulong moduleAddress)
        {
            EnsureClrRuntimeInitializedOrThrow();

            foreach (ClrModule module in _clrRuntime!.EnumerateModules())
            {
                if (module.Address != moduleAddress)
                    continue;
                foreach ((ulong mt, int _) in module.EnumerateTypeDefToMethodTableMap())
                {
                    ClrType? type = _clrRuntime.GetTypeByMethodTable(mt);
                    if (type != null) 
                        yield return type;
                }
            }
        }

        public ClrModule? GetModule(ulong hModule)
        {
            EnsureClrRuntimeInitializedOrThrow();

            return EnumerateModules().FirstOrDefault(m => m.Address == hModule);
        }

        public ClrType? GetType(ulong methodTable)
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.GetTypeByMethodTable(methodTable);
        }

        public ClrType? GetType(ulong moduleAddress, int typeToken)
        {
            EnsureClrRuntimeInitializedOrThrow();

            foreach (ClrModule module in _clrRuntime!.EnumerateModules())
            {
                if (module.Address != moduleAddress)
                    continue;
                foreach ((ulong mt, int tk) in module.EnumerateTypeDefToMethodTableMap())
                {
                    if (tk != typeToken)
                        continue;
                    ClrType? type = _clrRuntime.GetTypeByMethodTable(mt);
                    if (type == null)
                        return null;
                    return type;
                }
                break;
            }
            return null;
        }

        public ClrType? GetParentType(ulong methodTable)
        {
            EnsureClrRuntimeInitializedOrThrow();
            ClrType? type = _clrRuntime!.GetTypeByMethodTable(methodTable);
            return type?.BaseType;
        }

        public ClrType? GetParentType(ulong moduleAddress, int typeToken)
        {
            ClrType? type = GetType(moduleAddress, typeToken);
            return type?.BaseType;
        }

        public IEnumerable<ClrMethod> EnumerateMethods(ulong methodTable)
        {
            EnsureClrRuntimeInitializedOrThrow();

            ClrType? type = _clrRuntime!.GetTypeByMethodTable(methodTable);
            return type == null ? [] : type.Methods;
        }

        public IEnumerable<ClrMethod> EnumerateMethods(ulong moduleAddress, int typeToken)
        {
            EnsureClrRuntimeInitializedOrThrow();

            ClrType? type = GetType(moduleAddress, typeToken);
            return type == null ? [] : type.Methods;
        }

        public ClrMethod? GetMethod(ulong methodHandle)
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.GetMethodByHandle(methodHandle);
        }

        public ClrMethod? GetMethod(ulong moduleAddress, int methodToken)
        {
            EnsureClrRuntimeInitializedOrThrow();

            foreach (ClrModule module in _clrRuntime!.EnumerateModules())
            {
                if (module.Address != moduleAddress)
                    continue;
                foreach ((ulong mt, int tk) in module.EnumerateTypeDefToMethodTableMap())
                {
                    ClrType? type = _clrRuntime.GetTypeByMethodTable(mt);
                    if (type == null)
                        continue;
                    foreach (ClrMethod method in ClrExtensions.EnumerateMethods(type))
                    {
                        if (method.MetadataToken == methodToken)
                            return method;
                    }
                }
            }
            return null;
        }

        public IEnumerable<ClrObject> EnumerateObjects(bool throwOnInconsistentHeap = false)
        {
            EnsureClrRuntimeInitializedOrThrow();
            if (throwOnInconsistentHeap && !_clrRuntime!.Heap.CanWalkHeap)
                throw new InvalidOperationException("Heap is in an inconsistent state and cannot be walked. This may indicate corruption or an incomplete GC.");
            return _clrRuntime!.Heap.EnumerateObjects();
        }

        public IEnumerable<ClrObject> EnumerateObjectsOfType(ClrType type, bool throwOnInconsistentHeap = false)
        {
            EnsureClrRuntimeInitializedOrThrow();
            if (throwOnInconsistentHeap && !_clrRuntime!.Heap.CanWalkHeap)
                throw new InvalidOperationException("Heap is in an inconsistent state and cannot be walked. This may indicate corruption or an incomplete GC.");
            foreach (ClrObject obj in _clrRuntime!.Heap.EnumerateObjects())
            {
                if (type.Equals(obj.Type))
                    yield return obj;
            }
        }

        public IEnumerable<ClrObject> EnumerateObjectsOfType(ulong moduleAddress, int typeToken, bool throwOnInconsistentHeap = false)
        {
            EnsureClrRuntimeInitializedOrThrow();
            if (throwOnInconsistentHeap && !_clrRuntime!.Heap.CanWalkHeap)
                throw new InvalidOperationException("Heap is in an inconsistent state and cannot be walked. This may indicate corruption or an incomplete GC.");
            foreach (ClrObject obj in _clrRuntime!.Heap.EnumerateObjects())
            {
                if (obj.IsFree || !obj.IsValid)
                    continue;
                ClrType? type = obj.Type;
                if (type != null && type.MetadataToken == typeToken && type.Module.Address == moduleAddress)
                    yield return obj;
            }
        }

        public IEnumerable<ClrHandle> EnumerateGCHandles()
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.EnumerateHandles();
        }

        public ClrObject? GetObjectForAddress(ulong address, bool throwOnInconsistentHeap = false)
        {
            EnsureClrRuntimeInitializedOrThrow();
            if (throwOnInconsistentHeap && !_clrRuntime!.Heap.CanWalkHeap)
                throw new InvalidOperationException("Heap is in an inconsistent state and cannot be walked. This may indicate corruption or an incomplete GC.");
            ClrSegment? segment = _clrRuntime!.Heap.GetSegmentByAddress(address);
            if (segment == null)
                return null;
            ulong newAddress = ClrExtensions.GetValidObjectForAddress(segment, address, false);
            if (newAddress == 0)
                return null;
            return _clrRuntime.Heap.GetObject(newAddress);
        }

        public ClrModule GetBaseClassModule()
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.BaseClassLibrary;
        }

        public ClrAppDomain? GetAppDomainByAddress(ulong address)
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.GetAppDomainByAddress(address);
        }

        public ClrMethod? GetMethodByInstructionPointer(ulong ip)
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.GetMethodByInstructionPointer(ip);
        }

        public ClrType? ClrTypeFromElementType(ClrElementType elementType, uint specialType = 0)
        {
            EnsureClrRuntimeInitializedOrThrow();
            return ClrExtensions.GetClrTypeFromElementType(_clrRuntime!, elementType, specialType);
        }

        public IEnumerable<ClrThread> EnumerateThreads()
        {
            EnsureClrRuntimeInitializedOrThrow();
            return _clrRuntime!.Threads;
        }

        public string? DumpModule(ClrModule module, string outputFile)
        {
            EnsureClrRuntimeInitializedOrThrow();
            if (module.IsDynamic) 
                return "Module can't be dynamic!";
            IntPtr hProcess = IntPtr.Zero;
            try
            {
                hProcess = NativeMethods.OpenProcess(NativeMethods.PROCESS_VM_READ | NativeMethods.PROCESS_QUERY_INFORMATION, false, _processId);
                if (hProcess == IntPtr.Zero)
                    return "Failed to open process";

                if (NativeMethods.VirtualQueryEx(hProcess, (nint)module.ImageBase, out NativeMethods.MEMORY_BASIC_INFORMATION mbi, (uint)Marshal.SizeOf<NativeMethods.MEMORY_BASIC_INFORMATION>()) == 0)
                    return "Failed to query Memory!";

                byte[] buffer = new byte[module.Size];

                ulong readableSize = Math.Min(module.Size, (ulong)mbi.RegionSize);

                if (!NativeMethods.ReadProcessMemory(hProcess, (nint)module.ImageBase, buffer, (int)readableSize, out IntPtr bytesRead) || bytesRead == 0)
                    return "Failed to read memory";

                File.WriteAllBytes(outputFile, buffer);
                return null;
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
            finally
            {
                if (hProcess != IntPtr.Zero)
                    NativeMethods.CloseHandle(hProcess);
            }
        }

        //public void Test()
        //{
        //}

        ~ClrMDInspector()
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
            _dataTarget?.Dispose();
            _clrRuntime?.Dispose();
        }
    }
}
