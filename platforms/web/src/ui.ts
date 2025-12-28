/**
 * Zylix UI Component Library
 *
 * A comprehensive UI component library with:
 * - Theme system with customizable colors, spacing, and typography
 * - 30+ accessible, customizable components
 * - WCAG 2.1 AA compliant
 * - Keyboard navigation support
 * - Reduced motion support
 */

// ============================================================================
// Types
// ============================================================================

export interface ThemeColors {
  primary: string;
  primaryHover: string;
  primaryActive: string;
  secondary: string;
  secondaryHover: string;
  secondaryActive: string;
  success: string;
  successHover: string;
  warning: string;
  warningHover: string;
  danger: string;
  dangerHover: string;
  info: string;
  infoHover: string;
  background: string;
  surface: string;
  surfaceHover: string;
  border: string;
  borderFocus: string;
  text: string;
  textSecondary: string;
  textMuted: string;
  textInverse: string;
  overlay: string;
  shadow: string;
}

export interface ThemeSpacing {
  xs: string;
  sm: string;
  md: string;
  lg: string;
  xl: string;
  '2xl': string;
  '3xl': string;
}

export interface ThemeBorderRadius {
  none: string;
  sm: string;
  md: string;
  lg: string;
  xl: string;
  full: string;
}

export interface ThemeFontSize {
  xs: string;
  sm: string;
  md: string;
  lg: string;
  xl: string;
  '2xl': string;
  '3xl': string;
}

export interface ThemeShadow {
  sm: string;
  md: string;
  lg: string;
  xl: string;
}

export interface ThemeTransition {
  fast: string;
  normal: string;
  slow: string;
}

export interface ThemeBreakpoints {
  sm: string;
  md: string;
  lg: string;
  xl: string;
}

export interface Theme {
  colors: ThemeColors;
  spacing: ThemeSpacing;
  borderRadius: ThemeBorderRadius;
  fontSize: ThemeFontSize;
  shadow: ThemeShadow;
  transition: ThemeTransition;
  breakpoints: ThemeBreakpoints;
  fontFamily: string;
}

export type ComponentSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';
export type ComponentVariant = 'primary' | 'secondary' | 'success' | 'warning' | 'danger' | 'info' | 'ghost' | 'outline';

// ============================================================================
// Theme System
// ============================================================================

const defaultTheme: Theme = {
  colors: {
    primary: '#3b82f6',
    primaryHover: '#2563eb',
    primaryActive: '#1d4ed8',
    secondary: '#6b7280',
    secondaryHover: '#4b5563',
    secondaryActive: '#374151',
    success: '#10b981',
    successHover: '#059669',
    warning: '#f59e0b',
    warningHover: '#d97706',
    danger: '#ef4444',
    dangerHover: '#dc2626',
    info: '#06b6d4',
    infoHover: '#0891b2',
    background: '#ffffff',
    surface: '#f9fafb',
    surfaceHover: '#f3f4f6',
    border: '#e5e7eb',
    borderFocus: '#3b82f6',
    text: '#111827',
    textSecondary: '#4b5563',
    textMuted: '#9ca3af',
    textInverse: '#ffffff',
    overlay: 'rgba(0, 0, 0, 0.5)',
    shadow: 'rgba(0, 0, 0, 0.1)',
  },
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem',
    md: '1rem',
    lg: '1.5rem',
    xl: '2rem',
    '2xl': '3rem',
    '3xl': '4rem',
  },
  borderRadius: {
    none: '0',
    sm: '0.25rem',
    md: '0.5rem',
    lg: '0.75rem',
    xl: '1rem',
    full: '9999px',
  },
  fontSize: {
    xs: '0.75rem',
    sm: '0.875rem',
    md: '1rem',
    lg: '1.125rem',
    xl: '1.25rem',
    '2xl': '1.5rem',
    '3xl': '2rem',
  },
  shadow: {
    sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
    md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
    lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
    xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
  },
  transition: {
    fast: '150ms ease',
    normal: '250ms ease',
    slow: '350ms ease',
  },
  breakpoints: {
    sm: '640px',
    md: '768px',
    lg: '1024px',
    xl: '1280px',
  },
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
};

let currentTheme: Theme = { ...defaultTheme };
const themeListeners: Set<() => void> = new Set();

export const theme = {
  get(): Theme {
    return currentTheme;
  },

  set(partial: Partial<Theme> | ((theme: Theme) => Partial<Theme>)): void {
    const updates = typeof partial === 'function' ? partial(currentTheme) : partial;
    currentTheme = deepMerge(currentTheme, updates) as Theme;
    themeListeners.forEach(listener => listener());
  },

  reset(): void {
    currentTheme = { ...defaultTheme };
    themeListeners.forEach(listener => listener());
  },

  subscribe(listener: () => void): () => void {
    themeListeners.add(listener);
    return () => themeListeners.delete(listener);
  },

  // Generate CSS custom properties
  toCSSVars(): string {
    const vars: string[] = [];

    const addVars = (obj: Record<string, any>, prefix: string) => {
      for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'object') {
          addVars(value, `${prefix}-${key}`);
        } else {
          vars.push(`--zylix${prefix}-${key}: ${value};`);
        }
      }
    };

    addVars(currentTheme.colors, '-color');
    addVars(currentTheme.spacing, '-spacing');
    addVars(currentTheme.borderRadius, '-radius');
    addVars(currentTheme.fontSize, '-font-size');
    addVars(currentTheme.shadow, '-shadow');
    addVars(currentTheme.transition, '-transition');

    return `:root {\n  ${vars.join('\n  ')}\n}`;
  },

  // Inject theme as CSS
  inject(): void {
    let styleEl = document.getElementById('zylix-theme') as HTMLStyleElement;
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.id = 'zylix-theme';
      document.head.appendChild(styleEl);
    }
    styleEl.textContent = this.toCSSVars() + '\n' + baseStyles;
  },
};

// Deep merge utility
function deepMerge(target: any, source: any): any {
  const result = { ...target };
  for (const key of Object.keys(source)) {
    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
      result[key] = deepMerge(target[key] || {}, source[key]);
    } else {
      result[key] = source[key];
    }
  }
  return result;
}

// Base styles
const baseStyles = `
* {
  box-sizing: border-box;
}

.zylix-component {
  font-family: var(--zylix-font-family, ${defaultTheme.fontFamily});
}

@media (prefers-reduced-motion: reduce) {
  .zylix-component,
  .zylix-component * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
`;

// ============================================================================
// Utility Functions
// ============================================================================

function createId(): string {
  return `zylix-${Math.random().toString(36).substr(2, 9)}`;
}

function mergeClasses(...classes: (string | undefined | null | false)[]): string {
  return classes.filter(Boolean).join(' ');
}

function createStyleString(styles: Record<string, string | number | undefined>): string {
  return Object.entries(styles)
    .filter(([_, value]) => value !== undefined)
    .map(([key, value]) => {
      const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
      return `${cssKey}: ${value}`;
    })
    .join('; ');
}

function getVariantColors(variant: ComponentVariant): { bg: string; text: string; border: string; hover: string } {
  const t = theme.get();
  const variants: Record<ComponentVariant, { bg: string; text: string; border: string; hover: string }> = {
    primary: { bg: t.colors.primary, text: t.colors.textInverse, border: t.colors.primary, hover: t.colors.primaryHover },
    secondary: { bg: t.colors.secondary, text: t.colors.textInverse, border: t.colors.secondary, hover: t.colors.secondaryHover },
    success: { bg: t.colors.success, text: t.colors.textInverse, border: t.colors.success, hover: t.colors.successHover },
    warning: { bg: t.colors.warning, text: t.colors.text, border: t.colors.warning, hover: t.colors.warningHover },
    danger: { bg: t.colors.danger, text: t.colors.textInverse, border: t.colors.danger, hover: t.colors.dangerHover },
    info: { bg: t.colors.info, text: t.colors.textInverse, border: t.colors.info, hover: t.colors.infoHover },
    ghost: { bg: 'transparent', text: t.colors.text, border: 'transparent', hover: t.colors.surfaceHover },
    outline: { bg: 'transparent', text: t.colors.primary, border: t.colors.primary, hover: t.colors.surface },
  };
  return variants[variant];
}

function getSizeStyles(size: ComponentSize, type: 'button' | 'input' | 'text'): Record<string, string> {
  const t = theme.get();

  if (type === 'button') {
    const sizes: Record<ComponentSize, Record<string, string>> = {
      xs: { padding: `${t.spacing.xs} ${t.spacing.sm}`, fontSize: t.fontSize.xs, height: '1.75rem' },
      sm: { padding: `${t.spacing.xs} ${t.spacing.md}`, fontSize: t.fontSize.sm, height: '2rem' },
      md: { padding: `${t.spacing.sm} ${t.spacing.lg}`, fontSize: t.fontSize.md, height: '2.5rem' },
      lg: { padding: `${t.spacing.md} ${t.spacing.xl}`, fontSize: t.fontSize.lg, height: '3rem' },
      xl: { padding: `${t.spacing.lg} ${t.spacing['2xl']}`, fontSize: t.fontSize.xl, height: '3.5rem' },
    };
    return sizes[size];
  }

  if (type === 'input') {
    const sizes: Record<ComponentSize, Record<string, string>> = {
      xs: { padding: `${t.spacing.xs} ${t.spacing.sm}`, fontSize: t.fontSize.xs, height: '1.75rem' },
      sm: { padding: `${t.spacing.xs} ${t.spacing.md}`, fontSize: t.fontSize.sm, height: '2rem' },
      md: { padding: `${t.spacing.sm} ${t.spacing.md}`, fontSize: t.fontSize.md, height: '2.5rem' },
      lg: { padding: `${t.spacing.md} ${t.spacing.lg}`, fontSize: t.fontSize.lg, height: '3rem' },
      xl: { padding: `${t.spacing.lg} ${t.spacing.xl}`, fontSize: t.fontSize.xl, height: '3.5rem' },
    };
    return sizes[size];
  }

  const sizes: Record<ComponentSize, Record<string, string>> = {
    xs: { fontSize: t.fontSize.xs },
    sm: { fontSize: t.fontSize.sm },
    md: { fontSize: t.fontSize.md },
    lg: { fontSize: t.fontSize.lg },
    xl: { fontSize: t.fontSize.xl },
  };
  return sizes[size];
}

// ============================================================================
// Component Factory
// ============================================================================

