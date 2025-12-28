/**
 * Zylix Form Library
 * React-hook-form inspired form management with validation
 */

// ========================================
// Types
// ========================================

export type FieldValue = string | number | boolean | Date | null | undefined;
export type FieldValues = Record<string, FieldValue | FieldValue[] | Record<string, FieldValue>>;

export interface ValidationRule {
  validate: (value: FieldValue, formValues: FieldValues) => boolean | Promise<boolean>;
  message: string | ((value: FieldValue) => string);
}

export interface FieldState {
  value: FieldValue;
  error: string | null;
  touched: boolean;
  dirty: boolean;
  validating: boolean;
}

export interface FieldConfig {
  defaultValue?: FieldValue;
  validation?: ValidationRule[];
  validateOnChange?: boolean;
  validateOnBlur?: boolean;
}

export interface FormConfig<T extends FieldValues> {
  defaultValues: T;
  validation?: Partial<Record<keyof T, ValidationRule[]>>;
  validateOnChange?: boolean;
  validateOnBlur?: boolean;
  validateOnSubmit?: boolean;
  mode?: 'onChange' | 'onBlur' | 'onSubmit' | 'all';
}

export interface FormState<T extends FieldValues> {
  values: T;
  errors: Partial<Record<keyof T, string>>;
  touched: Partial<Record<keyof T, boolean>>;
  dirty: Partial<Record<keyof T, boolean>>;
  isValid: boolean;
  isSubmitting: boolean;
  isValidating: boolean;
  submitCount: number;
}

export interface RegisterResult {
  name: string;
  value: FieldValue;
  onChange: (e: Event | FieldValue) => void;
  onBlur: (e: Event) => void;
  onFocus: (e: Event) => void;
  ref: (el: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | null) => void;
}

export interface UseFormReturn<T extends FieldValues> {
  // Registration
  register: (name: keyof T, config?: FieldConfig) => RegisterResult;
  unregister: (name: keyof T) => void;

  // Values
  getValues: () => T;
  getValue: (name: keyof T) => FieldValue;
  setValue: (name: keyof T, value: FieldValue, options?: { shouldValidate?: boolean; shouldDirty?: boolean }) => void;
  setValues: (values: Partial<T>, options?: { shouldValidate?: boolean }) => void;
  reset: (values?: Partial<T>) => void;

  // Validation
  validate: (name?: keyof T) => Promise<boolean>;
  clearErrors: (name?: keyof T) => void;
  setError: (name: keyof T, message: string) => void;

  // Form state
  formState: FormState<T>;
  errors: Partial<Record<keyof T, string>>;
  isValid: boolean;
  isSubmitting: boolean;
  isDirty: boolean;

  // Submission
  handleSubmit: (onValid: (data: T) => void | Promise<void>, onInvalid?: (errors: Partial<Record<keyof T, string>>) => void) => (e?: Event) => Promise<void>;

  // Field arrays
  useFieldArray: (name: keyof T) => FieldArrayReturn<T>;

  // Watch
  watch: (name?: keyof T | (keyof T)[]) => FieldValue | Partial<T>;
}

export interface FieldArrayReturn<T extends FieldValues> {
  fields: Array<{ id: string; [key: string]: FieldValue }>;
  append: (value: Record<string, FieldValue>) => void;
  prepend: (value: Record<string, FieldValue>) => void;
  insert: (index: number, value: Record<string, FieldValue>) => void;
  remove: (index: number) => void;
  swap: (indexA: number, indexB: number) => void;
  move: (from: number, to: number) => void;
  update: (index: number, value: Record<string, FieldValue>) => void;
  replace: (values: Array<Record<string, FieldValue>>) => void;
}

// ========================================
// Built-in Validators
// ========================================

