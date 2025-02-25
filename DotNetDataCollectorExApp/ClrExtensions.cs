using Microsoft.Diagnostics.Runtime;
using System.Collections.Concurrent;

namespace DotNetDataCollectorEx
{
    public static class ClrExtensions
    {
        private static readonly ConcurrentDictionary<ClrElementType, ClrType> typeCache = new();

        public static void ClearClrElementTypeCache()
        {
            typeCache.Clear();
        }

        public static IEnumerable<ClrMethod> EnumerateMethods(ClrType clrType)
        {
            return clrType.Methods;
        }

        public static IEnumerable<ClrField> EnumerateAllFields(ClrType clrType)
        {
            foreach (ClrInstanceField field in clrType.Fields)
                yield return field;
            foreach (ClrStaticField staticField in clrType.StaticFields)
                yield return staticField;
        }

        public static IEnumerable<ClrInstanceField> EnumerateInstanceFields(ClrType clrType)
        {
            return clrType.Fields;
        }

        public static IEnumerable<ClrStaticField> EnumerateStaticFields(ClrType clrType)
        {
            return clrType.StaticFields;
        }

        public static IEnumerable<ClrStackFrame> EnumerateStackTrace(ClrThread thread, bool includeContext = false, int maxFrames = 8096)
        {
            return thread.EnumerateStackTrace(includeContext, maxFrames);
        }

        public static ulong GetValidObjectForAddress(ClrSegment segment, ulong address, bool previous = false)
        {
            if (segment.FirstObjectAddress == 0)
                return 0;
            if (address == segment.FirstObjectAddress)
                return segment.FirstObjectAddress;

            ulong lastValidObject = segment.FirstObjectAddress;

            foreach (ClrObject obj in segment.EnumerateObjects())
            {
                if (obj.Address == address)
                    return obj.Address;
                if (previous)
                {
                    if (obj.Address < address)
                        lastValidObject = obj.Address;
                    else
                        break;
                }
                else
                {
                    if (obj.Address <= address)
                        lastValidObject = obj.Address;
                    else
                        break;
                }
            }

            return lastValidObject;
        }

        public static ClrType? GetClrTypeFromElementType(ClrRuntime runtime, ClrElementType elementType, uint specialType = 0)
        {
            switch (specialType)
            {
                case 1:
                    return runtime.Heap.FreeType;
                case 2:
                    return runtime.Heap.ExceptionType;
                default:
                    break;
            }

            if (typeCache.TryGetValue(elementType, out ClrType? result))
            {
                return result;
            }

            switch (elementType)
            {
                case ClrElementType.Object or ClrElementType.Class:
                    return runtime.Heap.ObjectType;
                case ClrElementType.String:
                    return runtime.Heap.StringType;
            }

            string? typeName = elementType switch
            {
                // Primitive types
                ClrElementType.Boolean => "System.Boolean",
                ClrElementType.Char => "System.Char",
                ClrElementType.Int8 => "System.SByte",
                ClrElementType.UInt8 => "System.Byte",
                ClrElementType.Int16 => "System.Int16",
                ClrElementType.UInt16 => "System.UInt16",
                ClrElementType.Int32 => "System.Int32",
                ClrElementType.UInt32 => "System.UInt32",
                ClrElementType.Int64 => "System.Int64",
                ClrElementType.UInt64 => "System.UInt64",
                ClrElementType.Float => "System.Single",
                ClrElementType.Double => "System.Double",
                //ClrElementType.String => "System.String",
                //ClrElementType.Object => "System.Object",
                //ClrElementType.Class => "System.Object",  // Generic class type
                ClrElementType.NativeInt => "System.IntPtr",
                ClrElementType.NativeUInt => "System.UIntPtr",
                ClrElementType.FunctionPointer => "System.IntPtr",
                ClrElementType.Struct => "System.ValueType",
                _ => null
            };
            if (typeName == null)
                return null;

            result = runtime.Heap.GetTypeByName(typeName);
            if (result != null)
                typeCache.TryAdd(elementType, result);

            return result;
        }
    }
}
