/**
 * Zylix Web SDK
 *
 * TypeScript bindings for Zylix WASM core.
 */

// === Event Types ===

export const ZYLIX_EVENT = {
  // Lifecycle
  APP_INIT: 0x0001,
  APP_TERMINATE: 0x0002,
  APP_FOREGROUND: 0x0003,
  APP_BACKGROUND: 0x0004,
  APP_LOW_MEMORY: 0x0005,

  // User interaction
  BUTTON_PRESS: 0x0100,
  TEXT_INPUT: 0x0101,
  TEXT_COMMIT: 0x0102,
  SELECTION: 0x0103,
  SCROLL: 0x0104,
  GESTURE: 0x0105,

  // Navigation
  NAVIGATE: 0x0200,
  NAVIGATE_BACK: 0x0201,
  TAB_SWITCH: 0x0202,

  // Counter PoC
  COUNTER_INCREMENT: 0x1000,
  COUNTER_DECREMENT: 0x1001,
  COUNTER_RESET: 0x1002,

  // Custom events base
  CUSTOM_BASE: 0x2000,
} as const;

export const ZYLIX_PRIORITY = {
  LOW: 0,
  NORMAL: 1,
  HIGH: 2,
  IMMEDIATE: 3,
} as const;

export const ZYLIX_RESULT = {
  OK: 0,
  ERR_INVALID_ARG: 1,
  ERR_OUT_OF_MEMORY: 2,
  ERR_INVALID_STATE: 3,
  ERR_NOT_INITIALIZED: 4,
} as const;

// === Type Definitions ===

export interface ZylixState {
  version: bigint;
  screen: number;
  loading: boolean;
  errorMessage: string | null;
  counter: bigint;
}

export interface ZylixDiff {
  changedMask: bigint;
  changeCount: number;
  version: bigint;
}

export interface ZylixExports {
  // Lifecycle
  zylix_init: () => number;
  zylix_deinit: () => number;
  zylix_get_abi_version: () => number;

  // State
  zylix_get_state: () => number;
  zylix_get_state_version: () => bigint;

  // Events
  zylix_dispatch: (eventType: number, payload: number, payloadLen: number) => number;
  zylix_queue_event: (eventType: number, payload: number, payloadLen: number, priority: number) => number;
  zylix_process_events: (maxEvents: number) => number;
  zylix_queue_depth: () => number;
  zylix_queue_clear: () => void;

  // Diff
  zylix_get_diff: () => number;
  zylix_field_changed: (fieldId: number) => boolean;

  // Error
  zylix_get_last_error: () => number;
  zylix_copy_string: (src: number, srcLen: number, dst: number, dstLen: number) => number;

  // WASM-specific
  zylix_wasm_get_counter: () => bigint;
  zylix_wasm_get_counter_ptr: () => number;
  zylix_wasm_alloc: (size: number) => number;
  zylix_wasm_free_scratch: () => void;
  zylix_wasm_memory_used: () => number;
  zylix_wasm_memory_peak: () => number;

  // Memory
  memory: WebAssembly.Memory;
}

// === Zylix Class ===

export class Zylix {
  private instance: WebAssembly.Instance | null = null;
  private exports: ZylixExports | null = null;
  private memory: WebAssembly.Memory | null = null;
  private listeners: Map<string, Set<(state: ZylixState) => void>> = new Map();
  private lastVersion: bigint = 0n;

  /**
   * Load and initialize Zylix WASM module
   */
  async init(wasmPath: string): Promise<void> {
    const response = await fetch(wasmPath);
    const bytes = await response.arrayBuffer();

    const result = await WebAssembly.instantiate(bytes, {
      env: {
        // WASM imports (if needed in future)
      },
    });

    this.instance = result.instance;
    this.exports = result.instance.exports as unknown as ZylixExports;
    this.memory = this.exports.memory;

    // Initialize Zylix core
    const initResult = this.exports.zylix_init();
    if (initResult !== ZYLIX_RESULT.OK) {
      throw new Error(`Zylix init failed with code: ${initResult}`);
    }

    console.log(`Zylix initialized, ABI version: ${this.exports.zylix_get_abi_version()}`);
  }

  /**
   * Cleanup and release resources
   */
  deinit(): void {
    if (this.exports) {
      this.exports.zylix_deinit();
    }
    this.instance = null;
    this.exports = null;
    this.memory = null;
  }

  /**
   * Get current counter value
   */
  getCounter(): bigint {
    this.ensureInitialized();
    return this.exports!.zylix_wasm_get_counter();
  }

