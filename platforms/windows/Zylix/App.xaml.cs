using Microsoft.UI.Xaml;

namespace Zylix;

/// <summary>
/// Application entry point
/// </summary>
public partial class App : Application
{
    private Window? _window;

    public App()
    {
        this.InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Launch Todo app (use MainWindow for Counter demo)
        _window = new TodoWindow();
        _window.Activate();
    }
}
