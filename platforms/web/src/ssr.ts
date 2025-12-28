/**
 * Zylix Server-Side Rendering (SSR)
 * v0.25.0 - Web Dominance
 *
 * Full SSR support including:
 * - renderToString: Render to HTML string
 * - renderToStream: Streaming SSR for large pages
 * - hydrate: Client-side hydration
 * - Head management: Meta tags, title, scripts
 * - Data prefetching: Automatic data serialization
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

export interface RenderOptions {
  /**
   * Enable streaming mode
   * @default false
   */
  stream?: boolean;

  /**
   * Prefix for data-zylix-* attributes
   * @default 'zylix'
   */
  prefix?: string;

  /**
   * Custom serializer for data
   */
  serializer?: (data: unknown) => string;

  /**
   * Abort signal for cancellation
   */
  signal?: AbortSignal;
}

export interface HeadConfig {
  title?: string;
  meta?: Array<{ name?: string; property?: string; content: string }>;
  links?: Array<{ rel: string; href: string; [key: string]: string }>;
  scripts?: Array<{ src?: string; content?: string; async?: boolean; defer?: boolean }>;
  styles?: Array<{ href?: string; content?: string }>;
}

export interface SSRContext {
  head: HeadConfig;
  data: Record<string, unknown>;
  modules: Set<string>;
  errors: Error[];
}

// =============================================================================
// Global State for SSR
// =============================================================================

let currentSSRContext: SSRContext | null = null;

/**
 * Get the current SSR context.
 */
export function getSSRContext(): SSRContext | null {
  return currentSSRContext;
}

/**
 * Set data in the SSR context for hydration.
 */
export function setSSRData(key: string, data: unknown): void {
  if (currentSSRContext) {
    currentSSRContext.data[key] = data;
  }
}

// =============================================================================
// Render to String
// =============================================================================

/**
 * Renders a VNode tree to an HTML string.
 *
 * @example
 * ```ts
 * import { renderToString } from 'zylix/ssr';
 *
 * const html = await renderToString(h(App, { user }));
 * res.send(`
 *   <!DOCTYPE html>
 *   <html>
 *     <head>${head}</head>
 *     <body>
 *       <div id="app">${html}</div>
 *       ${hydrationScript}
 *     </body>
 *   </html>
 * `);
 * ```
 */
export async function renderToString(
  vnode: VNode,
  options: RenderOptions = {}
): Promise<string> {
  const { prefix = 'zylix' } = options;

  // Initialize SSR context
  currentSSRContext = {
    head: { title: '', meta: [], links: [], scripts: [], styles: [] },
    data: {},
    modules: new Set(),
    errors: [],
  };

  try {
    const html = await renderVNodeToString(vnode, prefix, 0);
    return html;
  } finally {
    currentSSRContext = null;
  }
}

/**
 * Recursively renders a VNode to string.
 */
async function renderVNodeToString(
  vnode: VNode | string | null | undefined,
  prefix: string,
  depth: number
): Promise<string> {
  // Handle null/undefined
  if (vnode == null) {
    return '';
  }

  // Handle strings
  if (typeof vnode === 'string') {
    return escapeHtml(vnode);
  }

  // Handle numbers
  if (typeof vnode === 'number') {
    return String(vnode);
  }

  // Handle arrays
  if (Array.isArray(vnode)) {
    const results = await Promise.all(
      vnode.map((child) => renderVNodeToString(child, prefix, depth))
    );
    return results.join('');
  }

  const { type, props = {}, children = [] } = vnode;

  // Handle function components
  if (typeof type === 'function') {
    try {
      // Execute the component function
      const result = await type({ ...props, children });
      return renderVNodeToString(result, prefix, depth);
    } catch (error) {
      if (currentSSRContext) {
        currentSSRContext.errors.push(error as Error);
      }
      return `<!-- SSR Error: ${escapeHtml((error as Error).message)} -->`;
    }
  }

  // Handle special types
  if (type === 'suspense') {
    // Render children, showing fallback if there's an error
    try {
      const childrenHtml = await renderChildren(children, prefix, depth + 1);
      return childrenHtml;
    } catch {
      // Render fallback
      if (props.fallback) {
        return renderVNodeToString(props.fallback, prefix, depth);
      }
      return '';
    }
  }

  if (type === 'portal') {
    // Portals render their children normally in SSR
    return renderChildren(children, prefix, depth + 1);
  }

  // Handle HTML elements
  const tagName = type as string;
  const attrsString = renderAttributes(props, prefix);
  const childrenHtml = await renderChildren(children, prefix, depth + 1);

  // Self-closing tags
  const voidElements = new Set([
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
  ]);

  if (voidElements.has(tagName)) {
    return `<${tagName}${attrsString} />`;
  }

  return `<${tagName}${attrsString}>${childrenHtml}</${tagName}>`;
}

