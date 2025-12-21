using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Microsoft.UI;
using Windows.UI;

namespace Zylix;

/// <summary>
/// Component type enum matching Zig's ComponentType.
/// Must stay in sync with core/src/component.zig
/// </summary>
public enum ZylixComponentType : byte
{
    // Basic Components (0-9)
    Container = 0,
    Text = 1,
    Button = 2,
    Input = 3,
    Image = 4,
    Link = 5,
    List = 6,
    ListItem = 7,
    Heading = 8,
    Paragraph = 9,

    // Form Components (10-20)
    Select = 10,
    Checkbox = 11,
    Radio = 12,
    Textarea = 13,
    ToggleSwitch = 14,
    Slider = 15,
    DatePicker = 16,
    TimePicker = 17,
    FileInput = 18,
    ColorPicker = 19,
    Form = 20,

    // Layout Components (21-28)
    Stack = 21,
    Grid = 22,
    ScrollView = 23,
    Spacer = 24,
    Divider = 25,
    Card = 26,
    AspectRatio = 27,
    SafeArea = 28,

    // Navigation Components (30-34)
    NavBar = 30,
    TabBar = 31,
    Drawer = 32,
    Breadcrumb = 33,
    Pagination = 34,

    // Feedback Components (40-46)
    Alert = 40,
    Toast = 41,
    Modal = 42,
    Progress = 43,
    Spinner = 44,
    Skeleton = 45,
    Badge = 46,

    // Data Display Components (50-56)
    Table = 50,
    Avatar = 51,
    Icon = 52,
    Tag = 53,
    Tooltip = 54,
    Accordion = 55,
    Carousel = 56,

    Custom = 255
}

/// <summary>
/// Component category for grouping.
/// </summary>
public enum ComponentCategory
{
    Basic,
    Form,
    Layout,
    Navigation,
    Feedback,
    DataDisplay,
    Custom
}

/// <summary>
/// Stack direction enum.
/// </summary>
public enum ZylixStackDirection : byte
{
    Vertical = 0,
    Horizontal = 1,
    ZStack = 2
}

/// <summary>
/// Stack alignment enum.
/// </summary>
public enum ZylixStackAlignment : byte
{
    Start = 0,
    Center = 1,
    End = 2,
    Stretch = 3,
    SpaceBetween = 4,
    SpaceAround = 5,
    SpaceEvenly = 6
}

/// <summary>
/// Progress style enum.
/// </summary>
public enum ZylixProgressStyle : byte
{
    Linear = 0,
    Circular = 1,
    Indeterminate = 2
}

/// <summary>
/// Alert style enum.
/// </summary>
public enum ZylixAlertStyle : byte
{
    Info = 0,
    Success = 1,
    Warning = 2,
    Error = 3
}

/// <summary>
/// Toast position enum.
/// </summary>
public enum ZylixToastPosition : byte
{
    Top = 0,
    Bottom = 1,
    TopLeft = 2,
    TopRight = 3,
    BottomLeft = 4,
    BottomRight = 5
}

/// <summary>
/// Component properties.
/// </summary>
public class ZylixComponentProps
{
    public uint Id { get; set; } = 0;
    public ZylixComponentType ComponentType { get; set; } = ZylixComponentType.Container;
    public string Text { get; set; } = "";
    public bool IsDisabled { get; set; } = false;
    public bool IsVisible { get; set; } = true;

    // Layout
    public double? Width { get; set; }
    public double? Height { get; set; }
    public double Padding { get; set; } = 0;
    public double Margin { get; set; } = 0;

    // Stack
    public ZylixStackDirection StackDirection { get; set; } = ZylixStackDirection.Vertical;
    public ZylixStackAlignment StackAlignment { get; set; } = ZylixStackAlignment.Start;
    public double StackSpacing { get; set; } = 0;

    // Form
    public string Placeholder { get; set; } = "";
    public bool IsChecked { get; set; } = false;
    public double Value { get; set; } = 0;
    public double MinValue { get; set; } = 0;
    public double MaxValue { get; set; } = 100;

    // Progress/Feedback
    public ZylixProgressStyle ProgressStyle { get; set; } = ZylixProgressStyle.Linear;
    public double ProgressValue { get; set; } = 0;
    public ZylixAlertStyle AlertStyle { get; set; } = ZylixAlertStyle.Info;
    public ZylixToastPosition ToastPosition { get; set; } = ZylixToastPosition.Bottom;
    public int ToastDuration { get; set; } = 3000;

    // Heading
    public int HeadingLevel { get; set; } = 1;
}

