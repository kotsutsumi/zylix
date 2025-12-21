// ZylixRouter.cs - Windows Router for Zylix v0.3.0
//
// Provides WinUI 3 NavigationView integration for Zylix routing system.
// Features:
// - NavigationView/Frame integration
// - Deep link handling (Protocol activation)
// - Route parameters and query strings
// - Navigation guards
// - Back button handling

using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Zylix
{
    // ========================================================================
    // Route Definition
    // ========================================================================

    /// <summary>
    /// A route parameter extracted from URL
    /// </summary>
    public record RouteParam(string Name, string Value);

    /// <summary>
    /// Parsed URL components
    /// </summary>
    public record ParsedURL(
        string Path,
        List<RouteParam> Params,
        Dictionary<string, string> Query,
        string? Fragment
    )
    {
        public string? GetParam(string name) =>
            Params.FirstOrDefault(p => p.Name == name)?.Value;

        public string? GetQuery(string key) =>
            Query.TryGetValue(key, out var value) ? value : null;
    }

    /// <summary>
    /// Route guard result
    /// </summary>
    public abstract record GuardResult
    {
        public record Allow() : GuardResult;
        public record Deny(string? Message = null) : GuardResult;
        public record Redirect(string To) : GuardResult;
    }

    /// <summary>
    /// Route metadata
    /// </summary>
    public record RouteMeta(
        string? Title = null,
        bool RequiresAuth = false,
        List<string>? Permissions = null,
        string? Icon = null,
        bool ShowInNavigation = true
    );

    /// <summary>
    /// A single route definition
    /// </summary>
    public class Route
    {
        public Guid Id { get; } = Guid.NewGuid();
        public string Path { get; set; } = "/";
        public RouteMeta Meta { get; set; } = new();
        public List<Func<RouteContext, GuardResult>> Guards { get; set; } = new();
        public List<Route> Children { get; set; } = new();
        public Type? PageType { get; set; }
    }

    /// <summary>
    /// Context passed to route handlers
    /// </summary>
    public class RouteContext
    {
        public ParsedURL Url { get; set; }
        public ZylixRouter? Router { get; set; }
        public bool IsAuthenticated { get; set; }
        public List<string> UserRoles { get; set; } = new();
        public object? UserData { get; set; }

        public RouteContext(ParsedURL url, ZylixRouter? router = null)
        {
            Url = url;
            Router = router;
        }

        public bool HasRole(string role) => UserRoles.Contains(role);
    }

    // ========================================================================
    // Navigation Event
    // ========================================================================

    public enum NavigationEvent
    {
        Push,
        Replace,
        Back,
        Forward,
        DeepLink
    }

    // ========================================================================
    // Router
    // ========================================================================

    /// <summary>
    /// Main router class for Zylix Windows
    /// </summary>
    public class ZylixRouter
    {
        private List<Route> _routes = new();
        private readonly List<string> _history = new();
        private int _historyIndex = -1;
        private readonly List<Action<NavigationEvent, string, RouteContext>> _navigationCallbacks = new();
        private Action<ParsedURL>? _notFoundHandler;
        private string _basePath = "";

        public string CurrentPath { get; private set; } = "/";
        public Route? CurrentRoute { get; private set; }
        public RouteContext? CurrentContext { get; private set; }
        public Frame? NavigationFrame { get; set; }
        public NavigationView? NavigationView { get; set; }

        public event EventHandler<RouteContext>? NavigationChanged;

        // ====================================================================
        // Configuration
        // ====================================================================

        public ZylixRouter DefineRoutes(List<Route> routes)
        {
            _routes = routes;
            return this;
        }

        public ZylixRouter SetBasePath(string path)
        {
            _basePath = path;
            return this;
        }

        public ZylixRouter OnNotFound(Action<ParsedURL> handler)
        {
            _notFoundHandler = handler;
            return this;
        }

        public ZylixRouter OnNavigate(Action<NavigationEvent, string, RouteContext> callback)
        {
            _navigationCallbacks.Add(callback);
            return this;
        }

        public IEnumerable<Route> GetNavigationRoutes() =>
            _routes.Where(r => r.Meta.ShowInNavigation);

        // ====================================================================
        // Navigation
        // ====================================================================

        public void Push(string path, object? userData = null)
        {
            Navigate(path, NavigationEvent.Push, userData: userData);
        }

        public void Replace(string path, object? userData = null)
        {
            Navigate(path, NavigationEvent.Replace, userData: userData);
        }

        public void Back()
        {
            if (!CanGoBack) return;
            _historyIndex--;
            var path = _history[_historyIndex];
            Navigate(path, NavigationEvent.Back, updateHistory: false);
        }

        public void Forward()
        {
            if (!CanGoForward) return;
            _historyIndex++;
            var path = _history[_historyIndex];
            Navigate(path, NavigationEvent.Forward, updateHistory: false);
        }

        public bool CanGoBack => _historyIndex > 0;
        public bool CanGoForward => _historyIndex < _history.Count - 1;

        // ====================================================================
        // Deep Linking
        // ====================================================================

        public void HandleDeepLink(Uri uri)
        {
            var path = string.IsNullOrEmpty(uri.AbsolutePath) ? "/" : uri.AbsolutePath;
            Navigate(path, NavigationEvent.DeepLink);
        }

        public void HandleProtocolActivation(Uri uri)
        {
            // Handle zylix:// protocol
            if (uri.Scheme.Equals("zylix", StringComparison.OrdinalIgnoreCase))
            {
                var path = "/" + uri.Host + uri.AbsolutePath;
                Navigate(path, NavigationEvent.DeepLink);
            }
        }

        // ====================================================================
        // URL Parsing
        // ====================================================================

        public ParsedURL ParseURL(string urlString)
        {
            var path = urlString;
            string? fragment = null;
            string? queryString = null;

            // Extract fragment
            var hashIndex = path.IndexOf('#');
            if (hashIndex >= 0)
            {
                fragment = path[(hashIndex + 1)..];
                path = path[..hashIndex];
            }

            // Extract query string
            var queryIndex = path.IndexOf('?');
            if (queryIndex >= 0)
            {
                queryString = path[(queryIndex + 1)..];
                path = path[..queryIndex];
            }

            // Parse query parameters
            var query = new Dictionary<string, string>();
            if (!string.IsNullOrEmpty(queryString))
            {
                foreach (var pair in queryString.Split('&'))
                {
                    var parts = pair.Split('=', 2);
                    if (parts.Length == 2)
                    {
                        query[parts[0]] = Uri.UnescapeDataString(parts[1]);
                    }
                }
            }

            return new ParsedURL(path, new List<RouteParam>(), query, fragment);
        }

        // ====================================================================
        // Route Matching
        // ====================================================================

        public (Route Route, List<RouteParam> Params)? MatchRoute(string path)
        {
            foreach (var route in _routes)
            {
                var match = MatchPattern(route.Path, path);
                if (match != null)
                {
                    return (route, match);
                }

                // Check children
                foreach (var child in route.Children)
                {
                    var fullPattern = route.Path + child.Path;
                    match = MatchPattern(fullPattern, path);
                    if (match != null)
                    {
                        return (child, match);
                    }
                }
            }
            return null;
        }

        private List<RouteParam>? MatchPattern(string pattern, string path)
        {
            var patternParts = pattern.Split('/', StringSplitOptions.RemoveEmptyEntries);
            var pathParts = path.Split('/', StringSplitOptions.RemoveEmptyEntries);

            if (patternParts.Length != pathParts.Length) return null;

            var parameters = new List<RouteParam>();

            for (int i = 0; i < patternParts.Length; i++)
            {
                var patternPart = patternParts[i];
                var pathPart = pathParts[i];

                if (patternPart.StartsWith(':'))
                {
                    var paramName = patternPart[1..];
                    parameters.Add(new RouteParam(paramName, pathPart));
                }
                else if (patternPart == "*")
                {
                    parameters.Add(new RouteParam("wildcard", pathPart));
                }
                else if (!patternPart.Equals(pathPart, StringComparison.OrdinalIgnoreCase))
                {
                    return null;
                }
            }

            return parameters;
        }

        // ====================================================================
        // Private Navigation
        // ====================================================================

        private void Navigate(
            string path,
            NavigationEvent navEvent,
            bool updateHistory = true,
            object? userData = null)
        {
            var fullPath = _basePath + path;
            var parsed = ParseURL(fullPath);

            // Match route
            var matched = MatchRoute(parsed.Path);
            if (matched == null)
            {
                _notFoundHandler?.Invoke(parsed);
                return;
            }

            var (route, parameters) = matched.Value;

            // Update parsed URL with params
            parsed = parsed with { Params = parameters };

            // Create context
            var context = new RouteContext(parsed, this)
            {
                UserData = userData
            };

            // Check guards
            foreach (var guard in route.Guards)
            {
                var result = guard(context);
                switch (result)
                {
                    case GuardResult.Allow:
                        continue;
                    case GuardResult.Deny deny:
                        System.Diagnostics.Debug.WriteLine($"[ZylixRouter] Navigation denied: {deny.Message}");
                        return;
                    case GuardResult.Redirect redirect:
                        Replace(redirect.To);
                        return;
                }
            }

            // Update history
            if (updateHistory && (navEvent == NavigationEvent.Push || navEvent == NavigationEvent.DeepLink))
            {
                // Remove forward history
                if (_historyIndex < _history.Count - 1)
                {
                    _history.RemoveRange(_historyIndex + 1, _history.Count - _historyIndex - 1);
                }
                _history.Add(path);
                _historyIndex = _history.Count - 1;
            }

            // Update state
            CurrentPath = path;
            CurrentRoute = route;
            CurrentContext = context;

            // Navigate Frame if available
            if (NavigationFrame != null && route.PageType != null)
            {
                if (navEvent == NavigationEvent.Replace && NavigationFrame.CanGoBack)
                {
                    NavigationFrame.GoBack();
                }
                NavigationFrame.Navigate(route.PageType, context);
            }

            // Notify callbacks
            foreach (var callback in _navigationCallbacks)
            {
                callback(navEvent, path, context);
            }

            NavigationChanged?.Invoke(this, context);
        }
    }

    // ========================================================================
    // Common Guards
    // ========================================================================

    public static class RouteGuards
    {
        public static GuardResult RequireAuth(RouteContext context)
        {
            if (context.IsAuthenticated)
            {
                return new GuardResult.Allow();
            }
            return new GuardResult.Redirect("/login");
        }

        public static Func<RouteContext, GuardResult> RequireRole(string role)
        {
            return context =>
            {
                if (context.HasRole(role))
                {
                    return new GuardResult.Allow();
                }
                return new GuardResult.Deny("Insufficient permissions");
            };
        }
    }

    // ========================================================================
    // NavigationView Helper
    // ========================================================================

    public static class ZylixNavigationHelper
    {
        public static void SetupNavigationView(
            NavigationView navigationView,
            Frame contentFrame,
            ZylixRouter router)
        {
            router.NavigationFrame = contentFrame;
            router.NavigationView = navigationView;

            // Add navigation items from routes
            foreach (var route in router.GetNavigationRoutes())
            {
                var item = new NavigationViewItem
                {
                    Content = route.Meta.Title ?? route.Path,
                    Tag = route.Path
                };

                if (!string.IsNullOrEmpty(route.Meta.Icon))
                {
                    item.Icon = new SymbolIcon((Symbol)Enum.Parse(typeof(Symbol), route.Meta.Icon));
                }

                navigationView.MenuItems.Add(item);
            }

            // Handle selection
            navigationView.SelectionChanged += (sender, args) =>
            {
                if (args.SelectedItem is NavigationViewItem item && item.Tag is string path)
                {
                    router.Push(path);
                }
            };

            // Handle back button
            navigationView.BackRequested += (sender, args) =>
            {
                if (router.CanGoBack)
                {
                    router.Back();
                }
            };

            // Update back button visibility
            router.NavigationChanged += (sender, context) =>
            {
                navigationView.IsBackEnabled = router.CanGoBack;
            };
        }
    }
}
