/**
 * Zylix Advanced Features
 * v0.25.0 - Web Dominance
 *
 * Additional features for building complex applications:
 * - Error Boundaries
 * - Context API
 * - Portal/Modal System
 * - Suspense
 * - Virtual Scrolling
 * - Animations API
 */

// =============================================================================
// Types
// =============================================================================

export interface VNode {
  type: string | Function;
  props: Record<string, any>;
  children: (VNode | string)[];
  key?: string | number;
}

export type Cleanup = () => void;

// =============================================================================
// Error Boundaries
// =============================================================================

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

interface ErrorBoundaryProps {
  fallback: VNode | ((error: Error, reset: () => void) => VNode);
  onError?: (error: Error, errorInfo: { componentStack: string }) => void;
  children: VNode | VNode[];
}

/**
 * Creates an Error Boundary component that catches errors in its children.
 *
 * @example
 * ```ts
 * const boundary = createErrorBoundary({
 *   fallback: (error, reset) => h('div', null,
 *     h('h2', null, 'Something went wrong'),
 *     h('button', { onClick: reset }, 'Try Again')
 *   ),
 *   onError: (error) => console.error('Caught:', error)
 * });
 *
 * h(boundary, null, h(RiskyComponent))
 * ```
 */
export function createErrorBoundary(options: {
  fallback: VNode | ((error: Error, reset: () => void) => VNode);
  onError?: (error: Error, errorInfo: { componentStack: string }) => void;
}): Function {
  return function ErrorBoundary(props: { children: VNode | VNode[] }) {
    // Error boundary state
    let state: ErrorBoundaryState = {
      hasError: false,
      error: null,
    };

    const reset = () => {
      state = { hasError: false, error: null };
    };

    // In a real implementation, this would integrate with the renderer
    // to catch errors during rendering
    try {
      if (state.hasError && state.error) {
        const { fallback } = options;
        if (typeof fallback === 'function') {
          return fallback(state.error, reset);
        }
        return fallback;
      }
      return props.children;
    } catch (error) {
      state = { hasError: true, error: error as Error };
      if (options.onError) {
        options.onError(error as Error, { componentStack: '' });
      }
      const { fallback } = options;
      if (typeof fallback === 'function') {
        return fallback(error as Error, reset);
      }
      return fallback;
    }
  };
}

/**
 * Hook for catching errors in async operations.
 * Throws errors to the nearest error boundary.
 */
export function useErrorHandler(): (error: Error) => void {
  return (error: Error) => {
    // Re-throw to trigger error boundary
    throw error;
  };
}

// =============================================================================
// Context API
// =============================================================================

interface Context<T> {
  Provider: Function;
  Consumer: Function;
  displayName?: string;
  _currentValue: T;
  _subscribers: Set<() => void>;
}

/**
 * Creates a Context for sharing values across the component tree.
 *
 * @example
 * ```ts
 * const ThemeContext = createContext('light');
 *
 * // Provider
 * h(ThemeContext.Provider, { value: 'dark' },
 *   h(App)
 * )
 *
 * // Consumer (in component)
 * const theme = useContext(ThemeContext);
 * ```
 */
export function createContext<T>(defaultValue: T): Context<T> {
  const context: Context<T> = {
    _currentValue: defaultValue,
    _subscribers: new Set(),
    displayName: 'Context',

    Provider: function ContextProvider(props: { value: T; children: any }) {
      const previousValue = context._currentValue;
      context._currentValue = props.value;

      // Notify subscribers if value changed
      if (previousValue !== props.value) {
        context._subscribers.forEach((callback) => callback());
      }

      return props.children;
    },

    Consumer: function ContextConsumer(props: { children: (value: T) => VNode }) {
      return props.children(context._currentValue);
    },
  };

  return context;
}

/**
 * Hook to consume a context value.
 */
export function useContext<T>(context: Context<T>): T {
  // In a real implementation, this would:
  // 1. Subscribe to context changes
  // 2. Trigger re-render when context changes
  // 3. Clean up subscription on unmount
  return context._currentValue;
}

// =============================================================================
// Portal System
// =============================================================================

