/**
 * Zylix Component Framework
 *
 * React-like component system with hooks for declarative UI.
 *
 * @example
 * ```typescript
 * import { h, render, useState, useEffect } from 'zylix/component';
 *
 * const Counter = () => {
 *   const [count, setCount] = useState(0);
 *
 *   useEffect(() => {
 *     document.title = `Count: ${count}`;
 *   }, [count]);
 *
 *   return h('div', null,
 *     h('p', null, `Count: ${count}`),
 *     h('button', { onClick: () => setCount(c => c + 1) }, '+1')
 *   );
 * };
 *
 * render(h(Counter), document.getElementById('app'));
 * ```
 */

// =============================================================================
// TYPES
// =============================================================================

/** Virtual DOM node types */
export type VNodeType = string | FunctionComponent | typeof Fragment | typeof Portal;

/** Props for a virtual DOM node */
export interface Props {
  key?: string | number;
  ref?: RefObject<any>;
  children?: VNode | VNode[];
  [key: string]: any;
}

/** Virtual DOM node */
export interface VNode {
  type: VNodeType;
  props: Props;
  key: string | number | null;
  _dom?: Node | null;
  _component?: ComponentInstance | null;
  _children?: VNode[] | null;
  _parent?: VNode | null;
  _depth?: number;
}

/** Function component type */
export type FunctionComponent<P = Props> = (props: P) => VNode | null;

/** Ref object for DOM access */
export interface RefObject<T> {
  current: T | null;
}

/** Effect cleanup function */
export type EffectCleanup = void | (() => void);

/** Effect function */
export type EffectFunction = () => EffectCleanup;

/** Hook state */
interface HookState {
  _value?: any;
  _args?: any[];
  _cleanup?: EffectCleanup;
  _pendingArgs?: any[];
  _factory?: () => any;
}

/** Component instance for tracking hooks */
interface ComponentInstance {
  _hooks: HookState[];
  _hookIndex: number;
  _vnode: VNode;
  _parentDom: Node;
  _pendingEffects: EffectFunction[];
  _depth: number;
}

// =============================================================================
// SYMBOLS & CONSTANTS
// =============================================================================

/** Fragment symbol for grouping children without wrapper */
export const Fragment = Symbol.for('zylix.fragment');

/** Portal symbol for rendering outside parent hierarchy */
export const Portal = Symbol.for('zylix.portal');

/** Empty children placeholder */
const EMPTY_ARR: any[] = [];

/** Empty object placeholder */
const EMPTY_OBJ: Props = {};

// =============================================================================
// GLOBAL STATE
// =============================================================================

/** Current component being rendered */
let currentComponent: ComponentInstance | null = null;

/** Pending re-renders */
let rerenderQueue: ComponentInstance[] = [];

/** Batch update in progress */
let isBatching = false;

/** Pending effects to run after render */
let pendingEffects: Array<() => void> = [];

/** Component depth counter for ordering */
let currentDepth = 0;

// =============================================================================
// HYPERSCRIPT (h function)
// =============================================================================

/**
 * Create a virtual DOM node (hyperscript)
 *
 * @param type - Element tag name, component function, Fragment, or Portal
 * @param props - Properties/attributes
 * @param children - Child nodes
 * @returns Virtual DOM node
 *
 * @example
 * ```typescript
 * // Element
 * h('div', { class: 'container' }, 'Hello');
 *
 * // Component
 * h(MyComponent, { name: 'World' });
 *
 * // Fragment
 * h(Fragment, null, h('li', null, 'A'), h('li', null, 'B'));
 *
 * // Nested children
 * h('ul', null,
 *   h('li', null, 'First'),
 *   h('li', null, 'Second')
 * );
 * ```
 */
export function h(
  type: VNodeType,
  props?: Props | null,
  ...children: any[]
): VNode {
  const normalizedProps: Props = props ? { ...props } : {};

  // Flatten and normalize children
  const flatChildren = flattenChildren(children);
  if (flatChildren.length > 0) {
    normalizedProps.children = flatChildren.length === 1 ? flatChildren[0] : flatChildren;
  }

  // Extract key
  const key = normalizedProps.key ?? null;
  delete normalizedProps.key;

  return createVNode(type, normalizedProps, key);
}

