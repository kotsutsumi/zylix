/**
 * Zylix DevTools - Developer Experience Tools
 *
 * Provides state inspection, action history, time-travel debugging,
 * performance profiling, and component tree visualization.
 */

// =============================================================================
// Types
// =============================================================================

export interface DevToolsConfig {
  maxHistory?: number;
  trace?: boolean;
  persist?: boolean;
  collapsed?: boolean;
  position?: 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left';
  theme?: 'dark' | 'light' | 'auto';
}

export interface ActionRecord {
  id: number;
  type: string;
  payload: unknown;
  timestamp: number;
  stateBefore: unknown;
  stateAfter: unknown;
  duration: number;
}

export interface PerformanceMetrics {
  renders: number;
  lastRenderTime: number;
  averageRenderTime: number;
  peakRenderTime: number;
  totalRenderTime: number;
  fps: number;
  memoryUsage?: number;
}

export interface ComponentNode {
  id: string;
  name: string;
  props: Record<string, unknown>;
  state: unknown;
  children: ComponentNode[];
  renderCount: number;
  lastRenderTime: number;
}

interface DevToolsState {
  enabled: boolean;
  visible: boolean;
  activeTab: 'state' | 'actions' | 'components' | 'performance' | 'network';
  selectedStore: string | null;
  selectedAction: number | null;
  historyIndex: number;
}

// =============================================================================
// DevTools Core
// =============================================================================

class ZylixDevTools {
  private config: Required<DevToolsConfig>;
  private stores: Map<string, { getState: () => unknown; setState: (state: unknown) => void }> = new Map();
  private actionHistory: ActionRecord[] = [];
  private actionIdCounter = 0;
  private performanceMetrics: PerformanceMetrics = {
    renders: 0,
    lastRenderTime: 0,
    averageRenderTime: 0,
    peakRenderTime: 0,
    totalRenderTime: 0,
    fps: 60,
  };
  private componentTree: ComponentNode | null = null;
  private networkRequests: Array<{ id: number; method: string; url: string; status: number; duration: number; timestamp: number }> = [];
  private state: DevToolsState = {
    enabled: false,
    visible: false,
    activeTab: 'state',
    selectedStore: null,
    selectedAction: null,
    historyIndex: -1,
  };
  private listeners: Set<() => void> = new Set();
  private panel: HTMLElement | null = null;
  private frameCount = 0;
  private lastFpsUpdate = 0;

