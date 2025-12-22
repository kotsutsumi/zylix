// Zylix Test Framework - Windows UI Automation Bridge Server
// HTTP server for Windows desktop automation using UI Automation API

using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Automation;

namespace ZylixTest;

class Program
{
    static void Main(string[] args)
    {
        var port = int.Parse(Environment.GetEnvironmentVariable("ZYLIX_TEST_PORT") ?? "4723");
        var server = new ZylixTestServer(port);

        Console.WriteLine($"ZylixTestServer starting on port {port}");
        Console.WriteLine("Press Ctrl+C to stop");

        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true;
            server.Stop();
        };

        server.Start();
    }
}

/// <summary>
/// HTTP server that receives commands from Zig Windows driver
/// and executes them using Windows UI Automation API.
/// </summary>
public class ZylixTestServer
{
    private readonly int _port;
    private readonly HttpListener _listener;
    private readonly ConcurrentDictionary<string, Session> _sessions = new();
    private int _sessionCounter;
    private bool _running;

    public ZylixTestServer(int port)
    {
        _port = port;
        _listener = new HttpListener();
        _listener.Prefixes.Add($"http://127.0.0.1:{port}/");
    }

    public void Start()
    {
        _running = true;
        _listener.Start();
        Console.WriteLine($"Server running on http://127.0.0.1:{_port}");

        while (_running)
        {
            try
            {
                var context = _listener.GetContext();
                ThreadPool.QueueUserWorkItem(_ => HandleRequest(context));
            }
            catch (HttpListenerException) when (!_running)
            {
                // Expected when stopping
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }

    public void Stop()
    {
        _running = false;

        foreach (var session in _sessions.Values)
        {
            session.Close();
        }
        _sessions.Clear();

        _listener.Stop();
        Console.WriteLine("Server stopped");
    }

    private void HandleRequest(HttpListenerContext context)
    {
        try
        {
            var request = context.Request;
            var response = context.Response;

            // Parse body
            string body = "";
            if (request.HasEntityBody)
            {
                using var reader = new StreamReader(request.InputStream, request.ContentEncoding);
                body = reader.ReadToEnd();
            }

            var requestData = string.IsNullOrEmpty(body)
                ? new Dictionary<string, object>()
                : JsonSerializer.Deserialize<Dictionary<string, object>>(body) ?? new();

            // Handle command
            var result = HandleCommand(request.Url?.AbsolutePath ?? "/", request.HttpMethod, requestData);

            // Send response
            var responseJson = JsonSerializer.Serialize(result);
            var buffer = Encoding.UTF8.GetBytes(responseJson);

            response.ContentType = "application/json";
            response.ContentLength64 = buffer.Length;
            response.OutputStream.Write(buffer, 0, buffer.Length);
            response.Close();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Request error: {ex.Message}");
        }
    }

    private Dictionary<string, object?> HandleCommand(string path, string method, Dictionary<string, object> data)
    {
        var parts = path.Split('/', StringSplitOptions.RemoveEmptyEntries);

        if (parts.Length < 2 || parts[0] != "session")
        {
            return new() { ["error"] = "Invalid path" };
        }

        // New session
        if (parts[1] == "new" && parts.Length >= 3)
        {
            return parts[2] switch
            {
                "launch" => HandleLaunch(data),
                "attach" => HandleAttach(data),
                _ => new() { ["error"] = "Unknown command" }
            };
        }

        // Existing session
        var sessionId = parts[1];
        if (!_sessions.TryGetValue(sessionId, out var session))
        {
            return new() { ["error"] = "Session not found" };
        }

        if (parts.Length < 3)
        {
            if (method == "DELETE")
            {
                return HandleClose(session);
            }
            return new() { ["error"] = "Missing command" };
        }

        var command = parts[2];

        return command switch
        {
            "findElement" => HandleFindElement(session, data),
            "findElements" => HandleFindElements(session, data),
            "click" => HandleClick(session, data),
            "doubleClick" => HandleDoubleClick(session, data),
            "rightClick" => HandleRightClick(session, data),
            "type" => HandleType(session, data),
            "clear" => HandleClear(session, data),
            "getText" => HandleGetText(session, data),
            "getName" => HandleGetName(session, data),
            "getPattern" => HandleGetPattern(session, data),
            "isVisible" => HandleIsVisible(session, data),
            "isEnabled" => HandleIsEnabled(session, data),
            "isFocused" => HandleIsFocused(session, data),
            "focus" => HandleFocus(session, data),
            "getBounds" => HandleGetBounds(session, data),
            "getAttribute" => HandleGetAttribute(session, data),
            "screenshot" => HandleScreenshot(session),
            "elementScreenshot" => HandleElementScreenshot(session, data),
            "window" => HandleWindowInfo(session),
            "keys" => HandleKeys(session, data),
            _ => new() { ["error"] = $"Unknown command: {command}" }
        };
    }

    private Dictionary<string, object?> HandleLaunch(Dictionary<string, object> data)
    {
        try
        {
            var exePath = GetString(data, "executable") ?? GetString(data, "appPath");
            var args = GetString(data, "args") ?? "";
            var workingDir = GetString(data, "workingDir");

            if (string.IsNullOrEmpty(exePath))
            {
                return new() { ["error"] = "Missing executable" };
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = exePath,
                Arguments = args,
                UseShellExecute = true
            };

            if (!string.IsNullOrEmpty(workingDir))
            {
                startInfo.WorkingDirectory = workingDir;
            }

            var process = Process.Start(startInfo);
            if (process == null)
            {
                return new() { ["error"] = "Failed to start process" };
            }

            // Wait for main window
            process.WaitForInputIdle(10000);
            Thread.Sleep(500); // Additional wait for UI to stabilize

            var sessionId = $"session-{++_sessionCounter}";
            var session = new Session(sessionId, process);

            // Find main window
            var root = AutomationElement.FromHandle(process.MainWindowHandle);
            session.RootElement = root;

            _sessions[sessionId] = session;

            return new()
            {
                ["sessionId"] = sessionId,
                ["pid"] = process.Id,
                ["success"] = true
            };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleAttach(Dictionary<string, object> data)
    {
        try
        {
            var pid = GetInt(data, "pid");
            var windowTitle = GetString(data, "windowTitle");
            var className = GetString(data, "className");

            Process? process = null;
            AutomationElement? root = null;

            if (pid.HasValue)
            {
                process = Process.GetProcessById(pid.Value);
                root = AutomationElement.FromHandle(process.MainWindowHandle);
            }
            else if (!string.IsNullOrEmpty(windowTitle))
            {
                // Find by window title
                var condition = new PropertyCondition(AutomationElement.NameProperty, windowTitle);
                root = AutomationElement.RootElement.FindFirst(TreeScope.Children, condition);

                if (root != null)
                {
                    pid = root.Current.ProcessId;
                    process = Process.GetProcessById(pid.Value);
                }
            }
            else if (!string.IsNullOrEmpty(className))
            {
                // Find by class name
                var condition = new PropertyCondition(AutomationElement.ClassNameProperty, className);
                root = AutomationElement.RootElement.FindFirst(TreeScope.Children, condition);

                if (root != null)
                {
                    pid = root.Current.ProcessId;
                    process = Process.GetProcessById(pid.Value);
                }
            }

            if (root == null || process == null)
            {
                return new() { ["error"] = "Window not found" };
            }

            var sessionId = $"session-{++_sessionCounter}";
            var session = new Session(sessionId, process)
            {
                RootElement = root
            };

            _sessions[sessionId] = session;

            return new()
            {
                ["sessionId"] = sessionId,
                ["pid"] = process.Id,
                ["success"] = true
            };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleClose(Session session)
    {
        session.Close();
        _sessions.TryRemove(session.Id, out _);
        return new() { ["success"] = true };
    }

    private Dictionary<string, object?> HandleFindElement(Session session, Dictionary<string, object> data)
    {
        var strategy = GetString(data, "strategy") ?? "";
        var value = GetString(data, "value") ?? "";
        var parentId = GetString(data, "parentId");

        var root = session.RootElement;
        if (!string.IsNullOrEmpty(parentId) && session.Elements.TryGetValue(parentId, out var parent))
        {
            root = parent;
        }

        if (root == null)
        {
            return new() { ["error"] = "No root element" };
        }

        var element = FindElement(root, strategy, value);
        if (element == null)
        {
            return new() { ["elementId"] = null };
        }

        var elementId = session.StoreElement(element);
        return new() { ["elementId"] = elementId };
    }

    private Dictionary<string, object?> HandleFindElements(Session session, Dictionary<string, object> data)
    {
        var strategy = GetString(data, "strategy") ?? "";
        var value = GetString(data, "value") ?? "";

        if (session.RootElement == null)
        {
            return new() { ["elements"] = Array.Empty<string>() };
        }

        var elements = FindElements(session.RootElement, strategy, value);
        var elementIds = elements.Select(e => session.StoreElement(e)).ToArray();

        return new() { ["elements"] = elementIds };
    }

    private AutomationElement? FindElement(AutomationElement root, string strategy, string value)
    {
        Condition condition = strategy switch
        {
            "automationId" => new PropertyCondition(AutomationElement.AutomationIdProperty, value),
            "name" => new PropertyCondition(AutomationElement.NameProperty, value),
            "className" => new PropertyCondition(AutomationElement.ClassNameProperty, value),
            "controlType" => GetControlTypeCondition(value),
            _ => Condition.FalseCondition
        };

        return root.FindFirst(TreeScope.Descendants, condition);
    }

    private List<AutomationElement> FindElements(AutomationElement root, string strategy, string value)
    {
        Condition condition = strategy switch
        {
            "automationId" => new PropertyCondition(AutomationElement.AutomationIdProperty, value),
            "name" => new PropertyCondition(AutomationElement.NameProperty, value),
            "className" => new PropertyCondition(AutomationElement.ClassNameProperty, value),
            "controlType" => GetControlTypeCondition(value),
            _ => Condition.FalseCondition
        };

        var found = root.FindAll(TreeScope.Descendants, condition);
        return found.Cast<AutomationElement>().ToList();
    }

    private Condition GetControlTypeCondition(string typeName)
    {
        var controlType = typeName.ToLower() switch
        {
            "button" => ControlType.Button,
            "text" or "textbox" => ControlType.Text,
            "edit" => ControlType.Edit,
            "checkbox" => ControlType.CheckBox,
            "radiobutton" => ControlType.RadioButton,
            "combobox" => ControlType.ComboBox,
            "list" => ControlType.List,
            "listitem" => ControlType.ListItem,
            "menu" => ControlType.Menu,
            "menuitem" => ControlType.MenuItem,
            "tree" => ControlType.Tree,
            "treeitem" => ControlType.TreeItem,
            "tab" => ControlType.Tab,
            "tabitem" => ControlType.TabItem,
            "window" => ControlType.Window,
            "pane" => ControlType.Pane,
            "scrollbar" => ControlType.ScrollBar,
            "slider" => ControlType.Slider,
            "progressbar" => ControlType.ProgressBar,
            "hyperlink" => ControlType.Hyperlink,
            "image" => ControlType.Image,
            _ => ControlType.Custom
        };

        return new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
    }

    private Dictionary<string, object?> HandleClick(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            if (element.TryGetCurrentPattern(InvokePattern.Pattern, out var pattern))
            {
                ((InvokePattern)pattern).Invoke();
                return new() { ["success"] = true };
            }

            // Fallback to click at center
            var bounds = element.Current.BoundingRectangle;
            var x = (int)(bounds.X + bounds.Width / 2);
            var y = (int)(bounds.Y + bounds.Height / 2);

            SetCursorPos(x, y);
            mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, x, y, 0, 0);

            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleDoubleClick(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            var bounds = element.Current.BoundingRectangle;
            var x = (int)(bounds.X + bounds.Width / 2);
            var y = (int)(bounds.Y + bounds.Height / 2);

            SetCursorPos(x, y);
            mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, x, y, 0, 0);
            mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, x, y, 0, 0);

            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleRightClick(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            var bounds = element.Current.BoundingRectangle;
            var x = (int)(bounds.X + bounds.Width / 2);
            var y = (int)(bounds.Y + bounds.Height / 2);

            SetCursorPos(x, y);
            mouse_event(MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP, x, y, 0, 0);

            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleType(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        var text = GetString(data, "text") ?? "";

        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            if (element.TryGetCurrentPattern(ValuePattern.Pattern, out var pattern))
            {
                ((ValuePattern)pattern).SetValue(text);
                return new() { ["success"] = true };
            }

            // Fallback: focus and send keys
            element.SetFocus();
            System.Windows.Forms.SendKeys.SendWait(text);

            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleClear(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            if (element.TryGetCurrentPattern(ValuePattern.Pattern, out var pattern))
            {
                ((ValuePattern)pattern).SetValue("");
                return new() { ["success"] = true };
            }

            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleGetText(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            string text = "";

            if (element.TryGetCurrentPattern(ValuePattern.Pattern, out var valuePattern))
            {
                text = ((ValuePattern)valuePattern).Current.Value;
            }
            else if (element.TryGetCurrentPattern(TextPattern.Pattern, out var textPattern))
            {
                text = ((TextPattern)textPattern).DocumentRange.GetText(-1);
            }
            else
            {
                text = element.Current.Name;
            }

            return new() { ["value"] = text };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleGetName(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        return new() { ["value"] = element.Current.Name };
    }

    private Dictionary<string, object?> HandleGetPattern(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        var patterns = element.GetSupportedPatterns();
        var patternNames = patterns.Select(p => Automation.PatternName(p)).ToArray();

        return new() { ["patterns"] = patternNames };
    }

    private Dictionary<string, object?> HandleIsVisible(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["value"] = false };
        }

        return new() { ["value"] = !element.Current.IsOffscreen };
    }

    private Dictionary<string, object?> HandleIsEnabled(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["value"] = false };
        }

        return new() { ["value"] = element.Current.IsEnabled };
    }

    private Dictionary<string, object?> HandleIsFocused(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["value"] = false };
        }

        return new() { ["value"] = element.Current.HasKeyboardFocus };
    }

    private Dictionary<string, object?> HandleFocus(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            element.SetFocus();
            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleGetBounds(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        var bounds = element.Current.BoundingRectangle;
        return new()
        {
            ["x"] = (int)bounds.X,
            ["y"] = (int)bounds.Y,
            ["width"] = (int)bounds.Width,
            ["height"] = (int)bounds.Height
        };
    }

    private Dictionary<string, object?> HandleGetAttribute(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        var name = GetString(data, "name") ?? "";

        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        object? value = name switch
        {
            "automationId" => element.Current.AutomationId,
            "name" => element.Current.Name,
            "className" => element.Current.ClassName,
            "controlType" => element.Current.ControlType.ProgrammaticName,
            "isEnabled" => element.Current.IsEnabled,
            "isOffscreen" => element.Current.IsOffscreen,
            "processId" => element.Current.ProcessId,
            _ => null
        };

        return new() { ["value"] = value };
    }

    private Dictionary<string, object?> HandleScreenshot(Session session)
    {
        if (session.RootElement == null)
        {
            return new() { ["error"] = "No window" };
        }

        try
        {
            var bounds = session.RootElement.Current.BoundingRectangle;
            using var bitmap = new Bitmap((int)bounds.Width, (int)bounds.Height);
            using var graphics = Graphics.FromImage(bitmap);

            graphics.CopyFromScreen(
                (int)bounds.X, (int)bounds.Y,
                0, 0,
                new Size((int)bounds.Width, (int)bounds.Height)
            );

            using var stream = new MemoryStream();
            bitmap.Save(stream, ImageFormat.Png);
            var base64 = Convert.ToBase64String(stream.ToArray());

            return new()
            {
                ["data"] = base64,
                ["width"] = (int)bounds.Width,
                ["height"] = (int)bounds.Height
            };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleElementScreenshot(Session session, Dictionary<string, object> data)
    {
        var element = GetElement(session, data);
        if (element == null)
        {
            return new() { ["error"] = "Element not found" };
        }

        try
        {
            var bounds = element.Current.BoundingRectangle;
            using var bitmap = new Bitmap((int)bounds.Width, (int)bounds.Height);
            using var graphics = Graphics.FromImage(bitmap);

            graphics.CopyFromScreen(
                (int)bounds.X, (int)bounds.Y,
                0, 0,
                new Size((int)bounds.Width, (int)bounds.Height)
            );

            using var stream = new MemoryStream();
            bitmap.Save(stream, ImageFormat.Png);
            var base64 = Convert.ToBase64String(stream.ToArray());

            return new()
            {
                ["data"] = base64,
                ["width"] = (int)bounds.Width,
                ["height"] = (int)bounds.Height
            };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private Dictionary<string, object?> HandleWindowInfo(Session session)
    {
        if (session.RootElement == null)
        {
            return new() { ["error"] = "No window" };
        }

        var bounds = session.RootElement.Current.BoundingRectangle;
        return new()
        {
            ["title"] = session.RootElement.Current.Name,
            ["x"] = (int)bounds.X,
            ["y"] = (int)bounds.Y,
            ["width"] = (int)bounds.Width,
            ["height"] = (int)bounds.Height
        };
    }

    private Dictionary<string, object?> HandleKeys(Session session, Dictionary<string, object> data)
    {
        var keys = GetString(data, "keys") ?? "";

        try
        {
            System.Windows.Forms.SendKeys.SendWait(keys);
            return new() { ["success"] = true };
        }
        catch (Exception ex)
        {
            return new() { ["error"] = ex.Message };
        }
    }

    private AutomationElement? GetElement(Session session, Dictionary<string, object> data)
    {
        var elementId = GetString(data, "elementId");
        if (string.IsNullOrEmpty(elementId))
        {
            return null;
        }

        session.Elements.TryGetValue(elementId, out var element);
        return element;
    }

    private static string? GetString(Dictionary<string, object> data, string key)
    {
        if (data.TryGetValue(key, out var value))
        {
            if (value is JsonElement jsonElement)
            {
                return jsonElement.GetString();
            }
            return value?.ToString();
        }
        return null;
    }

    private static int? GetInt(Dictionary<string, object> data, string key)
    {
        if (data.TryGetValue(key, out var value))
        {
            if (value is JsonElement jsonElement)
            {
                return jsonElement.GetInt32();
            }
            if (value is int i)
            {
                return i;
            }
        }
        return null;
    }

    // P/Invoke for mouse operations
    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    private static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);

    private const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    private const uint MOUSEEVENTF_LEFTUP = 0x04;
    private const uint MOUSEEVENTF_RIGHTDOWN = 0x08;
    private const uint MOUSEEVENTF_RIGHTUP = 0x10;
}

/// <summary>
/// Session manages a Windows application instance
/// </summary>
public class Session
{
    public string Id { get; }
    public Process? Process { get; }
    public AutomationElement? RootElement { get; set; }
    public ConcurrentDictionary<string, AutomationElement> Elements { get; } = new();

    private int _elementCounter;

    public Session(string id, Process? process)
    {
        Id = id;
        Process = process;
    }

    public string StoreElement(AutomationElement element)
    {
        var id = $"elem-{++_elementCounter}";
        Elements[id] = element;
        return id;
    }

    public void Close()
    {
        Elements.Clear();

        try
        {
            Process?.Kill();
        }
        catch
        {
            // Ignore
        }
    }
}
