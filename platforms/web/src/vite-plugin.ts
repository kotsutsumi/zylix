/**
 * Zylix Vite Plugin - Hot Module Replacement with State Preservation
 *
 * Provides seamless HMR for Zylix components with automatic state preservation,
 * style hot reload, and error recovery.
 */

// =============================================================================
// Types
// =============================================================================

export interface ZylixPluginOptions {
  /**
   * Enable Hot Module Replacement
   * @default true
   */
  hmr?: boolean;

  /**
   * Preserve component state across HMR updates
   * @default true
   */
  preserveState?: boolean;

  /**
   * Enable DevTools integration
   * @default true in development
   */
  devtools?: boolean;

  /**
   * File extensions to process
   * @default ['.ts', '.tsx', '.js', '.jsx']
   */
  extensions?: string[];

  /**
   * Custom transform options
   */
  transform?: {
    /**
     * JSX pragma function name
     * @default 'h'
     */
    jsxPragma?: string;

    /**
     * JSX fragment pragma
     * @default 'Fragment'
     */
    jsxPragmaFrag?: string;
  };
}

interface VitePlugin {
  name: string;
  enforce?: 'pre' | 'post';
  configResolved?: (config: { command: string }) => void;
  transform?: (code: string, id: string) => string | null | { code: string; map?: unknown };
  handleHotUpdate?: (ctx: { file: string; modules: unknown[]; server: { ws: { send: (msg: unknown) => void } } }) => void;
}

// =============================================================================
// Vite Plugin
// =============================================================================

/**
 * Zylix Vite Plugin
 *
 * @example
 * ```ts
 * // vite.config.ts
 * import { defineConfig } from 'vite';
 * import { zylixPlugin } from 'zylix/vite';
 *
 * export default defineConfig({
 *   plugins: [
 *     zylixPlugin({
 *       hmr: true,
 *       preserveState: true,
 *       devtools: true
 *     })
 *   ]
 * });
 * ```
 */
export function zylixPlugin(options: ZylixPluginOptions = {}): VitePlugin {
  const opts: Required<ZylixPluginOptions> = {
    hmr: options.hmr ?? true,
    preserveState: options.preserveState ?? true,
    devtools: options.devtools ?? true,
    extensions: options.extensions ?? ['.ts', '.tsx', '.js', '.jsx'],
    transform: {
      jsxPragma: options.transform?.jsxPragma ?? 'h',
      jsxPragmaFrag: options.transform?.jsxPragmaFrag ?? 'Fragment',
    },
  };

  let isDev = false;

  return {
    name: 'vite-plugin-zylix',
    enforce: 'pre',

    configResolved(config) {
      isDev = config.command === 'serve';
    },

    transform(code: string, id: string) {
      // Only process relevant files
      if (!opts.extensions.some(ext => id.endsWith(ext))) {
        return null;
      }

      // Skip node_modules
      if (id.includes('node_modules')) {
        return null;
      }

      let transformedCode = code;

      // Add HMR support
      if (isDev && opts.hmr) {
        transformedCode = injectHMR(transformedCode, id, opts);
      }

      // Add DevTools integration
      if (isDev && opts.devtools) {
        transformedCode = injectDevTools(transformedCode, id);
      }

      return {
        code: transformedCode,
        map: null,
      };
    },

    handleHotUpdate(ctx) {
      if (!opts.hmr) return;

      const { file, server } = ctx;

      // Handle Zylix-specific file updates
      if (opts.extensions.some(ext => file.endsWith(ext))) {
        // Notify client of Zylix component update
        server.ws.send({
          type: 'custom',
          event: 'zylix:update',
          data: {
            file,
            timestamp: Date.now(),
            preserveState: opts.preserveState,
          },
        });
      }
    },
  };
}

// =============================================================================
// HMR Injection
// =============================================================================

/**
 * Inject HMR support into the code
 */
