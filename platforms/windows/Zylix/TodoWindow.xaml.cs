using System;
using Microsoft.UI.Xaml;
using Windows.UI.Text;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Input;
using Windows.System;

namespace Zylix;

/// <summary>
/// Converter: bool to TextDecorations (strikethrough for completed items)
/// </summary>
public class StrikethroughConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        return (bool)value ? TextDecorations.Strikethrough : TextDecorations.None;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
    {
        throw new NotImplementedException();
    }
}

/// <summary>
/// Converter: bool to opacity (0.5 for completed items)
/// </summary>
public class CompletedOpacityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        return (bool)value ? 0.5 : 1.0;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
    {
        throw new NotImplementedException();
    }
}

/// <summary>
/// Converter: bool to Visibility
/// </summary>
public class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        return (bool)value ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
    {
        throw new NotImplementedException();
    }
}

/// <summary>
/// Todo application window
/// </summary>
public sealed partial class TodoWindow : Window
{
    public TodoViewModel ViewModel { get; } = new();

    public TodoWindow()
    {
        this.InitializeComponent();
        Title = "Zylix Todo";

        // Set up resources for converters
        var resources = ((FrameworkElement)this.Content).Resources;
        resources["StrikethroughConverter"] = new StrikethroughConverter();
        resources["CompletedOpacityConverter"] = new CompletedOpacityConverter();
        resources["BoolToVisibilityConverter"] = new BoolToVisibilityConverter();

        // Set initial window size
        var appWindow = this.AppWindow;
        appWindow.Resize(new Windows.Graphics.SizeInt32(600, 700));

        // Update filter button styles
        UpdateFilterButtons();
        ViewModel.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(ViewModel.CurrentFilter))
            {
                UpdateFilterButtons();
            }
        };
    }

    private void UpdateFilterButtons()
    {
        // Reset all buttons
        FilterAllButton.Style = (Style)Application.Current.Resources["DefaultButtonStyle"];
        FilterActiveButton.Style = (Style)Application.Current.Resources["DefaultButtonStyle"];
        FilterCompletedButton.Style = (Style)Application.Current.Resources["DefaultButtonStyle"];

        // Highlight active filter
        var activeButton = ViewModel.CurrentFilter switch
        {
            TodoFilter.All => FilterAllButton,
            TodoFilter.Active => FilterActiveButton,
            TodoFilter.Completed => FilterCompletedButton,
            _ => FilterAllButton
        };
        activeButton.Style = (Style)Application.Current.Resources["AccentButtonStyle"];
    }

    private void AddTodo_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.AddTodo();
        NewTodoInput.Focus(FocusState.Programmatic);
    }

    private void NewTodoInput_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter && ViewModel.CanAddTodo)
        {
            ViewModel.AddTodo();
        }
    }

    private void ToggleAll_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.ToggleAll();
    }

    private void DeleteTodo_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is TodoItem item)
        {
            ViewModel.RemoveTodo(item);
        }
    }

    private void FilterAll_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.SetFilter(TodoFilter.All);
    }

    private void FilterActive_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.SetFilter(TodoFilter.Active);
    }

    private void FilterCompleted_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.SetFilter(TodoFilter.Completed);
    }

    private void ClearCompleted_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.ClearCompleted();
    }
}