export interface ComponentConfig {
  tag?: string;
  className?: string;
  style?: Record<string, string | number | undefined>;
  attrs?: Record<string, string | boolean | number | undefined>;
  children?: (Node | string)[];
  events?: Record<string, EventListener>;
  ref?: (el: HTMLElement) => void;
}

export function createElement(config: ComponentConfig): HTMLElement {
  const { tag = 'div', className, style, attrs, children, events, ref } = config;

  const el = document.createElement(tag);
  el.className = mergeClasses('zylix-component', className);

  if (style) {
    el.setAttribute('style', createStyleString(style));
  }

  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (value === undefined) continue;
      if (typeof value === 'boolean') {
        if (value) el.setAttribute(key, '');
      } else {
        el.setAttribute(key, String(value));
      }
    }
  }

  if (children) {
    for (const child of children) {
      if (typeof child === 'string') {
        el.appendChild(document.createTextNode(child));
      } else if (child) {
        el.appendChild(child);
      }
    }
  }

  if (events) {
    for (const [event, handler] of Object.entries(events)) {
      el.addEventListener(event, handler);
    }
  }

  if (ref) {
    ref(el);
  }

  return el;
}

// ============================================================================
// Layout Components
// ============================================================================

export interface ContainerProps {
  maxWidth?: 'sm' | 'md' | 'lg' | 'xl' | 'full' | string;
  padding?: string;
  center?: boolean;
  className?: string;
  children?: (Node | string)[];
}

export function Container(props: ContainerProps): HTMLElement {
  const { maxWidth = 'lg', padding, center = true, className, children } = props;
  const t = theme.get();

  const widths: Record<string, string> = {
    sm: t.breakpoints.sm,
    md: t.breakpoints.md,
    lg: t.breakpoints.lg,
    xl: t.breakpoints.xl,
    full: '100%',
  };

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-container', className),
    style: {
      width: '100%',
      maxWidth: widths[maxWidth] || maxWidth,
      margin: center ? '0 auto' : undefined,
      padding: padding || t.spacing.md,
    },
    children,
  });
}

export interface FlexProps {
  direction?: 'row' | 'row-reverse' | 'column' | 'column-reverse';
  wrap?: 'nowrap' | 'wrap' | 'wrap-reverse';
  justify?: 'start' | 'end' | 'center' | 'between' | 'around' | 'evenly';
  align?: 'start' | 'end' | 'center' | 'stretch' | 'baseline';
  gap?: string;
  className?: string;
  style?: Record<string, string | number | undefined>;
  children?: (Node | string)[];
}

export function Flex(props: FlexProps): HTMLElement {
  const { direction = 'row', wrap = 'nowrap', justify = 'start', align = 'stretch', gap, className, style, children } = props;
  const t = theme.get();

  const justifyMap: Record<string, string> = {
    start: 'flex-start',
    end: 'flex-end',
    center: 'center',
    between: 'space-between',
    around: 'space-around',
    evenly: 'space-evenly',
  };

  const alignMap: Record<string, string> = {
    start: 'flex-start',
    end: 'flex-end',
    center: 'center',
    stretch: 'stretch',
    baseline: 'baseline',
  };

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-flex', className),
    style: {
      display: 'flex',
      flexDirection: direction,
      flexWrap: wrap,
      justifyContent: justifyMap[justify],
      alignItems: alignMap[align],
      gap: gap || t.spacing.md,
      ...style,
    },
    children,
  });
}

export interface GridProps {
  columns?: number | string;
  rows?: number | string;
  gap?: string;
  columnGap?: string;
  rowGap?: string;
  className?: string;
  style?: Record<string, string | number | undefined>;
  children?: (Node | string)[];
}

export function Grid(props: GridProps): HTMLElement {
  const { columns = 12, rows, gap, columnGap, rowGap, className, style, children } = props;
  const t = theme.get();

  const gridCols = typeof columns === 'number' ? `repeat(${columns}, 1fr)` : columns;
  const gridRows = rows ? (typeof rows === 'number' ? `repeat(${rows}, 1fr)` : rows) : undefined;

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-grid', className),
    style: {
      display: 'grid',
      gridTemplateColumns: gridCols,
      gridTemplateRows: gridRows,
      gap: gap || t.spacing.md,
      columnGap,
      rowGap,
      ...style,
    },
    children,
  });
}

export interface GridItemProps {
  colSpan?: number;
  rowSpan?: number;
  colStart?: number;
  rowStart?: number;
  className?: string;
  style?: Record<string, string | number | undefined>;
  children?: (Node | string)[];
}

export function GridItem(props: GridItemProps): HTMLElement {
  const { colSpan, rowSpan, colStart, rowStart, className, style, children } = props;

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-grid-item', className),
    style: {
      gridColumn: colSpan ? `span ${colSpan}` : undefined,
      gridRow: rowSpan ? `span ${rowSpan}` : undefined,
      gridColumnStart: colStart,
      gridRowStart: rowStart,
      ...style,
    },
    children,
  });
}

export interface StackProps {
  direction?: 'vertical' | 'horizontal';
  gap?: string;
  align?: 'start' | 'end' | 'center' | 'stretch';
  className?: string;
  children?: (Node | string)[];
}

export function Stack(props: StackProps): HTMLElement {
  const { direction = 'vertical', gap, align = 'stretch', className, children } = props;
  const t = theme.get();

  return Flex({
    direction: direction === 'vertical' ? 'column' : 'row',
    gap: gap || t.spacing.md,
    align,
    className: mergeClasses('zylix-stack', className),
    children,
  });
}

export interface DividerProps {
  orientation?: 'horizontal' | 'vertical';
  color?: string;
  thickness?: string;
  margin?: string;
  className?: string;
}

export function Divider(props: DividerProps = {}): HTMLElement {
  const { orientation = 'horizontal', color, thickness = '1px', margin, className } = props;
  const t = theme.get();

  const isHorizontal = orientation === 'horizontal';

  return createElement({
    tag: 'hr',
    className: mergeClasses('zylix-divider', className),
    style: {
      border: 'none',
      backgroundColor: color || t.colors.border,
      width: isHorizontal ? '100%' : thickness,
      height: isHorizontal ? thickness : '100%',
      margin: margin || (isHorizontal ? `${t.spacing.md} 0` : `0 ${t.spacing.md}`),
    },
    attrs: {
      role: 'separator',
      'aria-orientation': orientation,
    },
  });
}

// ============================================================================
// Form Components
// ============================================================================

export interface ButtonProps {
  variant?: ComponentVariant;
  size?: ComponentSize;
  disabled?: boolean;
  loading?: boolean;
  fullWidth?: boolean;
  type?: 'button' | 'submit' | 'reset';
  leftIcon?: Node;
  rightIcon?: Node;
  onClick?: (e: MouseEvent) => void;
  className?: string;
  children?: (Node | string)[];
}

export function Button(props: ButtonProps): HTMLButtonElement {
  const {
    variant = 'primary',
    size = 'md',
    disabled = false,
    loading = false,
    fullWidth = false,
    type = 'button',
    leftIcon,
    rightIcon,
    onClick,
    className,
    children = [],
  } = props;

  const t = theme.get();
  const colors = getVariantColors(variant);
  const sizeStyles = getSizeStyles(size, 'button');

  const isOutline = variant === 'outline';
  const isGhost = variant === 'ghost';

  const buttonChildren: (Node | string)[] = [];

  if (loading) {
    buttonChildren.push(Spinner({ size: 'sm', color: isOutline || isGhost ? colors.text : colors.text }));
  } else if (leftIcon) {
    buttonChildren.push(leftIcon);
  }

  buttonChildren.push(...children);

  if (rightIcon && !loading) {
    buttonChildren.push(rightIcon);
  }

  const button = createElement({
    tag: 'button',
    className: mergeClasses('zylix-button', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: t.spacing.sm,
      border: isOutline ? `2px solid ${colors.border}` : 'none',
      borderRadius: t.borderRadius.md,
      backgroundColor: colors.bg,
      color: colors.text,
      cursor: disabled || loading ? 'not-allowed' : 'pointer',
      opacity: disabled ? '0.5' : '1',
      fontWeight: '500',
      transition: `all ${t.transition.fast}`,
      width: fullWidth ? '100%' : undefined,
      ...sizeStyles,
    },
    attrs: {
      type,
      disabled: disabled || loading,
      'aria-disabled': disabled || loading,
      'aria-busy': loading,
    },
    children: buttonChildren,
    events: onClick && !disabled && !loading ? {
      click: onClick as EventListener,
      mouseenter: (e) => {
        const btn = e.target as HTMLButtonElement;
        btn.style.backgroundColor = isGhost ? colors.hover : colors.hover;
        if (isOutline) btn.style.backgroundColor = colors.hover;
      },
      mouseleave: (e) => {
        const btn = e.target as HTMLButtonElement;
        btn.style.backgroundColor = colors.bg;
      },
    } : undefined,
  }) as HTMLButtonElement;

  return button;
}

export interface InputProps {
  type?: 'text' | 'password' | 'email' | 'number' | 'tel' | 'url' | 'search';
  size?: ComponentSize;
  placeholder?: string;
  value?: string;
  defaultValue?: string;
  disabled?: boolean;
  readOnly?: boolean;
  required?: boolean;
  error?: boolean | string;
  label?: string;
  helperText?: string;
  leftIcon?: Node;
  rightIcon?: Node;
  onChange?: (value: string, e: Event) => void;
  onBlur?: (e: FocusEvent) => void;
  onFocus?: (e: FocusEvent) => void;
  className?: string;
  id?: string;
}

