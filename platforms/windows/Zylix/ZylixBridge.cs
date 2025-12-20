using System;
using System.Runtime.InteropServices;
using System.ComponentModel;

namespace Zylix;

/// <summary>
/// C ABI function imports from Zylix Core (Zig)
/// </summary>
internal static partial class ZylixNative
{
    private const string LibName = "zylix";

    // Result codes
    public const int ZYLIX_OK = 0;
    public const int ZYLIX_ERR_INVALID_ARG = 1;
    public const int ZYLIX_ERR_OUT_OF_MEMORY = 2;
    public const int ZYLIX_ERR_INVALID_STATE = 3;
    public const int ZYLIX_ERR_NOT_INITIALIZED = 4;

    // Event types - Counter
    public const uint ZYLIX_EVENT_COUNTER_INCREMENT = 0x1000;
    public const uint ZYLIX_EVENT_COUNTER_DECREMENT = 0x1001;
    public const uint ZYLIX_EVENT_COUNTER_RESET = 0x1002;

    // Event types - Todo
    public const uint ZYLIX_EVENT_TODO_ADD = 0x3000;
    public const uint ZYLIX_EVENT_TODO_REMOVE = 0x3001;
    public const uint ZYLIX_EVENT_TODO_TOGGLE = 0x3002;
    public const uint ZYLIX_EVENT_TODO_TOGGLE_ALL = 0x3003;
    public const uint ZYLIX_EVENT_TODO_CLEAR_DONE = 0x3004;
    public const uint ZYLIX_EVENT_TODO_SET_FILTER = 0x3005;

    // Filter types
    public const int ZYLIX_FILTER_ALL = 0;
    public const int ZYLIX_FILTER_ACTIVE = 1;
    public const int ZYLIX_FILTER_COMPLETED = 2;

    [StructLayout(LayoutKind.Sequential)]
    public struct ZylixState
    {
        public ulong Version;
        public uint Screen;
        [MarshalAs(UnmanagedType.I1)]
        public bool Loading;
        public IntPtr ErrorMessage;
        public IntPtr ViewData;
        public nuint ViewDataSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ZylixAppState
    {
        public long Counter;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public byte[] InputText;
        public nuint InputLen;
    }

    // Lifecycle
    [LibraryImport(LibName, EntryPoint = "zylix_init")]
    public static partial int Init();

    [LibraryImport(LibName, EntryPoint = "zylix_deinit")]
    public static partial int Deinit();

    [LibraryImport(LibName, EntryPoint = "zylix_get_abi_version")]
    public static partial uint GetAbiVersion();

    // State
    [LibraryImport(LibName, EntryPoint = "zylix_get_state")]
    public static partial IntPtr GetState();

    [LibraryImport(LibName, EntryPoint = "zylix_get_state_version")]
    public static partial ulong GetStateVersion();

    // Events
    [LibraryImport(LibName, EntryPoint = "zylix_dispatch")]
    public static partial int Dispatch(uint eventType, IntPtr payload, nuint payloadLen);

    // Errors
    [LibraryImport(LibName, EntryPoint = "zylix_get_last_error")]
    public static partial IntPtr GetLastError();
}

/// <summary>
/// High-level wrapper for Zylix Core
/// </summary>
public sealed class ZylixBridge : INotifyPropertyChanged, IDisposable
{
    private static ZylixBridge? _instance;
    public static ZylixBridge Instance => _instance ??= new ZylixBridge();

    private bool _isInitialized;
    private long _counter;
    private string? _lastError;

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsInitialized
    {
        get => _isInitialized;
        private set
        {
            if (_isInitialized != value)
            {
                _isInitialized = value;
                OnPropertyChanged(nameof(IsInitialized));
            }
        }
    }

    public long Counter
    {
        get => _counter;
        private set
        {
            if (_counter != value)
            {
                _counter = value;
                OnPropertyChanged(nameof(Counter));
            }
        }
    }

    public string? LastError
    {
        get => _lastError;
        private set
        {
            if (_lastError != value)
            {
                _lastError = value;
                OnPropertyChanged(nameof(LastError));
            }
        }
    }

    private ZylixBridge() { }

    /// <summary>
    /// Initialize Zylix Core
    /// </summary>
    public bool Initialize()
    {
        if (IsInitialized) return true;

        var result = ZylixNative.Init();
        if (result == ZylixNative.ZYLIX_OK)
        {
            IsInitialized = true;
            RefreshState();
            System.Diagnostics.Debug.WriteLine($"[Zylix] Core initialized, ABI version: {ZylixNative.GetAbiVersion()}");
            return true;
        }

        LastError = GetErrorString();
        System.Diagnostics.Debug.WriteLine($"[Zylix] Failed to initialize: {LastError}");
        return false;
    }

    /// <summary>
    /// Shutdown Zylix Core
    /// </summary>
    public void Shutdown()
    {
        if (!IsInitialized) return;

        var result = ZylixNative.Deinit();
        if (result == ZylixNative.ZYLIX_OK)
        {
            IsInitialized = false;
            Counter = 0;
            System.Diagnostics.Debug.WriteLine("[Zylix] Core shutdown");
        }
    }

    /// <summary>
    /// Dispatch an event to Zylix Core
    /// </summary>
    public bool Dispatch(uint eventType)
    {
        if (!IsInitialized)
        {
            System.Diagnostics.Debug.WriteLine("[Zylix] Cannot dispatch: not initialized");
            return false;
        }

        var result = ZylixNative.Dispatch(eventType, IntPtr.Zero, 0);
        if (result == ZylixNative.ZYLIX_OK)
        {
            RefreshState();
            return true;
        }

        LastError = GetErrorString();
        System.Diagnostics.Debug.WriteLine($"[Zylix] Dispatch failed: {LastError}");
        return false;
    }

    // Convenience methods
    public void Increment() => Dispatch(ZylixNative.ZYLIX_EVENT_COUNTER_INCREMENT);
    public void Decrement() => Dispatch(ZylixNative.ZYLIX_EVENT_COUNTER_DECREMENT);
    public void Reset() => Dispatch(ZylixNative.ZYLIX_EVENT_COUNTER_RESET);

    private void RefreshState()
    {
        var statePtr = ZylixNative.GetState();
        if (statePtr == IntPtr.Zero) return;

        var state = Marshal.PtrToStructure<ZylixNative.ZylixState>(statePtr);

        if (state.ViewData != IntPtr.Zero)
        {
            var appState = Marshal.PtrToStructure<ZylixNative.ZylixAppState>(state.ViewData);
            Counter = appState.Counter;
        }
    }

    private static string? GetErrorString()
    {
        var errorPtr = ZylixNative.GetLastError();
        return errorPtr != IntPtr.Zero ? Marshal.PtrToStringAnsi(errorPtr) : null;
    }

    private void OnPropertyChanged(string propertyName)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    public void Dispose()
    {
        Shutdown();
    }
}
