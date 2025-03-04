namespace DotNetDataCollectorEx
{
    internal class Program
    {
        private static PipeServer? pipeServer;

        private static string? pipeName;

        private static bool noLegacyDataCollector = false;

        private static void HandleArgs(string[] args)
        {
            for (int i = 0; i < args.Length; i++)
            {
                if (i == 0) // 1st arg should always be pipe name
                {
                    pipeName = args[i];
                    continue;
                }

                switch (args[i].ToLower().Trim())
                {
                    case "-nldc":
                        noLegacyDataCollector = true;
                        break;
                    default:
                        Logger.LogWarning($"Invalid args passed: '{args[i]}'");
                        break;
                }
            }
        }

        static void Main(string[] args)
        {
            string argstring = string.Empty;
            for (int i = 0; i < args.Length; i++)
            {
                if (i + 1 == args.Length)
                    argstring += args[i];
                else
                    argstring += $"{args[i]} | ";
            }
            Logger.LogInfo($"Args: '{argstring}'");
            //Console.WriteLine("Hello, World!");
            HandleArgs(args);

            if (string.IsNullOrEmpty(pipeName))
            {
                Logger.LogError("No Pipe Name!");
#if DEBUG
                Console.ReadLine();
#endif
                return;
            }
            Logger.LogInfo($"Pipe Name is: '{pipeName}'");

            AppDomain.CurrentDomain.UnhandledException += (sender, e) =>
            {
                Exception? ex = e.ExceptionObject as Exception;
                Logger.LogError("Uncaught Exception:");
                Logger.LogException(ex!);
                pipeServer?.legacyDotNetDataCollectorProcess?.Kill();
#if DEBUG
                Console.ReadLine();
#else
                Thread.Sleep(5000);
#endif
            };

            pipeServer = new PipeServer(pipeName, noLegacyDataCollector);

            pipeServer.RunLoop();

            pipeServer.legacyDotNetDataCollectorProcess?.Kill();

#if DEBUG
            Console.ReadLine();
#else
            Thread.Sleep(5000);
#endif
        }
    }
}