export function Input(props: InputProps): HTMLElement {
  const {
    type = 'text',
    size = 'md',
    placeholder,
    value,
    defaultValue,
    disabled = false,
    readOnly = false,
    required = false,
    error,
    label,
    helperText,
    leftIcon,
    rightIcon,
    onChange,
    onBlur,
    onFocus,
    className,
    id = createId(),
  } = props;

  const t = theme.get();
  const sizeStyles = getSizeStyles(size, 'input');
  const hasError = !!error;
  const errorMessage = typeof error === 'string' ? error : undefined;

  const inputEl = createElement({
    tag: 'input',
    className: 'zylix-input-field',
    style: {
      width: '100%',
      border: `1px solid ${hasError ? t.colors.danger : t.colors.border}`,
      borderRadius: t.borderRadius.md,
      backgroundColor: disabled ? t.colors.surface : t.colors.background,
      color: t.colors.text,
      outline: 'none',
      transition: `all ${t.transition.fast}`,
      paddingLeft: leftIcon ? t.spacing.xl : undefined,
      paddingRight: rightIcon ? t.spacing.xl : undefined,
      ...sizeStyles,
    },
    attrs: {
      type,
      id,
      placeholder,
      value,
      disabled,
      readonly: readOnly,
      required,
      'aria-invalid': hasError,
      'aria-describedby': errorMessage || helperText ? `${id}-helper` : undefined,
    },
    events: {
      input: onChange ? (e) => onChange((e.target as HTMLInputElement).value, e) : undefined,
      blur: onBlur as EventListener | undefined,
      focus: onFocus as EventListener | undefined,
      focusin: (e) => {
        const input = e.target as HTMLInputElement;
        input.style.borderColor = hasError ? t.colors.danger : t.colors.borderFocus;
        input.style.boxShadow = `0 0 0 3px ${hasError ? t.colors.danger : t.colors.primary}20`;
      },
      focusout: (e) => {
        const input = e.target as HTMLInputElement;
        input.style.borderColor = hasError ? t.colors.danger : t.colors.border;
        input.style.boxShadow = 'none';
      },
    } as Record<string, EventListener>,
  }) as HTMLInputElement;

  if (defaultValue !== undefined) {
    inputEl.value = defaultValue;
  }

  const children: (Node | string)[] = [];

  if (label) {
    children.push(createElement({
      tag: 'label',
      className: 'zylix-input-label',
      style: {
        display: 'block',
        marginBottom: t.spacing.xs,
        fontSize: t.fontSize.sm,
        fontWeight: '500',
        color: t.colors.text,
      },
      attrs: { for: id },
      children: [label, required ? createElement({
        tag: 'span',
        style: { color: t.colors.danger, marginLeft: t.spacing.xs },
        children: ['*'],
      }) : ''].filter(Boolean) as (Node | string)[],
    }));
  }

  const inputWrapper = createElement({
    tag: 'div',
    className: 'zylix-input-wrapper',
    style: { position: 'relative' },
    children: [
      leftIcon ? createElement({
        tag: 'span',
        className: 'zylix-input-icon-left',
        style: {
          position: 'absolute',
          left: t.spacing.sm,
          top: '50%',
          transform: 'translateY(-50%)',
          color: t.colors.textMuted,
          pointerEvents: 'none',
        },
        children: [leftIcon],
      }) : null,
      inputEl,
      rightIcon ? createElement({
        tag: 'span',
        className: 'zylix-input-icon-right',
        style: {
          position: 'absolute',
          right: t.spacing.sm,
          top: '50%',
          transform: 'translateY(-50%)',
          color: t.colors.textMuted,
          pointerEvents: 'none',
        },
        children: [rightIcon],
      }) : null,
    ].filter(Boolean) as Node[],
  });

  children.push(inputWrapper);

  if (errorMessage || helperText) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-input-helper',
      style: {
        display: 'block',
        marginTop: t.spacing.xs,
        fontSize: t.fontSize.xs,
        color: errorMessage ? t.colors.danger : t.colors.textMuted,
      },
      attrs: { id: `${id}-helper` },
      children: [errorMessage || helperText || ''],
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-input', className),
    children,
  });
}

export interface TextareaProps {
  size?: ComponentSize;
  placeholder?: string;
  value?: string;
  defaultValue?: string;
  disabled?: boolean;
  readOnly?: boolean;
  required?: boolean;
  error?: boolean | string;
  label?: string;
  helperText?: string;
  rows?: number;
  resize?: 'none' | 'vertical' | 'horizontal' | 'both';
  onChange?: (value: string, e: Event) => void;
  onBlur?: (e: FocusEvent) => void;
  className?: string;
  id?: string;
}

export function Textarea(props: TextareaProps): HTMLElement {
  const {
    size = 'md',
    placeholder,
    value,
    defaultValue,
    disabled = false,
    readOnly = false,
    required = false,
    error,
    label,
    helperText,
    rows = 4,
    resize = 'vertical',
    onChange,
    onBlur,
    className,
    id = createId(),
  } = props;

  const t = theme.get();
  const sizeStyles = getSizeStyles(size, 'input');
  const hasError = !!error;
  const errorMessage = typeof error === 'string' ? error : undefined;

  const textareaEl = createElement({
    tag: 'textarea',
    className: 'zylix-textarea-field',
    style: {
      width: '100%',
      border: `1px solid ${hasError ? t.colors.danger : t.colors.border}`,
      borderRadius: t.borderRadius.md,
      backgroundColor: disabled ? t.colors.surface : t.colors.background,
      color: t.colors.text,
      outline: 'none',
      transition: `all ${t.transition.fast}`,
      resize,
      minHeight: '80px',
      ...sizeStyles,
      height: undefined,
    },
    attrs: {
      id,
      placeholder,
      disabled,
      readonly: readOnly,
      required,
      rows,
      'aria-invalid': hasError,
    },
    events: {
      input: onChange ? (e) => onChange((e.target as HTMLTextAreaElement).value, e) : undefined,
      blur: onBlur as EventListener | undefined,
      focusin: (e) => {
        const textarea = e.target as HTMLTextAreaElement;
        textarea.style.borderColor = hasError ? t.colors.danger : t.colors.borderFocus;
        textarea.style.boxShadow = `0 0 0 3px ${hasError ? t.colors.danger : t.colors.primary}20`;
      },
      focusout: (e) => {
        const textarea = e.target as HTMLTextAreaElement;
        textarea.style.borderColor = hasError ? t.colors.danger : t.colors.border;
        textarea.style.boxShadow = 'none';
      },
    } as Record<string, EventListener>,
  }) as HTMLTextAreaElement;

  if (value !== undefined) {
    textareaEl.value = value;
  } else if (defaultValue !== undefined) {
    textareaEl.value = defaultValue;
  }

  const children: (Node | string)[] = [];

  if (label) {
    children.push(createElement({
      tag: 'label',
      className: 'zylix-textarea-label',
      style: {
        display: 'block',
        marginBottom: t.spacing.xs,
        fontSize: t.fontSize.sm,
        fontWeight: '500',
        color: t.colors.text,
      },
      attrs: { for: id },
      children: [label],
    }));
  }

  children.push(textareaEl);

  if (errorMessage || helperText) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-textarea-helper',
      style: {
        display: 'block',
        marginTop: t.spacing.xs,
        fontSize: t.fontSize.xs,
        color: errorMessage ? t.colors.danger : t.colors.textMuted,
      },
      children: [errorMessage || helperText || ''],
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-textarea', className),
    children,
  });
}

export interface SelectOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface SelectProps {
  options: SelectOption[];
  size?: ComponentSize;
  placeholder?: string;
  value?: string;
  defaultValue?: string;
  disabled?: boolean;
  required?: boolean;
  error?: boolean | string;
  label?: string;
  helperText?: string;
  onChange?: (value: string, e: Event) => void;
  className?: string;
  id?: string;
}

export function Select(props: SelectProps): HTMLElement {
  const {
    options,
    size = 'md',
    placeholder,
    value,
    defaultValue,
    disabled = false,
    required = false,
    error,
    label,
    helperText,
    onChange,
    className,
    id = createId(),
  } = props;

  const t = theme.get();
  const sizeStyles = getSizeStyles(size, 'input');
  const hasError = !!error;
  const errorMessage = typeof error === 'string' ? error : undefined;

  const optionElements: Node[] = [];

  if (placeholder) {
    optionElements.push(createElement({
      tag: 'option',
      attrs: { value: '', disabled: true, selected: !value && !defaultValue },
      children: [placeholder],
    }));
  }

  for (const opt of options) {
    optionElements.push(createElement({
      tag: 'option',
      attrs: {
        value: opt.value,
        disabled: opt.disabled,
        selected: value === opt.value || defaultValue === opt.value,
      },
      children: [opt.label],
    }));
  }

  const selectEl = createElement({
    tag: 'select',
    className: 'zylix-select-field',
    style: {
      width: '100%',
      border: `1px solid ${hasError ? t.colors.danger : t.colors.border}`,
      borderRadius: t.borderRadius.md,
      backgroundColor: disabled ? t.colors.surface : t.colors.background,
      color: t.colors.text,
      outline: 'none',
      transition: `all ${t.transition.fast}`,
      cursor: disabled ? 'not-allowed' : 'pointer',
      appearance: 'none',
      backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%236b7280'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E")`,
      backgroundRepeat: 'no-repeat',
      backgroundPosition: `right ${t.spacing.sm} center`,
      backgroundSize: '1.5em',
      paddingRight: t.spacing['2xl'],
      ...sizeStyles,
    },
    attrs: {
      id,
      disabled,
      required,
      'aria-invalid': hasError,
    },
    children: optionElements,
    events: {
      change: onChange ? (e) => onChange((e.target as HTMLSelectElement).value, e) : undefined,
      focusin: (e) => {
        const select = e.target as HTMLSelectElement;
        select.style.borderColor = hasError ? t.colors.danger : t.colors.borderFocus;
        select.style.boxShadow = `0 0 0 3px ${hasError ? t.colors.danger : t.colors.primary}20`;
      },
      focusout: (e) => {
        const select = e.target as HTMLSelectElement;
        select.style.borderColor = hasError ? t.colors.danger : t.colors.border;
        select.style.boxShadow = 'none';
      },
    } as Record<string, EventListener>,
  }) as HTMLSelectElement;

  const children: (Node | string)[] = [];

  if (label) {
    children.push(createElement({
      tag: 'label',
      className: 'zylix-select-label',
      style: {
        display: 'block',
        marginBottom: t.spacing.xs,
        fontSize: t.fontSize.sm,
        fontWeight: '500',
        color: t.colors.text,
      },
      attrs: { for: id },
      children: [label],
    }));
  }

  children.push(selectEl);

  if (errorMessage || helperText) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-select-helper',
      style: {
        display: 'block',
        marginTop: t.spacing.xs,
        fontSize: t.fontSize.xs,
        color: errorMessage ? t.colors.danger : t.colors.textMuted,
      },
      children: [errorMessage || helperText || ''],
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-select', className),
    children,
  });
}

export interface CheckboxProps {
  checked?: boolean;
  defaultChecked?: boolean;
  disabled?: boolean;
  indeterminate?: boolean;
  label?: string;
  size?: ComponentSize;
  onChange?: (checked: boolean, e: Event) => void;
  className?: string;
  id?: string;
}

