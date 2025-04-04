﻿using Microsoft.Diagnostics.Runtime;
using System;
using System.Text;
using System.Buffers;

namespace DotNetDataCollectorEx
{
    public static class MethodSignatureParser
    {
        private static readonly SearchValues<char> s_invalidCharsNSC = SearchValues.Create("@#$%^&*()-=/\\,;:[]{}|?");
        private static readonly SearchValues<char> s_invalidCharsMethod = SearchValues.Create("@#$%^&*()-+=/\\,;:[]{}|?");

        public enum CPlusTypeFlag
        {
            ELEMENT_TYPE_NONE = 0x00,
            ELEMENT_TYPE_VOID = 0x01,
            ELEMENT_TYPE_BOOLEAN = 0x02,
            ELEMENT_TYPE_CHAR = 0x03,
            ELEMENT_TYPE_I1 = 0x04,
            ELEMENT_TYPE_U1 = 0x05,
            ELEMENT_TYPE_I2 = 0x06,
            ELEMENT_TYPE_U2 = 0x07,
            ELEMENT_TYPE_I4 = 0x08,
            ELEMENT_TYPE_U4 = 0x09,
            ELEMENT_TYPE_I8 = 0x0A,
            ELEMENT_TYPE_U8 = 0x0B,
            ELEMENT_TYPE_R4 = 0x0C,
            ELEMENT_TYPE_R8 = 0x0D,
            ELEMENT_TYPE_STRING = 0x0E,
            ELEMENT_TYPE_PTR = 0x0F,
            ELEMENT_TYPE_BYREF = 0x10,
            ELEMENT_TYPE_VALUETYPE = 0x11,
            ELEMENT_TYPE_CLASS = 0x12,
            ELEMENT_TYPE_VAR = 0x13,
            ELEMENT_TYPE_ARRAY = 0x14,
            ELEMENT_TYPE_GENERICINST = 0x15,
            ELEMENT_TYPE_TYPEDBYREF = 0x16,
            ELEMENT_TYPE_I = 0x18,
            ELEMENT_TYPE_U = 0x19,
            ELEMENT_TYPE_FNPTR = 0x1B,
            ELEMENT_TYPE_OBJECT = 0x1C,
            ELEMENT_TYPE_SZARRAY = 0x1D,
            ELEMENT_TYPE_MVAR = 0x1E,
        }

        public static CPlusTypeFlag MapTypeToCPlusTypeFlag(string type)
        {
            return (type.StartsWith("System.") ? type[7..] : type) switch
            {
                "Void" => CPlusTypeFlag.ELEMENT_TYPE_VOID,
                "Boolean" => CPlusTypeFlag.ELEMENT_TYPE_BOOLEAN,
                "Char" => CPlusTypeFlag.ELEMENT_TYPE_CHAR,
                "SByte" => CPlusTypeFlag.ELEMENT_TYPE_I1,
                "Byte" => CPlusTypeFlag.ELEMENT_TYPE_U1,
                "Int16" => CPlusTypeFlag.ELEMENT_TYPE_I2,
                "UInt16" => CPlusTypeFlag.ELEMENT_TYPE_U2,
                "Int32" => CPlusTypeFlag.ELEMENT_TYPE_I4,
                "UInt32" => CPlusTypeFlag.ELEMENT_TYPE_U4,
                "Int64" => CPlusTypeFlag.ELEMENT_TYPE_I8,
                "UInt64" => CPlusTypeFlag.ELEMENT_TYPE_U8,
                "Single" => CPlusTypeFlag.ELEMENT_TYPE_R4,
                "Double" => CPlusTypeFlag.ELEMENT_TYPE_R8,
                "String" => CPlusTypeFlag.ELEMENT_TYPE_STRING,
                "Object" => CPlusTypeFlag.ELEMENT_TYPE_OBJECT,
                _ => CPlusTypeFlag.ELEMENT_TYPE_OBJECT,
            };
        }

        public static List<(string paramName, CPlusTypeFlag cPlusTypeFlag)> ParseSignature(string signature)
        {
            // Extract the parameter section
            int startIdx = signature.IndexOf('(');
            int endIdx = signature.IndexOf(')');

            if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx)
            {
                return [];
            }

            string parametersPart = signature.Substring(startIdx + 1, endIdx - startIdx - 1);

            // Split parameters by comma, and trim whitespace
            List<string> parameters = [.. parametersPart.Split([','], StringSplitOptions.RemoveEmptyEntries).Select(param => param.Trim())];

            // List to hold parsed parameters and their CPlusTypeFlags
            List<(string paramName, CPlusTypeFlag cPlusTypeFlag)> parsedParams = [];

            foreach (string param in parameters)
            {
                CPlusTypeFlag typeFlag = CPlusTypeFlag.ELEMENT_TYPE_NONE;
                string typeName = param;
                // Check for Array types
                if (param.EndsWith("[]"))
                    typeFlag |= CPlusTypeFlag.ELEMENT_TYPE_SZARRAY;
                else if (param.Contains(','))
                    typeFlag |= CPlusTypeFlag.ELEMENT_TYPE_ARRAY;
                if (param.EndsWith('*'))
                    typeFlag |= CPlusTypeFlag.ELEMENT_TYPE_PTR;
                if (param.Contains('<'))
                    typeFlag |= CPlusTypeFlag.ELEMENT_TYPE_GENERICINST;
                // Handle 'ref' or 'out' modifiers
                if (param.StartsWith("ref ") || param.StartsWith("out "))
                {
                    typeFlag |= CPlusTypeFlag.ELEMENT_TYPE_BYREF;
                    typeName = param[4..].Trim(); // Remove 'ref' / 'out' and get the type name
                }
                parsedParams.Add((typeName, typeFlag | MapTypeToCPlusTypeFlag(typeName)));
            }

