using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;

namespace DotNetDataCollectorEx
{
    internal static class PipeHelper
    {
        private static bool SafeWrite(PipeStream pipe, byte[] v)
        {
            try
            {
                pipe.Write(v);
                return true;
            }
            catch (Exception)
            {
                Logger.LogWarning("Pipe exception");
                return false;
            }
        }

        public static bool WriteByte(PipeStream pipe, byte v)
        {
            try
            {
                pipe.WriteByte(v);
                return true;
            }
            catch (Exception)
            {
                Logger.LogWarning("Pipe exception");
                return false;
            }
        }

        public static byte ReadByte(PipeStream pipe)
        {
            byte[] array = new byte[1];
            if (pipe.Read(array, 0, 1) == -1)
                throw new Exception("Error while reading from Pipe");
            return array[0];
        }

        public static bool WriteWord(PipeStream pipe, ushort v)
        {
            return SafeWrite(pipe, BitConverter.GetBytes(v));
        }

        public static ushort ReadWord(PipeStream pipe)
        {
            byte[] array = new byte[2];
            _ = pipe.Read(array, 0, 2);
            return BitConverter.ToUInt16(array, 0);
        }

        public static bool WriteDword(PipeStream pipe, uint v)
        {
            return SafeWrite(pipe, BitConverter.GetBytes(v));
        }

        public static uint ReadDword(PipeStream pipe)
        {
            byte[] array = new byte[4];
            _ = pipe.Read(array, 0, 4);
            return BitConverter.ToUInt32(array, 0);
        }

        public static bool WriteQword(PipeStream pipe, ulong v)
        {
            return SafeWrite(pipe, BitConverter.GetBytes(v));
        }

        public static ulong ReadQword(PipeStream pipe)
        {
            byte[] array = new byte[8];
            _ = pipe.Read(array, 0, 8);
            return BitConverter.ToUInt64(array, 0);
        }

        public static bool WriteUTF8String(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(str);
            return WriteDword(pipe, (uint)bytes.Length) && (bytes.Length == 0 || SafeWrite(pipe, bytes));
        }

        public static string ReadUTF8String(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.UTF8.GetString(bytes);
        }

        public static bool WriteUTF16String(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.Unicode.GetBytes(str);
            return WriteDword(pipe, (uint)bytes.Length) && (bytes.Length == 0 || SafeWrite(pipe, bytes));
        }

        public static string ReadUTF16String(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            //Logger.LogInfo($"String length: {length}");
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.Unicode.GetString(bytes);
        }

        public static bool WriteASCIIString(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(str);
            return WriteDword(pipe, (uint)bytes.Length) && (bytes.Length == 0 || SafeWrite(pipe, bytes));
        }

        public static string ReadASCIIString(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            if (length == 0)
                return string.Empty;
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.ASCII.GetString(bytes);
        }

        public static bool WriteByteArray(PipeStream pipe, byte[] v)
        {
            bool result = WriteDword(pipe, (uint)v.Length);
            return result && SafeWrite(pipe, v);
        }

        public static byte[] ReadByteArray(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return bytes;
        }

        public static void WriteBool(PipeStream pipe, bool v)
        {
            pipe.WriteByte((byte)(v ? 1 : 0));
        }

        public static bool ReadBool(PipeStream pipe)
        {
            return pipe.ReadByte() != 0;
        }

        public static byte[] StructToBytes<T>(T data) where T : struct
        {
            return MemoryMarshal.AsBytes(MemoryMarshal.CreateSpan(ref data, 1)).ToArray();
        }

        public static T ByteArrayToStructure<T>(byte[] byteArray) where T : struct
        {
            return MemoryMarshal.Cast<byte, T>(new Span<byte>(byteArray))[0];
        }
    }
}