export function Checkbox(props: CheckboxProps): HTMLElement {
  const {
    checked,
    defaultChecked,
    disabled = false,
    indeterminate = false,
    label,
    size = 'md',
    onChange,
    className,
    id = createId(),
  } = props;

  const t = theme.get();

  const sizes: Record<ComponentSize, string> = {
    xs: '14px',
    sm: '16px',
    md: '18px',
    lg: '20px',
    xl: '24px',
  };

  const checkboxSize = sizes[size];

  const inputEl = createElement({
    tag: 'input',
    className: 'zylix-checkbox-input',
    style: {
      width: checkboxSize,
      height: checkboxSize,
      margin: '0',
      cursor: disabled ? 'not-allowed' : 'pointer',
      accentColor: t.colors.primary,
    },
    attrs: {
      type: 'checkbox',
      id,
      checked: checked ?? defaultChecked,
      disabled,
    },
    events: {
      change: onChange ? (e) => onChange((e.target as HTMLInputElement).checked, e) : undefined,
    } as Record<string, EventListener>,
  }) as HTMLInputElement;

  if (indeterminate) {
    inputEl.indeterminate = true;
  }

  const children: Node[] = [inputEl];

  if (label) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-checkbox-label',
      style: {
        marginLeft: t.spacing.sm,
        fontSize: getSizeStyles(size, 'text').fontSize,
        color: disabled ? t.colors.textMuted : t.colors.text,
        cursor: disabled ? 'not-allowed' : 'pointer',
      },
      children: [label],
    }));
  }

  return createElement({
    tag: 'label',
    className: mergeClasses('zylix-checkbox', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      cursor: disabled ? 'not-allowed' : 'pointer',
    },
    attrs: { for: id },
    children,
  });
}

export interface RadioProps {
  name: string;
  value: string;
  checked?: boolean;
  disabled?: boolean;
  label?: string;
  size?: ComponentSize;
  onChange?: (value: string, e: Event) => void;
  className?: string;
  id?: string;
}

export function Radio(props: RadioProps): HTMLElement {
  const {
    name,
    value,
    checked = false,
    disabled = false,
    label,
    size = 'md',
    onChange,
    className,
    id = createId(),
  } = props;

  const t = theme.get();

  const sizes: Record<ComponentSize, string> = {
    xs: '14px',
    sm: '16px',
    md: '18px',
    lg: '20px',
    xl: '24px',
  };

  const radioSize = sizes[size];

  const inputEl = createElement({
    tag: 'input',
    className: 'zylix-radio-input',
    style: {
      width: radioSize,
      height: radioSize,
      margin: '0',
      cursor: disabled ? 'not-allowed' : 'pointer',
      accentColor: t.colors.primary,
    },
    attrs: {
      type: 'radio',
      id,
      name,
      value,
      checked,
      disabled,
    },
    events: {
      change: onChange ? (e) => onChange((e.target as HTMLInputElement).value, e) : undefined,
    } as Record<string, EventListener>,
  }) as HTMLInputElement;

  const children: Node[] = [inputEl];

  if (label) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-radio-label',
      style: {
        marginLeft: t.spacing.sm,
        fontSize: getSizeStyles(size, 'text').fontSize,
        color: disabled ? t.colors.textMuted : t.colors.text,
        cursor: disabled ? 'not-allowed' : 'pointer',
      },
      children: [label],
    }));
  }

  return createElement({
    tag: 'label',
    className: mergeClasses('zylix-radio', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      cursor: disabled ? 'not-allowed' : 'pointer',
    },
    attrs: { for: id },
    children,
  });
}

export interface RadioGroupProps {
  name: string;
  options: { value: string; label: string; disabled?: boolean }[];
  value?: string;
  defaultValue?: string;
  disabled?: boolean;
  direction?: 'horizontal' | 'vertical';
  size?: ComponentSize;
  onChange?: (value: string) => void;
  className?: string;
}

export function RadioGroup(props: RadioGroupProps): HTMLElement {
  const {
    name,
    options,
    value,
    defaultValue,
    disabled = false,
    direction = 'vertical',
    size = 'md',
    onChange,
    className,
  } = props;

  const t = theme.get();
  let currentValue = value ?? defaultValue;

  const radios = options.map(opt => Radio({
    name,
    value: opt.value,
    checked: currentValue === opt.value,
    disabled: disabled || opt.disabled,
    label: opt.label,
    size,
    onChange: (val) => {
      currentValue = val;
      if (onChange) onChange(val);
    },
  }));

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-radio-group', className),
    style: {
      display: 'flex',
      flexDirection: direction === 'vertical' ? 'column' : 'row',
      gap: t.spacing.sm,
    },
    attrs: { role: 'radiogroup' },
    children: radios,
  });
}

export interface SwitchProps {
  checked?: boolean;
  defaultChecked?: boolean;
  disabled?: boolean;
  label?: string;
  size?: ComponentSize;
  onChange?: (checked: boolean) => void;
  className?: string;
  id?: string;
}

export function Switch(props: SwitchProps): HTMLElement {
  const {
    checked,
    defaultChecked,
    disabled = false,
    label,
    size = 'md',
    onChange,
    className,
    id = createId(),
  } = props;

  const t = theme.get();

  const sizes: Record<ComponentSize, { width: string; height: string; knob: string }> = {
    xs: { width: '28px', height: '16px', knob: '12px' },
    sm: { width: '32px', height: '18px', knob: '14px' },
    md: { width: '40px', height: '22px', knob: '18px' },
    lg: { width: '48px', height: '26px', knob: '22px' },
    xl: { width: '56px', height: '30px', knob: '26px' },
  };

  const switchSize = sizes[size];
  let isChecked = checked ?? defaultChecked ?? false;

  const knob = createElement({
    tag: 'span',
    className: 'zylix-switch-knob',
    style: {
      position: 'absolute',
      width: switchSize.knob,
      height: switchSize.knob,
      backgroundColor: t.colors.background,
      borderRadius: t.borderRadius.full,
      top: '2px',
      left: isChecked ? `calc(100% - ${switchSize.knob} - 2px)` : '2px',
      transition: `left ${t.transition.fast}`,
      boxShadow: t.shadow.sm,
    },
  });

  const track = createElement({
    tag: 'span',
    className: 'zylix-switch-track',
    style: {
      display: 'inline-block',
      position: 'relative',
      width: switchSize.width,
      height: switchSize.height,
      backgroundColor: isChecked ? t.colors.primary : t.colors.border,
      borderRadius: t.borderRadius.full,
      transition: `background-color ${t.transition.fast}`,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? '0.5' : '1',
    },
    children: [knob],
  });

  const inputEl = createElement({
    tag: 'input',
    className: 'zylix-switch-input',
    style: {
      position: 'absolute',
      width: '1px',
      height: '1px',
      padding: '0',
      margin: '-1px',
      overflow: 'hidden',
      clip: 'rect(0, 0, 0, 0)',
      whiteSpace: 'nowrap',
      border: '0',
    },
    attrs: {
      type: 'checkbox',
      id,
      checked: isChecked,
      disabled,
      role: 'switch',
      'aria-checked': isChecked,
    },
    events: {
      change: (e) => {
        isChecked = (e.target as HTMLInputElement).checked;
        track.style.backgroundColor = isChecked ? t.colors.primary : t.colors.border;
        knob.style.left = isChecked ? `calc(100% - ${switchSize.knob} - 2px)` : '2px';
        if (onChange) onChange(isChecked);
      },
    },
  }) as HTMLInputElement;

  const children: Node[] = [inputEl, track];

  if (label) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-switch-label',
      style: {
        marginLeft: t.spacing.sm,
        fontSize: getSizeStyles(size, 'text').fontSize,
        color: disabled ? t.colors.textMuted : t.colors.text,
      },
      children: [label],
    }));
  }

  return createElement({
    tag: 'label',
    className: mergeClasses('zylix-switch', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      cursor: disabled ? 'not-allowed' : 'pointer',
    },
    attrs: { for: id },
    children,
  });
}

export interface SliderProps {
  min?: number;
  max?: number;
  step?: number;
  value?: number;
  defaultValue?: number;
  disabled?: boolean;
  label?: string;
  showValue?: boolean;
  size?: ComponentSize;
  onChange?: (value: number) => void;
  className?: string;
  id?: string;
}

export function Slider(props: SliderProps): HTMLElement {
  const {
    min = 0,
    max = 100,
    step = 1,
    value,
    defaultValue = min,
    disabled = false,
    label,
    showValue = true,
    size = 'md',
    onChange,
    className,
    id = createId(),
  } = props;

  const t = theme.get();
  let currentValue = value ?? defaultValue;

  const heights: Record<ComponentSize, string> = {
    xs: '4px',
    sm: '6px',
    md: '8px',
    lg: '10px',
    xl: '12px',
  };

  const valueDisplay = showValue ? createElement({
    tag: 'span',
    className: 'zylix-slider-value',
    style: {
      minWidth: '40px',
      textAlign: 'right',
      fontSize: t.fontSize.sm,
      color: t.colors.text,
    },
    children: [String(currentValue)],
  }) : null;

  const inputEl = createElement({
    tag: 'input',
    className: 'zylix-slider-input',
    style: {
      width: '100%',
      height: heights[size],
      cursor: disabled ? 'not-allowed' : 'pointer',
      accentColor: t.colors.primary,
    },
    attrs: {
      type: 'range',
      id,
      min,
      max,
      step,
      value: currentValue,
      disabled,
    },
    events: {
      input: (e) => {
        currentValue = Number((e.target as HTMLInputElement).value);
        if (valueDisplay) {
          valueDisplay.textContent = String(currentValue);
        }
        if (onChange) onChange(currentValue);
      },
    },
  }) as HTMLInputElement;

  const children: (Node | string)[] = [];

  if (label) {
    children.push(createElement({
      tag: 'label',
      className: 'zylix-slider-label',
      style: {
        display: 'block',
        marginBottom: t.spacing.xs,
        fontSize: t.fontSize.sm,
        fontWeight: '500',
        color: t.colors.text,
      },
      attrs: { for: id },
      children: [label],
    }));
  }

  const sliderRow = createElement({
    tag: 'div',
    className: 'zylix-slider-row',
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: t.spacing.md,
    },
    children: valueDisplay ? [inputEl, valueDisplay] : [inputEl],
  });

  children.push(sliderRow);

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-slider', className),
    children,
  });
}