/**
 * Render children array.
 */
async function renderChildren(
  children: (VNode | string)[],
  prefix: string,
  depth: number
): Promise<string> {
  const results = await Promise.all(
    children.map((child) => renderVNodeToString(child, prefix, depth))
  );
  return results.join('');
}

/**
 * Render props to attribute string.
 */
function renderAttributes(props: Record<string, any>, prefix: string): string {
  const attrs: string[] = [];

  for (const [key, value] of Object.entries(props)) {
    // Skip special props
    if (key === 'children' || key === 'key' || key === 'ref') {
      continue;
    }

    // Skip event handlers (they don't work in SSR)
    if (key.startsWith('on') && typeof value === 'function') {
      continue;
    }

    // Handle style object
    if (key === 'style' && typeof value === 'object') {
      const styleString = Object.entries(value)
        .map(([k, v]) => `${camelToKebab(k)}: ${v}`)
        .join('; ');
      attrs.push(`style="${escapeHtml(styleString)}"`);
      continue;
    }

    // Handle className
    if (key === 'className') {
      attrs.push(`class="${escapeHtml(String(value))}"`);
      continue;
    }

    // Handle boolean attributes
    if (typeof value === 'boolean') {
      if (value) {
        attrs.push(key);
      }
      continue;
    }

    // Handle dangerouslySetInnerHTML
    if (key === 'dangerouslySetInnerHTML') {
      // Will be handled separately
      continue;
    }

    // Regular attributes
    if (value != null) {
      attrs.push(`${key}="${escapeHtml(String(value))}"`);
    }
  }

  // Add hydration marker
  attrs.push(`data-${prefix}-ssr="true"`);

  return attrs.length > 0 ? ' ' + attrs.join(' ') : '';
}

// =============================================================================
// Render to Stream
// =============================================================================

/**
 * Renders a VNode tree to a readable stream.
 * Useful for large pages to start sending content early.
 *
 * @example
 * ```ts
 * import { renderToStream } from 'zylix/ssr';
 *
 * const stream = renderToStream(h(App));
 * stream.pipe(res);
 * ```
 */
export function renderToStream(
  vnode: VNode,
  options: RenderOptions = {}
): ReadableStream<string> {
  const { prefix = 'zylix', signal } = options;

  // Initialize SSR context
  currentSSRContext = {
    head: { title: '', meta: [], links: [], scripts: [], styles: [] },
    data: {},
    modules: new Set(),
    errors: [],
  };

  let controller: ReadableStreamDefaultController<string>;

  const stream = new ReadableStream<string>({
    async start(ctrl) {
      controller = ctrl;

      try {
        await streamVNode(vnode, prefix, 0, controller, signal);
        controller.close();
      } catch (error) {
        controller.error(error);
      } finally {
        currentSSRContext = null;
      }
    },
    cancel() {
      currentSSRContext = null;
    },
  });

  return stream;
}

/**
 * Stream a VNode.
 */
async function streamVNode(
  vnode: VNode | string | null | undefined,
  prefix: string,
  depth: number,
  controller: ReadableStreamDefaultController<string>,
  signal?: AbortSignal
): Promise<void> {
  // Check for abort
  if (signal?.aborted) {
    throw new Error('SSR aborted');
  }

  // Handle null/undefined
  if (vnode == null) {
    return;
  }

  // Handle strings
  if (typeof vnode === 'string') {
    controller.enqueue(escapeHtml(vnode));
    return;
  }

  // Handle numbers
  if (typeof vnode === 'number') {
    controller.enqueue(String(vnode));
    return;
  }

  // Handle arrays
  if (Array.isArray(vnode)) {
    for (const child of vnode) {
      await streamVNode(child, prefix, depth, controller, signal);
    }
    return;
  }

  const { type, props = {}, children = [] } = vnode;

  // Handle function components
  if (typeof type === 'function') {
    try {
      const result = await type({ ...props, children });
      await streamVNode(result, prefix, depth, controller, signal);
    } catch (error) {
      controller.enqueue(`<!-- SSR Error: ${escapeHtml((error as Error).message)} -->`);
    }
    return;
  }

  // Handle HTML elements
  const tagName = type as string;
  const attrsString = renderAttributes(props, prefix);

  // Self-closing tags
  const voidElements = new Set([
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
  ]);

  if (voidElements.has(tagName)) {
    controller.enqueue(`<${tagName}${attrsString} />`);
    return;
  }

  // Open tag
  controller.enqueue(`<${tagName}${attrsString}>`);

  // Stream children
  for (const child of children) {
    await streamVNode(child, prefix, depth + 1, controller, signal);
  }

  // Close tag
  controller.enqueue(`</${tagName}>`);
}

