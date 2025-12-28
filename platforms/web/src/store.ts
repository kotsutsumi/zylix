/**
 * Zylix Store - State Management Library
 *
 * A lightweight, Redux-like state management solution with:
 * - Immutable state updates
 * - Memoized selectors
 * - Async actions (thunks)
 * - Middleware support
 * - Time-travel debugging
 *
 * @example
 * ```typescript
 * import { createStore, useStore } from 'zylix/store';
 *
 * const store = createStore({
 *   state: { count: 0 },
 *   actions: {
 *     increment: (state) => ({ ...state, count: state.count + 1 }),
 *     add: (state, amount: number) => ({ ...state, count: state.count + amount })
 *   },
 *   selectors: {
 *     doubled: (state) => state.count * 2
 *   }
 * });
 *
 * // In component
 * const count = useStore(store, s => s.count);
 * store.actions.increment();
 * ```
 */

// =============================================================================
// TYPES
// =============================================================================

/** Store configuration */
export interface StoreConfig<S, A extends ActionDefinitions<S>, L extends SelectorDefinitions<S>> {
  /** Initial state */
  state: S;
  /** Action definitions */
  actions?: A;
  /** Selector definitions */
  selectors?: L;
  /** Middleware functions */
  middleware?: Middleware<S>[];
  /** Enable DevTools */
  devtools?: boolean | DevToolsOptions;
}

/** Action function that returns new state */
export type ActionFn<S, P extends any[] = any[]> = (state: S, ...args: P) => S | Promise<S>;

/** Async action function (thunk) */
export type AsyncActionFn<S, P extends any[] = any[]> = (
  context: { getState: () => S; dispatch: (action: string, ...args: any[]) => void },
  ...args: P
) => Promise<void>;

/** Action definitions object */
export type ActionDefinitions<S> = Record<string, ActionFn<S, any[]> | AsyncActionFn<S, any[]>>;

/** Selector function */
export type SelectorFn<S, R = any> = (state: S) => R;

/** Selector definitions object */
export type SelectorDefinitions<S> = Record<string, SelectorFn<S, any>>;

/** Bound actions with proper typing */
export type BoundActions<S, A extends ActionDefinitions<S>> = {
  [K in keyof A]: A[K] extends ActionFn<S, infer P>
    ? (...args: P) => void
    : A[K] extends AsyncActionFn<S, infer P>
    ? (...args: P) => Promise<void>
    : never;
};

/** Subscriber callback */
export type Subscriber<S> = (state: S, prevState: S) => void;

/** Unsubscribe function */
export type Unsubscribe = () => void;

/** Middleware function */
export type Middleware<S> = (context: MiddlewareContext<S>) => (next: MiddlewareNext) => MiddlewareNext;

/** Middleware context */
export interface MiddlewareContext<S> {
  getState: () => S;
  dispatch: (action: string, ...args: any[]) => void;
}

/** Middleware next function */
export type MiddlewareNext = (action: string, ...args: any[]) => void;

/** DevTools options */
export interface DevToolsOptions {
  /** Maximum history entries */
  maxHistory?: number;
  /** Enable action tracing */
  trace?: boolean;
  /** Store name for DevTools */
  name?: string;
}

/** DevTools API */
export interface DevToolsAPI<S> {
  /** Undo last action */
  undo: () => boolean;
  /** Redo undone action */
  redo: () => boolean;
  /** Jump to specific history index */
  jumpTo: (index: number) => boolean;
  /** Get full history */
  getHistory: () => HistoryEntry<S>[];
  /** Get current history index */
  getCurrentIndex: () => number;
  /** Clear history */
  clearHistory: () => void;
  /** Enable/disable recording */
  setRecording: (enabled: boolean) => void;
  /** Check if recording */
  isRecording: () => boolean;
}

/** History entry for time-travel */
export interface HistoryEntry<S> {
  /** State snapshot */
  state: S;
  /** Action that caused this state */
  action: string;
  /** Action arguments */
  args: any[];
  /** Timestamp */
  timestamp: number;
}

