using System.Diagnostics;
using System.Runtime.ConstrainedExecution;
using System.Runtime.InteropServices;

namespace DotNetDataCollectorEx
{
    internal class ThreadSuspender : CriticalFinalizerObject, IDisposable
    {
        private readonly object _lock = new();
        private readonly int _pid;
        private volatile int[]? _suspendedThreads;

        public ThreadSuspender(int pid)
        {
            _pid = pid;
            SuspendThreads();
        }

        private int[] SuspendThreads()
        {
            bool permissionFailure = false;
            HashSet<int>? suspendedThreads = new();

            try
            {
                int originalCount;
                do
                {
                    originalCount = suspendedThreads.Count;

                    Process process;
                    try
                    {
                        process = Process.GetProcessById(_pid);
                    } catch (ArgumentException e)
                    {
                        throw new InvalidOperationException($"Unable to inspect process {_pid:x}.", e);
                    }
                    foreach (ProcessThread? thread in process.Threads)
                    {
                        if (thread != null)
                        {
                            if (suspendedThreads.Contains(thread.Id))
                                continue;

                            using SafeWin32Handle threadHandle = OpenThread(0x2, false, (uint)thread.Id);
                            if (threadHandle.IsInvalid || SuspendThread(threadHandle.DangerousGetHandle()) == -1)
                            {
                                permissionFailure = true;
                                continue;
                            }

                            suspendedThreads.Add(thread.Id);
                        }
                    }
                } while (originalCount != suspendedThreads.Count);

                if (permissionFailure && suspendedThreads.Count == 0)
                    throw new InvalidOperationException($"Unable to suspend threads of process {_pid:x}.");

                int[] result = suspendedThreads.ToArray();
                suspendedThreads = null;
                return result;
            }
            finally
            {
                if (suspendedThreads != null)
                    ResumeThreads(suspendedThreads);
            }
        }

        private void ResumeThreads(IEnumerable<int> suspendedThreads)
        {
            foreach (int threadId in suspendedThreads)
            {
                using SafeWin32Handle threadHandle = OpenThread(0x2, false, (uint)threadId);
                if (threadHandle.IsInvalid || ResumeThread(threadHandle.DangerousGetHandle()) == -1)
                {
                    Logger.LogFatal($"Failed to resume thread id:{threadId:id} in pid:{_pid:x}.");
                }
            }
        }

        ~ThreadSuspender() 
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
            lock (_lock)
            {
                if (_suspendedThreads != null)
                {
                    int[] suspendedThreads = _suspendedThreads;
                    _suspendedThreads = null;
                    ResumeThreads(suspendedThreads);
                }
            }
        }

        [DllImport("Kernel32.dll", SetLastError = true)]
        internal static extern SafeWin32Handle OpenThread(int dwDesiredAccess, [MarshalAs(UnmanagedType.Bool)] bool bInheritHandle, uint dwThreadId);

        [DllImport("Kernel32.dll", SetLastError = true)]
        internal static extern int SuspendThread(IntPtr hThread);

        [DllImport("Kernel32.dll", SetLastError = true)]
        internal static extern int ResumeThread(IntPtr hThread);
    }
}