  constructor(config: DevToolsConfig = {}) {
    this.config = {
      maxHistory: config.maxHistory ?? 50,
      trace: config.trace ?? true,
      persist: config.persist ?? false,
      collapsed: config.collapsed ?? true,
      position: config.position ?? 'bottom-right',
      theme: config.theme ?? 'auto',
    };

    // Restore persisted state
    if (this.config.persist && typeof localStorage !== 'undefined') {
      try {
        const saved = localStorage.getItem('zylix-devtools-state');
        if (saved) {
          const parsed = JSON.parse(saved);
          this.state = { ...this.state, ...parsed };
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Start FPS monitoring
    this.startFpsMonitoring();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /**
   * Enable DevTools
   */
  enable(): void {
    this.state.enabled = true;
    this.notify();
    this.log('DevTools enabled');
  }

  /**
   * Disable DevTools
   */
  disable(): void {
    this.state.enabled = false;
    this.hidePanel();
    this.notify();
    this.log('DevTools disabled');
  }

  /**
   * Toggle DevTools visibility
   */
  toggle(): void {
    if (this.state.visible) {
      this.hidePanel();
    } else {
      this.showPanel();
    }
  }

  /**
   * Show DevTools panel
   */
  showPanel(): void {
    if (!this.state.enabled) {
      this.enable();
    }
    this.state.visible = true;
    this.renderPanel();
    this.notify();
  }

  /**
   * Hide DevTools panel
   */
  hidePanel(): void {
    this.state.visible = false;
    if (this.panel) {
      this.panel.remove();
      this.panel = null;
    }
    this.notify();
  }

  /**
   * Connect a store for inspection
   */
  connectStore(name: string, store: { getState: () => unknown; setState?: (state: unknown) => void }): () => void {
    this.stores.set(name, {
      getState: store.getState,
      setState: store.setState || (() => {}),
    });
    if (!this.state.selectedStore) {
      this.state.selectedStore = name;
    }
    this.notify();
    this.log(`Store "${name}" connected`);

    return () => {
      this.stores.delete(name);
      if (this.state.selectedStore === name) {
        this.state.selectedStore = this.stores.size > 0 ? this.stores.keys().next().value : null;
      }
      this.notify();
    };
  }

  /**
   * Record an action
   */
  recordAction(type: string, payload: unknown, stateBefore: unknown, stateAfter: unknown, duration: number): void {
    if (!this.state.enabled) return;

    const record: ActionRecord = {
      id: ++this.actionIdCounter,
      type,
      payload,
      timestamp: Date.now(),
      stateBefore,
      stateAfter,
      duration,
    };

    this.actionHistory.push(record);

    // Trim history if needed
    while (this.actionHistory.length > this.config.maxHistory) {
      this.actionHistory.shift();
    }

    this.state.historyIndex = this.actionHistory.length - 1;

    if (this.config.trace) {
      this.log(`Action: ${type}`, { payload, duration: `${duration.toFixed(2)}ms` });
    }

    this.notify();
  }

  /**
   * Time travel to a specific action
   */
  jumpTo(actionId: number): void {
    const index = this.actionHistory.findIndex(a => a.id === actionId);
    if (index === -1) return;

    const action = this.actionHistory[index];
    const storeName = this.state.selectedStore;
    if (!storeName) return;

    const store = this.stores.get(storeName);
    if (!store) return;

    // Apply state from that point in history
    store.setState(action.stateAfter);
    this.state.historyIndex = index;
    this.notify();
    this.log(`Jumped to action #${actionId}`);
  }

  /**
   * Undo last action
   */
  undo(): void {
    if (this.state.historyIndex <= 0) return;

    const prevAction = this.actionHistory[this.state.historyIndex - 1];
    const storeName = this.state.selectedStore;
    if (!storeName) return;

    const store = this.stores.get(storeName);
    if (!store) return;

    store.setState(prevAction.stateAfter);
    this.state.historyIndex--;
    this.notify();
    this.log('Undo');
  }

  /**
   * Redo next action
   */
  redo(): void {
    if (this.state.historyIndex >= this.actionHistory.length - 1) return;

    const nextAction = this.actionHistory[this.state.historyIndex + 1];
    const storeName = this.state.selectedStore;
    if (!storeName) return;

    const store = this.stores.get(storeName);
    if (!store) return;

    store.setState(nextAction.stateAfter);
    this.state.historyIndex++;
    this.notify();
    this.log('Redo');
  }

  /**
   * Clear action history
   */
  clearHistory(): void {
    this.actionHistory = [];
    this.state.historyIndex = -1;
    this.state.selectedAction = null;
    this.notify();
    this.log('History cleared');
  }

  /**
   * Record render performance
   */
  recordRender(duration: number): void {
    this.performanceMetrics.renders++;
    this.performanceMetrics.lastRenderTime = duration;
    this.performanceMetrics.totalRenderTime += duration;
    this.performanceMetrics.averageRenderTime =
      this.performanceMetrics.totalRenderTime / this.performanceMetrics.renders;
    if (duration > this.performanceMetrics.peakRenderTime) {
      this.performanceMetrics.peakRenderTime = duration;
    }
    this.notify();
  }

  /**
   * Update component tree
   */
  updateComponentTree(tree: ComponentNode): void {
    this.componentTree = tree;
    this.notify();
  }

  /**
   * Record network request
   */
  recordNetworkRequest(method: string, url: string, status: number, duration: number): void {
    this.networkRequests.push({
      id: Date.now(),
      method,
      url,
      status,
      duration,
      timestamp: Date.now(),
    });

    // Keep last 100 requests
    while (this.networkRequests.length > 100) {
      this.networkRequests.shift();
    }

    this.notify();
  }

  /**
   * Get current state
   */
  getState(): DevToolsState {
    return { ...this.state };
  }

  /**
   * Get action history
   */
  getHistory(): ActionRecord[] {
    return [...this.actionHistory];
  }

  /**
   * Get performance metrics
   */
  getPerformanceMetrics(): PerformanceMetrics {
    return { ...this.performanceMetrics };
  }

  /**
   * Get all connected stores
   */
  getStores(): string[] {
    return Array.from(this.stores.keys());
  }

  /**
   * Get store state by name
   */
  getStoreState(name: string): unknown {
    const store = this.stores.get(name);
    return store ? store.getState() : null;
  }

  /**
   * Subscribe to changes
   */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * Export state for debugging
   */
  exportState(): string {
    const data = {
      stores: Object.fromEntries(
        Array.from(this.stores.entries()).map(([name, store]) => [name, store.getState()])
      ),
      actions: this.actionHistory,
      performance: this.performanceMetrics,
      network: this.networkRequests,
    };
    return JSON.stringify(data, null, 2);
  }

  /**
   * Import state
   */
  importState(json: string): void {
    try {
      const data = JSON.parse(json);
      if (data.actions) {
        this.actionHistory = data.actions;
        this.state.historyIndex = this.actionHistory.length - 1;
      }
      this.notify();
      this.log('State imported');
    } catch (e) {
      console.error('Failed to import state:', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private Methods
  // ---------------------------------------------------------------------------

  private notify(): void {
    this.listeners.forEach(listener => listener());
    if (this.state.visible) {
      this.renderPanel();
    }
    this.persistState();
  }

  private persistState(): void {
    if (this.config.persist && typeof localStorage !== 'undefined') {
      try {
        localStorage.setItem('zylix-devtools-state', JSON.stringify({
          visible: this.state.visible,
          activeTab: this.state.activeTab,
          selectedStore: this.state.selectedStore,
        }));
      } catch (e) {
        // Ignore storage errors
      }
    }
  }

  private log(message: string, data?: unknown): void {
    if (this.config.trace) {
      if (data) {
        console.log(`%c[Zylix DevTools] ${message}`, 'color: #3b82f6; font-weight: bold;', data);
      } else {
        console.log(`%c[Zylix DevTools] ${message}`, 'color: #3b82f6; font-weight: bold;');
      }
    }
  }

  private startFpsMonitoring(): void {
    if (typeof requestAnimationFrame === 'undefined') return;

    const measureFps = (timestamp: number) => {
      this.frameCount++;

      if (timestamp - this.lastFpsUpdate >= 1000) {
        this.performanceMetrics.fps = Math.round(this.frameCount * 1000 / (timestamp - this.lastFpsUpdate));
        this.frameCount = 0;
        this.lastFpsUpdate = timestamp;
      }

      if (this.state.enabled) {
        requestAnimationFrame(measureFps);
      }
    };

    requestAnimationFrame(measureFps);
  }

  private getTheme(): 'dark' | 'light' {
    if (this.config.theme === 'auto') {
      return typeof matchMedia !== 'undefined' && matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light';
    }
    return this.config.theme;
  }

  private getPositionStyles(): Record<string, string> {
    const positions: Record<string, Record<string, string>> = {
      'bottom-right': { bottom: '16px', right: '16px' },
      'bottom-left': { bottom: '16px', left: '16px' },
      'top-right': { top: '16px', right: '16px' },
      'top-left': { top: '16px', left: '16px' },
    };
    return positions[this.config.position];
  }

  private renderPanel(): void {
    if (typeof document === 'undefined') return;

    if (!this.panel) {
      this.panel = document.createElement('div');
      this.panel.id = 'zylix-devtools';
      document.body.appendChild(this.panel);
    }

    const isDark = this.getTheme() === 'dark';
    const positionStyles = this.getPositionStyles();

    const colors = isDark
      ? { bg: '#1e1e1e', surface: '#252526', border: '#3c3c3c', text: '#cccccc', textMuted: '#858585', accent: '#3b82f6', success: '#10b981', warning: '#f59e0b', danger: '#ef4444' }
      : { bg: '#ffffff', surface: '#f5f5f5', border: '#e0e0e0', text: '#333333', textMuted: '#666666', accent: '#3b82f6', success: '#10b981', warning: '#f59e0b', danger: '#ef4444' };

    const tabs = [
      { id: 'state', icon: '📊', label: 'State' },
      { id: 'actions', icon: '🔄', label: 'Actions' },
      { id: 'components', icon: '🌳', label: 'Components' },
      { id: 'performance', icon: '⚡', label: 'Performance' },
      { id: 'network', icon: '🌐', label: 'Network' },
    ];

    this.panel.innerHTML = `
      <style>
        #zylix-devtools {
          position: fixed;
          ${Object.entries(positionStyles).map(([k, v]) => `${k}: ${v};`).join(' ')}
          width: 400px;
          max-height: 500px;
          background: ${colors.bg};
          border: 1px solid ${colors.border};
          border-radius: 8px;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace;
          font-size: 12px;
          color: ${colors.text};
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
          z-index: 999999;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }
        #zylix-devtools * { box-sizing: border-box; }
        .zdt-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 8px 12px;
          background: ${colors.surface};
          border-bottom: 1px solid ${colors.border};
        }
        .zdt-title {
          font-weight: 600;
          color: ${colors.accent};
        }
        .zdt-close {
          background: none;
          border: none;
          color: ${colors.textMuted};
          cursor: pointer;
          font-size: 16px;
          padding: 0 4px;
        }
        .zdt-close:hover { color: ${colors.text}; }
        .zdt-tabs {
          display: flex;
          border-bottom: 1px solid ${colors.border};
          background: ${colors.surface};
        }
        .zdt-tab {
          flex: 1;
          padding: 8px;
          text-align: center;
          cursor: pointer;
          border: none;
          background: none;
          color: ${colors.textMuted};
          border-bottom: 2px solid transparent;
          font-size: 11px;
        }
        .zdt-tab:hover { color: ${colors.text}; background: ${colors.bg}; }
        .zdt-tab.active { color: ${colors.accent}; border-bottom-color: ${colors.accent}; }
        .zdt-content {
          flex: 1;
          overflow: auto;
          padding: 12px;
          max-height: 400px;
        }
        .zdt-section {
          margin-bottom: 12px;
        }
        .zdt-section-title {
          font-weight: 600;
          margin-bottom: 8px;
          color: ${colors.textMuted};
          text-transform: uppercase;
          font-size: 10px;
        }
        .zdt-store-select {
          width: 100%;
          padding: 6px 8px;
          background: ${colors.surface};
          border: 1px solid ${colors.border};
          border-radius: 4px;
          color: ${colors.text};
          font-size: 12px;
          margin-bottom: 8px;
        }
        .zdt-tree {
          font-family: monospace;
          font-size: 11px;
          line-height: 1.5;
          white-space: pre-wrap;
          word-break: break-all;
        }
        .zdt-key { color: ${colors.accent}; }
        .zdt-string { color: ${colors.success}; }
        .zdt-number { color: ${colors.warning}; }
        .zdt-boolean { color: ${colors.danger}; }
        .zdt-null { color: ${colors.textMuted}; }
        .zdt-action-list {
          list-style: none;
          margin: 0;
          padding: 0;
        }
        .zdt-action-item {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 6px 8px;
          border-radius: 4px;
          cursor: pointer;
          margin-bottom: 4px;
          background: ${colors.surface};
        }
        .zdt-action-item:hover { background: ${colors.border}; }
        .zdt-action-item.active { background: ${colors.accent}20; border-left: 3px solid ${colors.accent}; }
        .zdt-action-id { color: ${colors.textMuted}; font-size: 10px; min-width: 24px; }
        .zdt-action-type { flex: 1; font-weight: 500; }
        .zdt-action-time { color: ${colors.textMuted}; font-size: 10px; }
        .zdt-toolbar {
          display: flex;
          gap: 4px;
          margin-bottom: 8px;
        }
        .zdt-btn {
          padding: 4px 8px;
          border: 1px solid ${colors.border};
          border-radius: 4px;
          background: ${colors.surface};
          color: ${colors.text};
          cursor: pointer;
          font-size: 11px;
        }
        .zdt-btn:hover { background: ${colors.bg}; }
        .zdt-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .zdt-metrics {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 8px;
        }
        .zdt-metric {
          background: ${colors.surface};
          padding: 12px;
          border-radius: 4px;
        }
        .zdt-metric-value {
          font-size: 18px;
          font-weight: 600;
          color: ${colors.accent};
        }
        .zdt-metric-label {
          font-size: 10px;
          color: ${colors.textMuted};
          text-transform: uppercase;
        }
        .zdt-network-list {
          list-style: none;
          margin: 0;
          padding: 0;
        }
        .zdt-network-item {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 6px 8px;
          border-radius: 4px;
          margin-bottom: 4px;
          background: ${colors.surface};
          font-size: 11px;
        }
        .zdt-network-method {
          font-weight: 600;
          min-width: 40px;
        }
        .zdt-network-method.GET { color: ${colors.success}; }
        .zdt-network-method.POST { color: ${colors.accent}; }
        .zdt-network-method.PUT { color: ${colors.warning}; }
        .zdt-network-method.DELETE { color: ${colors.danger}; }
        .zdt-network-url {
          flex: 1;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        .zdt-network-status {
          padding: 2px 6px;
          border-radius: 3px;
          font-size: 10px;
        }
        .zdt-network-status.success { background: ${colors.success}20; color: ${colors.success}; }
        .zdt-network-status.error { background: ${colors.danger}20; color: ${colors.danger}; }
        .zdt-empty {
          text-align: center;
          color: ${colors.textMuted};
          padding: 20px;
        }
      </style>
      <div class="zdt-header">
        <span class="zdt-title">Zylix DevTools</span>
        <button class="zdt-close" onclick="window.__ZYLIX_DEVTOOLS__.hidePanel()">×</button>
      </div>
      <div class="zdt-tabs">
        ${tabs.map(tab => `
          <button class="zdt-tab ${this.state.activeTab === tab.id ? 'active' : ''}"
                  onclick="window.__ZYLIX_DEVTOOLS__.setActiveTab('${tab.id}')">
            ${tab.icon} ${tab.label}
          </button>
        `).join('')}
      </div>
      <div class="zdt-content">
        ${this.renderTabContent()}
      </div>
    `;

    // Expose to window for button handlers
    (window as unknown as { __ZYLIX_DEVTOOLS__: ZylixDevTools }).__ZYLIX_DEVTOOLS__ = this;
  }

  setActiveTab(tab: DevToolsState['activeTab']): void {
    this.state.activeTab = tab;
    this.notify();
  }

  private renderTabContent(): string {
    switch (this.state.activeTab) {
      case 'state':
        return this.renderStateTab();
      case 'actions':
        return this.renderActionsTab();
      case 'components':
        return this.renderComponentsTab();
      case 'performance':
        return this.renderPerformanceTab();
      case 'network':
        return this.renderNetworkTab();
      default:
        return '';
    }
  }

  private renderStateTab(): string {
    const storeNames = Array.from(this.stores.keys());
    if (storeNames.length === 0) {
      return '<div class="zdt-empty">No stores connected</div>';
    }

    const selectedStore = this.state.selectedStore || storeNames[0];
    const state = this.getStoreState(selectedStore);

    return `
      <div class="zdt-section">
        <select class="zdt-store-select" onchange="window.__ZYLIX_DEVTOOLS__.selectStore(this.value)">
          ${storeNames.map(name => `<option value="${name}" ${name === selectedStore ? 'selected' : ''}>${name}</option>`).join('')}
        </select>
        <div class="zdt-tree">${this.formatValue(state)}</div>
      </div>
    `;
  }

  selectStore(name: string): void {
    this.state.selectedStore = name;
    this.notify();
  }

  private renderActionsTab(): string {
    if (this.actionHistory.length === 0) {
      return '<div class="zdt-empty">No actions recorded</div>';
    }

    const canUndo = this.state.historyIndex > 0;
    const canRedo = this.state.historyIndex < this.actionHistory.length - 1;

    return `
      <div class="zdt-toolbar">
        <button class="zdt-btn" ${canUndo ? '' : 'disabled'} onclick="window.__ZYLIX_DEVTOOLS__.undo()">⟲ Undo</button>
        <button class="zdt-btn" ${canRedo ? '' : 'disabled'} onclick="window.__ZYLIX_DEVTOOLS__.redo()">↺ Redo</button>
        <button class="zdt-btn" onclick="window.__ZYLIX_DEVTOOLS__.clearHistory()">🗑 Clear</button>
      </div>
      <ul class="zdt-action-list">
        ${this.actionHistory.slice().reverse().map((action, idx) => {
          const realIdx = this.actionHistory.length - 1 - idx;
          return `
            <li class="zdt-action-item ${realIdx === this.state.historyIndex ? 'active' : ''}"
                onclick="window.__ZYLIX_DEVTOOLS__.jumpTo(${action.id})">
              <span class="zdt-action-id">#${action.id}</span>
              <span class="zdt-action-type">${action.type}</span>
              <span class="zdt-action-time">${action.duration.toFixed(1)}ms</span>
            </li>
          `;
        }).join('')}
      </ul>
    `;
  }

  private renderComponentsTab(): string {
    if (!this.componentTree) {
      return '<div class="zdt-empty">No component tree available</div>';
    }

    const renderNode = (node: ComponentNode, depth: number): string => {
      const indent = '  '.repeat(depth);
      const childrenHtml = node.children.map(child => renderNode(child, depth + 1)).join('');
      return `${indent}&lt;${node.name}&gt;\n${childrenHtml}`;
    };

    return `<div class="zdt-tree">${renderNode(this.componentTree, 0)}</div>`;
  }

  private renderPerformanceTab(): string {
    const m = this.performanceMetrics;

    return `
      <div class="zdt-metrics">
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.fps}</div>
          <div class="zdt-metric-label">FPS</div>
        </div>
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.renders}</div>
          <div class="zdt-metric-label">Renders</div>
        </div>
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.lastRenderTime.toFixed(2)}ms</div>
          <div class="zdt-metric-label">Last Render</div>
        </div>
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.averageRenderTime.toFixed(2)}ms</div>
          <div class="zdt-metric-label">Avg Render</div>
        </div>
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.peakRenderTime.toFixed(2)}ms</div>
          <div class="zdt-metric-label">Peak Render</div>
        </div>
        <div class="zdt-metric">
          <div class="zdt-metric-value">${m.memoryUsage ? `${(m.memoryUsage / 1024 / 1024).toFixed(1)}MB` : 'N/A'}</div>
          <div class="zdt-metric-label">Memory</div>
        </div>
      </div>
    `;
  }

  private renderNetworkTab(): string {
    if (this.networkRequests.length === 0) {
      return '<div class="zdt-empty">No network requests</div>';
    }

    return `
      <ul class="zdt-network-list">
        ${this.networkRequests.slice().reverse().map(req => `
          <li class="zdt-network-item">
            <span class="zdt-network-method ${req.method}">${req.method}</span>
            <span class="zdt-network-url" title="${req.url}">${new URL(req.url, window.location.origin).pathname}</span>
            <span class="zdt-network-status ${req.status >= 200 && req.status < 300 ? 'success' : 'error'}">${req.status}</span>
            <span>${req.duration.toFixed(0)}ms</span>
          </li>
        `).join('')}
      </ul>
    `;
  }

  private formatValue(value: unknown, depth = 0): string {
    if (depth > 10) return '<span class="zdt-null">...</span>';

    if (value === null) return '<span class="zdt-null">null</span>';
    if (value === undefined) return '<span class="zdt-null">undefined</span>';

    if (typeof value === 'string') {
      return `<span class="zdt-string">"${this.escapeHtml(value)}"</span>`;
    }
    if (typeof value === 'number') {
      return `<span class="zdt-number">${value}</span>`;
    }
    if (typeof value === 'boolean') {
      return `<span class="zdt-boolean">${value}</span>`;
    }

    if (Array.isArray(value)) {
      if (value.length === 0) return '[]';
      const items = value.map((v, i) => `${i}: ${this.formatValue(v, depth + 1)}`).join(',\n');
      return `[\n${items}\n]`;
    }

    if (typeof value === 'object') {
      const entries = Object.entries(value);
      if (entries.length === 0) return '{}';
      const items = entries.map(([k, v]) =>
        `<span class="zdt-key">"${this.escapeHtml(k)}"</span>: ${this.formatValue(v, depth + 1)}`
      ).join(',\n');
      return `{\n${items}\n}`;
    }

    return String(value);
  }

  private escapeHtml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}

// =============================================================================
// Singleton Instance
// =============================================================================

let devToolsInstance: ZylixDevTools | null = null;

/**
 * Get or create the DevTools instance
 */
export function getDevTools(): ZylixDevTools {
  if (!devToolsInstance) {
    devToolsInstance = new ZylixDevTools();
  }
  return devToolsInstance;
}

/**
 * Enable DevTools with optional configuration
 */
export function enableDevTools(config?: DevToolsConfig): ZylixDevTools {
  if (devToolsInstance) {
    devToolsInstance.enable();
    return devToolsInstance;
  }
  devToolsInstance = new ZylixDevTools(config);
  devToolsInstance.enable();
  return devToolsInstance;
}

/**
 * Connect a store to DevTools
 */
export function connectStore(name: string, store: { getState: () => unknown; setState?: (state: unknown) => void }): () => void {
  return getDevTools().connectStore(name, store);
}

/**
 * Record an action
 */
export function recordAction(type: string, payload: unknown, stateBefore: unknown, stateAfter: unknown, duration: number): void {
  getDevTools().recordAction(type, payload, stateBefore, stateAfter, duration);
}

/**
 * Record render performance
 */
export function recordRender(duration: number): void {
  getDevTools().recordRender(duration);
}

/**
 * Record network request
 */
export function recordNetworkRequest(method: string, url: string, status: number, duration: number): void {
  getDevTools().recordNetworkRequest(method, url, status, duration);
}

// =============================================================================
// Keyboard Shortcut
// =============================================================================

if (typeof window !== 'undefined') {
  window.addEventListener('keydown', (e) => {
    // Cmd/Ctrl + Shift + Z to toggle DevTools
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'Z') {
      e.preventDefault();
      getDevTools().toggle();
    }
  });
}

// Export class for type usage
export { ZylixDevTools };