/**
 * Create VNode internal helper
 */
function createVNode(
  type: VNodeType,
  props: Props,
  key: string | number | null
): VNode {
  return {
    type,
    props,
    key,
    _dom: null,
    _component: null,
    _children: null,
    _parent: null,
    _depth: 0,
  };
}

/**
 * Flatten nested children arrays and normalize primitives
 */
function flattenChildren(children: any[]): VNode[] {
  const result: VNode[] = [];

  for (const child of children) {
    if (child == null || typeof child === 'boolean') {
      continue;
    }
    if (Array.isArray(child)) {
      result.push(...flattenChildren(child));
    } else if (typeof child === 'string' || typeof child === 'number') {
      result.push(createVNode(null as any, { textContent: String(child) }, null));
    } else if (child.type !== undefined) {
      result.push(child);
    }
  }

  return result;
}

// =============================================================================
// RENDER
// =============================================================================

/**
 * Render a virtual DOM tree to a container
 *
 * @param vnode - Virtual DOM node to render
 * @param container - DOM container element
 *
 * @example
 * ```typescript
 * const App = () => h('div', null, 'Hello, Zylix!');
 * render(h(App), document.getElementById('app'));
 * ```
 */
export function render(vnode: VNode | null, container: Node): void {
  // Get old vnode from container
  const oldVNode = (container as any)._vnode;

  // Create new vnode or use existing
  const newVNode = vnode;

  // Diff and patch
  diff(container, newVNode, oldVNode, 0);

  // Store vnode on container
  (container as any)._vnode = newVNode;

  // Run pending effects
  flushEffects();
}

/**
 * Diff two virtual DOM trees and update the DOM
 */
function diff(
  parentDom: Node,
  newVNode: VNode | null,
  oldVNode: VNode | null,
  depth: number
): void {
  if (newVNode === oldVNode) {
    return;
  }

  // Remove old node
  if (newVNode == null) {
    if (oldVNode != null) {
      unmount(oldVNode);
    }
    return;
  }

  // Set depth
  newVNode._depth = depth;

  // Different types - replace
  if (oldVNode == null || oldVNode.type !== newVNode.type) {
    if (oldVNode != null) {
      unmount(oldVNode);
    }
    mount(parentDom, newVNode, null, depth);
    return;
  }

  // Same type - update
  if (typeof newVNode.type === 'function') {
    // Function component
    diffComponent(parentDom, newVNode, oldVNode, depth);
  } else if (newVNode.type === Fragment) {
    // Fragment
    diffChildren(parentDom, newVNode, oldVNode, depth);
  } else if (newVNode.type === Portal) {
    // Portal
    const portalContainer = newVNode.props.container as Node;
    diffChildren(portalContainer, newVNode, oldVNode, depth);
  } else if (newVNode.props.textContent !== undefined) {
    // Text node
    diffText(parentDom, newVNode, oldVNode);
  } else {
    // Element
    diffElement(parentDom, newVNode, oldVNode, depth);
  }
}

/**
 * Mount a new VNode to the DOM
 */
function mount(
  parentDom: Node,
  vnode: VNode,
  beforeNode: Node | null,
  depth: number
): void {
  vnode._depth = depth;

  if (typeof vnode.type === 'function') {
    mountComponent(parentDom, vnode, beforeNode, depth);
  } else if (vnode.type === Fragment) {
    mountFragment(parentDom, vnode, beforeNode, depth);
  } else if (vnode.type === Portal) {
    const portalContainer = vnode.props.container as Node;
    mountFragment(portalContainer, vnode, null, depth);
  } else if (vnode.props.textContent !== undefined) {
    mountText(parentDom, vnode, beforeNode);
  } else {
    mountElement(parentDom, vnode, beforeNode, depth);
  }
}

/**
 * Mount a text node
 */
