namespace DotNetDataCollectorEx
{
    public static class Logger
    {
        private enum LogSeverity
        {
            Info,
            Warning,
            Error,
            Fatal,
            Exception
        }

        private static void DoLog(string message, LogSeverity logSeverity)
        {
            Console.WriteLine($"{DateTime.Now} {message}");
        }

        public static void LogInfo(string message)
        {
            DoLog($"[INFO] {message}", LogSeverity.Info);
        }

        public static void LogWarning(string message)
        {
            DoLog($"[WARNING] {message}", LogSeverity.Warning);
        }

        public static void LogError(string message)
        {
            DoLog($"[ERROR] {message}", LogSeverity.Error);
        }

        public static void LogFatal(string message)
        {
            DoLog($"[FATAL] {message}", LogSeverity.Fatal);
        }

        public static void LogException(Exception ex)
        {
            DoLog($"[EXCEPTION] {ex.Message}\nStackTrace: {ex.StackTrace}", LogSeverity.Exception);
        }
    }
}