  /**
   * Get current state version
   */
  getVersion(): bigint {
    this.ensureInitialized();
    return this.exports!.zylix_get_state_version();
  }

  /**
   * Dispatch an event
   */
  dispatch(eventType: number, payload: Uint8Array | null = null): number {
    this.ensureInitialized();

    let payloadPtr = 0;
    let payloadLen = 0;

    if (payload && payload.length > 0) {
      payloadPtr = this.exports!.zylix_wasm_alloc(payload.length);
      if (payloadPtr === 0) {
        throw new Error('Failed to allocate memory for payload');
      }
      const memView = new Uint8Array(this.memory!.buffer, payloadPtr, payload.length);
      memView.set(payload);
      payloadLen = payload.length;
    }

    const result = this.exports!.zylix_dispatch(eventType, payloadPtr, payloadLen);

    // Free scratch memory after dispatch
    this.exports!.zylix_wasm_free_scratch();

    // Check if state changed and notify listeners
    const newVersion = this.getVersion();
    if (newVersion !== this.lastVersion) {
      this.lastVersion = newVersion;
      this.notifyListeners();
    }

    return result;
  }

  /**
   * Increment counter
   */
  increment(): void {
    this.dispatch(ZYLIX_EVENT.COUNTER_INCREMENT);
  }

  /**
   * Decrement counter
   */
  decrement(): void {
    this.dispatch(ZYLIX_EVENT.COUNTER_DECREMENT);
  }

  /**
   * Reset counter
   */
  reset(): void {
    this.dispatch(ZYLIX_EVENT.COUNTER_RESET);
  }

  /**
   * Queue an event for later processing
   */
  queueEvent(
    eventType: number,
    payload: Uint8Array | null = null,
    priority: number = ZYLIX_PRIORITY.NORMAL
  ): number {
    this.ensureInitialized();

    let payloadPtr = 0;
    let payloadLen = 0;

    if (payload && payload.length > 0) {
      payloadPtr = this.exports!.zylix_wasm_alloc(payload.length);
      if (payloadPtr === 0) {
        throw new Error('Failed to allocate memory for payload');
      }
      const memView = new Uint8Array(this.memory!.buffer, payloadPtr, payload.length);
      memView.set(payload);
      payloadLen = payload.length;
    }

    return this.exports!.zylix_queue_event(eventType, payloadPtr, payloadLen, priority);
  }

  /**
   * Process queued events
   */
  processEvents(maxEvents: number = 10): number {
    this.ensureInitialized();
    const processed = this.exports!.zylix_process_events(maxEvents);

    // Check if state changed and notify listeners
    const newVersion = this.getVersion();
    if (newVersion !== this.lastVersion) {
      this.lastVersion = newVersion;
      this.notifyListeners();
    }

    return processed;
  }

  /**
   * Get queue depth
   */
  getQueueDepth(): number {
    this.ensureInitialized();
    return this.exports!.zylix_queue_depth();
  }

  /**
   * Clear event queue
   */
  clearQueue(): void {
    this.ensureInitialized();
    this.exports!.zylix_queue_clear();
  }

  /**
   * Check if a field changed since last state update
   */
  fieldChanged(fieldId: number): boolean {
    this.ensureInitialized();
    return this.exports!.zylix_field_changed(fieldId);
  }

  /**
   * Subscribe to state changes
   */
  subscribe(listener: (state: ZylixState) => void): () => void {
    const key = 'state';
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(listener);

    // Return unsubscribe function
    return () => {
      this.listeners.get(key)?.delete(listener);
    };
  }

  /**
   * Get current state
   */
  getState(): ZylixState {
    this.ensureInitialized();
    return {
      version: this.getVersion(),
      screen: 0, // TODO: Read from state struct
      loading: false,
      errorMessage: null,
      counter: this.getCounter(),
    };
  }

  /**
   * Get memory usage stats
   */
  getMemoryStats(): { used: number; peak: number } {
    this.ensureInitialized();
    return {
      used: this.exports!.zylix_wasm_memory_used(),
      peak: this.exports!.zylix_wasm_memory_peak(),
    };
  }

  private ensureInitialized(): void {
    if (!this.exports) {
      throw new Error('Zylix not initialized. Call init() first.');
    }
  }

  private notifyListeners(): void {
    const state = this.getState();
    const listeners = this.listeners.get('state');
    if (listeners) {
      for (const listener of listeners) {
        try {
          listener(state);
        } catch (e) {
          console.error('Listener error:', e);
        }
      }
    }
  }
}

// === Default Instance ===

export const zylix = new Zylix();
export default zylix;
