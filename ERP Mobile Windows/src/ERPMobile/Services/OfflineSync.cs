using System.Net.NetworkInformation;
using Avalonia.Threading;

namespace ERPMobile.Services;

public static class OfflineSync
{
    public static event Action? Changed;

    private static AppSession? _session;
    private static DispatcherTimer? _timer;
    private static int _running;

    public static void Start(AppSession session)
    {
        _session = session;
        if (_timer != null)
            return;
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(15) };
        _timer.Tick += async (_, _) => await Flush();
        _timer.Start();
        NetworkChange.NetworkAddressChanged += (_, _) => Dispatcher.UIThread.Post(() => _ = Flush());
        NetworkChange.NetworkAvailabilityChanged += (_, _) => Dispatcher.UIThread.Post(() => _ = Flush());
    }

    public static async Task<bool> Flush()
    {
        if (_session == null)
            return false;
        if (Interlocked.CompareExchange(ref _running, 1, 0) != 0)
            return false;
        try
        {
            var items = OfflineOutbox.Load();
            if (items.Count == 0)
                return true;
            try
            {
                await _session.SelectRows("companies", "select=id&limit=1");
            }
            catch
            {
                return false;
            }

            var left = new List<OfflineItem>();
            foreach (var item in items)
            {
                try
                {
                    await _session.ReplayOutboxItem(item);
                }
                catch (Exception ex)
                {
                    item.Status = "failed";
                    item.Error = ex.Message;
                    left.Add(item);
                }
            }
            OfflineOutbox.Save(left);
            Changed?.Invoke();
            return true;
        }
        finally
        {
            Interlocked.Exchange(ref _running, 0);
        }
    }
}
