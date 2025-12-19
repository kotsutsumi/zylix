using Microsoft.UI.Xaml;
using System.ComponentModel;

namespace Zylix;

/// <summary>
/// Main window for Zylix Counter application
/// </summary>
public sealed partial class MainWindow : Window
{
    private readonly ZylixBridge _bridge;

    public MainWindow()
    {
        this.InitializeComponent();

        // Set window size
        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);
        appWindow.Resize(new Windows.Graphics.SizeInt32(400, 500));

        // Initialize Zylix
        _bridge = ZylixBridge.Instance;
        _bridge.PropertyChanged += OnBridgePropertyChanged;

        if (_bridge.Initialize())
        {
            StatusText.Text = "Zylix Core initialized";
            UpdateCounter();
        }
        else
        {
            StatusText.Text = $"Error: {_bridge.LastError}";
        }
    }

    private void OnBridgePropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ZylixBridge.Counter))
        {
            DispatcherQueue.TryEnqueue(() => UpdateCounter());
        }
    }

    private void UpdateCounter()
    {
        CounterText.Text = _bridge.Counter.ToString();
    }

    private void OnIncrement(object sender, RoutedEventArgs e)
    {
        _bridge.Increment();
    }

    private void OnDecrement(object sender, RoutedEventArgs e)
    {
        _bridge.Decrement();
    }

    private void OnReset(object sender, RoutedEventArgs e)
    {
        _bridge.Reset();
    }
}