// ============================================================================
// Data Display Components
// ============================================================================

export interface CardProps {
  variant?: 'elevated' | 'outlined' | 'filled';
  padding?: string;
  radius?: keyof ThemeBorderRadius;
  hoverable?: boolean;
  clickable?: boolean;
  onClick?: () => void;
  className?: string;
  children?: (Node | string)[];
}

export function Card(props: CardProps): HTMLElement {
  const {
    variant = 'elevated',
    padding,
    radius = 'lg',
    hoverable = false,
    clickable = false,
    onClick,
    className,
    children,
  } = props;

  const t = theme.get();

  const variantStyles: Record<string, Record<string, string>> = {
    elevated: {
      backgroundColor: t.colors.background,
      boxShadow: t.shadow.md,
      border: 'none',
    },
    outlined: {
      backgroundColor: t.colors.background,
      boxShadow: 'none',
      border: `1px solid ${t.colors.border}`,
    },
    filled: {
      backgroundColor: t.colors.surface,
      boxShadow: 'none',
      border: 'none',
    },
  };

  const card = createElement({
    tag: clickable || onClick ? 'button' : 'div',
    className: mergeClasses('zylix-card', className),
    style: {
      padding: padding || t.spacing.lg,
      borderRadius: t.borderRadius[radius],
      transition: `all ${t.transition.fast}`,
      cursor: (hoverable || clickable || onClick) ? 'pointer' : undefined,
      textAlign: 'left',
      width: '100%',
      ...variantStyles[variant],
    },
    attrs: clickable || onClick ? { type: 'button' } : undefined,
    children,
    events: {
      click: onClick as EventListener | undefined,
      mouseenter: hoverable || clickable ? (e) => {
        const el = e.target as HTMLElement;
        if (variant === 'elevated') {
          el.style.boxShadow = t.shadow.lg;
        } else if (variant === 'outlined') {
          el.style.borderColor = t.colors.borderFocus;
        } else {
          el.style.backgroundColor = t.colors.surfaceHover;
        }
      } : undefined,
      mouseleave: hoverable || clickable ? (e) => {
        const el = e.target as HTMLElement;
        if (variant === 'elevated') {
          el.style.boxShadow = t.shadow.md;
        } else if (variant === 'outlined') {
          el.style.borderColor = t.colors.border;
        } else {
          el.style.backgroundColor = t.colors.surface;
        }
      } : undefined,
    } as Record<string, EventListener>,
  });

  return card;
}

export interface AvatarProps {
  src?: string;
  alt?: string;
  name?: string;
  size?: ComponentSize | number;
  shape?: 'circle' | 'square';
  className?: string;
}

export function Avatar(props: AvatarProps): HTMLElement {
  const {
    src,
    alt,
    name,
    size = 'md',
    shape = 'circle',
    className,
  } = props;

  const t = theme.get();

  const sizes: Record<ComponentSize, string> = {
    xs: '24px',
    sm: '32px',
    md: '40px',
    lg: '48px',
    xl: '64px',
  };

  const avatarSize = typeof size === 'number' ? `${size}px` : sizes[size];
  const fontSize = typeof size === 'number' ? `${size / 2.5}px` : getSizeStyles(size, 'text').fontSize;

  const getInitials = (name: string): string => {
    return name
      .split(' ')
      .map(part => part[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  const bgColors = [
    t.colors.primary,
    t.colors.secondary,
    t.colors.success,
    t.colors.warning,
    t.colors.danger,
    t.colors.info,
  ];

  const getColorFromName = (name: string): string => {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    return bgColors[Math.abs(hash) % bgColors.length];
  };

  const children: (Node | string)[] = [];

  if (src) {
    children.push(createElement({
      tag: 'img',
      style: {
        width: '100%',
        height: '100%',
        objectFit: 'cover',
      },
      attrs: {
        src,
        alt: alt || name || 'Avatar',
      },
    }));
  } else if (name) {
    children.push(getInitials(name));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-avatar', className),
    style: {
      width: avatarSize,
      height: avatarSize,
      borderRadius: shape === 'circle' ? t.borderRadius.full : t.borderRadius.md,
      backgroundColor: name ? getColorFromName(name) : t.colors.secondary,
      color: t.colors.textInverse,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize,
      fontWeight: '500',
      overflow: 'hidden',
      flexShrink: '0',
    },
    attrs: {
      role: 'img',
      'aria-label': alt || name || 'Avatar',
    },
    children,
  });
}

export interface BadgeProps {
  variant?: ComponentVariant;
  size?: ComponentSize;
  rounded?: boolean;
  dot?: boolean;
  className?: string;
  children?: (Node | string)[];
}

export function Badge(props: BadgeProps): HTMLElement {
  const {
    variant = 'primary',
    size = 'md',
    rounded = false,
    dot = false,
    className,
    children,
  } = props;

  const t = theme.get();
  const colors = getVariantColors(variant);

  const sizes: Record<ComponentSize, Record<string, string>> = {
    xs: { padding: `${t.spacing.xs} ${t.spacing.sm}`, fontSize: '10px' },
    sm: { padding: `${t.spacing.xs} ${t.spacing.sm}`, fontSize: t.fontSize.xs },
    md: { padding: `${t.spacing.xs} ${t.spacing.md}`, fontSize: t.fontSize.sm },
    lg: { padding: `${t.spacing.sm} ${t.spacing.md}`, fontSize: t.fontSize.md },
    xl: { padding: `${t.spacing.sm} ${t.spacing.lg}`, fontSize: t.fontSize.lg },
  };

  if (dot) {
    return createElement({
      tag: 'span',
      className: mergeClasses('zylix-badge', 'zylix-badge-dot', className),
      style: {
        display: 'inline-block',
        width: '8px',
        height: '8px',
        borderRadius: t.borderRadius.full,
        backgroundColor: colors.bg,
      },
    });
  }

  return createElement({
    tag: 'span',
    className: mergeClasses('zylix-badge', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: rounded ? t.borderRadius.full : t.borderRadius.sm,
      backgroundColor: colors.bg,
      color: colors.text,
      fontWeight: '500',
      whiteSpace: 'nowrap',
      ...sizes[size],
    },
    children,
  });
}

export interface TagProps {
  variant?: ComponentVariant;
  size?: ComponentSize;
  removable?: boolean;
  onRemove?: () => void;
  className?: string;
  children?: (Node | string)[];
}

export function Tag(props: TagProps): HTMLElement {
  const {
    variant = 'secondary',
    size = 'md',
    removable = false,
    onRemove,
    className,
    children = [],
  } = props;

  const t = theme.get();
  const colors = getVariantColors(variant);

  const sizes: Record<ComponentSize, Record<string, string>> = {
    xs: { padding: `2px ${t.spacing.sm}`, fontSize: '10px', gap: t.spacing.xs },
    sm: { padding: `${t.spacing.xs} ${t.spacing.sm}`, fontSize: t.fontSize.xs, gap: t.spacing.xs },
    md: { padding: `${t.spacing.xs} ${t.spacing.md}`, fontSize: t.fontSize.sm, gap: t.spacing.sm },
    lg: { padding: `${t.spacing.sm} ${t.spacing.md}`, fontSize: t.fontSize.md, gap: t.spacing.sm },
    xl: { padding: `${t.spacing.sm} ${t.spacing.lg}`, fontSize: t.fontSize.lg, gap: t.spacing.md },
  };

  const tagChildren: (Node | string)[] = [...children];

  if (removable) {
    tagChildren.push(createElement({
      tag: 'button',
      className: 'zylix-tag-remove',
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0',
        border: 'none',
        background: 'none',
        color: 'inherit',
        cursor: 'pointer',
        opacity: '0.7',
        marginLeft: t.spacing.xs,
      },
      attrs: { type: 'button', 'aria-label': 'Remove' },
      children: ['×'],
      events: {
        click: (e) => {
          e.stopPropagation();
          if (onRemove) onRemove();
        },
        mouseenter: (e) => {
          (e.target as HTMLElement).style.opacity = '1';
        },
        mouseleave: (e) => {
          (e.target as HTMLElement).style.opacity = '0.7';
        },
      },
    }));
  }

  return createElement({
    tag: 'span',
    className: mergeClasses('zylix-tag', className),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      borderRadius: t.borderRadius.md,
      backgroundColor: `${colors.bg}20`,
      color: colors.bg,
      fontWeight: '500',
      ...sizes[size],
    },
    children: tagChildren,
  });
}

export interface TooltipProps {
  content: string;
  position?: 'top' | 'bottom' | 'left' | 'right';
  delay?: number;
  className?: string;
  children: Node;
}

export function Tooltip(props: TooltipProps): HTMLElement {
  const {
    content,
    position = 'top',
    delay = 200,
    className,
    children,
  } = props;

  const t = theme.get();
  let tooltipEl: HTMLElement | null = null;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  const showTooltip = (target: HTMLElement) => {
    if (tooltipEl) return;

    tooltipEl = createElement({
      tag: 'div',
      className: 'zylix-tooltip-content',
      style: {
        position: 'fixed',
        padding: `${t.spacing.xs} ${t.spacing.sm}`,
        backgroundColor: t.colors.text,
        color: t.colors.textInverse,
        borderRadius: t.borderRadius.sm,
        fontSize: t.fontSize.xs,
        zIndex: '9999',
        pointerEvents: 'none',
        whiteSpace: 'nowrap',
        opacity: '0',
        transition: `opacity ${t.transition.fast}`,
      },
      attrs: { role: 'tooltip' },
      children: [content],
    });

    document.body.appendChild(tooltipEl);

    const rect = target.getBoundingClientRect();
    const tooltipRect = tooltipEl.getBoundingClientRect();

    let top = 0;
    let left = 0;

    switch (position) {
      case 'top':
        top = rect.top - tooltipRect.height - 8;
        left = rect.left + (rect.width - tooltipRect.width) / 2;
        break;
      case 'bottom':
        top = rect.bottom + 8;
        left = rect.left + (rect.width - tooltipRect.width) / 2;
        break;
      case 'left':
        top = rect.top + (rect.height - tooltipRect.height) / 2;
        left = rect.left - tooltipRect.width - 8;
        break;
      case 'right':
        top = rect.top + (rect.height - tooltipRect.height) / 2;
        left = rect.right + 8;
        break;
    }

    tooltipEl.style.top = `${top}px`;
    tooltipEl.style.left = `${left}px`;

    requestAnimationFrame(() => {
      if (tooltipEl) tooltipEl.style.opacity = '1';
    });
  };

  const hideTooltip = () => {
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
    if (tooltipEl) {
      tooltipEl.style.opacity = '0';
      setTimeout(() => {
        if (tooltipEl) {
          tooltipEl.remove();
          tooltipEl = null;
        }
      }, 150);
    }
  };

  const wrapper = createElement({
    tag: 'span',
    className: mergeClasses('zylix-tooltip', className),
    style: { display: 'inline-block' },
    children: [children],
    events: {
      mouseenter: (e) => {
        timeoutId = setTimeout(() => showTooltip(e.target as HTMLElement), delay);
      },
      mouseleave: hideTooltip,
      focusin: (e) => showTooltip(e.target as HTMLElement),
      focusout: hideTooltip,
    },
  });

  return wrapper;
}