function mountText(parentDom: Node, vnode: VNode, beforeNode: Node | null): void {
  const textNode = document.createTextNode(vnode.props.textContent);
  vnode._dom = textNode;
  parentDom.insertBefore(textNode, beforeNode);
}

/**
 * Mount an element
 */
function mountElement(
  parentDom: Node,
  vnode: VNode,
  beforeNode: Node | null,
  depth: number
): void {
  const dom = document.createElement(vnode.type as string);
  vnode._dom = dom;

  // Set props
  setProps(dom, vnode.props, EMPTY_OBJ);

  // Mount children
  const children = normalizeChildren(vnode.props.children);
  vnode._children = children;

  for (const child of children) {
    child._parent = vnode;
    mount(dom, child, null, depth + 1);
  }

  // Handle ref
  if (vnode.props.ref) {
    vnode.props.ref.current = dom;
  }

  parentDom.insertBefore(dom, beforeNode);
}

/**
 * Mount a fragment
 */
function mountFragment(
  parentDom: Node,
  vnode: VNode,
  beforeNode: Node | null,
  depth: number
): void {
  const children = normalizeChildren(vnode.props.children);
  vnode._children = children;

  for (const child of children) {
    child._parent = vnode;
    mount(parentDom, child, beforeNode, depth + 1);
  }
}

/**
 * Mount a function component
 */
function mountComponent(
  parentDom: Node,
  vnode: VNode,
  beforeNode: Node | null,
  depth: number
): void {
  // Create component instance
  const component: ComponentInstance = {
    _hooks: [],
    _hookIndex: 0,
    _vnode: vnode,
    _parentDom: parentDom,
    _pendingEffects: [],
    _depth: depth,
  };

  vnode._component = component;

  // Render component
  currentComponent = component;
  component._hookIndex = 0;
  currentDepth = depth;

  const rendered = (vnode.type as FunctionComponent)(vnode.props);

  currentComponent = null;

  // Mount rendered output
  if (rendered) {
    rendered._parent = vnode;
    vnode._children = [rendered];
    mount(parentDom, rendered, beforeNode, depth + 1);
  } else {
    vnode._children = [];
  }

  // Queue effects
  for (const effect of component._pendingEffects) {
    pendingEffects.push(effect);
  }
  component._pendingEffects = [];
}

/**
 * Diff a function component
 */
function diffComponent(
  parentDom: Node,
  newVNode: VNode,
  oldVNode: VNode,
  depth: number
): void {
  // Reuse component instance
  const component = oldVNode._component!;
  component._vnode = newVNode;
  newVNode._component = component;

  // Render component
  currentComponent = component;
  component._hookIndex = 0;
  currentDepth = depth;

  const rendered = (newVNode.type as FunctionComponent)(newVNode.props);

  currentComponent = null;

  // Diff rendered output
  const oldChildren = oldVNode._children || [];
  const oldChild = oldChildren[0] || null;

  if (rendered) {
    rendered._parent = newVNode;
    newVNode._children = [rendered];
    diff(parentDom, rendered, oldChild, depth + 1);
  } else {
    newVNode._children = [];
    if (oldChild) {
      unmount(oldChild);
    }
  }

  // Queue effects
  for (const effect of component._pendingEffects) {
    pendingEffects.push(effect);
  }
  component._pendingEffects = [];
}

/**
 * Diff a text node
 */
function diffText(parentDom: Node, newVNode: VNode, oldVNode: VNode): void {
  if (newVNode.props.textContent !== oldVNode.props.textContent) {
    (oldVNode._dom as Text).textContent = newVNode.props.textContent;
  }
  newVNode._dom = oldVNode._dom;
}

/**
 * Diff an element
 */
function diffElement(
  parentDom: Node,
  newVNode: VNode,
  oldVNode: VNode,
  depth: number
): void {
  const dom = oldVNode._dom as Element;
  newVNode._dom = dom;

  // Update props
  setProps(dom, newVNode.props, oldVNode.props);

  // Update ref
  if (newVNode.props.ref !== oldVNode.props.ref) {
    if (oldVNode.props.ref) {
      oldVNode.props.ref.current = null;
    }
    if (newVNode.props.ref) {
      newVNode.props.ref.current = dom;
    }
  }

  // Diff children
  diffChildren(dom, newVNode, oldVNode, depth);
}