// =============================================================================
// Client Hydration
// =============================================================================

/**
 * Hydrates a server-rendered DOM with client-side interactivity.
 *
 * @example
 * ```ts
 * import { hydrate } from 'zylix/ssr';
 *
 * // On the client
 * hydrate(h(App, { user: window.__SSR_DATA__.user }), document.getElementById('app'));
 * ```
 */
export function hydrate(vnode: VNode, container: HTMLElement): void {
  // Check if SSR markers exist
  const ssrRoot = container.querySelector('[data-zylix-ssr="true"]');

  if (!ssrRoot) {
    // No SSR content, do a full render instead
    console.warn('[Zylix SSR] No SSR markers found, falling back to client render');
    // Would call regular render here
    return;
  }

  console.log('[Zylix SSR] Starting hydration');

  try {
    hydrateVNode(vnode, container, 0);
    console.log('[Zylix SSR] Hydration complete');
  } catch (error) {
    console.error('[Zylix SSR] Hydration failed:', error);
    // Could fall back to full client render here
  }
}

/**
 * Hydrate a single VNode.
 */
function hydrateVNode(
  vnode: VNode | string | null,
  domNode: Node,
  _index: number
): void {
  if (vnode == null || typeof vnode === 'string') {
    return;
  }

  if (typeof vnode === 'number') {
    return;
  }

  const { type, props = {}, children = [] } = vnode;

  // Handle function components
  if (typeof type === 'function') {
    const result = type({ ...props, children });
    hydrateVNode(result, domNode, 0);
    return;
  }

  // Attach event listeners
  if (domNode instanceof Element) {
    for (const [key, value] of Object.entries(props)) {
      if (key.startsWith('on') && typeof value === 'function') {
        const eventName = key.slice(2).toLowerCase();
        domNode.addEventListener(eventName, value as EventListener);
      }

      // Handle refs
      if (key === 'ref' && typeof value === 'object' && value !== null) {
        (value as { current: Element | null }).current = domNode;
      }
    }
  }

  // Hydrate children
  const childNodes = Array.from(domNode.childNodes).filter(
    (node) => node.nodeType === Node.ELEMENT_NODE || node.nodeType === Node.TEXT_NODE
  );

  let childIndex = 0;
  for (const child of children) {
    if (child == null || child === '') continue;

    const childNode = childNodes[childIndex];
    if (childNode) {
      hydrateVNode(child as VNode, childNode, childIndex);
    }
    childIndex++;
  }
}

// =============================================================================
// Head Management
// =============================================================================

/**
 * Set the document title during SSR.
 */
export function useHead(config: HeadConfig): void {
  if (currentSSRContext) {
    if (config.title) {
      currentSSRContext.head.title = config.title;
    }
    if (config.meta) {
      currentSSRContext.head.meta = [
        ...(currentSSRContext.head.meta || []),
        ...config.meta,
      ];
    }
    if (config.links) {
      currentSSRContext.head.links = [
        ...(currentSSRContext.head.links || []),
        ...config.links,
      ];
    }
    if (config.scripts) {
      currentSSRContext.head.scripts = [
        ...(currentSSRContext.head.scripts || []),
        ...config.scripts,
      ];
    }
    if (config.styles) {
      currentSSRContext.head.styles = [
        ...(currentSSRContext.head.styles || []),
        ...config.styles,
      ];
    }
  } else if (typeof document !== 'undefined') {
    // Client-side head management
    if (config.title) {
      document.title = config.title;
    }
    // Could add more client-side head management here
  }
}

/**
 * Render head tags to string.
 */