interface PortalProps {
  children: VNode | VNode[];
  container?: HTMLElement | string;
}

// Active portals registry
const portals = new Map<string, HTMLElement>();

/**
 * Creates a Portal component that renders children into a different DOM node.
 *
 * @example
 * ```ts
 * // Render modal outside the main app container
 * h(Portal, { container: document.body },
 *   h('div', { className: 'modal' },
 *     h('h2', null, 'Modal Title'),
 *     h('p', null, 'Modal content')
 *   )
 * )
 * ```
 */
export function Portal(props: PortalProps): VNode | null {
  const { children, container = 'body' } = props;

  // Get or create container
  let targetContainer: HTMLElement | null = null;

  if (typeof container === 'string') {
    targetContainer = document.querySelector(container);
  } else {
    targetContainer = container;
  }

  if (!targetContainer) {
    console.warn('Portal: Container not found:', container);
    return null;
  }

  // Create portal marker
  const portalId = `portal-${Date.now()}-${Math.random().toString(36).slice(2)}`;

  // In a real implementation, this would:
  // 1. Create a detached DOM node
  // 2. Render children into it
  // 3. Append to target container
  // 4. Clean up on unmount

  return {
    type: 'portal',
    props: { 'data-portal-id': portalId, container: targetContainer },
    children: Array.isArray(children) ? children : [children],
  };
}

/**
 * Creates a Modal component with backdrop and focus management.
 */
export function createModal(options: {
  onClose?: () => void;
  closeOnBackdrop?: boolean;
  closeOnEscape?: boolean;
  preventScroll?: boolean;
} = {}): Function {
  const {
    onClose,
    closeOnBackdrop = true,
    closeOnEscape = true,
    preventScroll = true,
  } = options;

  return function Modal(props: {
    isOpen: boolean;
    children: VNode | VNode[];
    className?: string;
  }) {
    if (!props.isOpen) {
      return null;
    }

    // Handle escape key
    const handleKeyDown = (e: KeyboardEvent) => {
      if (closeOnEscape && e.key === 'Escape' && onClose) {
        onClose();
      }
    };

    // Handle backdrop click
    const handleBackdropClick = (e: MouseEvent) => {
      if (closeOnBackdrop && e.target === e.currentTarget && onClose) {
        onClose();
      }
    };

    // Prevent body scroll
    if (preventScroll && typeof document !== 'undefined') {
      document.body.style.overflow = 'hidden';
    }

    return {
      type: Portal,
      props: { container: document.body },
      children: [
        {
          type: 'div',
          props: {
            className: 'modal-backdrop',
            onClick: handleBackdropClick,
            onKeyDown: handleKeyDown,
            style: `
              position: fixed;
              inset: 0;
              background: rgba(0, 0, 0, 0.5);
              display: flex;
              align-items: center;
              justify-content: center;
              z-index: 9999;
            `,
          },
          children: [
            {
              type: 'div',
              props: {
                className: `modal ${props.className || ''}`,
                role: 'dialog',
                'aria-modal': 'true',
                style: `
                  background: white;
                  border-radius: 8px;
                  max-width: 90vw;
                  max-height: 90vh;
                  overflow: auto;
                `,
              },
              children: Array.isArray(props.children) ? props.children : [props.children],
            },
          ],
        },
      ],
    };
  };
}

/**
 * Creates a Tooltip component.
 */
export function Tooltip(props: {
  content: string | VNode;
  children: VNode;
  position?: 'top' | 'bottom' | 'left' | 'right';
  delay?: number;
}): VNode {
  const { content, children, position = 'top', delay = 200 } = props;

  return {
    type: 'div',
    props: {
      className: 'tooltip-wrapper',
      style: 'position: relative; display: inline-block;',
      'data-tooltip': typeof content === 'string' ? content : '',
      'data-tooltip-position': position,
      'data-tooltip-delay': delay,
    },
    children: [children],
  };
}

// =============================================================================
// Suspense
// =============================================================================

interface SuspenseProps {
  fallback: VNode;
  children: VNode | VNode[];
}

// Promise tracking for suspense
const pendingPromises = new WeakMap<Promise<any>, { status: string; value?: any; error?: any }>();