/**
 * Diff children using key-based reconciliation
 */
function diffChildren(
  parentDom: Node,
  newVNode: VNode,
  oldVNode: VNode,
  depth: number
): void {
  const newChildren = normalizeChildren(newVNode.props.children);
  const oldChildren = oldVNode._children || [];

  newVNode._children = newChildren;

  // Build key map for old children
  const oldKeyMap = new Map<string | number, VNode>();
  const oldIndexMap = new Map<VNode, number>();

  for (let i = 0; i < oldChildren.length; i++) {
    const oldChild = oldChildren[i];
    oldIndexMap.set(oldChild, i);
    if (oldChild.key != null) {
      oldKeyMap.set(oldChild.key, oldChild);
    }
  }

  // Track which old children are matched
  const matchedOld = new Set<VNode>();

  // Match new children to old children
  const matches: Array<{ newChild: VNode; oldChild: VNode | null }> = [];

  for (let i = 0; i < newChildren.length; i++) {
    const newChild = newChildren[i];
    newChild._parent = newVNode;

    let oldChild: VNode | null = null;

    // Try to find by key
    if (newChild.key != null && oldKeyMap.has(newChild.key)) {
      oldChild = oldKeyMap.get(newChild.key)!;
      if (oldChild.type === newChild.type) {
        matchedOld.add(oldChild);
      } else {
        oldChild = null;
      }
    }

    // Try to find by index if no key match
    if (!oldChild && i < oldChildren.length) {
      const candidate = oldChildren[i];
      if (
        !matchedOld.has(candidate) &&
        candidate.key == null &&
        newChild.key == null &&
        candidate.type === newChild.type
      ) {
        oldChild = candidate;
        matchedOld.add(oldChild);
      }
    }

    matches.push({ newChild, oldChild });
  }

  // Unmount unmatched old children
  for (const oldChild of oldChildren) {
    if (!matchedOld.has(oldChild)) {
      unmount(oldChild);
    }
  }

  // Diff/mount matched children
  let lastDom: Node | null = null;

  for (let i = 0; i < matches.length; i++) {
    const { newChild, oldChild } = matches[i];

    if (oldChild) {
      diff(parentDom, newChild, oldChild, depth + 1);
      // Move if needed
      const dom = getDom(newChild);
      if (dom && lastDom && dom.previousSibling !== lastDom) {
        parentDom.insertBefore(dom, lastDom.nextSibling);
      }
      lastDom = dom || lastDom;
    } else {
      const beforeNode = lastDom ? lastDom.nextSibling : parentDom.firstChild;
      mount(parentDom, newChild, beforeNode, depth + 1);
      lastDom = getDom(newChild) || lastDom;
    }
  }
}

/**
 * Unmount a VNode and cleanup
 */
function unmount(vnode: VNode): void {
  // Call effect cleanups
  if (vnode._component) {
    for (const hook of vnode._component._hooks) {
      if (hook._cleanup) {
        hook._cleanup();
      }
    }
  }

  // Clear ref
  if (vnode.props.ref) {
    vnode.props.ref.current = null;
  }

  // Unmount children
  if (vnode._children) {
    for (const child of vnode._children) {
      unmount(child);
    }
  }

  // Remove DOM
  if (vnode._dom && vnode._dom.parentNode) {
    vnode._dom.parentNode.removeChild(vnode._dom);
  }

  vnode._dom = null;
  vnode._component = null;
  vnode._children = null;
}

/**
 * Get the DOM node for a VNode (traversing fragments)
 */
function getDom(vnode: VNode): Node | null {
  if (vnode._dom) {
    return vnode._dom;
  }
  if (vnode._children && vnode._children.length > 0) {
    return getDom(vnode._children[0]);
  }
  return null;
}