export function renderHead(head: HeadConfig): string {
  const parts: string[] = [];

  if (head.title) {
    parts.push(`<title>${escapeHtml(head.title)}</title>`);
  }

  for (const meta of head.meta || []) {
    const attrs = Object.entries(meta)
      .map(([k, v]) => `${k}="${escapeHtml(v)}"`)
      .join(' ');
    parts.push(`<meta ${attrs} />`);
  }

  for (const link of head.links || []) {
    const attrs = Object.entries(link)
      .map(([k, v]) => `${k}="${escapeHtml(v)}"`)
      .join(' ');
    parts.push(`<link ${attrs} />`);
  }

  for (const style of head.styles || []) {
    if (style.href) {
      parts.push(`<link rel="stylesheet" href="${escapeHtml(style.href)}" />`);
    } else if (style.content) {
      parts.push(`<style>${style.content}</style>`);
    }
  }

  for (const script of head.scripts || []) {
    if (script.src) {
      const attrs = [];
      attrs.push(`src="${escapeHtml(script.src)}"`);
      if (script.async) attrs.push('async');
      if (script.defer) attrs.push('defer');
      parts.push(`<script ${attrs.join(' ')}></script>`);
    } else if (script.content) {
      parts.push(`<script>${script.content}</script>`);
    }
  }

  return parts.join('\n');
}

// =============================================================================
// Data Prefetching
// =============================================================================

/**
 * Creates an async data loader for SSR.
 */
export function createLoader<T>(
  loader: () => Promise<T>
): { load: () => Promise<T>; getCache: () => T | undefined } {
  let cache: T | undefined;
  let promise: Promise<T> | null = null;

  return {
    async load(): Promise<T> {
      if (cache !== undefined) {
        return cache;
      }

      if (!promise) {
        promise = loader().then((data) => {
          cache = data;
          return data;
        });
      }

      return promise;
    },
    getCache(): T | undefined {
      return cache;
    },
  };
}

/**
 * Generates the hydration script with serialized data.
 */
export function getHydrationScript(data: Record<string, unknown>): string {
  const serialized = JSON.stringify(data)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026');

  return `<script>window.__ZYLIX_SSR_DATA__ = ${serialized};</script>`;
}

/**
 * Get SSR data on the client.
 */
export function getSSRData<T>(key: string): T | undefined {
  if (typeof window !== 'undefined') {
    const data = (window as any).__ZYLIX_SSR_DATA__;
    return data?.[key];
  }
  return undefined;
}

// =============================================================================
// SSR Utilities
// =============================================================================

/**
 * Check if code is running on the server.
 */
export function isServer(): boolean {
  return typeof window === 'undefined';
}

/**
 * Check if code is running on the client.
 */
export function isClient(): boolean {
  return typeof window !== 'undefined';
}

/**
 * Run code only on the server.
 */
export function onServer<T>(fn: () => T): T | undefined {
  if (isServer()) {
    return fn();
  }
  return undefined;
}

/**
 * Run code only on the client.
 */
export function onClient<T>(fn: () => T): T | undefined {
  if (isClient()) {
    return fn();
  }
  return undefined;
}

// =============================================================================
// Helper Functions
// =============================================================================

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function camelToKebab(str: string): string {
  return str.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
}

// =============================================================================
// Express/Node.js Middleware
// =============================================================================

/**
 * Creates an Express middleware for SSR.
 *
 * @example
 * ```ts
 * import express from 'express';
 * import { createSSRMiddleware, renderToString } from 'zylix/ssr';
 *
 * const app = express();
 *
 * app.use(createSSRMiddleware({
 *   render: async (req) => {
 *     const html = await renderToString(h(App, { url: req.url }));
 *     return html;
 *   }
 * }));
 * ```
 */
export function createSSRMiddleware(options: {
  render: (req: { url: string; headers: Record<string, string> }) => Promise<string>;
  template?: string;
}): (req: any, res: any, next: any) => Promise<void> {
  const { render, template = defaultTemplate } = options;

  return async (req, res, next) => {
    try {
      const html = await render({
        url: req.url,
        headers: req.headers,
      });

      const context = currentSSRContext || {
        head: {},
        data: {},
        modules: new Set(),
        errors: [],
      };

      const headString = renderHead(context.head);
      const dataScript = getHydrationScript(context.data);

      const fullHtml = template
        .replace('<!--zylix-head-->', headString)
        .replace('<!--zylix-app-->', html)
        .replace('<!--zylix-data-->', dataScript);

      res.setHeader('Content-Type', 'text/html');
      res.send(fullHtml);
    } catch (error) {
      next(error);
    }
  };
}

const defaultTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <!--zylix-head-->
</head>
<body>
  <div id="app"><!--zylix-app--></div>
  <!--zylix-data-->
  <script type="module" src="/src/main.ts"></script>
</body>
</html>`;

// =============================================================================
// Exports
// =============================================================================

export default {
  renderToString,
  renderToStream,
  hydrate,
  useHead,
  renderHead,
  createLoader,
  getHydrationScript,
  getSSRData,
  getSSRContext,
  setSSRData,
  isServer,
  isClient,
  onServer,
  onClient,
  createSSRMiddleware,
};
