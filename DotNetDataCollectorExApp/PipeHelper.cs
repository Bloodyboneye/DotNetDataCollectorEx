using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;

namespace DotNetDataCollectorEx
{
    internal static class PipeHelper
    {
        public static void WriteByte(PipeStream pipe, byte v)
        {
            pipe.WriteByte(v);
        }

        public static byte ReadByte(PipeStream pipe)
        {
            byte[] array = new byte[1];
            if (pipe.Read(array, 0, 1) == -1)
                throw new Exception("Error while reading from Pipe");
            return array[0];
        }

        public static void WriteWord(PipeStream pipe, ushort v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 2);
        }

        public static ushort ReadWord(PipeStream pipe)
        {
            byte[] array = new byte[2];
            _ = pipe.Read(array, 0, 2);
            return BitConverter.ToUInt16(array, 0);
        }

        public static void WriteDword(PipeStream pipe, uint v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 4);
        }

        public static uint ReadDword(PipeStream pipe)
        {
            byte[] array = new byte[4];
            _ = pipe.Read(array, 0, 4);
            return BitConverter.ToUInt32(array, 0);
        }

        public static void WriteQword(PipeStream pipe, ulong v)
        {
            pipe.Write(BitConverter.GetBytes(v), 0, 8);
        }

        public static ulong ReadQword(PipeStream pipe)
        {
            byte[] array = new byte[8];
            _ = pipe.Read(array, 0, 8);
            return BitConverter.ToUInt64(array, 0);
        }

        public static void WriteUTF8String(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(str);
            WriteDword(pipe, (uint)bytes.Length);
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
        }

        public static string ReadUTF8String(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.UTF8.GetString(bytes);
        }

        public static void WriteUTF16String(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.Unicode.GetBytes(str);
            WriteDword(pipe, (uint)bytes.Length);
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
        }

        public static string ReadUTF16String(PipeStream pipe)
        {
            int length = (int)ReadDword(pipe);
            byte[] bytes = new byte[length];
            _ = pipe.Read(bytes, 0, length);
            return Encoding.Unicode.GetString(bytes);
        }

        public static void WriteASCIIString(PipeStream pipe, string str)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(str);
            WriteDword(pipe, (uint)bytes.Length);
            if (bytes.Length > 0)
                pipe.Write(bytes, 0, bytes.Length);
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

        public static void WriteByteArray(PipeStream pipe, byte[] v)
        {
            WriteDword(pipe, (uint)v.Length);
            pipe.Write(v, 0, v.Length);
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