// ============================================================================
// Feedback Components
// ============================================================================

export interface AlertProps {
  variant?: 'info' | 'success' | 'warning' | 'danger';
  title?: string;
  closable?: boolean;
  onClose?: () => void;
  className?: string;
  children?: (Node | string)[];
}

export function Alert(props: AlertProps): HTMLElement {
  const {
    variant = 'info',
    title,
    closable = false,
    onClose,
    className,
    children,
  } = props;

  const t = theme.get();

  const variantStyles: Record<string, { bg: string; border: string; text: string; icon: string }> = {
    info: {
      bg: `${t.colors.info}15`,
      border: t.colors.info,
      text: t.colors.info,
      icon: 'ℹ️',
    },
    success: {
      bg: `${t.colors.success}15`,
      border: t.colors.success,
      text: t.colors.success,
      icon: '✓',
    },
    warning: {
      bg: `${t.colors.warning}15`,
      border: t.colors.warning,
      text: t.colors.warning,
      icon: '⚠',
    },
    danger: {
      bg: `${t.colors.danger}15`,
      border: t.colors.danger,
      text: t.colors.danger,
      icon: '✕',
    },
  };

  const styles = variantStyles[variant];

  const alertChildren: (Node | string)[] = [];

  // Icon
  alertChildren.push(createElement({
    tag: 'span',
    className: 'zylix-alert-icon',
    style: {
      marginRight: t.spacing.sm,
      fontSize: t.fontSize.lg,
    },
    children: [styles.icon],
  }));

  // Content
  const contentChildren: (Node | string)[] = [];

  if (title) {
    contentChildren.push(createElement({
      tag: 'div',
      className: 'zylix-alert-title',
      style: {
        fontWeight: '600',
        marginBottom: children ? t.spacing.xs : undefined,
      },
      children: [title],
    }));
  }

  if (children) {
    contentChildren.push(createElement({
      tag: 'div',
      className: 'zylix-alert-content',
      children,
    }));
  }

  alertChildren.push(createElement({
    tag: 'div',
    className: 'zylix-alert-body',
    style: { flex: '1' },
    children: contentChildren,
  }));

  // Close button
  if (closable) {
    alertChildren.push(createElement({
      tag: 'button',
      className: 'zylix-alert-close',
      style: {
        padding: t.spacing.xs,
        border: 'none',
        background: 'none',
        color: styles.text,
        cursor: 'pointer',
        opacity: '0.7',
        fontSize: t.fontSize.lg,
      },
      attrs: { type: 'button', 'aria-label': 'Close' },
      children: ['×'],
      events: {
        click: () => {
          if (onClose) onClose();
        },
        mouseenter: (e) => {
          (e.target as HTMLElement).style.opacity = '1';
        },
        mouseleave: (e) => {
          (e.target as HTMLElement).style.opacity = '0.7';
        },
      },
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-alert', className),
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      padding: t.spacing.md,
      backgroundColor: styles.bg,
      borderLeft: `4px solid ${styles.border}`,
      borderRadius: t.borderRadius.md,
      color: styles.text,
    },
    attrs: { role: 'alert' },
    children: alertChildren,
  });
}

export interface ToastOptions {
  variant?: 'info' | 'success' | 'warning' | 'danger';
  duration?: number;
  position?: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left' | 'top-center' | 'bottom-center';
}

let toastContainer: HTMLElement | null = null;

export function toast(message: string, options: ToastOptions = {}): void {
  const {
    variant = 'info',
    duration = 3000,
    position = 'top-right',
  } = options;

  const t = theme.get();

  // Create container if needed
  if (!toastContainer) {
    toastContainer = createElement({
      tag: 'div',
      className: 'zylix-toast-container',
      style: {
        position: 'fixed',
        zIndex: '10000',
        pointerEvents: 'none',
      },
    });
    document.body.appendChild(toastContainer);
  }

  // Position the container
  const positions: Record<string, Record<string, string>> = {
    'top-right': { top: t.spacing.lg, right: t.spacing.lg },
    'top-left': { top: t.spacing.lg, left: t.spacing.lg },
    'bottom-right': { bottom: t.spacing.lg, right: t.spacing.lg },
    'bottom-left': { bottom: t.spacing.lg, left: t.spacing.lg },
    'top-center': { top: t.spacing.lg, left: '50%', transform: 'translateX(-50%)' },
    'bottom-center': { bottom: t.spacing.lg, left: '50%', transform: 'translateX(-50%)' },
  };

  Object.assign(toastContainer.style, positions[position]);

  const colors: Record<string, { bg: string; text: string }> = {
    info: { bg: t.colors.info, text: t.colors.textInverse },
    success: { bg: t.colors.success, text: t.colors.textInverse },
    warning: { bg: t.colors.warning, text: t.colors.text },
    danger: { bg: t.colors.danger, text: t.colors.textInverse },
  };

  const toastEl = createElement({
    tag: 'div',
    className: 'zylix-toast',
    style: {
      padding: `${t.spacing.md} ${t.spacing.lg}`,
      backgroundColor: colors[variant].bg,
      color: colors[variant].text,
      borderRadius: t.borderRadius.md,
      boxShadow: t.shadow.lg,
      marginBottom: t.spacing.sm,
      pointerEvents: 'auto',
      opacity: '0',
      transform: 'translateY(-10px)',
      transition: `all ${t.transition.normal}`,
    },
    attrs: { role: 'alert' },
    children: [message],
  });

  toastContainer.appendChild(toastEl);

  // Animate in
  requestAnimationFrame(() => {
    toastEl.style.opacity = '1';
    toastEl.style.transform = 'translateY(0)';
  });

  // Remove after duration
  setTimeout(() => {
    toastEl.style.opacity = '0';
    toastEl.style.transform = 'translateY(-10px)';
    setTimeout(() => {
      toastEl.remove();
    }, 250);
  }, duration);
}

export interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  closeOnOverlay?: boolean;
  closeOnEsc?: boolean;
  showCloseButton?: boolean;
  className?: string;
  children?: (Node | string)[];
}

export function Modal(props: ModalProps): HTMLElement | null {
  const {
    isOpen,
    onClose,
    title,
    size = 'md',
    closeOnOverlay = true,
    closeOnEsc = true,
    showCloseButton = true,
    className,
    children,
  } = props;

  if (!isOpen) return null;

  const t = theme.get();

  const sizes: Record<string, string> = {
    sm: '400px',
    md: '500px',
    lg: '700px',
    xl: '900px',
    full: '100%',
  };

  // Handle ESC key
  const handleKeyDown = (e: KeyboardEvent) => {
    if (closeOnEsc && e.key === 'Escape') {
      onClose();
    }
  };

  document.addEventListener('keydown', handleKeyDown);

  const modalContent: (Node | string)[] = [];

  // Header
  if (title || showCloseButton) {
    const headerChildren: (Node | string)[] = [];

    if (title) {
      headerChildren.push(createElement({
        tag: 'h2',
        className: 'zylix-modal-title',
        style: {
          margin: '0',
          fontSize: t.fontSize.xl,
          fontWeight: '600',
        },
        children: [title],
      }));
    }

    if (showCloseButton) {
      headerChildren.push(createElement({
        tag: 'button',
        className: 'zylix-modal-close',
        style: {
          marginLeft: 'auto',
          padding: t.spacing.xs,
          border: 'none',
          background: 'none',
          cursor: 'pointer',
          fontSize: t.fontSize.xl,
          color: t.colors.textMuted,
        },
        attrs: { type: 'button', 'aria-label': 'Close modal' },
        children: ['×'],
        events: {
          click: () => {
            document.removeEventListener('keydown', handleKeyDown);
            onClose();
          },
        },
      }));
    }

    modalContent.push(createElement({
      tag: 'div',
      className: 'zylix-modal-header',
      style: {
        display: 'flex',
        alignItems: 'center',
        padding: t.spacing.lg,
        borderBottom: `1px solid ${t.colors.border}`,
      },
      children: headerChildren,
    }));
  }

  // Body
  modalContent.push(createElement({
    tag: 'div',
    className: 'zylix-modal-body',
    style: {
      padding: t.spacing.lg,
      overflow: 'auto',
      maxHeight: size === 'full' ? undefined : '70vh',
    },
    children,
  }));

  const dialog = createElement({
    tag: 'div',
    className: 'zylix-modal-content',
    style: {
      backgroundColor: t.colors.background,
      borderRadius: size === 'full' ? '0' : t.borderRadius.lg,
      boxShadow: t.shadow.xl,
      width: '100%',
      maxWidth: sizes[size],
      maxHeight: size === 'full' ? '100%' : '90vh',
      display: 'flex',
      flexDirection: 'column',
      animation: 'zylix-modal-in 0.2s ease',
    },
    attrs: {
      role: 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': title ? 'modal-title' : undefined,
    },
    children: modalContent,
    events: {
      click: (e) => e.stopPropagation(),
    },
  });

  const overlay = createElement({
    tag: 'div',
    className: mergeClasses('zylix-modal', className),
    style: {
      position: 'fixed',
      inset: '0',
      backgroundColor: t.colors.overlay,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: size === 'full' ? '0' : t.spacing.lg,
      zIndex: '1000',
    },
    children: [dialog],
    events: closeOnOverlay ? {
      click: () => {
        document.removeEventListener('keydown', handleKeyDown);
        onClose();
      },
    } : undefined,
  });

  // Add animation keyframes
  if (!document.getElementById('zylix-modal-styles')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'zylix-modal-styles';
    styleEl.textContent = `
      @keyframes zylix-modal-in {
        from {
          opacity: 0;
          transform: scale(0.95);
        }
        to {
          opacity: 1;
          transform: scale(1);
        }
      }
    `;
    document.head.appendChild(styleEl);
  }

  return overlay;
}