/** Store instance */
export interface Store<S, A extends ActionDefinitions<S>, L extends SelectorDefinitions<S>> {
  /** Get current state */
  getState: () => S;
  /** Subscribe to state changes */
  subscribe: (callback: Subscriber<S>) => Unsubscribe;
  /** Bound action functions */
  actions: BoundActions<S, A>;
  /** Selector functions */
  selectors: { [K in keyof L]: () => ReturnType<L[K]> };
  /** DevTools API (if enabled) */
  devtools?: DevToolsAPI<S>;
  /** Dispatch raw action */
  dispatch: (action: string, ...args: any[]) => void;
}

// =============================================================================
// MEMOIZATION
// =============================================================================

/** Create a memoized selector */
function createMemoizedSelector<S, R>(selector: SelectorFn<S, R>): (state: S) => R {
  let lastState: S | undefined;
  let lastResult: R;
  let hasResult = false;

  return (state: S): R => {
    if (hasResult && Object.is(state, lastState)) {
      return lastResult;
    }
    lastState = state;
    lastResult = selector(state);
    hasResult = true;
    return lastResult;
  };
}

// =============================================================================
// DEVTOOLS
// =============================================================================

/** Create DevTools API */
function createDevTools<S>(
  options: DevToolsOptions,
  getState: () => S,
  setState: (state: S) => void
): DevToolsAPI<S> {
  const maxHistory = options.maxHistory ?? 50;
  let history: HistoryEntry<S>[] = [];
  let currentIndex = -1;
  let recording = true;

  const addEntry = (state: S, action: string, args: any[]) => {
    if (!recording) return;

    // Remove future entries if we've time-traveled back
    if (currentIndex < history.length - 1) {
      history = history.slice(0, currentIndex + 1);
    }

    // Add new entry
    history.push({
      state,
      action,
      args,
      timestamp: Date.now(),
    });

    // Trim history if too long
    if (history.length > maxHistory) {
      history = history.slice(history.length - maxHistory);
    }

    currentIndex = history.length - 1;
  };

  // Add initial state
  addEntry(getState(), '@@INIT', []);

  return {
    undo: () => {
      if (currentIndex > 0) {
        currentIndex--;
        setState(history[currentIndex].state);
        return true;
      }
      return false;
    },

    redo: () => {
      if (currentIndex < history.length - 1) {
        currentIndex++;
        setState(history[currentIndex].state);
        return true;
      }
      return false;
    },

    jumpTo: (index: number) => {
      if (index >= 0 && index < history.length) {
        currentIndex = index;
        setState(history[currentIndex].state);
        return true;
      }
      return false;
    },

    getHistory: () => [...history],

    getCurrentIndex: () => currentIndex,

    clearHistory: () => {
      const currentState = getState();
      history = [{ state: currentState, action: '@@INIT', args: [], timestamp: Date.now() }];
      currentIndex = 0;
    },

    setRecording: (enabled: boolean) => {
      recording = enabled;
    },

    isRecording: () => recording,

    // Internal method for adding entries
    _addEntry: addEntry,
  } as DevToolsAPI<S> & { _addEntry: typeof addEntry };
}

// =============================================================================
// STORE CREATION
// =============================================================================

/**
 * Create a new store
 *
 * @param config - Store configuration
 * @returns Store instance
 *
 * @example
 * ```typescript
 * const store = createStore({
 *   state: {
 *     todos: [],
 *     filter: 'all'
 *   },
 *   actions: {
 *     addTodo: (state, text: string) => ({
 *       ...state,
 *       todos: [...state.todos, { id: Date.now(), text, done: false }]
 *     }),
 *     toggleTodo: (state, id: number) => ({
 *       ...state,
 *       todos: state.todos.map(t =>
 *         t.id === id ? { ...t, done: !t.done } : t
 *       )
 *     })
 *   },
 *   selectors: {
 *     activeTodos: (state) => state.todos.filter(t => !t.done),
 *     completedCount: (state) => state.todos.filter(t => t.done).length
 *   }
 * });
 * ```
 */