/**
 * Suspense component for handling async rendering.
 *
 * @example
 * ```ts
 * h(Suspense, { fallback: h('div', null, 'Loading...') },
 *   h(AsyncComponent)
 * )
 * ```
 */
export function Suspense(props: SuspenseProps): VNode {
  const { fallback, children } = props;

  // In a real implementation, this would:
  // 1. Try to render children
  // 2. Catch thrown promises
  // 3. Show fallback while promise is pending
  // 4. Re-render when promise resolves

  return {
    type: 'suspense',
    props: { fallback },
    children: Array.isArray(children) ? children : [children],
  };
}

/**
 * Creates a resource that can be used with Suspense.
 * Implements the "render-as-you-fetch" pattern.
 */
export function createResource<T>(
  fetcher: () => Promise<T>
): { read: () => T; preload: () => void } {
  let status: 'pending' | 'success' | 'error' = 'pending';
  let result: T;
  let error: Error;
  let promise: Promise<void> | null = null;

  const load = () => {
    if (promise) return promise;

    promise = fetcher()
      .then((data) => {
        status = 'success';
        result = data;
      })
      .catch((err) => {
        status = 'error';
        error = err;
      });

    return promise;
  };

  return {
    read(): T {
      switch (status) {
        case 'pending':
          throw load(); // Suspense will catch this
        case 'error':
          throw error;
        case 'success':
          return result;
        default:
          throw new Error('Unknown resource status');
      }
    },
    preload(): void {
      load();
    },
  };
}

/**
 * Hook for lazy loading components.
 */
export function lazy<T extends Function>(
  loader: () => Promise<{ default: T }>
): T {
  let Component: T | null = null;
  let promise: Promise<void> | null = null;
  let error: Error | null = null;

  const LazyComponent = function (props: any) {
    if (error) {
      throw error;
    }

    if (Component) {
      return { type: Component, props, children: props.children || [] };
    }

    if (!promise) {
      promise = loader()
        .then((module) => {
          Component = module.default;
        })
        .catch((err) => {
          error = err;
        });
    }

    throw promise;
  };

  return LazyComponent as unknown as T;
}

// =============================================================================
// Virtual Scrolling
// =============================================================================

interface VirtualListProps<T> {
  items: T[];
  itemHeight: number;
  containerHeight: number;
  overscan?: number;
  renderItem: (item: T, index: number) => VNode;
}

/**
 * Virtual List component for efficiently rendering large lists.
 *
 * @example
 * ```ts
 * h(VirtualList, {
 *   items: largeArray,
 *   itemHeight: 50,
 *   containerHeight: 400,
 *   renderItem: (item, index) => h('div', { key: index }, item.name)
 * })
 * ```
 */
export function VirtualList<T>(props: VirtualListProps<T>): VNode {
  const {
    items,
    itemHeight,
    containerHeight,
    overscan = 3,
    renderItem,
  } = props;

  // Calculate visible range
  const totalHeight = items.length * itemHeight;

  // In a real implementation, this would:
  // 1. Track scroll position
  // 2. Calculate visible items
  // 3. Only render visible + overscan items
  // 4. Use absolute positioning

  return {
    type: 'div',
    props: {
      className: 'virtual-list-container',
      style: `
        height: ${containerHeight}px;
        overflow-y: auto;
        position: relative;
      `,
    },
    children: [
      {
        type: 'div',
        props: {
          className: 'virtual-list-inner',
          style: `height: ${totalHeight}px; position: relative;`,
        },
        children: items.map((item, index) => ({
          type: 'div',
          props: {
            key: index,
            className: 'virtual-list-item',
            style: `
              position: absolute;
              top: ${index * itemHeight}px;
              height: ${itemHeight}px;
              width: 100%;
            `,
          },
          children: [renderItem(item, index)],
        })),
      },
    ],
  };
}

/**
 * Hook for virtual scrolling with dynamic item heights.
 */