/**
 * Normalize children to array
 */
function normalizeChildren(children: any): VNode[] {
  if (children == null) {
    return [];
  }
  if (Array.isArray(children)) {
    return flattenChildren(children);
  }
  return flattenChildren([children]);
}

// =============================================================================
// PROPS
// =============================================================================

/** Props to skip when setting attributes */
const SKIP_PROPS = new Set(['children', 'key', 'ref', 'textContent', 'container']);

/** Event prop prefix */
const EVENT_PREFIX = 'on';

/**
 * Set props on a DOM element
 */
function setProps(dom: Element, newProps: Props, oldProps: Props): void {
  // Remove old props
  for (const key of Object.keys(oldProps)) {
    if (SKIP_PROPS.has(key)) continue;
    if (!(key in newProps)) {
      setProp(dom, key, null, oldProps[key]);
    }
  }

  // Set new props
  for (const key of Object.keys(newProps)) {
    if (SKIP_PROPS.has(key)) continue;
    if (newProps[key] !== oldProps[key]) {
      setProp(dom, key, newProps[key], oldProps[key]);
    }
  }
}

/**
 * Set a single prop on a DOM element
 */
function setProp(dom: Element, key: string, newValue: any, oldValue: any): void {
  // Event handlers
  if (key.startsWith(EVENT_PREFIX) && key.length > 2) {
    const eventName = key.slice(2).toLowerCase();

    if (oldValue) {
      dom.removeEventListener(eventName, oldValue);
    }
    if (newValue) {
      dom.addEventListener(eventName, newValue);
    }
    return;
  }

  // Style
  if (key === 'style') {
    if (typeof newValue === 'string') {
      (dom as HTMLElement).style.cssText = newValue;
    } else if (typeof newValue === 'object') {
      const style = (dom as HTMLElement).style;
      if (typeof oldValue === 'object') {
        for (const k of Object.keys(oldValue)) {
          if (!(k in newValue)) {
            (style as any)[k] = '';
          }
        }
      }
      for (const k of Object.keys(newValue)) {
        (style as any)[k] = newValue[k];
      }
    }
    return;
  }

  // className
  if (key === 'className' || key === 'class') {
    dom.setAttribute('class', newValue || '');
    return;
  }

  // dangerouslySetInnerHTML
  if (key === 'dangerouslySetInnerHTML') {
    if (newValue && newValue.__html != null) {
      dom.innerHTML = newValue.__html;
    }
    return;
  }

  // Boolean attributes
  if (newValue === true) {
    dom.setAttribute(key, '');
  } else if (newValue === false || newValue == null) {
    dom.removeAttribute(key);
  } else {
    dom.setAttribute(key, String(newValue));
  }
}

// =============================================================================
// HOOKS
// =============================================================================

/**
 * Get or create hook state at current index
 */
function getHookState(initialValue: () => HookState): HookState {
  if (!currentComponent) {
    throw new Error('Hooks can only be called inside a component');
  }

  const index = currentComponent._hookIndex++;
  const hooks = currentComponent._hooks;

  if (index >= hooks.length) {
    hooks.push(initialValue());
  }

  return hooks[index];
}

/**
 * useState - Local state hook
 *
 * @param initialState - Initial state value or factory function
 * @returns Tuple of [state, setState]
 *
 * @example
 * ```typescript
 * const [count, setCount] = useState(0);
 * setCount(count + 1);
 * setCount(prev => prev + 1);
 * ```
 */
export function useState<T>(
  initialState: T | (() => T)
): [T, (action: T | ((prev: T) => T)) => void] {
  const hookState = getHookState(() => ({
    _value: typeof initialState === 'function' ? (initialState as () => T)() : initialState,
  }));

  const component = currentComponent!;

  const setState = (action: T | ((prev: T) => T)) => {
    const newValue =
      typeof action === 'function'
        ? (action as (prev: T) => T)(hookState._value)
        : action;

    if (!Object.is(hookState._value, newValue)) {
      hookState._value = newValue;
      scheduleRerender(component);
    }
  };

  return [hookState._value, setState];
}