function injectHMR(code: string, id: string, opts: Required<ZylixPluginOptions>): string {
  // Check if file exports components
  const hasExports = /export\s+(default\s+)?(function|const|class)\s+\w+/g.test(code);
  if (!hasExports) return code;

  // Generate unique module ID
  const moduleId = generateModuleId(id);

  // Create HMR wrapper
  const hmrCode = `
// Zylix HMR Runtime
if (import.meta.hot) {
  const __ZYLIX_MODULE_ID__ = '${moduleId}';
  const __ZYLIX_PRESERVE_STATE__ = ${opts.preserveState};

  // State storage for HMR
  if (!window.__ZYLIX_HMR_STATE__) {
    window.__ZYLIX_HMR_STATE__ = new Map();
  }

  // Save state before update
  import.meta.hot.on('zylix:before-update', () => {
    if (__ZYLIX_PRESERVE_STATE__ && window.__ZYLIX_CURRENT_STATES__) {
      window.__ZYLIX_HMR_STATE__.set(__ZYLIX_MODULE_ID__, window.__ZYLIX_CURRENT_STATES__);
      console.log('[Zylix HMR] State preserved for', __ZYLIX_MODULE_ID__);
    }
  });

  // Restore state after update
  import.meta.hot.on('zylix:after-update', () => {
    if (__ZYLIX_PRESERVE_STATE__) {
      const savedState = window.__ZYLIX_HMR_STATE__.get(__ZYLIX_MODULE_ID__);
      if (savedState && window.__ZYLIX_RESTORE_STATES__) {
        window.__ZYLIX_RESTORE_STATES__(savedState);
        console.log('[Zylix HMR] State restored for', __ZYLIX_MODULE_ID__);
      }
    }
  });

  // Handle custom events
  import.meta.hot.on('zylix:update', (data) => {
    console.log('[Zylix HMR] Component updated:', data.file);
  });

  // Accept HMR
  import.meta.hot.accept((newModule) => {
    if (newModule) {
      console.log('[Zylix HMR] Module updated:', __ZYLIX_MODULE_ID__);
      // Trigger re-render with new module
      if (window.__ZYLIX_HMR_UPDATE__) {
        window.__ZYLIX_HMR_UPDATE__(__ZYLIX_MODULE_ID__, newModule);
      }
    }
  });
}
`;

  return code + '\n' + hmrCode;
}

/**
 * Inject DevTools integration
 */
function injectDevTools(code: string, _id: string): string {
  // Check if already has devtools import
  if (code.includes('zylix/devtools') || code.includes('enableDevTools')) {
    return code;
  }

  // Check if this is the main entry file (has render call)
  const hasRender = /render\s*\(/.test(code);
  if (!hasRender) return code;

  // Add devtools initialization
  const devtoolsCode = `
// Zylix DevTools Auto-Init
if (typeof window !== 'undefined' && import.meta.env?.DEV) {
  import('zylix/devtools').then(({ enableDevTools }) => {
    enableDevTools({ trace: true });
    console.log('[Zylix] DevTools enabled. Press Cmd/Ctrl+Shift+Z to toggle.');
  }).catch(() => {
    // DevTools not available
  });
}
`;

  // Insert at the beginning of the file
  return devtoolsCode + '\n' + code;
}

/**
 * Generate a unique module ID from file path
 */
function generateModuleId(filePath: string): string {
  // Extract filename without extension
  const parts = filePath.split('/');
  const filename = parts[parts.length - 1].replace(/\.[^.]+$/, '');
  // Create a short hash
  let hash = 0;
  for (let i = 0; i < filePath.length; i++) {
    hash = ((hash << 5) - hash) + filePath.charCodeAt(i);
    hash = hash & hash;
  }
  return `${filename}_${Math.abs(hash).toString(36).substring(0, 6)}`;
}

// =============================================================================
// HMR Runtime (to be included in client bundle)
// =============================================================================

/**
 * HMR Runtime for Zylix
 * This should be imported in the client entry point
 */
export function initHMRRuntime(): void {
  if (typeof window === 'undefined') return;

  type WindowWithZylix = Window & {
    __ZYLIX_HMR_STATE__: Map<string, unknown>;
    __ZYLIX_CURRENT_STATES__: unknown;
    __ZYLIX_RESTORE_STATES__: ((state: unknown) => void) | null;
    __ZYLIX_HMR_UPDATE__: ((moduleId: string, newModule: unknown) => void) | null;
    __ZYLIX_HMR_COMPONENTS__: Map<string, Set<() => void>>;
  };

  const win = window as unknown as WindowWithZylix;

  // Initialize HMR state storage
  if (!win.__ZYLIX_HMR_STATE__) {
    win.__ZYLIX_HMR_STATE__ = new Map();
  }

  // Initialize component registry
  if (!win.__ZYLIX_HMR_COMPONENTS__) {
    win.__ZYLIX_HMR_COMPONENTS__ = new Map();
  }

  // HMR update handler
  win.__ZYLIX_HMR_UPDATE__ = (moduleId: string, _newModule: unknown) => {
    console.log(`[Zylix HMR] Updating module: ${moduleId}`);

    // Get registered update handlers for this module
    const handlers = win.__ZYLIX_HMR_COMPONENTS__.get(moduleId);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler();
        } catch (error) {
          console.error('[Zylix HMR] Update error:', error);
        }
      });
    }
  };

  // Register component for HMR updates
  win.__ZYLIX_HMR_COMPONENTS__.set = function(moduleId: string, handlers: Set<() => void>) {
    Map.prototype.set.call(this, moduleId, handlers);
    return this;
  };

  console.log('[Zylix HMR] Runtime initialized');
}