/// <summary>
/// Extension methods for component types.
/// </summary>
public static class ZylixComponentTypeExtensions
{
    public static string GetDisplayName(this ZylixComponentType type)
    {
        return type switch
        {
            ZylixComponentType.Container => "Container",
            ZylixComponentType.Text => "Text",
            ZylixComponentType.Button => "Button",
            ZylixComponentType.Input => "Input",
            ZylixComponentType.Image => "Image",
            ZylixComponentType.Link => "Link",
            ZylixComponentType.List => "List",
            ZylixComponentType.ListItem => "List Item",
            ZylixComponentType.Heading => "Heading",
            ZylixComponentType.Paragraph => "Paragraph",
            ZylixComponentType.Select => "Select",
            ZylixComponentType.Checkbox => "Checkbox",
            ZylixComponentType.Radio => "Radio",
            ZylixComponentType.Textarea => "Textarea",
            ZylixComponentType.ToggleSwitch => "Toggle Switch",
            ZylixComponentType.Slider => "Slider",
            ZylixComponentType.DatePicker => "Date Picker",
            ZylixComponentType.TimePicker => "Time Picker",
            ZylixComponentType.FileInput => "File Input",
            ZylixComponentType.ColorPicker => "Color Picker",
            ZylixComponentType.Form => "Form",
            ZylixComponentType.Stack => "Stack",
            ZylixComponentType.Grid => "Grid",
            ZylixComponentType.ScrollView => "Scroll View",
            ZylixComponentType.Spacer => "Spacer",
            ZylixComponentType.Divider => "Divider",
            ZylixComponentType.Card => "Card",
            ZylixComponentType.AspectRatio => "Aspect Ratio",
            ZylixComponentType.SafeArea => "Safe Area",
            ZylixComponentType.NavBar => "Nav Bar",
            ZylixComponentType.TabBar => "Tab Bar",
            ZylixComponentType.Drawer => "Drawer",
            ZylixComponentType.Breadcrumb => "Breadcrumb",
            ZylixComponentType.Pagination => "Pagination",
            ZylixComponentType.Alert => "Alert",
            ZylixComponentType.Toast => "Toast",
            ZylixComponentType.Modal => "Modal",
            ZylixComponentType.Progress => "Progress",
            ZylixComponentType.Spinner => "Spinner",
            ZylixComponentType.Skeleton => "Skeleton",
            ZylixComponentType.Badge => "Badge",
            ZylixComponentType.Table => "Table",
            ZylixComponentType.Avatar => "Avatar",
            ZylixComponentType.Icon => "Icon",
            ZylixComponentType.Tag => "Tag",
            ZylixComponentType.Tooltip => "Tooltip",
            ZylixComponentType.Accordion => "Accordion",
            ZylixComponentType.Carousel => "Carousel",
            ZylixComponentType.Custom => "Custom",
            _ => type.ToString()
        };
    }

    public static ComponentCategory GetCategory(this ZylixComponentType type)
    {
        return (byte)type switch
        {
            >= 0 and <= 9 => ComponentCategory.Basic,
            >= 10 and <= 20 => ComponentCategory.Form,
            >= 21 and <= 28 => ComponentCategory.Layout,
            >= 30 and <= 34 => ComponentCategory.Navigation,
            >= 40 and <= 46 => ComponentCategory.Feedback,
            >= 50 and <= 56 => ComponentCategory.DataDisplay,
            _ => ComponentCategory.Custom
        };
    }

    public static Color GetAlertColor(this ZylixAlertStyle style)
    {
        return style switch
        {
            ZylixAlertStyle.Info => Colors.DodgerBlue,
            ZylixAlertStyle.Success => Colors.LimeGreen,
            ZylixAlertStyle.Warning => Colors.Orange,
            ZylixAlertStyle.Error => Colors.Red,
            _ => Colors.Gray
        };
    }

    public static Symbol GetAlertIcon(this ZylixAlertStyle style)
    {
        return style switch
        {
            ZylixAlertStyle.Info => Symbol.Help,
            ZylixAlertStyle.Success => Symbol.Accept,
            ZylixAlertStyle.Warning => Symbol.Important,
            ZylixAlertStyle.Error => Symbol.Cancel,
            _ => Symbol.Placeholder
        };
    }
}