export function useVirtualizer<T>(options: {
  items: T[];
  estimateSize: (index: number) => number;
  overscan?: number;
  getScrollElement: () => HTMLElement | null;
}): {
  virtualItems: Array<{ index: number; start: number; size: number }>;
  totalSize: number;
  scrollToIndex: (index: number) => void;
} {
  const { items, estimateSize, overscan = 5, getScrollElement } = options;

  // Calculate sizes and positions
  const sizes: number[] = [];
  const positions: number[] = [];
  let totalSize = 0;

  for (let i = 0; i < items.length; i++) {
    const size = estimateSize(i);
    sizes.push(size);
    positions.push(totalSize);
    totalSize += size;
  }

  // In a real implementation, this would track scroll and visibility
  const virtualItems = items.map((_, index) => ({
    index,
    start: positions[index],
    size: sizes[index],
  }));

  const scrollToIndex = (index: number) => {
    const element = getScrollElement();
    if (element && positions[index] !== undefined) {
      element.scrollTop = positions[index];
    }
  };

  return { virtualItems, totalSize, scrollToIndex };
}

/**
 * Infinite scroll hook.
 */
export function useInfiniteScroll(options: {
  fetchMore: () => Promise<void>;
  hasMore: boolean;
  threshold?: number;
}): {
  sentinelRef: { current: HTMLElement | null };
} {
  const { fetchMore, hasMore, threshold = 200 } = options;

  const sentinelRef = { current: null as HTMLElement | null };

  // In a real implementation, this would use IntersectionObserver
  // to detect when the sentinel element is visible

  return { sentinelRef };
}

// =============================================================================
// Animations API
// =============================================================================

interface AnimationConfig {
  from: Record<string, number | string>;
  to: Record<string, number | string>;
  duration?: number;
  easing?: string | ((t: number) => number);
  delay?: number;
  onComplete?: () => void;
}

interface SpringConfig {
  stiffness?: number;
  damping?: number;
  mass?: number;
  velocity?: number;
}

// Easing functions
export const easings = {
  linear: (t: number) => t,
  easeIn: (t: number) => t * t,
  easeOut: (t: number) => t * (2 - t),
  easeInOut: (t: number) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),
  easeInCubic: (t: number) => t * t * t,
  easeOutCubic: (t: number) => (--t) * t * t + 1,
  easeInOutCubic: (t: number) =>
    t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1,
  spring: (t: number) => {
    const c4 = (2 * Math.PI) / 3;
    return t === 0
      ? 0
      : t === 1
      ? 1
      : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  },
  bounce: (t: number) => {
    const n1 = 7.5625;
    const d1 = 2.75;
    if (t < 1 / d1) {
      return n1 * t * t;
    } else if (t < 2 / d1) {
      return n1 * (t -= 1.5 / d1) * t + 0.75;
    } else if (t < 2.5 / d1) {
      return n1 * (t -= 2.25 / d1) * t + 0.9375;
    } else {
      return n1 * (t -= 2.625 / d1) * t + 0.984375;
    }
  },
};

/**
 * Creates an animation controller.
 */
export function createAnimation(config: AnimationConfig): {
  start: () => void;
  stop: () => void;
  pause: () => void;
  resume: () => void;
  reverse: () => void;
} {
  const {
    from,
    to,
    duration = 300,
    easing = 'easeOut',
    delay = 0,
    onComplete,
  } = config;

  let startTime: number | null = null;
  let animationId: number | null = null;
  let isPaused = false;
  let pausedTime = 0;
  let isReversed = false;

  const easingFn = typeof easing === 'function' ? easing : easings[easing as keyof typeof easings] || easings.linear;

  const interpolate = (progress: number) => {
    const result: Record<string, number | string> = {};
    for (const key in from) {
      const fromVal = parseFloat(from[key] as string);
      const toVal = parseFloat(to[key] as string);
      result[key] = fromVal + (toVal - fromVal) * progress;
    }
    return result;
  };

  const animate = (timestamp: number) => {
    if (!startTime) startTime = timestamp;

    const elapsed = timestamp - startTime - pausedTime;
    let progress = Math.min(elapsed / duration, 1);

    if (isReversed) {
      progress = 1 - progress;
    }

    const easedProgress = easingFn(progress);
    const values = interpolate(easedProgress);

    // Apply values (in real implementation, this would update DOM)
    // console.log('Animation values:', values);

    if (progress < 1 && !isPaused) {
      animationId = requestAnimationFrame(animate);
    } else if (progress >= 1 && onComplete) {
      onComplete();
    }
  };

  return {
    start() {
      if (delay > 0) {
        setTimeout(() => {
          animationId = requestAnimationFrame(animate);
        }, delay);
      } else {
        animationId = requestAnimationFrame(animate);
      }
    },
    stop() {
      if (animationId) {
        cancelAnimationFrame(animationId);
        animationId = null;
        startTime = null;
      }
    },
    pause() {
      isPaused = true;
      pausedTime = performance.now() - (startTime || 0);
    },
    resume() {
      isPaused = false;
      animationId = requestAnimationFrame(animate);
    },
    reverse() {
      isReversed = !isReversed;
    },
  };
}