export function createStore<
  S,
  A extends ActionDefinitions<S> = {},
  L extends SelectorDefinitions<S> = {}
>(config: StoreConfig<S, A, L>): Store<S, A, L> {
  let state = config.state;
  const subscribers = new Set<Subscriber<S>>();
  const actionDefs = config.actions ?? ({} as A);
  const selectorDefs = config.selectors ?? ({} as L);
  const middleware = config.middleware ?? [];

  // Create memoized selectors
  const memoizedSelectors = new Map<keyof L, (state: S) => any>();
  for (const key of Object.keys(selectorDefs) as Array<keyof L>) {
    memoizedSelectors.set(key, createMemoizedSelector(selectorDefs[key]));
  }

  // DevTools
  let devtools: (DevToolsAPI<S> & { _addEntry?: (state: S, action: string, args: any[]) => void }) | undefined;
  if (config.devtools) {
    const options = typeof config.devtools === 'object' ? config.devtools : {};
    devtools = createDevTools(options, () => state, (s) => {
      const prevState = state;
      state = s;
      notifySubscribers(prevState);
    });
  }

  // Notify subscribers
  const notifySubscribers = (prevState: S) => {
    for (const subscriber of subscribers) {
      try {
        subscriber(state, prevState);
      } catch (error) {
        console.error('Store subscriber error:', error);
      }
    }
  };

  // Core dispatch function
  const coreDispatch = (action: string, ...args: any[]) => {
    const actionFn = actionDefs[action as keyof A];
    if (!actionFn) {
      console.warn(`Unknown action: ${action}`);
      return;
    }

    const prevState = state;

    // Check if it's an async action (thunk)
    if (actionFn.length >= 1 && typeof actionFn === 'function') {
      const result = (actionFn as ActionFn<S>)(state, ...args);

      if (result instanceof Promise) {
        // Async action
        result.then((newState) => {
          state = newState;
          devtools?._addEntry?.(state, action, args);
          notifySubscribers(prevState);
        });
      } else {
        // Sync action
        state = result;
        devtools?._addEntry?.(state, action, args);
        notifySubscribers(prevState);
      }
    }
  };

  // Build middleware chain
  let dispatch = coreDispatch;
  if (middleware.length > 0) {
    const context: MiddlewareContext<S> = {
      getState: () => state,
      dispatch: (action, ...args) => dispatch(action, ...args),
    };

    // Apply middleware in reverse order
    dispatch = middleware.reduceRight(
      (next, mw) => mw(context)(next),
      coreDispatch
    );
  }

  // Create bound actions
  const actions = {} as BoundActions<S, A>;
  for (const key of Object.keys(actionDefs) as Array<keyof A>) {
    (actions as any)[key] = (...args: any[]) => dispatch(key as string, ...args);
  }

  // Create selector accessors
  const selectors = {} as { [K in keyof L]: () => ReturnType<L[K]> };
  for (const key of Object.keys(selectorDefs) as Array<keyof L>) {
    const memoized = memoizedSelectors.get(key)!;
    (selectors as any)[key] = () => memoized(state);
  }

  return {
    getState: () => state,

    subscribe: (callback: Subscriber<S>) => {
      subscribers.add(callback);
      return () => subscribers.delete(callback);
    },

    actions,
    selectors,
    dispatch,

    devtools: devtools as DevToolsAPI<S> | undefined,
  };
}

// =============================================================================
// REACT INTEGRATION (useStore hook)
// =============================================================================

// Import types from component module (assumes they're available)
// In actual usage, these would be imported from the component module

/** Current component context (from component.ts) */
declare let currentComponent: any;

/** Schedule rerender function */
declare function scheduleRerender(component: any): void;

