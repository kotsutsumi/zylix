// ZylixHotReload.cs - Windows Hot Reload for Zylix v0.5.0
//
// Provides hot reload functionality for Windows development.
// Features:
// - File system watcher
// - State preservation
// - Error overlay
// - WebSocket communication

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace Zylix
{
    // ========================================================================
    // Hot Reload State
    // ========================================================================

    public enum HotReloadState
    {
        Disconnected,
        Connecting,
        Connected,
        Reloading,
        Error
    }

    // ========================================================================
    // Build Error
    // ========================================================================

    public record BuildError(
        string File,
        int Line,
        int Column,
        string Message,
        string Severity = "error"
    );

    // ========================================================================
    // Hot Reload Client
    // ========================================================================

    public sealed class ZylixHotReloadClient : IDisposable
    {
        private static readonly Lazy<ZylixHotReloadClient> _instance = new(() => new ZylixHotReloadClient());
        public static ZylixHotReloadClient Shared => _instance.Value;

        private ClientWebSocket? _webSocket;
        private CancellationTokenSource _cts = new();
        private Task? _receiveTask;
        private int _reconnectAttempts;
        private const int MaxReconnectAttempts = 10;

        private readonly StatePreservationManager _stateManager = new();
        private readonly ConcurrentDictionary<string, Action<JsonElement>> _handlers = new();
        private ErrorOverlayWindow? _errorOverlay;

        public event EventHandler<HotReloadState>? StateChanged;
        public event EventHandler<BuildError>? ErrorOccurred;
        public event EventHandler? ReloadTriggered;
        public event EventHandler<string>? HotUpdateTriggered;

        public HotReloadState State { get; private set; } = HotReloadState.Disconnected;
        public BuildError? LastError { get; private set; }
        public string ServerUrl { get; set; } = "ws://localhost:3001";

        private ZylixHotReloadClient() { }

        // MARK: - Connection

        public async Task ConnectAsync()
        {
            if (State == HotReloadState.Connected || State == HotReloadState.Connecting)
                return;

            SetState(HotReloadState.Connecting);

            try
            {
                _webSocket = new ClientWebSocket();
                await _webSocket.ConnectAsync(new Uri(ServerUrl), _cts.Token);

                SetState(HotReloadState.Connected);
                _reconnectAttempts = 0;

                _receiveTask = ReceiveLoopAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Zylix HMR] Connection failed: {ex.Message}");
                SetState(HotReloadState.Error);
                await ScheduleReconnectAsync();
            }
        }

        public async Task DisconnectAsync()
        {
            _cts.Cancel();

            if (_webSocket != null && _webSocket.State == WebSocketState.Open)
            {
                await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Client closing", CancellationToken.None);
            }

            _webSocket?.Dispose();
            _webSocket = null;
            SetState(HotReloadState.Disconnected);
        }

        private async Task ScheduleReconnectAsync()
        {
            if (_reconnectAttempts >= MaxReconnectAttempts)
            {
                Console.WriteLine("[Zylix HMR] Max reconnect attempts reached");
                return;
            }

            _reconnectAttempts++;
            var delay = Math.Min(30000, (1 << (_reconnectAttempts - 1)) * 1000);

            Console.WriteLine($"[Zylix HMR] Reconnecting in {delay}ms (attempt {_reconnectAttempts})");

            await Task.Delay(delay);
            await ConnectAsync();
        }

        private void SetState(HotReloadState newState)
        {
            State = newState;
            StateChanged?.Invoke(this, newState);
        }

        // MARK: - Message Handling

        private async Task ReceiveLoopAsync()
        {
            var buffer = new byte[4096];

            while (_webSocket?.State == WebSocketState.Open && !_cts.IsCancellationRequested)
            {
                try
                {
                    var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);

                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        SetState(HotReloadState.Disconnected);
                        await ScheduleReconnectAsync();
                        return;
                    }

                    var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    HandleMessage(message);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Zylix HMR] Receive error: {ex.Message}");
                    SetState(HotReloadState.Error);
                    await ScheduleReconnectAsync();
                    return;
                }
            }
        }

        private void HandleMessage(string text)
        {
            try
            {
                var json = JsonDocument.Parse(text);
                var type = json.RootElement.GetProperty("type").GetString();

                switch (type)
                {
                    case "reload":
                        HandleReload();
                        break;
                    case "hot_update":
                        HandleHotUpdate(json.RootElement.GetProperty("payload"));
                        break;
                    case "error_overlay":
                        HandleErrorOverlay(json.RootElement.GetProperty("payload"));
                        break;
                    case "state_sync":
                        HandleStateSync(json.RootElement.GetProperty("payload"));
                        break;
                    case "ping":
                        SendAsync(new { type = "pong" }).Wait();
                        break;
                    default:
                        if (_handlers.TryGetValue(type ?? "", out var handler))
                        {
                            handler(json.RootElement.GetProperty("payload"));
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Zylix HMR] Message handling error: {ex.Message}");
            }
        }

        private void HandleReload()
        {
            Console.WriteLine("[Zylix HMR] Full reload triggered");
            SetState(HotReloadState.Reloading);

            _stateManager.SaveState();
            ReloadTriggered?.Invoke(this, EventArgs.Empty);
        }

        private void HandleHotUpdate(JsonElement payload)
        {
            var module = payload.GetProperty("module").GetString() ?? "";
            Console.WriteLine($"[Zylix HMR] Hot update for: {module}");

            HideErrorOverlay();
            HotUpdateTriggered?.Invoke(this, module);
        }

        private void HandleErrorOverlay(JsonElement payload)
        {
            var error = new BuildError(
                payload.GetProperty("file").GetString() ?? "unknown",
                payload.TryGetProperty("line", out var line) ? line.GetInt32() : 1,
                payload.TryGetProperty("column", out var col) ? col.GetInt32() : 1,
                payload.GetProperty("message").GetString() ?? "Unknown error",
                payload.TryGetProperty("severity", out var sev) ? sev.GetString() ?? "error" : "error"
            );

            LastError = error;
            ErrorOccurred?.Invoke(this, error);
            ShowErrorOverlay(error);
        }

        private void HandleStateSync(JsonElement state)
        {
            _stateManager.MergeState(state);
        }

        // MARK: - Error Overlay

        public void ShowErrorOverlay(BuildError error)
        {
            HideErrorOverlay();
            _errorOverlay = new ErrorOverlayWindow(error);
            _errorOverlay.Show();
        }

        public void HideErrorOverlay()
        {
            _errorOverlay?.Close();
            _errorOverlay = null;
            LastError = null;
        }

        // MARK: - Send

        public async Task SendAsync(object data)
        {
            if (_webSocket?.State != WebSocketState.Open) return;

            var json = JsonSerializer.Serialize(data);
            var bytes = Encoding.UTF8.GetBytes(json);
            await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, _cts.Token);
        }

        // MARK: - State Preservation

        public void SaveState(string key, object value)
        {
            _stateManager.Set(key, value);
        }

        public object? LoadState(string key)
        {
            return _stateManager.Get(key);
        }

        public void RestoreState()
        {
            _stateManager.RestoreState();
        }

        // MARK: - Handlers

        public void On(string eventName, Action<JsonElement> handler)
        {
            _handlers[eventName] = handler;
        }

        public void Off(string eventName)
        {
            _handlers.TryRemove(eventName, out _);
        }

        public void Dispose()
        {
            _cts.Cancel();
            _webSocket?.Dispose();
            _cts.Dispose();
        }
    }

    // ========================================================================
    // State Preservation Manager
    // ========================================================================

    public class StatePreservationManager
    {
        private readonly ConcurrentDictionary<string, object> _state = new();
        private const string StateKey = "__ZYLIX_HOT_RELOAD_STATE__";

        public void Set(string key, object value)
        {
            _state[key] = value;
        }

        public object? Get(string key)
        {
            return _state.TryGetValue(key, out var value) ? value : null;
        }

        public void MergeState(JsonElement state)
        {
            foreach (var prop in state.EnumerateObject())
            {
                _state[prop.Name] = prop.Value.ToString();
            }
        }

        public void SaveState()
        {
            var json = JsonSerializer.Serialize(_state);
            Windows.Storage.ApplicationData.Current.LocalSettings.Values[StateKey] = json;
        }

        public void RestoreState()
        {
            if (Windows.Storage.ApplicationData.Current.LocalSettings.Values.TryGetValue(StateKey, out var value))
            {
                if (value is string json)
                {
                    var restored = JsonSerializer.Deserialize<Dictionary<string, object>>(json);
                    if (restored != null)
                    {
                        foreach (var kvp in restored)
                        {
                            _state[kvp.Key] = kvp.Value;
                        }
                    }
                }

                Windows.Storage.ApplicationData.Current.LocalSettings.Values.Remove(StateKey);
            }
        }
    }

    // ========================================================================
    // Error Overlay Window
    // ========================================================================

    public class ErrorOverlayWindow : Window
    {
        private readonly BuildError _error;

        public ErrorOverlayWindow(BuildError error)
        {
            _error = error;
            Title = "Build Error";

            var rootGrid = new Grid
            {
                Background = new SolidColorBrush(Microsoft.UI.Colors.Black),
                Padding = new Thickness(20)
            };

            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            // Title
            var title = new TextBlock
            {
                Text = "⚠️ Build Error",
                FontSize = 24,
                FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                Foreground = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 255, 107, 107)),
                Margin = new Thickness(0, 0, 0, 10)
            };
            Grid.SetRow(title, 0);
            rootGrid.Children.Add(title);

            // Location
            var location = new TextBlock
            {
                Text = $"{error.File}:{error.Line}:{error.Column}",
                FontSize = 12,
                Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray),
                FontFamily = new FontFamily("Consolas"),
                Margin = new Thickness(0, 0, 0, 10)
            };
            Grid.SetRow(location, 1);
            rootGrid.Children.Add(location);

            // Message
            var scrollViewer = new ScrollViewer
            {
                Background = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 45, 45, 45)),
                Padding = new Thickness(10)
            };
            var message = new TextBlock
            {
                Text = error.Message,
                FontSize = 14,
                Foreground = new SolidColorBrush(Microsoft.UI.Colors.White),
                FontFamily = new FontFamily("Consolas"),
                TextWrapping = TextWrapping.Wrap
            };
            scrollViewer.Content = message;
            Grid.SetRow(scrollViewer, 2);
            rootGrid.Children.Add(scrollViewer);

            // Dismiss button
            var dismissButton = new Button
            {
                Content = "Dismiss",
                HorizontalAlignment = HorizontalAlignment.Left,
                Margin = new Thickness(0, 10, 0, 0)
            };
            dismissButton.Click += (s, e) => Close();
            Grid.SetRow(dismissButton, 3);
            rootGrid.Children.Add(dismissButton);

            Content = rootGrid;
        }

        public void Show()
        {
            Activate();
        }
    }

    // ========================================================================
    // File System Watcher
    // ========================================================================

    public class ZylixFileWatcher : IDisposable
    {
        private readonly List<FileSystemWatcher> _watchers = new();
        private readonly Action<string, WatcherChangeTypes> _callback;
        private DateTime _lastChange = DateTime.MinValue;
        private readonly TimeSpan _debounceTime = TimeSpan.FromMilliseconds(50);

        public ZylixFileWatcher(Action<string, WatcherChangeTypes> callback)
        {
            _callback = callback;
        }

        public void AddPath(string path)
        {
            var watcher = new FileSystemWatcher(path)
            {
                IncludeSubdirectories = true,
                EnableRaisingEvents = true
            };

            watcher.Changed += OnChanged;
            watcher.Created += OnChanged;
            watcher.Deleted += OnChanged;
            watcher.Renamed += OnRenamed;

            _watchers.Add(watcher);
        }

        private void OnChanged(object sender, FileSystemEventArgs e)
        {
            var now = DateTime.Now;
            if (now - _lastChange < _debounceTime) return;
            _lastChange = now;

            _callback(e.FullPath, e.ChangeType);
        }

        private void OnRenamed(object sender, RenamedEventArgs e)
        {
            _callback(e.FullPath, WatcherChangeTypes.Renamed);
        }

        public void Dispose()
        {
            foreach (var watcher in _watchers)
            {
                watcher.Dispose();
            }
            _watchers.Clear();
        }
    }

    // ========================================================================
    // Development Server
    // ========================================================================

    public class ZylixDevServer : IDisposable
    {
        private static readonly Lazy<ZylixDevServer> _instance = new(() => new ZylixDevServer());
        public static ZylixDevServer Shared => _instance.Value;

        private ZylixFileWatcher? _fileWatcher;
        private readonly ZylixHotReloadClient _hotReloadClient = ZylixHotReloadClient.Shared;

        public int Port { get; set; } = 3000;
        public List<string> WatchPaths { get; } = new();
        public bool IsRunning { get; private set; }

        public async Task StartAsync()
        {
            if (IsRunning) return;

            // Start file watcher
            _fileWatcher = new ZylixFileWatcher(HandleFileChange);
            foreach (var path in WatchPaths)
            {
                _fileWatcher.AddPath(path);
            }

            // Connect to hot reload server
            await _hotReloadClient.ConnectAsync();

            IsRunning = true;
            Console.WriteLine($"🚀 Zylix Dev Server running on port {Port}");
        }

        public async Task StopAsync()
        {
            _fileWatcher?.Dispose();
            _fileWatcher = null;

            await _hotReloadClient.DisconnectAsync();

            IsRunning = false;
        }

        private void HandleFileChange(string path, WatcherChangeTypes changeType)
        {
            Console.WriteLine($"📁 File {changeType}: {path}");

            var ext = Path.GetExtension(path).ToLowerInvariant();

            if (new[] { ".cs", ".xaml" }.Contains(ext))
            {
                // Trigger rebuild
                TriggerRebuild();
            }
            else if (new[] { ".js", ".css", ".html" }.Contains(ext))
            {
                // Trigger hot update
                TriggerHotUpdate(path);
            }
        }

        private void TriggerRebuild()
        {
            // Notify for full reload
            _hotReloadClient.SendAsync(new { type = "reload" }).Wait();
        }

        private void TriggerHotUpdate(string module)
        {
            _hotReloadClient.SendAsync(new
            {
                type = "hot_update",
                payload = new { module }
            }).Wait();
        }

        public void Dispose()
        {
            StopAsync().Wait();
        }
    }

    // ========================================================================
    // XAML Integration
    // ========================================================================

    public static class HotReloadExtensions
    {
        public static void EnableHotReload(this Window window)
        {
            ZylixHotReloadClient.Shared.ReloadTriggered += (s, e) =>
            {
                window.DispatcherQueue.TryEnqueue(() =>
                {
                    // Trigger window refresh
                    window.Content = window.Content;
                });
            };

            _ = ZylixHotReloadClient.Shared.ConnectAsync();
        }

        public static void DisableHotReload(this Window window)
        {
            _ = ZylixHotReloadClient.Shared.DisconnectAsync();
        }
    }
}