/// <summary>
/// Factory for creating WinUI 3 elements from Zylix component types.
/// </summary>
public static class ZylixComponentFactory
{
    public static UIElement CreateElement(ZylixComponentProps props)
    {
        return props.ComponentType switch
        {
            // Basic Components
            ZylixComponentType.Container => CreateContainer(props),
            ZylixComponentType.Text => CreateText(props),
            ZylixComponentType.Button => CreateButton(props),
            ZylixComponentType.Input => CreateInput(props),
            ZylixComponentType.Image => CreateImage(props),
            ZylixComponentType.Link => CreateLink(props),
            ZylixComponentType.List => CreateList(props),
            ZylixComponentType.ListItem => CreateListItem(props),
            ZylixComponentType.Heading => CreateHeading(props),
            ZylixComponentType.Paragraph => CreateParagraph(props),

            // Form Components
            ZylixComponentType.Select => CreateSelect(props),
            ZylixComponentType.Checkbox => CreateCheckbox(props),
            ZylixComponentType.Radio => CreateRadio(props),
            ZylixComponentType.Textarea => CreateTextarea(props),
            ZylixComponentType.ToggleSwitch => CreateToggleSwitch(props),
            ZylixComponentType.Slider => CreateSlider(props),
            ZylixComponentType.DatePicker => CreateDatePicker(props),
            ZylixComponentType.TimePicker => CreateTimePicker(props),
            ZylixComponentType.ColorPicker => CreateColorPicker(props),
            ZylixComponentType.Form => CreateForm(props),

            // Layout Components
            ZylixComponentType.Stack => CreateStack(props),
            ZylixComponentType.Grid => CreateGrid(props),
            ZylixComponentType.ScrollView => CreateScrollView(props),
            ZylixComponentType.Spacer => CreateSpacer(props),
            ZylixComponentType.Divider => CreateDivider(props),
            ZylixComponentType.Card => CreateCard(props),

            // Navigation Components
            ZylixComponentType.NavBar => CreateNavBar(props),
            ZylixComponentType.TabBar => CreateTabBar(props),
            ZylixComponentType.Breadcrumb => CreateBreadcrumb(props),
            ZylixComponentType.Pagination => CreatePagination(props),

            // Feedback Components
            ZylixComponentType.Alert => CreateAlert(props),
            ZylixComponentType.Progress => CreateProgress(props),
            ZylixComponentType.Spinner => CreateSpinner(props),
            ZylixComponentType.Skeleton => CreateSkeleton(props),
            ZylixComponentType.Badge => CreateBadge(props),

            // Data Display Components
            ZylixComponentType.Avatar => CreateAvatar(props),
            ZylixComponentType.Icon => CreateIcon(props),
            ZylixComponentType.Tag => CreateTag(props),

            // Placeholder for unimplemented
            _ => CreatePlaceholder(props)
        };
    }

    // Basic Components
    private static UIElement CreateContainer(ZylixComponentProps props)
    {
        return new StackPanel
        {
            Padding = new Thickness(props.Padding)
        };
    }

    private static UIElement CreateText(ZylixComponentProps props)
    {
        return new TextBlock
        {
            Text = props.Text
        };
    }