// We need to re-implement hooks inline since we can't import them easily
// This is a standalone implementation that works with component.ts

/**
 * Hook to use store state in a component
 *
 * @param store - The store instance
 * @param selector - Optional selector function (defaults to returning full state)
 * @returns Selected state value
 *
 * @example
 * ```typescript
 * // Get full state
 * const state = useStore(store);
 *
 * // Get specific value
 * const count = useStore(store, s => s.count);
 *
 * // Get derived value
 * const total = useStore(store, s => s.items.reduce((a, b) => a + b.price, 0));
 * ```
 */
export function useStore<S, A extends ActionDefinitions<S>, L extends SelectorDefinitions<S>, R = S>(
  store: Store<S, A, L>,
  selector?: (state: S) => R
): R {
  // Get hook state from component context
  if (typeof currentComponent === 'undefined' || !currentComponent) {
    throw new Error('useStore must be called inside a component');
  }

  const component = currentComponent;
  const index = component._hookIndex++;
  const hooks = component._hooks;

  // Initialize hook state
  if (index >= hooks.length) {
    const actualSelector = selector ?? ((s: S) => s as unknown as R);
    const initialValue = actualSelector(store.getState());

    // Create memoized selector
    const memoizedSelector = createMemoizedSelector(actualSelector);

    // Subscribe to store
    const unsubscribe = store.subscribe((newState) => {
      const newValue = memoizedSelector(newState);
      const currentValue = hooks[index]._value;

      if (!Object.is(newValue, currentValue)) {
        hooks[index]._value = newValue;
        scheduleRerender(component);
      }
    });

    hooks.push({
      _value: initialValue,
      _selector: memoizedSelector,
      _unsubscribe: unsubscribe,
    });
  }

  return hooks[index]._value;
}

// =============================================================================
// MIDDLEWARE
// =============================================================================

/**
 * Logger middleware - logs all actions and state changes
 *
 * @example
 * ```typescript
 * const store = createStore({
 *   state: { count: 0 },
 *   actions: { increment: s => ({ count: s.count + 1 }) },
 *   middleware: [loggerMiddleware()]
 * });
 * ```
 */
export function loggerMiddleware<S>(options?: {
  collapsed?: boolean;
  colors?: boolean;
}): Middleware<S> {
  const { collapsed = false, colors = true } = options ?? {};

  return (context) => (next) => (action, ...args) => {
    const prevState = context.getState();
    const startTime = performance.now();

    if (colors && typeof console.groupCollapsed === 'function') {
      const groupFn = collapsed ? console.groupCollapsed : console.group;
      groupFn.call(console, `%c action %c${action}`, 'color: gray', 'color: inherit; font-weight: bold');
      console.log('%c prev state', 'color: #9E9E9E', prevState);
      console.log('%c action', 'color: #03A9F4', { type: action, payload: args });
    }

    next(action, ...args);

    const nextState = context.getState();
    const duration = performance.now() - startTime;

    if (colors && typeof console.groupEnd === 'function') {
      console.log('%c next state', 'color: #4CAF50', nextState);
      console.log('%c duration', 'color: gray', `${duration.toFixed(2)}ms`);
      console.groupEnd();
    } else {
      console.log(`[${action}]`, { prev: prevState, next: nextState, duration: `${duration.toFixed(2)}ms` });
    }
  };
}

/**
 * Persist middleware - saves state to localStorage
 *
 * @example
 * ```typescript
 * const store = createStore({
 *   state: loadPersistedState() ?? { count: 0 },
 *   actions: { increment: s => ({ count: s.count + 1 }) },
 *   middleware: [persistMiddleware({ key: 'my-app-state' })]
 * });
 * ```
 */