export interface ProgressProps {
  value: number;
  max?: number;
  size?: ComponentSize;
  variant?: ComponentVariant;
  showLabel?: boolean;
  striped?: boolean;
  animated?: boolean;
  className?: string;
}

export function Progress(props: ProgressProps): HTMLElement {
  const {
    value,
    max = 100,
    size = 'md',
    variant = 'primary',
    showLabel = false,
    striped = false,
    animated = false,
    className,
  } = props;

  const t = theme.get();
  const colors = getVariantColors(variant);
  const percentage = Math.min(100, Math.max(0, (value / max) * 100));

  const heights: Record<ComponentSize, string> = {
    xs: '4px',
    sm: '6px',
    md: '10px',
    lg: '14px',
    xl: '20px',
  };

  // Add striped animation if needed
  if ((striped || animated) && !document.getElementById('zylix-progress-styles')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'zylix-progress-styles';
    styleEl.textContent = `
      @keyframes zylix-progress-stripes {
        from { background-position: 1rem 0; }
        to { background-position: 0 0; }
      }
    `;
    document.head.appendChild(styleEl);
  }

  const bar = createElement({
    tag: 'div',
    className: 'zylix-progress-bar',
    style: {
      width: `${percentage}%`,
      height: '100%',
      backgroundColor: colors.bg,
      borderRadius: t.borderRadius.full,
      transition: `width ${t.transition.normal}`,
      backgroundImage: striped || animated
        ? 'linear-gradient(45deg, rgba(255,255,255,0.15) 25%, transparent 25%, transparent 50%, rgba(255,255,255,0.15) 50%, rgba(255,255,255,0.15) 75%, transparent 75%, transparent)'
        : undefined,
      backgroundSize: striped || animated ? '1rem 1rem' : undefined,
      animation: animated ? 'zylix-progress-stripes 1s linear infinite' : undefined,
    },
    attrs: {
      role: 'progressbar',
      'aria-valuenow': value,
      'aria-valuemin': 0,
      'aria-valuemax': max,
    },
  });

  const progressChildren: (Node | string)[] = [bar];

  const track = createElement({
    tag: 'div',
    className: 'zylix-progress-track',
    style: {
      width: '100%',
      height: heights[size],
      backgroundColor: t.colors.surface,
      borderRadius: t.borderRadius.full,
      overflow: 'hidden',
    },
    children: [bar],
  });

  const children: (Node | string)[] = [track];

  if (showLabel) {
    children.push(createElement({
      tag: 'span',
      className: 'zylix-progress-label',
      style: {
        marginLeft: t.spacing.sm,
        fontSize: t.fontSize.sm,
        color: t.colors.textSecondary,
        minWidth: '40px',
        textAlign: 'right',
      },
      children: [`${Math.round(percentage)}%`],
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-progress', className),
    style: {
      display: 'flex',
      alignItems: 'center',
    },
    children,
  });
}

export interface SpinnerProps {
  size?: ComponentSize | number;
  color?: string;
  thickness?: number;
  className?: string;
}

export function Spinner(props: SpinnerProps = {}): HTMLElement {
  const {
    size = 'md',
    color,
    thickness = 3,
    className,
  } = props;

  const t = theme.get();

  const sizes: Record<ComponentSize, string> = {
    xs: '12px',
    sm: '16px',
    md: '24px',
    lg: '32px',
    xl: '48px',
  };

  const spinnerSize = typeof size === 'number' ? `${size}px` : sizes[size];

  // Add spinner animation if needed
  if (!document.getElementById('zylix-spinner-styles')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'zylix-spinner-styles';
    styleEl.textContent = `
      @keyframes zylix-spin {
        to { transform: rotate(360deg); }
      }
    `;
    document.head.appendChild(styleEl);
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-spinner', className),
    style: {
      width: spinnerSize,
      height: spinnerSize,
      border: `${thickness}px solid ${t.colors.border}`,
      borderTopColor: color || t.colors.primary,
      borderRadius: t.borderRadius.full,
      animation: 'zylix-spin 0.8s linear infinite',
    },
    attrs: {
      role: 'status',
      'aria-label': 'Loading',
    },
  });
}

export interface SkeletonProps {
  variant?: 'text' | 'circular' | 'rectangular';
  width?: string | number;
  height?: string | number;
  lines?: number;
  className?: string;
}

export function Skeleton(props: SkeletonProps = {}): HTMLElement {
  const {
    variant = 'text',
    width,
    height,
    lines = 1,
    className,
  } = props;

  const t = theme.get();

  // Add skeleton animation if needed
  if (!document.getElementById('zylix-skeleton-styles')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'zylix-skeleton-styles';
    styleEl.textContent = `
      @keyframes zylix-skeleton-pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
    `;
    document.head.appendChild(styleEl);
  }

  const createSkeletonLine = (w?: string | number, h?: string | number): HTMLElement => {
    const getWidth = () => {
      if (w !== undefined) return typeof w === 'number' ? `${w}px` : w;
      return variant === 'circular' ? (h !== undefined ? (typeof h === 'number' ? `${h}px` : h) : '40px') : '100%';
    };

    const getHeight = () => {
      if (h !== undefined) return typeof h === 'number' ? `${h}px` : h;
      if (variant === 'text') return t.fontSize.md;
      if (variant === 'circular') return getWidth();
      return '100px';
    };

    return createElement({
      tag: 'div',
      className: 'zylix-skeleton-line',
      style: {
        width: getWidth(),
        height: getHeight(),
        backgroundColor: t.colors.surface,
        borderRadius: variant === 'circular' ? t.borderRadius.full : t.borderRadius.sm,
        animation: 'zylix-skeleton-pulse 1.5s ease-in-out infinite',
      },
    });
  };

  if (lines === 1 || variant !== 'text') {
    return createElement({
      tag: 'div',
      className: mergeClasses('zylix-skeleton', className),
      children: [createSkeletonLine(width, height)],
    });
  }

  const skeletonLines: Node[] = [];
  for (let i = 0; i < lines; i++) {
    const lineWidth = i === lines - 1 ? '75%' : '100%';
    skeletonLines.push(createSkeletonLine(lineWidth, height));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-skeleton', className),
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: t.spacing.sm,
    },
    children: skeletonLines,
  });
}

// ============================================================================
// Navigation Components
// ============================================================================

export interface TabsProps {
  tabs: { id: string; label: string; content?: Node | string; disabled?: boolean }[];
  activeTab?: string;
  defaultTab?: string;
  variant?: 'line' | 'enclosed' | 'pills';
  size?: ComponentSize;
  onChange?: (tabId: string) => void;
  className?: string;
}

export function Tabs(props: TabsProps): HTMLElement {
  const {
    tabs,
    activeTab,
    defaultTab,
    variant = 'line',
    size = 'md',
    onChange,
    className,
  } = props;

  const t = theme.get();
  let currentTab = activeTab ?? defaultTab ?? tabs[0]?.id;

  const sizeStyles = getSizeStyles(size, 'button');

  const tabButtons: Node[] = tabs.map(tab => {
    const isActive = tab.id === currentTab;

    const getTabStyles = (): Record<string, string | undefined> => {
      const base: Record<string, string | undefined> = {
        ...sizeStyles,
        border: 'none',
        backgroundColor: 'transparent',
        color: isActive ? t.colors.primary : t.colors.textSecondary,
        cursor: tab.disabled ? 'not-allowed' : 'pointer',
        opacity: tab.disabled ? '0.5' : '1',
        transition: `all ${t.transition.fast}`,
        fontWeight: isActive ? '600' : '400',
      };

      if (variant === 'line') {
        base.borderBottom = isActive ? `2px solid ${t.colors.primary}` : '2px solid transparent';
        base.marginBottom = '-1px';
      } else if (variant === 'enclosed') {
        base.border = isActive ? `1px solid ${t.colors.border}` : '1px solid transparent';
        base.borderBottom = isActive ? `1px solid ${t.colors.background}` : undefined;
        base.backgroundColor = isActive ? t.colors.background : undefined;
        base.borderRadius = `${t.borderRadius.md} ${t.borderRadius.md} 0 0`;
        base.marginBottom = '-1px';
      } else if (variant === 'pills') {
        base.backgroundColor = isActive ? t.colors.primary : 'transparent';
        base.color = isActive ? t.colors.textInverse : t.colors.textSecondary;
        base.borderRadius = t.borderRadius.full;
      }

      return base;
    };

    return createElement({
      tag: 'button',
      className: 'zylix-tab-button',
      style: getTabStyles(),
      attrs: {
        type: 'button',
        role: 'tab',
        'aria-selected': isActive,
        'aria-controls': `tabpanel-${tab.id}`,
        disabled: tab.disabled,
      },
      children: [tab.label],
      events: !tab.disabled ? {
        click: () => {
          currentTab = tab.id;
          if (onChange) onChange(tab.id);
        },
      } : undefined,
    });
  });

  const tabList = createElement({
    tag: 'div',
    className: 'zylix-tabs-list',
    style: {
      display: 'flex',
      gap: variant === 'pills' ? t.spacing.sm : '0',
      borderBottom: variant === 'line' || variant === 'enclosed' ? `1px solid ${t.colors.border}` : undefined,
    },
    attrs: { role: 'tablist' },
    children: tabButtons,
  });

  const children: Node[] = [tabList];

  // Add tab panels
  const activeTabData = tabs.find(tab => tab.id === currentTab);
  if (activeTabData?.content) {
    children.push(createElement({
      tag: 'div',
      className: 'zylix-tab-panel',
      style: {
        padding: t.spacing.lg,
      },
      attrs: {
        role: 'tabpanel',
        id: `tabpanel-${activeTabData.id}`,
      },
      children: [activeTabData.content],
    }));
  }

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-tabs', className),
    children,
  });
}

export interface BreadcrumbItem {
  label: string;
  href?: string;
  onClick?: () => void;
}

export interface BreadcrumbProps {
  items: BreadcrumbItem[];
  separator?: string | Node;
  className?: string;
}