export const validators = {
  required: (message = 'This field is required'): ValidationRule => ({
    validate: (value) => {
      if (value === null || value === undefined) return false;
      if (typeof value === 'string') return value.trim().length > 0;
      if (Array.isArray(value)) return value.length > 0;
      return true;
    },
    message
  }),

  email: (message = 'Please enter a valid email address'): ValidationRule => ({
    validate: (value) => {
      if (!value || typeof value !== 'string') return true; // Not required by this validator
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      return emailRegex.test(value);
    },
    message
  }),

  url: (message = 'Please enter a valid URL'): ValidationRule => ({
    validate: (value) => {
      if (!value || typeof value !== 'string') return true;
      try {
        new URL(value);
        return true;
      } catch {
        return false;
      }
    },
    message
  }),

  minLength: (min: number, message?: string): ValidationRule => ({
    validate: (value) => {
      if (!value || typeof value !== 'string') return true;
      return value.length >= min;
    },
    message: message || `Must be at least ${min} characters`
  }),

  maxLength: (max: number, message?: string): ValidationRule => ({
    validate: (value) => {
      if (!value || typeof value !== 'string') return true;
      return value.length <= max;
    },
    message: message || `Must be at most ${max} characters`
  }),

  pattern: (regex: RegExp, message = 'Invalid format'): ValidationRule => ({
    validate: (value) => {
      if (!value || typeof value !== 'string') return true;
      return regex.test(value);
    },
    message
  }),

  min: (minValue: number, message?: string): ValidationRule => ({
    validate: (value) => {
      if (value === null || value === undefined || value === '') return true;
      const num = typeof value === 'number' ? value : parseFloat(String(value));
      return !isNaN(num) && num >= minValue;
    },
    message: message || `Must be at least ${minValue}`
  }),

  max: (maxValue: number, message?: string): ValidationRule => ({
    validate: (value) => {
      if (value === null || value === undefined || value === '') return true;
      const num = typeof value === 'number' ? value : parseFloat(String(value));
      return !isNaN(num) && num <= maxValue;
    },
    message: message || `Must be at most ${maxValue}`
  }),

  integer: (message = 'Must be a whole number'): ValidationRule => ({
    validate: (value) => {
      if (value === null || value === undefined || value === '') return true;
      const num = typeof value === 'number' ? value : parseFloat(String(value));
      return !isNaN(num) && Number.isInteger(num);
    },
    message
  }),

  match: (fieldName: string, message?: string): ValidationRule => ({
    validate: (value, formValues) => {
      return value === formValues[fieldName];
    },
    message: message || `Must match ${fieldName}`
  }),

  custom: (
    validateFn: (value: FieldValue, formValues: FieldValues) => boolean | Promise<boolean>,
    message: string | ((value: FieldValue) => string)
  ): ValidationRule => ({
    validate: validateFn,
    message
  }),

  // Async validator helper
  async: (
    validateFn: (value: FieldValue) => Promise<boolean>,
    message: string
  ): ValidationRule => ({
    validate: async (value) => {
      if (!value) return true;
      return await validateFn(value);
    },
    message
  })
};

// ========================================
// Utility Functions
// ========================================

function generateId(): string {
  return Math.random().toString(36).substring(2, 11);
}

function deepClone<T>(obj: T): T {
  if (obj === null || typeof obj !== 'object') return obj;
  if (obj instanceof Date) return new Date(obj.getTime()) as unknown as T;
  if (Array.isArray(obj)) return obj.map(deepClone) as unknown as T;
  const cloned = {} as T;
  for (const key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      cloned[key] = deepClone(obj[key]);
    }
  }
  return cloned;
}

function isEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null) return a === b;
  if (typeof a !== 'object') return a === b;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((item, i) => isEqual(item, b[i]));
  }
  if (Array.isArray(a) || Array.isArray(b)) return false;
  const aObj = a as Record<string, unknown>;
  const bObj = b as Record<string, unknown>;
  const aKeys = Object.keys(aObj);
  const bKeys = Object.keys(bObj);
  if (aKeys.length !== bKeys.length) return false;
  return aKeys.every(key => isEqual(aObj[key], bObj[key]));
}

// ========================================
// useForm Hook
// ========================================