/**
 * useReducer - Reducer-based state hook
 *
 * @param reducer - Reducer function
 * @param initialState - Initial state
 * @param init - Optional initializer function
 * @returns Tuple of [state, dispatch]
 *
 * @example
 * ```typescript
 * const reducer = (state, action) => {
 *   switch (action.type) {
 *     case 'increment': return { count: state.count + 1 };
 *     default: return state;
 *   }
 * };
 * const [state, dispatch] = useReducer(reducer, { count: 0 });
 * dispatch({ type: 'increment' });
 * ```
 */
export function useReducer<S, A>(
  reducer: (state: S, action: A) => S,
  initialState: S,
  init?: (initial: S) => S
): [S, (action: A) => void] {
  const hookState = getHookState(() => ({
    _value: init ? init(initialState) : initialState,
  }));

  const component = currentComponent!;

  const dispatch = (action: A) => {
    const newValue = reducer(hookState._value, action);
    if (!Object.is(hookState._value, newValue)) {
      hookState._value = newValue;
      scheduleRerender(component);
    }
  };

  return [hookState._value, dispatch];
}

/**
 * useEffect - Side effect hook
 *
 * @param effect - Effect function (optionally returns cleanup)
 * @param deps - Dependency array
 *
 * @example
 * ```typescript
 * useEffect(() => {
 *   const subscription = subscribe();
 *   return () => subscription.unsubscribe();
 * }, [topic]);
 * ```
 */
export function useEffect(effect: EffectFunction, deps?: any[]): void {
  const hookState = getHookState(() => ({ _args: undefined }));
  const component = currentComponent!;

  if (argsChanged(hookState._args, deps)) {
    hookState._args = deps;

    component._pendingEffects.push(() => {
      // Run cleanup from previous effect
      if (hookState._cleanup) {
        hookState._cleanup();
      }
      // Run new effect
      hookState._cleanup = effect();
    });
  }
}

/**
 * useLayoutEffect - Synchronous effect hook (runs before paint)
 *
 * @param effect - Effect function
 * @param deps - Dependency array
 */
export function useLayoutEffect(effect: EffectFunction, deps?: any[]): void {
  const hookState = getHookState(() => ({ _args: undefined }));

  if (argsChanged(hookState._args, deps)) {
    hookState._args = deps;

    // Run cleanup from previous effect
    if (hookState._cleanup) {
      hookState._cleanup();
    }
    // Run new effect synchronously
    hookState._cleanup = effect();
  }
}

/**
 * useMemo - Memoized computation hook
 *
 * @param factory - Factory function to compute value
 * @param deps - Dependency array
 * @returns Memoized value
 *
 * @example
 * ```typescript
 * const expensive = useMemo(() => computeExpensive(a, b), [a, b]);
 * ```
 */
export function useMemo<T>(factory: () => T, deps: any[]): T {
  const hookState = getHookState(() => ({
    _value: undefined as T | undefined,
    _args: undefined as any[] | undefined,
    _factory: factory,
  }));

  if (argsChanged(hookState._args, deps)) {
    hookState._value = factory();
    hookState._args = deps;
    hookState._factory = factory;
  }

  return hookState._value as T;
}

/**
 * useCallback - Memoized callback hook
 *
 * @param callback - Callback function
 * @param deps - Dependency array
 * @returns Memoized callback
 *
 * @example
 * ```typescript
 * const handleClick = useCallback(() => {
 *   console.log(value);
 * }, [value]);
 * ```
 */
export function useCallback<T extends (...args: any[]) => any>(callback: T, deps: any[]): T {
  return useMemo(() => callback, deps);
}

/**
 * useRef - Mutable ref hook
 *
 * @param initialValue - Initial ref value
 * @returns Ref object
 *
 * @example
 * ```typescript
 * const inputRef = useRef<HTMLInputElement>(null);
 * // In render: h('input', { ref: inputRef })
 * // Later: inputRef.current?.focus();
 * ```
 */