export function Breadcrumb(props: BreadcrumbProps): HTMLElement {
  const {
    items,
    separator = '/',
    className,
  } = props;

  const t = theme.get();

  const breadcrumbItems: Node[] = [];

  items.forEach((item, index) => {
    const isLast = index === items.length - 1;

    if (index > 0) {
      breadcrumbItems.push(createElement({
        tag: 'span',
        className: 'zylix-breadcrumb-separator',
        style: {
          margin: `0 ${t.spacing.sm}`,
          color: t.colors.textMuted,
        },
        attrs: { 'aria-hidden': 'true' },
        children: typeof separator === 'string' ? [separator] : [separator],
      }));
    }

    if (isLast || (!item.href && !item.onClick)) {
      breadcrumbItems.push(createElement({
        tag: 'span',
        className: 'zylix-breadcrumb-item',
        style: {
          color: isLast ? t.colors.text : t.colors.textSecondary,
          fontWeight: isLast ? '500' : undefined,
        },
        attrs: isLast ? { 'aria-current': 'page' } : undefined,
        children: [item.label],
      }));
    } else {
      breadcrumbItems.push(createElement({
        tag: 'a',
        className: 'zylix-breadcrumb-link',
        style: {
          color: t.colors.primary,
          textDecoration: 'none',
          cursor: 'pointer',
        },
        attrs: item.href ? { href: item.href } : undefined,
        children: [item.label],
        events: item.onClick ? { click: item.onClick as EventListener } : undefined,
      }));
    }
  });

  return createElement({
    tag: 'nav',
    className: mergeClasses('zylix-breadcrumb', className),
    style: {
      fontSize: t.fontSize.sm,
    },
    attrs: { 'aria-label': 'Breadcrumb' },
    children: [createElement({
      tag: 'ol',
      style: {
        display: 'flex',
        alignItems: 'center',
        listStyle: 'none',
        margin: '0',
        padding: '0',
      },
      children: breadcrumbItems.map(item => createElement({
        tag: 'li',
        style: { display: 'inline-flex', alignItems: 'center' },
        children: [item],
      })),
    })],
  });
}

export interface PaginationProps {
  total: number;
  page?: number;
  defaultPage?: number;
  pageSize?: number;
  siblings?: number;
  boundaries?: number;
  showFirst?: boolean;
  showLast?: boolean;
  onChange?: (page: number) => void;
  className?: string;
}

export function Pagination(props: PaginationProps): HTMLElement {
  const {
    total,
    page,
    defaultPage = 1,
    pageSize = 10,
    siblings = 1,
    boundaries = 1,
    showFirst = true,
    showLast = true,
    onChange,
    className,
  } = props;

  const t = theme.get();
  let currentPage = page ?? defaultPage;
  const totalPages = Math.ceil(total / pageSize);

  const range = (start: number, end: number): number[] => {
    const length = end - start + 1;
    return Array.from({ length }, (_, i) => start + i);
  };

  const getPageNumbers = (): (number | string)[] => {
    const totalNumbers = siblings * 2 + 3 + boundaries * 2;

    if (totalNumbers >= totalPages) {
      return range(1, totalPages);
    }

    const leftSiblingIndex = Math.max(currentPage - siblings, boundaries + 1);
    const rightSiblingIndex = Math.min(currentPage + siblings, totalPages - boundaries);

    const showLeftDots = leftSiblingIndex > boundaries + 2;
    const showRightDots = rightSiblingIndex < totalPages - boundaries - 1;

    if (!showLeftDots && showRightDots) {
      const leftItemCount = 3 + 2 * siblings + boundaries;
      const leftRange = range(1, leftItemCount);
      return [...leftRange, '...', ...range(totalPages - boundaries + 1, totalPages)];
    }

    if (showLeftDots && !showRightDots) {
      const rightItemCount = 3 + 2 * siblings + boundaries;
      const rightRange = range(totalPages - rightItemCount + 1, totalPages);
      return [...range(1, boundaries), '...', ...rightRange];
    }

    const middleRange = range(leftSiblingIndex, rightSiblingIndex);
    return [
      ...range(1, boundaries),
      '...',
      ...middleRange,
      '...',
      ...range(totalPages - boundaries + 1, totalPages),
    ];
  };

  const createButton = (content: string | number, pageNum?: number, disabled = false): HTMLElement => {
    const isActive = pageNum === currentPage;

    return createElement({
      tag: 'button',
      className: 'zylix-pagination-button',
      style: {
        minWidth: '32px',
        height: '32px',
        padding: `0 ${t.spacing.sm}`,
        border: `1px solid ${isActive ? t.colors.primary : t.colors.border}`,
        borderRadius: t.borderRadius.sm,
        backgroundColor: isActive ? t.colors.primary : t.colors.background,
        color: isActive ? t.colors.textInverse : t.colors.text,
        cursor: disabled || isActive ? 'default' : 'pointer',
        opacity: disabled ? '0.5' : '1',
        fontSize: t.fontSize.sm,
        transition: `all ${t.transition.fast}`,
      },
      attrs: {
        type: 'button',
        disabled,
        'aria-current': isActive ? 'page' : undefined,
      },
      children: [String(content)],
      events: !disabled && !isActive && pageNum ? {
        click: () => {
          currentPage = pageNum;
          if (onChange) onChange(pageNum);
        },
      } : undefined,
    });
  };

  const buttons: Node[] = [];

  // First button
  if (showFirst) {
    buttons.push(createButton('«', 1, currentPage === 1));
  }

  // Previous button
  buttons.push(createButton('‹', currentPage - 1, currentPage === 1));

  // Page numbers
  for (const pageNum of getPageNumbers()) {
    if (pageNum === '...') {
      buttons.push(createElement({
        tag: 'span',
        className: 'zylix-pagination-ellipsis',
        style: {
          padding: `0 ${t.spacing.sm}`,
          color: t.colors.textMuted,
        },
        children: ['...'],
      }));
    } else {
      buttons.push(createButton(pageNum as number, pageNum as number));
    }
  }

  // Next button
  buttons.push(createButton('›', currentPage + 1, currentPage === totalPages));

  // Last button
  if (showLast) {
    buttons.push(createButton('»', totalPages, currentPage === totalPages));
  }

  return createElement({
    tag: 'nav',
    className: mergeClasses('zylix-pagination', className),
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: t.spacing.xs,
    },
    attrs: { 'aria-label': 'Pagination' },
    children: buttons,
  });
}

export interface MenuItemProps {
  label: string;
  icon?: Node;
  disabled?: boolean;
  danger?: boolean;
  onClick?: () => void;
}

export interface MenuProps {
  items: MenuItemProps[];
  className?: string;
}

export function Menu(props: MenuProps): HTMLElement {
  const { items, className } = props;
  const t = theme.get();

  const menuItems = items.map(item => createElement({
    tag: 'button',
    className: 'zylix-menu-item',
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: t.spacing.sm,
      width: '100%',
      padding: `${t.spacing.sm} ${t.spacing.md}`,
      border: 'none',
      backgroundColor: 'transparent',
      color: item.danger ? t.colors.danger : t.colors.text,
      cursor: item.disabled ? 'not-allowed' : 'pointer',
      opacity: item.disabled ? '0.5' : '1',
      fontSize: t.fontSize.sm,
      textAlign: 'left',
      transition: `background-color ${t.transition.fast}`,
    },
    attrs: {
      type: 'button',
      disabled: item.disabled,
      role: 'menuitem',
    },
    children: item.icon ? [item.icon, item.label] : [item.label],
    events: !item.disabled && item.onClick ? {
      click: item.onClick as EventListener,
      mouseenter: (e) => {
        (e.target as HTMLElement).style.backgroundColor = t.colors.surfaceHover;
      },
      mouseleave: (e) => {
        (e.target as HTMLElement).style.backgroundColor = 'transparent';
      },
    } : undefined,
  }));

  return createElement({
    tag: 'div',
    className: mergeClasses('zylix-menu', className),
    style: {
      minWidth: '160px',
      padding: t.spacing.xs,
      backgroundColor: t.colors.background,
      border: `1px solid ${t.colors.border}`,
      borderRadius: t.borderRadius.md,
      boxShadow: t.shadow.lg,
    },
    attrs: { role: 'menu' },
    children: menuItems,
  });
}

// ============================================================================
// Overlay Components
// ============================================================================

export interface DropdownProps {
  trigger: Node;
  items: MenuItemProps[];
  position?: 'bottom-start' | 'bottom-end' | 'top-start' | 'top-end';
  className?: string;
}

export function Dropdown(props: DropdownProps): HTMLElement {
  const {
    trigger,
    items,
    position = 'bottom-start',
    className,
  } = props;

  const t = theme.get();
  let isOpen = false;
  let menuEl: HTMLElement | null = null;

  const toggleMenu = () => {
    isOpen = !isOpen;
    if (menuEl) {
      menuEl.style.display = isOpen ? 'block' : 'none';
    }
  };

  const closeMenu = () => {
    isOpen = false;
    if (menuEl) {
      menuEl.style.display = 'none';
    }
  };

  // Create menu items with close on click
  const menuItems = items.map(item => ({
    ...item,
    onClick: () => {
      if (item.onClick) item.onClick();
      closeMenu();
    },
  }));

  menuEl = Menu({ items: menuItems });
  menuEl.style.display = 'none';
  menuEl.style.position = 'absolute';
  menuEl.style.zIndex = '100';

  // Position the menu
  const positionStyles: Record<string, Record<string, string>> = {
    'bottom-start': { top: '100%', left: '0', marginTop: t.spacing.xs },
    'bottom-end': { top: '100%', right: '0', marginTop: t.spacing.xs },
    'top-start': { bottom: '100%', left: '0', marginBottom: t.spacing.xs },
    'top-end': { bottom: '100%', right: '0', marginBottom: t.spacing.xs },
  };

  Object.assign(menuEl.style, positionStyles[position]);

  const triggerWrapper = createElement({
    tag: 'div',
    className: 'zylix-dropdown-trigger',
    children: [trigger],
    events: {
      click: (e) => {
        e.stopPropagation();
        toggleMenu();
      },
    },
  });

  const dropdown = createElement({
    tag: 'div',
    className: mergeClasses('zylix-dropdown', className),
    style: {
      position: 'relative',
      display: 'inline-block',
    },
    children: [triggerWrapper, menuEl],
  });

  // Close on click outside
  document.addEventListener('click', closeMenu);

  return dropdown;
}

// ============================================================================
// Export All
// ============================================================================

export {
  // Theme
  defaultTheme,

  // Utils
  createId,
  mergeClasses,
  createStyleString,
  getVariantColors,
  getSizeStyles,
};
