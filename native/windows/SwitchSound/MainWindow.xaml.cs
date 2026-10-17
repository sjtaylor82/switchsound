using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using Forms = System.Windows.Forms;

namespace SwitchSound;

public partial class MainWindow : Window
{
    private const int HotkeyId = 0x5353;
    private const int WmHotkey = 0x0312;
    private const uint ModControl = 0x0002;
    private const uint VkOem5 = 0xDC;
    private IReadOnlyList<AudioDevice> devices = Array.Empty<AudioDevice>();
    private string selectedDeviceId = SettingsStore.Load();
    private readonly Forms.NotifyIcon trayIcon;
    private bool reallyClosing;
    private HwndSource? hwndSource;

    public MainWindow()
    {
        InitializeComponent();
        trayIcon = new Forms.NotifyIcon
        {
            Icon = System.Drawing.SystemIcons.Application,
            Text = "SwitchSound — Control plus backslash switches output",
            Visible = true,
            ContextMenuStrip = BuildTrayMenu()
        };
        trayIcon.DoubleClick += (_, _) => ToggleWindow();
        Loaded += (_, _) => RefreshDevices();
        SourceInitialized += OnSourceInitialized;
        StateChanged += (_, _) => { if (WindowState == WindowState.Minimized) HideWindow(); };
        Closing += OnClosing;
        OutputBox.SelectionChanged += (_, _) => SaveSelection();
    }

    private Forms.ContextMenuStrip BuildTrayMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Show or hide", null, (_, _) => Dispatcher.Invoke(ToggleWindow));
        menu.Items.Add("Switch to next output", null, (_, _) => Dispatcher.Invoke(CycleOutput));
        menu.Items.Add("Use selected output", null, (_, _) => Dispatcher.Invoke(UseSelectedOutput));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Dispatcher.Invoke(Quit));
        return menu;
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var handle = new WindowInteropHelper(this).Handle;
        hwndSource = HwndSource.FromHwnd(handle);
        hwndSource.AddHook(WindowProcedure);
        RegisterHotKey(handle, HotkeyId, ModControl, VkOem5);
    }

    private IntPtr WindowProcedure(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WmHotkey && wParam.ToInt32() == HotkeyId)
        {
            CycleOutput();
            handled = true;
        }
        return IntPtr.Zero;
    }

    private void RefreshDevices()
    {
        try
        {
            devices = CoreAudio.ListOutputs();
            OutputBox.ItemsSource = devices;
            var current = devices.FirstOrDefault(item => item.IsDefault);
            OutputBox.SelectedItem = current ?? devices.FirstOrDefault(item => item.Id == selectedDeviceId)
                ?? devices.FirstOrDefault();
            SetStatus($"Current output: {current?.Name ?? "Unknown"}");
            OutputBox.Focus();
        }
        catch (Exception error) { SetStatus($"Could not read audio outputs: {error.Message}", true); }
    }

    private void UseSelectedOutput()
    {
        if (OutputBox.SelectedItem is not AudioDevice target)
        {
            SetStatus("Choose an audio output first.", true);
            return;
        }
        try { SwitchTo(target); }
        catch (Exception error) { SetStatus($"Could not switch output: {error.Message}", true); }
    }

    private void CycleOutput()
    {
        try
        {
            devices = CoreAudio.ListOutputs();
            if (devices.Count == 0) { SetStatus("No audio outputs are available.", true); return; }
            var currentIndex = devices.ToList().FindIndex(item => item.IsDefault);
            var target = devices[(currentIndex + 1) % devices.Count];
            SwitchTo(target);
        }
        catch (Exception error) { SetStatus($"Could not switch output: {error.Message}", true); }
    }

    private void SwitchTo(AudioDevice target)
    {
        CoreAudio.SetDefault(target.Id);
        System.Threading.Thread.Sleep(150);
        devices = CoreAudio.ListOutputs();
        var confirmed = devices.FirstOrDefault(item => item.IsDefault);
        if (confirmed?.Id != target.Id)
            throw new InvalidOperationException($"Windows kept using {confirmed?.Name ?? "an unknown output"}.");
        selectedDeviceId = target.Id;
        SettingsStore.Save(selectedDeviceId);
        OutputBox.ItemsSource = devices;
        OutputBox.SelectedItem = confirmed;
        SetStatus($"Current output: {confirmed.Name}");
        trayIcon.BalloonTipTitle = "SwitchSound";
        trayIcon.BalloonTipText = $"Output: {confirmed.Name}";
        trayIcon.ShowBalloonTip(1500);
    }

    private void SaveSelection()
    {
        if (OutputBox.SelectedItem is AudioDevice selected)
        {
            selectedDeviceId = selected.Id;
            try { SettingsStore.Save(selectedDeviceId); }
            catch (Exception error) { SetStatus($"Could not save selection: {error.Message}", true); }
        }
    }

    private void SetStatus(string message, bool error = false)
    {
        StatusText.Text = message;
        StatusText.Foreground = error
            ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(253, 186, 116))
            : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(209, 213, 219));
    }

    private void ToggleWindow() { if (IsVisible) HideWindow(); else ShowWindow(); }
    private void HideWindow() => Hide();
    private void ShowWindow() { Show(); WindowState = WindowState.Normal; Activate(); OutputBox.Focus(); }

    private void Quit()
    {
        reallyClosing = true;
        trayIcon.Visible = false;
        trayIcon.Dispose();
        Close();
        System.Windows.Application.Current.Shutdown();
    }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        if (!reallyClosing) { e.Cancel = true; HideWindow(); return; }
        UnregisterHotKey(new WindowInteropHelper(this).Handle, HotkeyId);
        hwndSource?.RemoveHook(WindowProcedure);
    }

    private void UseOutputButton_Click(object sender, RoutedEventArgs e) => UseSelectedOutput();
    private void RefreshButton_Click(object sender, RoutedEventArgs e) => RefreshDevices();
    private void ExitButton_Click(object sender, RoutedEventArgs e) => Quit();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint virtualKey);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr window, int id);
}