export function useRef<T>(initialValue: T): RefObject<T> {
  return useMemo(() => ({ current: initialValue }), []);
}

/**
 * Context type
 */
export interface Context<T> {
  Provider: FunctionComponent<{ value: T; children?: VNode | VNode[] }>;
  _defaultValue: T;
  _id: symbol;
}

/** Context values storage */
const contextValues = new Map<symbol, any[]>();

/**
 * createContext - Create a context
 *
 * @param defaultValue - Default context value
 * @returns Context object with Provider
 *
 * @example
 * ```typescript
 * const ThemeContext = createContext('light');
 *
 * // Provider
 * h(ThemeContext.Provider, { value: 'dark' },
 *   h(App)
 * );
 *
 * // Consumer
 * const theme = useContext(ThemeContext);
 * ```
 */
export function createContext<T>(defaultValue: T): Context<T> {
  const id = Symbol('context');

  const Provider: FunctionComponent<{ value: T; children?: VNode | VNode[] }> = (props) => {
    // Push value to context stack
    if (!contextValues.has(id)) {
      contextValues.set(id, []);
    }
    const stack = contextValues.get(id)!;

    useLayoutEffect(() => {
      stack.push(props.value);
      return () => {
        stack.pop();
      };
    }, [props.value]);

    return h(Fragment, null, props.children);
  };

  return {
    Provider,
    _defaultValue: defaultValue,
    _id: id,
  };
}

/**
 * useContext - Consume a context value
 *
 * @param context - Context object
 * @returns Current context value
 */
export function useContext<T>(context: Context<T>): T {
  const stack = contextValues.get(context._id);
  if (stack && stack.length > 0) {
    return stack[stack.length - 1];
  }
  return context._defaultValue;
}

/**
 * Check if dependency arrays are different
 */
function argsChanged(oldArgs: any[] | undefined, newArgs: any[] | undefined): boolean {
  if (oldArgs === undefined || newArgs === undefined) {
    return true;
  }
  if (oldArgs.length !== newArgs.length) {
    return true;
  }
  for (let i = 0; i < oldArgs.length; i++) {
    if (!Object.is(oldArgs[i], newArgs[i])) {
      return true;
    }
  }
  return false;
}

// =============================================================================
// SCHEDULING
// =============================================================================

/**
 * Schedule a component re-render
 */
function scheduleRerender(component: ComponentInstance): void {
  if (!rerenderQueue.includes(component)) {
    rerenderQueue.push(component);
  }

  if (!isBatching) {
    isBatching = true;
    queueMicrotask(processRerenderQueue);
  }
}

/**
 * Process the re-render queue
 */
function processRerenderQueue(): void {
  // Sort by depth (parent first)
  rerenderQueue.sort((a, b) => a._depth - b._depth);

  const queue = rerenderQueue;
  rerenderQueue = [];
  isBatching = false;

  for (const component of queue) {
    // Skip if unmounted
    if (!component._vnode._component) {
      continue;
    }

    const vnode = component._vnode;
    const parentDom = component._parentDom;
    const oldChildren = vnode._children || [];
    const oldChild = oldChildren[0] || null;

    // Re-render
    currentComponent = component;
    component._hookIndex = 0;
    currentDepth = component._depth;

    const rendered = (vnode.type as FunctionComponent)(vnode.props);

    currentComponent = null;

    // Diff
    if (rendered) {
      rendered._parent = vnode;
      vnode._children = [rendered];
      diff(parentDom, rendered, oldChild, component._depth + 1);
    } else {
      vnode._children = [];
      if (oldChild) {
        unmount(oldChild);
      }
    }

    // Queue effects
    for (const effect of component._pendingEffects) {
      pendingEffects.push(effect);
    }
    component._pendingEffects = [];
  }

  // Run effects
  flushEffects();
}

/**
 * Flush pending effects
 */
function flushEffects(): void {
  const effects = pendingEffects;
  pendingEffects = [];

  for (const effect of effects) {
    effect();
  }
}

// =============================================================================
// UTILITIES
// =============================================================================