export function persistMiddleware<S>(options: {
  key: string;
  storage?: Storage;
  serialize?: (state: S) => string;
  deserialize?: (data: string) => S;
  debounce?: number;
}): Middleware<S> {
  const {
    key,
    storage = typeof localStorage !== 'undefined' ? localStorage : null,
    serialize = JSON.stringify,
    deserialize = JSON.parse,
    debounce = 100,
  } = options;

  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  return (context) => (next) => (action, ...args) => {
    next(action, ...args);

    if (!storage) return;

    // Debounce persistence
    if (timeoutId) clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      try {
        storage.setItem(key, serialize(context.getState()));
      } catch (error) {
        console.error('Failed to persist state:', error);
      }
    }, debounce);
  };
}

/**
 * Load persisted state from storage
 */
export function loadPersistedState<S>(options: {
  key: string;
  storage?: Storage;
  deserialize?: (data: string) => S;
}): S | null {
  const {
    key,
    storage = typeof localStorage !== 'undefined' ? localStorage : null,
    deserialize = JSON.parse,
  } = options;

  if (!storage) return null;

  try {
    const data = storage.getItem(key);
    if (data) {
      return deserialize(data);
    }
  } catch (error) {
    console.error('Failed to load persisted state:', error);
  }

  return null;
}

/**
 * Thunk middleware - enables async actions
 *
 * @example
 * ```typescript
 * const store = createStore({
 *   state: { data: null, loading: false },
 *   actions: {
 *     setLoading: (s, loading) => ({ ...s, loading }),
 *     setData: (s, data) => ({ ...s, data, loading: false })
 *   },
 *   middleware: [thunkMiddleware()]
 * });
 *
 * // Dispatch async action
 * store.dispatch('fetchData', async ({ dispatch }) => {
 *   dispatch('setLoading', true);
 *   const data = await fetch('/api/data').then(r => r.json());
 *   dispatch('setData', data);
 * });
 * ```
 */
export function thunkMiddleware<S>(): Middleware<S> {
  return (context) => (next) => (action, ...args) => {
    // Check if first arg is a function (thunk)
    if (typeof args[0] === 'function') {
      const thunk = args[0] as (ctx: MiddlewareContext<S>) => Promise<void> | void;
      return thunk(context);
    }
    return next(action, ...args);
  };
}

// =============================================================================
// UTILITIES
// =============================================================================

/**
 * Combine multiple stores into one
 */
export function combineStores<Stores extends Record<string, Store<any, any, any>>>(
  stores: Stores
): {
  getState: () => { [K in keyof Stores]: ReturnType<Stores[K]['getState']> };
  subscribe: (callback: (state: any) => void) => Unsubscribe;
} {
  const getState = () => {
    const combined: any = {};
    for (const key of Object.keys(stores)) {
      combined[key] = stores[key].getState();
    }
    return combined;
  };

  const subscribe = (callback: (state: any) => void) => {
    const unsubscribes = Object.values(stores).map((store) =>
      store.subscribe(() => callback(getState()))
    );
    return () => unsubscribes.forEach((unsub) => unsub());
  };

  return { getState, subscribe };
}

/**
 * Create a selector with dependencies (like reselect)
 */
export function createSelector<S, D extends any[], R>(
  dependencies: { [K in keyof D]: SelectorFn<S, D[K]> },
  combiner: (...deps: D) => R
): SelectorFn<S, R> {
  let lastDeps: D | undefined;
  let lastResult: R;
  let hasResult = false;

  return (state: S): R => {
    const deps = dependencies.map((dep) => dep(state)) as D;

    // Check if any dependency changed
    if (hasResult && lastDeps && deps.every((d, i) => Object.is(d, lastDeps![i]))) {
      return lastResult;
    }

    lastDeps = deps;
    lastResult = combiner(...deps);
    hasResult = true;
    return lastResult;
  };
}

// =============================================================================
// EXPORTS
// =============================================================================

export default {
  createStore,
  useStore,
  loggerMiddleware,
  persistMiddleware,
  loadPersistedState,
  thunkMiddleware,
  combineStores,
  createSelector,
};