export function useForm<T extends FieldValues>(config: FormConfig<T>): UseFormReturn<T> {
  const {
    defaultValues,
    validation = {},
    mode = 'onSubmit'
  } = config;

  // Internal state
  let values: T = deepClone(defaultValues);
  let initialValues: T = deepClone(defaultValues);
  const errors: Partial<Record<keyof T, string>> = {};
  const touched: Partial<Record<keyof T, boolean>> = {};
  const dirty: Partial<Record<keyof T, boolean>> = {};
  const fieldConfigs: Partial<Record<keyof T, FieldConfig>> = {};
  const fieldRefs: Partial<Record<keyof T, HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>> = {};
  const listeners: Set<() => void> = new Set();

  let isSubmitting = false;
  let isValidating = false;
  let submitCount = 0;

  // Notify listeners of state changes
  const notify = () => {
    listeners.forEach(listener => listener());
  };

  // Validate a single field
  const validateField = async (name: keyof T): Promise<string | null> => {
    const fieldValidation = validation[name] || fieldConfigs[name]?.validation || [];
    const value = values[name] as FieldValue;

    for (const rule of fieldValidation) {
      try {
        const isValid = await rule.validate(value, values);
        if (!isValid) {
          const message = typeof rule.message === 'function'
            ? rule.message(value)
            : rule.message;
          return message;
        }
      } catch (error) {
        return 'Validation error';
      }
    }
    return null;
  };

  // Validate all fields
  const validateAll = async (): Promise<boolean> => {
    isValidating = true;
    notify();

    const fieldNames = Object.keys(values) as (keyof T)[];
    let isValid = true;

    for (const name of fieldNames) {
      const error = await validateField(name);
      if (error) {
        errors[name] = error;
        isValid = false;
      } else {
        delete errors[name];
      }
    }

    isValidating = false;
    notify();
    return isValid;
  };

  // Register a field
  const register = (name: keyof T, config: FieldConfig = {}): RegisterResult => {
    fieldConfigs[name] = config;

    if (config.defaultValue !== undefined && values[name] === undefined) {
      values[name] = config.defaultValue as T[keyof T];
    }

    return {
      name: String(name),
      value: values[name] as FieldValue,

      onChange: (e: Event | FieldValue) => {
        let newValue: FieldValue;

        if (e && typeof e === 'object' && 'target' in e) {
          const target = (e as Event).target as HTMLInputElement;
          if (target.type === 'checkbox') {
            newValue = target.checked;
          } else if (target.type === 'number') {
            newValue = target.value === '' ? '' : parseFloat(target.value);
          } else {
            newValue = target.value;
          }
        } else {
          newValue = e as FieldValue;
        }

        values[name] = newValue as T[keyof T];
        dirty[name] = !isEqual(newValue, initialValues[name]);

        const shouldValidate = mode === 'onChange' || mode === 'all' ||
          config.validateOnChange || (touched[name] && Object.keys(errors).length > 0);

        if (shouldValidate) {
          validateField(name).then(error => {
            if (error) {
              errors[name] = error;
            } else {
              delete errors[name];
            }
            notify();
          });
        } else {
          notify();
        }
      },

      onBlur: (_e: Event) => {
        touched[name] = true;

        const shouldValidate = mode === 'onBlur' || mode === 'all' || config.validateOnBlur;

        if (shouldValidate) {
          validateField(name).then(error => {
            if (error) {
              errors[name] = error;
            } else {
              delete errors[name];
            }
            notify();
          });
        } else {
          notify();
        }
      },

      onFocus: (_e: Event) => {
        // Can be used for custom focus handling
      },

      ref: (el) => {
        if (el) {
          fieldRefs[name] = el;
        }
      }
    };
  };

  // Unregister a field
  const unregister = (name: keyof T) => {
    delete fieldConfigs[name];
    delete fieldRefs[name];
    delete errors[name];
    delete touched[name];
    delete dirty[name];
    notify();
  };

  // Get all values
  const getValues = (): T => deepClone(values);

  // Get a single value
  const getValue = (name: keyof T): FieldValue => values[name] as FieldValue;

  // Set a single value
  const setValue = (
    name: keyof T,
    value: FieldValue,
    options: { shouldValidate?: boolean; shouldDirty?: boolean } = {}
  ) => {
    values[name] = value as T[keyof T];

    if (options.shouldDirty !== false) {
      dirty[name] = !isEqual(value, initialValues[name]);
    }

    if (options.shouldValidate) {
      validateField(name).then(error => {
        if (error) {
          errors[name] = error;
        } else {
          delete errors[name];
        }
        notify();
      });
    } else {
      notify();
    }
  };

  // Set multiple values
  const setValues = (
    newValues: Partial<T>,
    options: { shouldValidate?: boolean } = {}
  ) => {
    for (const key in newValues) {
      values[key as keyof T] = newValues[key as keyof T] as T[keyof T];
      dirty[key as keyof T] = !isEqual(newValues[key as keyof T], initialValues[key as keyof T]);
    }

    if (options.shouldValidate) {
      validateAll().then(() => notify());
    } else {
      notify();
    }
  };

  // Reset form
  const reset = (newValues?: Partial<T>) => {
    if (newValues) {
      values = { ...deepClone(defaultValues), ...newValues } as T;
      initialValues = deepClone(values);
    } else {
      values = deepClone(defaultValues);
      initialValues = deepClone(defaultValues);
    }

    // Clear all state
    for (const key in errors) {
      delete errors[key];
    }
    for (const key in touched) {
      delete touched[key];
    }
    for (const key in dirty) {
      delete dirty[key];
    }

    notify();
  };

  // Validate
  const validate = async (name?: keyof T): Promise<boolean> => {
    if (name) {
      const error = await validateField(name);
      if (error) {
        errors[name] = error;
        notify();
        return false;
      }
      delete errors[name];
      notify();
      return true;
    }
    return await validateAll();
  };

  // Clear errors
  const clearErrors = (name?: keyof T) => {
    if (name) {
      delete errors[name];
    } else {
      for (const key in errors) {
        delete errors[key];
      }
    }
    notify();
  };

  // Set error manually
  const setError = (name: keyof T, message: string) => {
    errors[name] = message;
    notify();
  };

  // Handle submit
  const handleSubmit = (
    onValid: (data: T) => void | Promise<void>,
    onInvalid?: (errors: Partial<Record<keyof T, string>>) => void
  ) => {
    return async (e?: Event) => {
      if (e) {
        e.preventDefault();
      }

      submitCount++;
      isSubmitting = true;
      notify();

      const isValid = await validateAll();

      if (isValid) {
        try {
          await onValid(deepClone(values));
        } catch (error) {
          console.error('Form submission error:', error);
        }
      } else {
        onInvalid?.(errors);

        // Focus first error field
        const firstErrorField = Object.keys(errors)[0] as keyof T;
        if (firstErrorField && fieldRefs[firstErrorField]) {
          fieldRefs[firstErrorField]?.focus();
        }
      }

      isSubmitting = false;
      notify();
    };
  };

  // Field array support
  const useFieldArray = (name: keyof T): FieldArrayReturn<T> => {
    const getArray = (): Array<{ id: string; [key: string]: FieldValue }> => {
      const arr = values[name];
      if (!Array.isArray(arr)) return [];
      return arr.map((item, index) => {
        if (typeof item === 'object' && item !== null && !('id' in item)) {
          return { id: `${name}-${index}`, ...(item as Record<string, FieldValue>) };
        }
        if (typeof item === 'object' && item !== null) {
          return item as { id: string; [key: string]: FieldValue };
        }
        return { id: `${name}-${index}`, value: item };
      });
    };

    const setArray = (newArray: Array<Record<string, FieldValue>>) => {
      values[name] = newArray.map(item => {
        if (!item.id) {
          return { id: generateId(), ...item };
        }
        return item;
      }) as T[keyof T];
      dirty[name] = true;
      notify();
    };

    return {
      fields: getArray(),

      append: (value) => {
        const current = getArray();
        setArray([...current, { id: generateId(), ...value }]);
      },

      prepend: (value) => {
        const current = getArray();
        setArray([{ id: generateId(), ...value }, ...current]);
      },

      insert: (index, value) => {
        const current = getArray();
        const newArray = [...current];
        newArray.splice(index, 0, { id: generateId(), ...value });
        setArray(newArray);
      },

      remove: (index) => {
        const current = getArray();
        setArray(current.filter((_, i) => i !== index));
      },

      swap: (indexA, indexB) => {
        const current = getArray();
        const newArray = [...current];
        [newArray[indexA], newArray[indexB]] = [newArray[indexB], newArray[indexA]];
        setArray(newArray);
      },

      move: (from, to) => {
        const current = getArray();
        const newArray = [...current];
        const [item] = newArray.splice(from, 1);
        newArray.splice(to, 0, item);
        setArray(newArray);
      },

      update: (index, value) => {
        const current = getArray();
        const newArray = [...current];
        newArray[index] = { ...newArray[index], ...value };
        setArray(newArray);
      },

      replace: (newValues) => {
        setArray(newValues.map(v => ({ id: generateId(), ...v })));
      }
    };
  };

  // Watch values
  const watch = (name?: keyof T | (keyof T)[]): FieldValue | Partial<T> => {
    if (!name) {
      return deepClone(values);
    }
    if (Array.isArray(name)) {
      const result: Partial<T> = {};
      for (const n of name) {
        result[n] = values[n];
      }
      return result;
    }
    return values[name] as FieldValue;
  };

  // Compute form state
  const getFormState = (): FormState<T> => ({
    values: deepClone(values),
    errors: { ...errors },
    touched: { ...touched },
    dirty: { ...dirty },
    isValid: Object.keys(errors).length === 0,
    isSubmitting,
    isValidating,
    submitCount
  });

  // Check if form is dirty
  const checkIsDirty = (): boolean => {
    return Object.values(dirty).some(Boolean);
  };

  return {
    register,
    unregister,
    getValues,
    getValue,
    setValue,
    setValues,
    reset,
    validate,
    clearErrors,
    setError,
    get formState() { return getFormState(); },
    get errors() { return { ...errors }; },
    get isValid() { return Object.keys(errors).length === 0; },
    get isSubmitting() { return isSubmitting; },
    get isDirty() { return checkIsDirty(); },
    handleSubmit,
    useFieldArray,
    watch
  };
}

