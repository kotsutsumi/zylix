using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;

namespace Zylix;

/// <summary>
/// Represents a single todo item
/// </summary>
public class TodoItem : INotifyPropertyChanged
{
    private bool _isCompleted;

    public uint Id { get; init; }
    public string Text { get; init; } = string.Empty;

    public bool IsCompleted
    {
        get => _isCompleted;
        set
        {
            if (_isCompleted != value)
            {
                _isCompleted = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsCompleted)));
            }
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}

/// <summary>
/// Filter mode for todos
/// </summary>
public enum TodoFilter
{
    All,
    Active,
    Completed
}

/// <summary>
/// ViewModel for the Todo app
/// </summary>
public class TodoViewModel : INotifyPropertyChanged
{
    private string _newTodoText = string.Empty;
    private TodoFilter _currentFilter = TodoFilter.All;
    private uint _nextId = 1;
    private int _renderCount;
    private double _lastRenderTime;
    private readonly Stopwatch _stopwatch = new();

    public ObservableCollection<TodoItem> Items { get; } = new();

    public string NewTodoText
    {
        get => _newTodoText;
        set
        {
            if (_newTodoText != value)
            {
                _newTodoText = value;
                OnPropertyChanged(nameof(NewTodoText));
                OnPropertyChanged(nameof(CanAddTodo));
            }
        }
    }

    public TodoFilter CurrentFilter
    {
        get => _currentFilter;
        set
        {
            if (_currentFilter != value)
            {
                _currentFilter = value;
                OnPropertyChanged(nameof(CurrentFilter));
                OnPropertyChanged(nameof(FilteredItems));
                OnPropertyChanged(nameof(IsAllFilter));
                OnPropertyChanged(nameof(IsActiveFilter));
                OnPropertyChanged(nameof(IsCompletedFilter));
            }
        }
    }

    public bool IsAllFilter => CurrentFilter == TodoFilter.All;
    public bool IsActiveFilter => CurrentFilter == TodoFilter.Active;
    public bool IsCompletedFilter => CurrentFilter == TodoFilter.Completed;

    public ObservableCollection<TodoItem> FilteredItems
    {
        get
        {
            var filtered = CurrentFilter switch
            {
                TodoFilter.Active => Items.Where(x => !x.IsCompleted),
                TodoFilter.Completed => Items.Where(x => x.IsCompleted),
                _ => Items
            };
            return new ObservableCollection<TodoItem>(filtered);
        }
    }

    public int ActiveCount => Items.Count(x => !x.IsCompleted);
    public int CompletedCount => Items.Count(x => x.IsCompleted);
    public bool AllCompleted => Items.Count > 0 && Items.All(x => x.IsCompleted);
    public bool HasCompleted => CompletedCount > 0;
    public bool CanAddTodo => !string.IsNullOrWhiteSpace(NewTodoText);

    public int RenderCount
    {
        get => _renderCount;
        private set
        {
            _renderCount = value;
            OnPropertyChanged(nameof(RenderCount));
            OnPropertyChanged(nameof(StatsText));
        }
    }

    public double LastRenderTime
    {
        get => _lastRenderTime;
        private set
        {
            _lastRenderTime = value;
            OnPropertyChanged(nameof(LastRenderTime));
            OnPropertyChanged(nameof(StatsText));
        }
    }

    public string StatsText => $"{Items.Count} Todos  |  {RenderCount} Renders  |  {LastRenderTime:F2} ms";
    public string ItemsLeftText => $"{ActiveCount} item{(ActiveCount == 1 ? "" : "s")} left";

    public event PropertyChangedEventHandler? PropertyChanged;

    public TodoViewModel()
    {
        // Add sample todos
        AddTodo("Learn Zig");
        AddTodo("Build VDOM");
        AddTodo("Create Windows bindings");
    }

    public void AddTodo(string? text = null)
    {
        var todoText = text ?? NewTodoText.Trim();
        if (string.IsNullOrWhiteSpace(todoText)) return;

        _stopwatch.Restart();

        var item = new TodoItem
        {
            Id = _nextId++,
            Text = todoText,
            IsCompleted = false
        };
        Items.Add(item);

        if (text == null)
        {
            NewTodoText = string.Empty;
        }

        TrackRender();
        NotifyAllChanged();
    }

    public void RemoveTodo(TodoItem item)
    {
        _stopwatch.Restart();
        Items.Remove(item);
        TrackRender();
        NotifyAllChanged();
    }

    public void ToggleTodo(TodoItem item)
    {
        _stopwatch.Restart();
        item.IsCompleted = !item.IsCompleted;
        TrackRender();
        NotifyAllChanged();
    }

    public void ToggleAll()
    {
        _stopwatch.Restart();
        var shouldComplete = !AllCompleted;
        foreach (var item in Items)
        {
            item.IsCompleted = shouldComplete;
        }
        TrackRender();
        NotifyAllChanged();
    }

    public void ClearCompleted()
    {
        _stopwatch.Restart();
        var completed = Items.Where(x => x.IsCompleted).ToList();
        foreach (var item in completed)
        {
            Items.Remove(item);
        }
        TrackRender();
        NotifyAllChanged();
    }

    public void SetFilter(TodoFilter filter)
    {
        CurrentFilter = filter;
    }

    private void TrackRender()
    {
        _stopwatch.Stop();
        LastRenderTime = _stopwatch.Elapsed.TotalMilliseconds;
        RenderCount++;
    }

    private void NotifyAllChanged()
    {
        OnPropertyChanged(nameof(FilteredItems));
        OnPropertyChanged(nameof(ActiveCount));
        OnPropertyChanged(nameof(CompletedCount));
        OnPropertyChanged(nameof(AllCompleted));
        OnPropertyChanged(nameof(HasCompleted));
        OnPropertyChanged(nameof(ItemsLeftText));
        OnPropertyChanged(nameof(StatsText));
    }

    private void OnPropertyChanged(string propertyName)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