// =============================================================================
// State Preservation Utilities
// =============================================================================

/**
 * Create a state snapshot for HMR
 */
export function createStateSnapshot<T>(state: T): string {
  try {
    return JSON.stringify(state);
  } catch {
    console.warn('[Zylix HMR] Failed to serialize state');
    return '{}';
  }
}

/**
 * Restore state from snapshot
 */
export function restoreStateSnapshot<T>(snapshot: string): T | null {
  try {
    return JSON.parse(snapshot);
  } catch {
    console.warn('[Zylix HMR] Failed to restore state');
    return null;
  }
}

/**
 * Register a component for HMR
 */
export function registerHMR(moduleId: string, updateFn: () => void): () => void {
  if (typeof window === 'undefined') return () => {};

  type WindowWithHMR = Window & {
    __ZYLIX_HMR_COMPONENTS__?: Map<string, Set<() => void>>;
  };

  const win = window as WindowWithHMR;
  if (!win.__ZYLIX_HMR_COMPONENTS__) {
    win.__ZYLIX_HMR_COMPONENTS__ = new Map();
  }

  let handlers = win.__ZYLIX_HMR_COMPONENTS__.get(moduleId);
  if (!handlers) {
    handlers = new Set();
    win.__ZYLIX_HMR_COMPONENTS__.set(moduleId, handlers);
  }

  handlers.add(updateFn);

  // Return cleanup function
  return () => {
    handlers?.delete(updateFn);
  };
}

// =============================================================================
// Error Recovery
// =============================================================================

/**
 * Error overlay for development
 */
export function showErrorOverlay(error: Error): void {
  if (typeof document === 'undefined') return;

  // Remove existing overlay
  const existing = document.getElementById('zylix-error-overlay');
  if (existing) {
    existing.remove();
  }

  const overlay = document.createElement('div');
  overlay.id = 'zylix-error-overlay';
  overlay.innerHTML = `
    <style>
      #zylix-error-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.9);
        color: #ff5555;
        font-family: monospace;
        padding: 20px;
        z-index: 999999;
        overflow: auto;
      }
      #zylix-error-overlay h1 {
        color: #ff5555;
        margin-bottom: 16px;
      }
      #zylix-error-overlay pre {
        background: #1a1a1a;
        padding: 16px;
        border-radius: 8px;
        overflow: auto;
        white-space: pre-wrap;
        word-break: break-word;
      }
      #zylix-error-overlay .stack {
        color: #888;
        margin-top: 16px;
      }
      #zylix-error-overlay button {
        margin-top: 16px;
        padding: 8px 16px;
        background: #333;
        border: 1px solid #555;
        color: #fff;
        border-radius: 4px;
        cursor: pointer;
      }
      #zylix-error-overlay button:hover {
        background: #444;
      }
    </style>
    <h1>Zylix Error</h1>
    <pre>${escapeHtml(error.message)}</pre>
    <div class="stack">
      <pre>${escapeHtml(error.stack || '')}</pre>
    </div>
    <button onclick="document.getElementById('zylix-error-overlay').remove()">Dismiss</button>
    <button onclick="location.reload()">Reload</button>
  `;

  document.body.appendChild(overlay);
}

/**
 * Clear error overlay
 */
export function clearErrorOverlay(): void {
  if (typeof document === 'undefined') return;

  const overlay = document.getElementById('zylix-error-overlay');
  if (overlay) {
    overlay.remove();
  }
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// =============================================================================
// Default Export
// =============================================================================

export default zylixPlugin;