// ========================================
// FormProvider for Context (optional)
// ========================================

export interface FormContextValue<T extends FieldValues> {
  form: UseFormReturn<T>;
}

let formContext: FormContextValue<FieldValues> | null = null;

export function createFormContext<T extends FieldValues>(form: UseFormReturn<T>): FormContextValue<T> {
  const context = { form } as FormContextValue<T>;
  formContext = context as FormContextValue<FieldValues>;
  return context;
}

export function useFormContext<T extends FieldValues>(): UseFormReturn<T> {
  if (!formContext) {
    throw new Error('useFormContext must be used within a FormProvider');
  }
  return formContext.form as UseFormReturn<T>;
}

// ========================================
// Controller for complex inputs
// ========================================

export interface ControllerProps<T extends FieldValues> {
  name: keyof T;
  form: UseFormReturn<T>;
  rules?: ValidationRule[];
  defaultValue?: FieldValue;
}

export interface ControllerRenderProps {
  value: FieldValue;
  onChange: (value: FieldValue) => void;
  onBlur: () => void;
  name: string;
  ref: (el: HTMLElement | null) => void;
}

export interface ControllerFieldState {
  invalid: boolean;
  error?: string;
  isDirty: boolean;
  isTouched: boolean;
}

export function useController<T extends FieldValues>(
  props: ControllerProps<T>
): { field: ControllerRenderProps; fieldState: ControllerFieldState } {
  const { name, form, rules, defaultValue } = props;

  const registered = form.register(name, {
    validation: rules,
    defaultValue
  });

  return {
    field: {
      value: form.getValue(name),
      onChange: (value: FieldValue) => {
        form.setValue(name, value, { shouldValidate: true });
      },
      onBlur: () => {
        registered.onBlur(new Event('blur'));
      },
      name: String(name),
      ref: registered.ref
    },
    fieldState: {
      invalid: !!form.errors[name],
      error: form.errors[name],
      isDirty: form.formState.dirty[name] || false,
      isTouched: form.formState.touched[name] || false
    }
  };
}

// ========================================
// Exports
// ========================================

export default {
  useForm,
  validators,
  createFormContext,
  useFormContext,
  useController
};