            return parsedParams;
        }

        public static string[] MethodSignatureGetParameters(string methodSignature)
        {
            int startIdx = methodSignature.IndexOf('(');
            int endIdx = methodSignature.IndexOf(')');

            if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx)
            {
                return [];
            }

            string parametersPart = methodSignature.Substring(startIdx + 1, endIdx - startIdx - 1);

            string[] parameters = parametersPart.Split([','], StringSplitOptions.RemoveEmptyEntries);

            for (int i = 0; i < parameters.Length; i++)
            {
                parameters[i] = parameters[i].Trim();
            }

            return parameters;
        }

        public static string MethodSignatureGetFullTypeName(string? methodSignature)
        {
            if (string.IsNullOrEmpty(methodSignature))
                return "";

            // Find the last '(' in the signature to mark the start of parameters
            int lastParenIndex = methodSignature.IndexOf('(');
            if (lastParenIndex == -1)
                lastParenIndex = methodSignature.Length;

            // Find the last dot or colon before the parameter list (or the end of the string)
            int lastSeparatorIndex = methodSignature.LastIndexOfAny(['.', ':'], lastParenIndex - 1);

            if (lastSeparatorIndex == -1)
                return "";

            string fullTypeName = methodSignature[..lastSeparatorIndex];

            // Remove trailing period if it's from a constructor or static constructor / remove trailing colon if the signature uses those
            if (fullTypeName.EndsWith('.') || fullTypeName.EndsWith(':'))
            {
                fullTypeName = fullTypeName[..^1];
            }

            return fullTypeName;
        }

        public static bool AreMethodSignaturesEqual(string signature1, string signature2, bool caseSensitive)
        {
            if (string.IsNullOrEmpty(signature1) || string.IsNullOrEmpty(signature2))
                return false;

            return signature1.Equals(signature2, caseSensitive ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase) || (caseSensitive
                ? NormalizeMethodSignature(signature1).Equals(NormalizeMethodSignature(signature2))
                : NormalizeMethodSignature(signature1).Equals(NormalizeMethodSignature(signature2), StringComparison.OrdinalIgnoreCase));
        }

        public static bool IsValidNamespaceClassName(ReadOnlySpan<char> input)
        {
            if (input.IsEmpty || input[0] == '.' || input[^1] == '.')
                return false;

            if (input.IndexOfAny(s_invalidCharsNSC) >= 0)
                return false;

            bool expectStart = true;
            bool insideCompilerGenerated = false;

            foreach (char c in input)
            {
                if (c == '.' || c == '+') // Allow nested types (e.g., "Namespace.Class+NestedClass")
                {
                    expectStart = true;
                    insideCompilerGenerated = false; // Reset if a new part starts
                }
                else if (expectStart)
                {
                    if (!char.IsLetter(c) && c != '_' && c != '<') 
                        return false;
                    expectStart = false;

                    if (c == '<')
                        insideCompilerGenerated = true;
                }
                else
                {
                    if (!char.IsLetterOrDigit(c) && c != '_')
                    {
                        if (c == '>' && insideCompilerGenerated)
                            insideCompilerGenerated = false;
                        else 
                            return false;
                    }
                }
            }

            return !expectStart && !insideCompilerGenerated; // Ensure it doesn't end with '.' or '+'
        }

        public static bool IsValidMethodName(ReadOnlySpan<char> input)
        {
            if (input.IsEmpty)
                return false;

            if (input.IndexOfAny(s_invalidCharsMethod) >= 0)
                return false;

            // Method names can start with a letter, underscore, '.'(constructor) or '<' (compiler-generated)
            char first = input[0];
            if (!char.IsLetter(first) && first != '_' && first != '.' && first != '<')
                return false;

            // Remaining characters can be letters, digits, or underscores or `<>` for compiler-generated names
            for (int i = 1; i < input.Length; i++)
            {
                char c = input[i];
                if (!char.IsLetterOrDigit(c) && c != '_' && c != '<' && c != '>')
                    return false;
            }

            return true;
        }

        private static string NormalizeMethodSignature(string signature)
        {
            signature = signature.Trim();

            // Replace colons with dots for consistency
            signature = signature.Replace(":", ".");

            // Manually remove spaces around commas and parentheses
            StringBuilder normalizedSignature = new();
            bool insideParenthesis = false;

            for (int i = 0; i < signature.Length; i++)
            {
                char currentChar = signature[i];

                // Detect and handle parentheses to determine when we're inside them
                if (currentChar == '(')
                {
                    insideParenthesis = true;
                }
                else if (currentChar == ')')
                {
                    insideParenthesis = false;
                }

                // Skip spaces if we're not inside parentheses or if it's not between commas/parentheses
                if (currentChar != ' ' || insideParenthesis || (i > 0 && signature[i - 1] == ',' && currentChar == ' '))
                {
                    normalizedSignature.Append(currentChar);
                }
            }

            return normalizedSignature.ToString();
        }
    }
}