/**
 * Batch multiple state updates
 *
 * @param fn - Function containing multiple setState calls
 *
 * @example
 * ```typescript
 * batch(() => {
 *   setA(1);
 *   setB(2);
 *   setC(3);
 * }); // Single re-render
 * ```
 */
export function batch(fn: () => void): void {
  const wasBatching = isBatching;
  isBatching = true;

  try {
    fn();
  } finally {
    isBatching = wasBatching;
    if (!wasBatching && rerenderQueue.length > 0) {
      queueMicrotask(processRerenderQueue);
    }
  }
}

/**
 * Force a synchronous flush of pending updates
 */
export function flushSync(fn?: () => void): void {
  if (fn) {
    fn();
  }
  processRerenderQueue();
}

/**
 * Create a lazy-loaded component
 *
 * @param loader - Dynamic import function
 * @returns Lazy component
 *
 * @example
 * ```typescript
 * const LazyComponent = lazy(() => import('./HeavyComponent'));
 * ```
 */
export function lazy<P = Props>(
  loader: () => Promise<{ default: FunctionComponent<P> }>
): FunctionComponent<P> {
  let Component: FunctionComponent<P> | null = null;
  let promise: Promise<void> | null = null;
  let error: Error | null = null;

  return (props: P) => {
    if (error) {
      throw error;
    }

    if (Component) {
      return h(Component, props as any);
    }

    if (!promise) {
      promise = loader()
        .then((module) => {
          Component = module.default;
        })
        .catch((e) => {
          error = e;
        });
    }

    throw promise;
  };
}

/**
 * Error boundary for lazy components
 *
 * @param props - Fallback and children
 *
 * @example
 * ```typescript
 * h(Suspense, { fallback: h('div', null, 'Loading...') },
 *   h(LazyComponent)
 * );
 * ```
 */
export const Suspense: FunctionComponent<{
  fallback: VNode;
  children?: VNode | VNode[];
}> = (props) => {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  // Simple implementation - in production would use error boundaries
  try {
    if (pending || error) {
      return props.fallback;
    }
    return h(Fragment, null, props.children);
  } catch (e) {
    if (e instanceof Promise) {
      if (!pending) {
        setPending(true);
        e.finally(() => setPending(false));
      }
      return props.fallback;
    }
    throw e;
  }
};

/**
 * memo - Memoize a component to prevent unnecessary re-renders
 *
 * @param component - Component to memoize
 * @param areEqual - Optional comparison function
 * @returns Memoized component
 *
 * @example
 * ```typescript
 * const MemoizedComponent = memo(({ value }) => h('div', null, value));
 * ```
 */
export function memo<P extends Props>(
  component: FunctionComponent<P>,
  areEqual?: (prevProps: P, nextProps: P) => boolean
): FunctionComponent<P> {
  let prevProps: P | null = null;
  let prevResult: VNode | null = null;

  return (props: P) => {
    if (prevProps !== null) {
      const equal = areEqual
        ? areEqual(prevProps, props)
        : shallowEqual(prevProps, props);

      if (equal) {
        return prevResult;
      }
    }

    prevProps = props;
    prevResult = component(props);
    return prevResult;
  };
}

/**
 * Shallow equality check
 */
function shallowEqual(a: any, b: any): boolean {
  if (Object.is(a, b)) return true;
  if (typeof a !== 'object' || typeof b !== 'object') return false;
  if (a === null || b === null) return false;

  const keysA = Object.keys(a);
  const keysB = Object.keys(b);

  if (keysA.length !== keysB.length) return false;

  for (const key of keysA) {
    if (key === 'children') continue;
    if (!Object.is(a[key], b[key])) return false;
  }

  return true;
}

// =============================================================================
// EXPORTS
// =============================================================================

export default {
  h,
  render,
  Fragment,
  Portal,
  useState,
  useReducer,
  useEffect,
  useLayoutEffect,
  useMemo,
  useCallback,
  useRef,
  createContext,
  useContext,
  batch,
  flushSync,
  lazy,
  Suspense,
  memo,
};