    private static UIElement CreateButton(ZylixComponentProps props)
    {
        return new Microsoft.UI.Xaml.Controls.Button
        {
            Content = props.Text,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateInput(ZylixComponentProps props)
    {
        return new TextBox
        {
            PlaceholderText = props.Placeholder,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateImage(ZylixComponentProps props)
    {
        return new SymbolIcon
        {
            Symbol = Symbol.Pictures,
            Width = props.Width ?? 100,
            Height = props.Height ?? 100
        };
    }

    private static UIElement CreateLink(ZylixComponentProps props)
    {
        return new HyperlinkButton
        {
            Content = props.Text
        };
    }

    private static UIElement CreateList(ZylixComponentProps props)
    {
        return new ListView();
    }

    private static UIElement CreateListItem(ZylixComponentProps props)
    {
        return new TextBlock { Text = props.Text };
    }

    private static UIElement CreateHeading(ZylixComponentProps props)
    {
        var fontSize = props.HeadingLevel switch
        {
            1 => 32,
            2 => 28,
            3 => 24,
            4 => 20,
            5 => 18,
            _ => 16
        };

        return new TextBlock
        {
            Text = props.Text,
            FontSize = fontSize,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold
        };
    }

    private static UIElement CreateParagraph(ZylixComponentProps props)
    {
        return new TextBlock
        {
            Text = props.Text,
            TextWrapping = TextWrapping.Wrap
        };
    }

    // Form Components
    private static UIElement CreateSelect(ZylixComponentProps props)
    {
        var combo = new ComboBox
        {
            PlaceholderText = props.Placeholder,
            IsEnabled = !props.IsDisabled
        };
        combo.Items.Add("Option 1");
        combo.Items.Add("Option 2");
        combo.Items.Add("Option 3");
        return combo;
    }

    private static UIElement CreateCheckbox(ZylixComponentProps props)
    {
        return new CheckBox
        {
            Content = props.Text,
            IsChecked = props.IsChecked,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateRadio(ZylixComponentProps props)
    {
        return new RadioButton
        {
            Content = props.Text,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateTextarea(ZylixComponentProps props)
    {
        return new TextBox
        {
            PlaceholderText = props.Placeholder,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.Wrap,
            Height = 100,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateToggleSwitch(ZylixComponentProps props)
    {
        return new ToggleSwitch
        {
            Header = props.Text,
            IsOn = props.IsChecked,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateSlider(ZylixComponentProps props)
    {
        return new Microsoft.UI.Xaml.Controls.Slider
        {
            Minimum = props.MinValue,
            Maximum = props.MaxValue,
            Value = props.Value,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateDatePicker(ZylixComponentProps props)
    {
        return new DatePicker
        {
            Header = props.Text,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateTimePicker(ZylixComponentProps props)
    {
        return new TimePicker
        {
            Header = props.Text,
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateColorPicker(ZylixComponentProps props)
    {
        return new Microsoft.UI.Xaml.Controls.ColorPicker
        {
            IsEnabled = !props.IsDisabled
        };
    }

    private static UIElement CreateForm(ZylixComponentProps props)
    {
        return new StackPanel
        {
            Spacing = 16,
            Padding = new Thickness(16)
        };
    }

    // Layout Components
    private static UIElement CreateStack(ZylixComponentProps props)
    {
        return new StackPanel
        {
            Orientation = props.StackDirection == ZylixStackDirection.Horizontal
                ? Orientation.Horizontal
                : Orientation.Vertical,
            Spacing = props.StackSpacing
        };
    }

    private static UIElement CreateGrid(ZylixComponentProps props)
    {
        return new Microsoft.UI.Xaml.Controls.Grid();
    }

    private static UIElement CreateScrollView(ZylixComponentProps props)
    {
        return new ScrollViewer();
    }

    private static UIElement CreateSpacer(ZylixComponentProps props)
    {
        return new Border { Height = 16 };
    }

    private static UIElement CreateDivider(ZylixComponentProps props)
    {
        return new Border
        {
            Height = 1,
            Background = new SolidColorBrush(Colors.Gray),
            Margin = new Thickness(0, 8, 0, 8)
        };
    }

    private static UIElement CreateCard(ZylixComponentProps props)
    {
        return new Border
        {
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16),
            Background = new SolidColorBrush(Colors.White),
            Child = new TextBlock { Text = props.Text }
        };
    }

    // Navigation Components
    private static UIElement CreateNavBar(ZylixComponentProps props)
    {
        return new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Padding = new Thickness(16),
            Background = new SolidColorBrush(Colors.LightGray),
            Children =
            {
                new TextBlock
                {
                    Text = props.Text,
                    FontSize = 20,
                    FontWeight = Microsoft.UI.Text.FontWeights.Bold
                }
            }
        };
    }

    private static UIElement CreateTabBar(ZylixComponentProps props)
    {
        var pivot = new Pivot();
        pivot.Items.Add(new PivotItem { Header = "Tab 1" });
        pivot.Items.Add(new PivotItem { Header = "Tab 2" });
        pivot.Items.Add(new PivotItem { Header = "Tab 3" });
        return pivot;
    }

    private static UIElement CreateBreadcrumb(ZylixComponentProps props)
    {
        return new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 4,
            Children =
            {
                new HyperlinkButton { Content = "Home" },
                new TextBlock { Text = "/", VerticalAlignment = VerticalAlignment.Center },
                new HyperlinkButton { Content = "Category" },
                new TextBlock { Text = "/", VerticalAlignment = VerticalAlignment.Center },
                new TextBlock { Text = "Current", VerticalAlignment = VerticalAlignment.Center }
            }
        };
    }

    private static UIElement CreatePagination(ZylixComponentProps props)
    {
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 4
        };
        panel.Children.Add(new Microsoft.UI.Xaml.Controls.Button { Content = "<" });
        for (int i = 1; i <= 5; i++)
        {
            panel.Children.Add(new Microsoft.UI.Xaml.Controls.Button { Content = i.ToString() });
        }
        panel.Children.Add(new Microsoft.UI.Xaml.Controls.Button { Content = ">" });
        return panel;
    }

    // Feedback Components
    private static UIElement CreateAlert(ZylixComponentProps props)
    {
        var color = props.AlertStyle.GetAlertColor();
        return new Border
        {
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12),
            Background = new SolidColorBrush(Color.FromArgb(30, color.R, color.G, color.B)),
            Child = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 12,
                Children =
                {
                    new SymbolIcon { Symbol = props.AlertStyle.GetAlertIcon(), Foreground = new SolidColorBrush(color) },
                    new TextBlock { Text = props.Text, Foreground = new SolidColorBrush(color) }
                }
            }
        };
    }

    private static UIElement CreateProgress(ZylixComponentProps props)
    {
        return props.ProgressStyle switch
        {
            ZylixProgressStyle.Circular => new ProgressRing { Value = props.ProgressValue, IsIndeterminate = false },
            ZylixProgressStyle.Indeterminate => new ProgressRing { IsIndeterminate = true },
            _ => new ProgressBar { Value = props.ProgressValue, Maximum = 100 }
        };
    }

    private static UIElement CreateSpinner(ZylixComponentProps props)
    {
        return new ProgressRing { IsIndeterminate = true };
    }

    private static UIElement CreateSkeleton(ZylixComponentProps props)
    {
        return new Border
        {
            Height = 20,
            CornerRadius = new CornerRadius(4),
            Background = new SolidColorBrush(Color.FromArgb(50, 128, 128, 128))
        };
    }

    private static UIElement CreateBadge(ZylixComponentProps props)
    {
        return new Border
        {
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(8, 2, 8, 2),
            Background = new SolidColorBrush(Colors.DodgerBlue),
            Child = new TextBlock
            {
                Text = props.Text,
                Foreground = new SolidColorBrush(Colors.White),
                FontSize = 12,
                FontWeight = Microsoft.UI.Text.FontWeights.Bold
            }
        };
    }

    // Data Display Components
    private static UIElement CreateAvatar(ZylixComponentProps props)
    {
        var initial = string.IsNullOrEmpty(props.Text) ? "A" : props.Text[..1].ToUpper();
        return new Border
        {
            Width = 40,
            Height = 40,
            CornerRadius = new CornerRadius(20),
            Background = new LinearGradientBrush
            {
                StartPoint = new Windows.Foundation.Point(0, 0),
                EndPoint = new Windows.Foundation.Point(1, 1),
                GradientStops =
                {
                    new GradientStop { Color = Colors.DodgerBlue, Offset = 0 },
                    new GradientStop { Color = Colors.Purple, Offset = 1 }
                }
            },
            Child = new TextBlock
            {
                Text = initial,
                Foreground = new SolidColorBrush(Colors.White),
                FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        };
    }

    private static UIElement CreateIcon(ZylixComponentProps props)
    {
        return new SymbolIcon
        {
            Symbol = Symbol.Favorite,
            Width = 24,
            Height = 24
        };
    }

    private static UIElement CreateTag(ZylixComponentProps props)
    {
        return new Border
        {
            CornerRadius = new CornerRadius(16),
            Padding = new Thickness(12, 4, 12, 4),
            Background = new SolidColorBrush(Colors.LightGray),
            Child = new TextBlock
            {
                Text = props.Text,
                FontSize = 14
            }
        };
    }

    // Placeholder
    private static UIElement CreatePlaceholder(ZylixComponentProps props)
    {
        return new Border
        {
            Padding = new Thickness(16),
            Background = new SolidColorBrush(Colors.LightGray),
            CornerRadius = new CornerRadius(8),
            Child = new StackPanel
            {
                HorizontalAlignment = HorizontalAlignment.Center,
                Children =
                {
                    new SymbolIcon { Symbol = Symbol.ViewAll },
                    new TextBlock
                    {
                        Text = props.ComponentType.GetDisplayName(),
                        Foreground = new SolidColorBrush(Colors.Gray),
                        FontSize = 12,
                        Margin = new Thickness(0, 8, 0, 0)
                    }
                }
            }
        };
    }
}

/// <summary>
/// Helper to get all component types by category.
/// </summary>
public static class ZylixComponentCatalog
{
    public static IEnumerable<ZylixComponentType> GetAll()
    {
        return Enum.GetValues<ZylixComponentType>();
    }

    public static IEnumerable<ZylixComponentType> GetByCategory(ComponentCategory category)
    {
        return GetAll().Where(t => t.GetCategory() == category);
    }

    public static IEnumerable<ComponentCategory> GetCategories()
    {
        return Enum.GetValues<ComponentCategory>();
    }
}