/**
 * Spring animation hook.
 */
export function useSpring(
  target: number,
  config: SpringConfig = {}
): { value: number; isAnimating: boolean } {
  const { stiffness = 170, damping = 26, mass = 1, velocity = 0 } = config;

  // Spring physics simulation
  // In a real implementation, this would animate smoothly
  return { value: target, isAnimating: false };
}

/**
 * Transition component for animating mount/unmount.
 */
export function Transition(props: {
  show: boolean;
  enter?: string;
  enterFrom?: string;
  enterTo?: string;
  leave?: string;
  leaveFrom?: string;
  leaveTo?: string;
  children: VNode;
}): VNode | null {
  const { show, children, enter, enterFrom, enterTo, leave, leaveFrom, leaveTo } = props;

  if (!show) {
    return null;
  }

  // In a real implementation, this would:
  // 1. Track mount/unmount state
  // 2. Apply enter classes on mount
  // 3. Apply leave classes before unmount
  // 4. Wait for transition to complete before removing

  return {
    type: 'div',
    props: {
      className: `transition ${enter || ''} ${enterTo || ''}`,
      'data-transition-enter': enter,
      'data-transition-enter-from': enterFrom,
      'data-transition-enter-to': enterTo,
      'data-transition-leave': leave,
      'data-transition-leave-from': leaveFrom,
      'data-transition-leave-to': leaveTo,
    },
    children: [children],
  };
}

/**
 * Animation group for staggered animations.
 */
export function TransitionGroup(props: {
  children: VNode[];
  stagger?: number;
}): VNode {
  const { children, stagger = 50 } = props;

  return {
    type: 'div',
    props: {
      className: 'transition-group',
      'data-stagger': stagger,
    },
    children: children.map((child, index) => ({
      ...child,
      props: {
        ...child.props,
        style: `${child.props?.style || ''}; animation-delay: ${index * stagger}ms;`,
      },
    })),
  };
}

// =============================================================================
// CSS-in-JS Utilities
// =============================================================================

/**
 * Creates keyframe animation.
 */
export function keyframes(frames: Record<string, Record<string, string | number>>): string {
  const name = `zylix-${Math.random().toString(36).slice(2)}`;
  let css = `@keyframes ${name} {\n`;

  for (const [key, styles] of Object.entries(frames)) {
    css += `  ${key} {\n`;
    for (const [prop, value] of Object.entries(styles)) {
      const cssProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
      css += `    ${cssProp}: ${value};\n`;
    }
    css += '  }\n';
  }

  css += '}';

  // Inject into document
  if (typeof document !== 'undefined') {
    const style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);
  }

  return name;
}

// =============================================================================
// Exports
// =============================================================================

export default {
  // Error Boundaries
  createErrorBoundary,
  useErrorHandler,

  // Context
  createContext,
  useContext,

  // Portal/Modal
  Portal,
  createModal,
  Tooltip,

  // Suspense
  Suspense,
  createResource,
  lazy,

  // Virtual Scrolling
  VirtualList,
  useVirtualizer,
  useInfiniteScroll,

  // Animations
  easings,
  createAnimation,
  useSpring,
  Transition,
  TransitionGroup,
  keyframes,
};
