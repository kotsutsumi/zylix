/**
 * Zylix Fetch - HTTP Client with React-Query-like Hooks
 *
 * Provides a powerful HTTP client with automatic caching, retry logic,
 * request deduplication, and seamless integration with Zylix components.
 */

import { useState, useEffect, useRef, useCallback, useMemo } from './index.js';

// =============================================================================
// Types
// =============================================================================

export interface RequestConfig {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD' | 'OPTIONS';
  headers?: Record<string, string>;
  body?: unknown;
  params?: Record<string, string | number | boolean>;
  timeout?: number;
  signal?: AbortSignal;
  credentials?: RequestCredentials;
  cache?: RequestCache;
  mode?: RequestMode;
}

export interface ClientConfig {
  baseURL?: string;
  headers?: Record<string, string>;
  timeout?: number;
  credentials?: RequestCredentials;
  interceptors?: {
    request?: (config: RequestConfig & { url: string }) => RequestConfig & { url: string };
    response?: <T>(response: Response, data: T) => T;
    error?: (error: FetchError) => never | Promise<never>;
  };
  retry?: {
    count?: number;
    delay?: number;
    shouldRetry?: (error: FetchError) => boolean;
  };
}

export interface FetchError extends Error {
  status?: number;
  statusText?: string;
  response?: Response;
  data?: unknown;
  config?: RequestConfig & { url: string };
}

export interface QueryOptions<T> {
  enabled?: boolean;
  staleTime?: number;
  cacheTime?: number;
  refetchOnMount?: boolean;
  refetchOnWindowFocus?: boolean;
  refetchInterval?: number | false;
  retry?: number | boolean;
  retryDelay?: number;
  onSuccess?: (data: T) => void;
  onError?: (error: FetchError) => void;
  onSettled?: (data: T | undefined, error: FetchError | null) => void;
  initialData?: T;
  placeholderData?: T;
  select?: (data: T) => T;
  keepPreviousData?: boolean;
}

export interface QueryResult<T> {
  data: T | undefined;
  error: FetchError | null;
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  isSuccess: boolean;
  isStale: boolean;
  refetch: () => Promise<T>;
  remove: () => void;
}

export interface MutationOptions<TData, TVariables> {
  onMutate?: (variables: TVariables) => Promise<unknown> | unknown;
  onSuccess?: (data: TData, variables: TVariables, context: unknown) => void;
  onError?: (error: FetchError, variables: TVariables, context: unknown) => void;
  onSettled?: (data: TData | undefined, error: FetchError | null, variables: TVariables, context: unknown) => void;
  retry?: number | boolean;
  retryDelay?: number;
}

export interface MutationResult<TData, TVariables> {
  data: TData | undefined;
  error: FetchError | null;
  isLoading: boolean;
  isError: boolean;
  isSuccess: boolean;
  isIdle: boolean;
  mutate: (variables: TVariables) => void;
  mutateAsync: (variables: TVariables) => Promise<TData>;
  reset: () => void;
}

// =============================================================================
// Cache
// =============================================================================

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  staleTime: number;
}

class QueryCache {
  private cache = new Map<string, CacheEntry<unknown>>();
  private subscribers = new Map<string, Set<() => void>>();
  private gcInterval: ReturnType<typeof setInterval> | null = null;

  constructor() {
    // Start garbage collection
    if (typeof window !== 'undefined') {
      this.gcInterval = setInterval(() => this.gc(), 60000);
    }
  }

  get<T>(key: string): CacheEntry<T> | undefined {
    return this.cache.get(key) as CacheEntry<T> | undefined;
  }

  set<T>(key: string, data: T, staleTime: number): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      staleTime,
    });
    this.notify(key);
  }

  remove(key: string): void {
    this.cache.delete(key);
    this.notify(key);
  }

  clear(): void {
    this.cache.clear();
    this.subscribers.forEach((_, key) => this.notify(key));
  }

  isStale(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) return true;
    return Date.now() - entry.timestamp > entry.staleTime;
  }

  subscribe(key: string, callback: () => void): () => void {
    if (!this.subscribers.has(key)) {
      this.subscribers.set(key, new Set());
    }
    this.subscribers.get(key)!.add(callback);
    return () => {
      this.subscribers.get(key)?.delete(callback);
    };
  }

  private notify(key: string): void {
    this.subscribers.get(key)?.forEach(cb => cb());
  }

  private gc(): void {
    const now = Date.now();
    const cacheTime = 5 * 60 * 1000; // 5 minutes default cache time

    for (const [key, entry] of this.cache.entries()) {
      if (now - entry.timestamp > cacheTime) {
        this.cache.delete(key);
      }
    }
  }

  destroy(): void {
    if (this.gcInterval) {
      clearInterval(this.gcInterval);
    }
    this.cache.clear();
    this.subscribers.clear();
  }
}

// Global cache instance
const queryCache = new QueryCache();

// =============================================================================
// Request Deduplication
// =============================================================================

const pendingRequests = new Map<string, Promise<unknown>>();

function deduplicateRequest<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
  const pending = pendingRequests.get(key);
  if (pending) {
    return pending as Promise<T>;
  }

  const promise = fetcher().finally(() => {
    pendingRequests.delete(key);
  });

  pendingRequests.set(key, promise);
  return promise;
}

// =============================================================================
// HTTP Client
// =============================================================================

export interface HttpClient {
  get: <T = unknown>(url: string, config?: RequestConfig) => Promise<T>;
  post: <T = unknown>(url: string, data?: unknown, config?: RequestConfig) => Promise<T>;
  put: <T = unknown>(url: string, data?: unknown, config?: RequestConfig) => Promise<T>;
  patch: <T = unknown>(url: string, data?: unknown, config?: RequestConfig) => Promise<T>;
  delete: <T = unknown>(url: string, config?: RequestConfig) => Promise<T>;
  head: (url: string, config?: RequestConfig) => Promise<Response>;
  options: (url: string, config?: RequestConfig) => Promise<Response>;
  request: <T = unknown>(url: string, config?: RequestConfig) => Promise<T>;
}

/**
 * Create an HTTP client with configuration
 */
export function createClient(config: ClientConfig = {}): HttpClient {
  const {
    baseURL = '',
    headers: defaultHeaders = {},
    timeout: defaultTimeout = 30000,
    credentials: defaultCredentials,
    interceptors = {},
    retry: retryConfig = {},
  } = config;

  const {
    count: retryCount = 3,
    delay: retryDelay = 1000,
    shouldRetry = (error: FetchError) => {
      // Retry on network errors or 5xx status codes
      return !error.status || error.status >= 500;
    },
  } = retryConfig;

  async function request<T>(url: string, requestConfig: RequestConfig = {}): Promise<T> {
    let fullUrl = url.startsWith('http') ? url : `${baseURL}${url}`;

    // Add query parameters
    if (requestConfig.params) {
      const searchParams = new URLSearchParams();
      for (const [key, value] of Object.entries(requestConfig.params)) {
        searchParams.append(key, String(value));
      }
      const separator = fullUrl.includes('?') ? '&' : '?';
      fullUrl = `${fullUrl}${separator}${searchParams.toString()}`;
    }

    // Merge headers
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...defaultHeaders,
      ...requestConfig.headers,
    };

    // Build request config
    let finalConfig: RequestConfig & { url: string } = {
      ...requestConfig,
      url: fullUrl,
      headers,
      method: requestConfig.method || 'GET',
      credentials: requestConfig.credentials || defaultCredentials,
    };

    // Apply request interceptor
    if (interceptors.request) {
      finalConfig = interceptors.request(finalConfig);
    }

    // Prepare fetch options
    const fetchOptions: RequestInit = {
      method: finalConfig.method,
      headers: finalConfig.headers,
      credentials: finalConfig.credentials,
      cache: finalConfig.cache,
      mode: finalConfig.mode,
    };

    // Add body for non-GET requests
    if (finalConfig.body && finalConfig.method !== 'GET' && finalConfig.method !== 'HEAD') {
      fetchOptions.body = typeof finalConfig.body === 'string'
        ? finalConfig.body
        : JSON.stringify(finalConfig.body);
    }

    // Create abort controller for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      finalConfig.timeout || defaultTimeout
    );

    // Use provided signal or our timeout signal
    fetchOptions.signal = finalConfig.signal || controller.signal;

    // Retry logic
    let lastError: FetchError | null = null;
    let attempts = 0;

    while (attempts <= retryCount) {
      try {
        const response = await fetch(finalConfig.url, fetchOptions);
        clearTimeout(timeoutId);

        if (!response.ok) {
          const error: FetchError = new Error(`HTTP ${response.status}: ${response.statusText}`);
          error.status = response.status;
          error.statusText = response.statusText;
          error.response = response;
          error.config = finalConfig;

          // Try to parse error response
          try {
            error.data = await response.json();
          } catch {
            // Ignore parse errors
          }

          throw error;
        }

        // Parse response
        let data: T;
        const contentType = response.headers.get('content-type');

        if (contentType?.includes('application/json')) {
          data = await response.json();
        } else if (contentType?.includes('text/')) {
          data = await response.text() as unknown as T;
        } else {
          data = response as unknown as T;
        }

        // Apply response interceptor
        if (interceptors.response) {
          data = interceptors.response(response, data);
        }

        return data;
      } catch (err) {
        clearTimeout(timeoutId);

        const error = err as FetchError;
        error.config = finalConfig;
        lastError = error;

        // Check if we should retry
        if (attempts < retryCount && shouldRetry(error)) {
          attempts++;
          await new Promise(resolve => setTimeout(resolve, retryDelay * attempts));
          continue;
        }

        // Apply error interceptor
        if (interceptors.error) {
          return interceptors.error(error);
        }

        throw error;
      }
    }

    throw lastError;
  }

  return {
    request,
    get: <T>(url: string, config?: RequestConfig) =>
      request<T>(url, { ...config, method: 'GET' }),
    post: <T>(url: string, data?: unknown, config?: RequestConfig) =>
      request<T>(url, { ...config, method: 'POST', body: data }),
    put: <T>(url: string, data?: unknown, config?: RequestConfig) =>
      request<T>(url, { ...config, method: 'PUT', body: data }),
    patch: <T>(url: string, data?: unknown, config?: RequestConfig) =>
      request<T>(url, { ...config, method: 'PATCH', body: data }),
    delete: <T>(url: string, config?: RequestConfig) =>
      request<T>(url, { ...config, method: 'DELETE' }),
    head: (url: string, config?: RequestConfig) =>
      request<Response>(url, { ...config, method: 'HEAD' }),
    options: (url: string, config?: RequestConfig) =>
      request<Response>(url, { ...config, method: 'OPTIONS' }),
  };
}

// =============================================================================
// useQuery Hook
// =============================================================================

/**
 * Hook for fetching and caching data
 */
export function useQuery<T>(
  key: string | string[],
  fetcher: () => Promise<T>,
  options: QueryOptions<T> = {}
): QueryResult<T> {
  const {
    enabled = true,
    staleTime = 0,
    cacheTime = 5 * 60 * 1000,
    refetchOnMount = true,
    refetchOnWindowFocus = true,
    refetchInterval = false,
    retry = 3,
    retryDelay = 1000,
    onSuccess,
    onError,
    onSettled,
    initialData,
    placeholderData,
    select,
    keepPreviousData = false,
  } = options;

  // Normalize key
  const queryKey = Array.isArray(key) ? key.join(':') : key;

  // State
  const [data, setData] = useState<T | undefined>(() => {
    const cached = queryCache.get<T>(queryKey);
    if (cached) return select ? select(cached.data) : cached.data;
    return initialData;
  });
  const [error, setError] = useState<FetchError | null>(null);
  const [isLoading, setIsLoading] = useState(!data && enabled);
  const [isFetching, setIsFetching] = useState(false);
  const [isStale, setIsStale] = useState(queryCache.isStale(queryKey));

  // Refs
  const previousDataRef = useRef<T | undefined>(data);
  const mountedRef = useRef(true);
  const retryCountRef = useRef(0);

  // Fetch function
  const fetchData = useCallback(async (): Promise<T> => {
    if (!mountedRef.current) {
      throw new Error('Component unmounted');
    }

    setIsFetching(true);
    setError(null);

    try {
      // Deduplicate concurrent requests
      const result = await deduplicateRequest(queryKey, fetcher);

      if (!mountedRef.current) {
        throw new Error('Component unmounted');
      }

      // Update cache
      queryCache.set(queryKey, result, staleTime);

      // Apply selector
      const selectedData = select ? select(result) : result;

      // Update state
      setData(selectedData);
      setIsStale(false);
      setIsLoading(false);
      setIsFetching(false);
      previousDataRef.current = selectedData;
      retryCountRef.current = 0;

      // Callbacks
      onSuccess?.(selectedData);
      onSettled?.(selectedData, null);

      return selectedData;
    } catch (err) {
      if (!mountedRef.current) {
        throw err;
      }

      const fetchError = err as FetchError;

      // Retry logic
      const maxRetries = typeof retry === 'number' ? retry : (retry ? 3 : 0);
      if (retryCountRef.current < maxRetries) {
        retryCountRef.current++;
        await new Promise(resolve => setTimeout(resolve, retryDelay * retryCountRef.current));
        return fetchData();
      }

      setError(fetchError);
      setIsLoading(false);
      setIsFetching(false);

      // Callbacks
      onError?.(fetchError);
      onSettled?.(undefined, fetchError);

      throw fetchError;
    }
  }, [queryKey, fetcher, staleTime, select, retry, retryDelay, onSuccess, onError, onSettled]);

  // Refetch function
  const refetch = useCallback(async (): Promise<T> => {
    return fetchData();
  }, [fetchData]);

  // Remove from cache
  const remove = useCallback(() => {
    queryCache.remove(queryKey);
    setData(undefined);
    setError(null);
    setIsLoading(false);
    setIsFetching(false);
  }, [queryKey]);

  // Initial fetch and cache subscription
  useEffect(() => {
    mountedRef.current = true;

    // Subscribe to cache updates
    const unsubscribe = queryCache.subscribe(queryKey, () => {
      const cached = queryCache.get<T>(queryKey);
      if (cached) {
        const selectedData = select ? select(cached.data) : cached.data;
        setData(selectedData);
        setIsStale(queryCache.isStale(queryKey));
      }
    });

    // Initial fetch
    if (enabled) {
      const cached = queryCache.get<T>(queryKey);
      if (!cached || (refetchOnMount && queryCache.isStale(queryKey))) {
        fetchData().catch(() => {
          // Error already handled in fetchData
        });
      }
    }

    return () => {
      mountedRef.current = false;
      unsubscribe();
    };
  }, [queryKey, enabled, refetchOnMount, fetchData, select]);

  // Window focus refetch
  useEffect(() => {
    if (!refetchOnWindowFocus || typeof window === 'undefined') return;

    const handleFocus = () => {
      if (enabled && queryCache.isStale(queryKey)) {
        fetchData().catch(() => {
          // Error already handled in fetchData
        });
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [enabled, queryKey, refetchOnWindowFocus, fetchData]);

  // Interval refetch
  useEffect(() => {
    if (!refetchInterval || !enabled) return;

    const intervalId = setInterval(() => {
      fetchData().catch(() => {
        // Error already handled in fetchData
      });
    }, refetchInterval);

    return () => clearInterval(intervalId);
  }, [enabled, refetchInterval, fetchData]);

  // Use placeholder data when loading
  const displayData = useMemo(() => {
    if (data !== undefined) return data;
    if (keepPreviousData && previousDataRef.current !== undefined) {
      return previousDataRef.current;
    }
    return placeholderData;
  }, [data, keepPreviousData, placeholderData]);

  return {
    data: displayData,
    error,
    isLoading,
    isFetching,
    isError: error !== null,
    isSuccess: data !== undefined && error === null,
    isStale,
    refetch,
    remove,
  };
}

// =============================================================================
// useMutation Hook
// =============================================================================

/**
 * Hook for data mutations (POST, PUT, DELETE, etc.)
 */
export function useMutation<TData = unknown, TVariables = void>(
  mutationFn: (variables: TVariables) => Promise<TData>,
  options: MutationOptions<TData, TVariables> = {}
): MutationResult<TData, TVariables> {
  const {
    onMutate,
    onSuccess,
    onError,
    onSettled,
    retry = 0,
    retryDelay = 1000,
  } = options;

  // State
  const [data, setData] = useState<TData | undefined>(undefined);
  const [error, setError] = useState<FetchError | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');

  // Refs
  const mountedRef = useRef(true);
  const contextRef = useRef<unknown>(undefined);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  // Mutation function
  const mutateAsync = useCallback(async (variables: TVariables): Promise<TData> => {
    setIsLoading(true);
    setStatus('loading');
    setError(null);

    // Call onMutate for optimistic updates
    try {
      contextRef.current = await onMutate?.(variables);
    } catch {
      // Ignore onMutate errors
    }

    // Retry logic
    const maxRetries = typeof retry === 'number' ? retry : (retry ? 3 : 0);
    let attempts = 0;
    let lastError: FetchError | null = null;

    while (attempts <= maxRetries) {
      try {
        const result = await mutationFn(variables);

        if (!mountedRef.current) {
          throw new Error('Component unmounted');
        }

        setData(result);
        setStatus('success');
        setIsLoading(false);

        // Callbacks
        onSuccess?.(result, variables, contextRef.current);
        onSettled?.(result, null, variables, contextRef.current);

        return result;
      } catch (err) {
        lastError = err as FetchError;

        if (attempts < maxRetries) {
          attempts++;
          await new Promise(resolve => setTimeout(resolve, retryDelay * attempts));
          continue;
        }

        if (!mountedRef.current) {
          throw lastError;
        }

        setError(lastError);
        setStatus('error');
        setIsLoading(false);

        // Callbacks
        onError?.(lastError, variables, contextRef.current);
        onSettled?.(undefined, lastError, variables, contextRef.current);

        throw lastError;
      }
    }

    throw lastError;
  }, [mutationFn, retry, retryDelay, onMutate, onSuccess, onError, onSettled]);

  // Non-throwing mutate
  const mutate = useCallback((variables: TVariables) => {
    mutateAsync(variables).catch(() => {
      // Error already handled
    });
  }, [mutateAsync]);

  // Reset mutation state
  const reset = useCallback(() => {
    setData(undefined);
    setError(null);
    setIsLoading(false);
    setStatus('idle');
  }, []);

  return {
    data,
    error,
    isLoading,
    isError: status === 'error',
    isSuccess: status === 'success',
    isIdle: status === 'idle',
    mutate,
    mutateAsync,
    reset,
  };
}

// =============================================================================
// Query Utilities
// =============================================================================

/**
 * Prefetch and cache data
 */
export async function prefetchQuery<T>(
  key: string | string[],
  fetcher: () => Promise<T>,
  staleTime: number = 0
): Promise<void> {
  const queryKey = Array.isArray(key) ? key.join(':') : key;

  try {
    const data = await deduplicateRequest(queryKey, fetcher);
    queryCache.set(queryKey, data, staleTime);
  } catch {
    // Ignore prefetch errors
  }
}

/**
 * Invalidate cached queries
 */
export function invalidateQueries(key?: string | string[]): void {
  if (!key) {
    queryCache.clear();
    return;
  }

  const queryKey = Array.isArray(key) ? key.join(':') : key;
  queryCache.remove(queryKey);
}

/**
 * Get cached query data
 */
export function getQueryData<T>(key: string | string[]): T | undefined {
  const queryKey = Array.isArray(key) ? key.join(':') : key;
  return queryCache.get<T>(queryKey)?.data;
}

/**
 * Set query data directly
 */
export function setQueryData<T>(key: string | string[], data: T, staleTime: number = 0): void {
  const queryKey = Array.isArray(key) ? key.join(':') : key;
  queryCache.set(queryKey, data, staleTime);
}

// =============================================================================
// useInfiniteQuery Hook
// =============================================================================

export interface InfiniteQueryOptions<T, TPageParam> extends Omit<QueryOptions<T[]>, 'select'> {
  getNextPageParam?: (lastPage: T, allPages: T[]) => TPageParam | undefined;
  getPreviousPageParam?: (firstPage: T, allPages: T[]) => TPageParam | undefined;
  initialPageParam?: TPageParam;
}

export interface InfiniteQueryResult<T, TPageParam> extends Omit<QueryResult<T[]>, 'data'> {
  data: { pages: T[]; pageParams: TPageParam[] } | undefined;
  fetchNextPage: () => Promise<void>;
  fetchPreviousPage: () => Promise<void>;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
  isFetchingNextPage: boolean;
  isFetchingPreviousPage: boolean;
}

/**
 * Hook for infinite/paginated queries
 */
export function useInfiniteQuery<T, TPageParam = number>(
  key: string | string[],
  fetcher: (pageParam: TPageParam) => Promise<T>,
  options: InfiniteQueryOptions<T, TPageParam> = {}
): InfiniteQueryResult<T, TPageParam> {
  const {
    enabled = true,
    staleTime = 0,
    getNextPageParam,
    getPreviousPageParam,
    initialPageParam,
    onSuccess,
    onError,
    ...queryOptions
  } = options;

  // State
  const [pages, setPages] = useState<T[]>([]);
  const [pageParams, setPageParams] = useState<TPageParam[]>([]);
  const [isFetchingNextPage, setIsFetchingNextPage] = useState(false);
  const [isFetchingPreviousPage, setIsFetchingPreviousPage] = useState(false);
  const [error, setError] = useState<FetchError | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Refs
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  // Initial fetch
  useEffect(() => {
    if (!enabled || initialPageParam === undefined) return;

    const fetchInitial = async () => {
      setIsLoading(true);
      try {
        const data = await fetcher(initialPageParam);
        if (mountedRef.current) {
          setPages([data]);
          setPageParams([initialPageParam]);
          setIsLoading(false);
          onSuccess?.([data]);
        }
      } catch (err) {
        if (mountedRef.current) {
          setError(err as FetchError);
          setIsLoading(false);
          onError?.(err as FetchError);
        }
      }
    };

    fetchInitial();
  }, [enabled, initialPageParam, fetcher, onSuccess, onError]);

  // Fetch next page
  const fetchNextPage = useCallback(async () => {
    if (!getNextPageParam || pages.length === 0) return;

    const lastPage = pages[pages.length - 1];
    const nextPageParam = getNextPageParam(lastPage, pages);

    if (nextPageParam === undefined) return;

    setIsFetchingNextPage(true);
    try {
      const data = await fetcher(nextPageParam);
      if (mountedRef.current) {
        setPages(prev => [...prev, data]);
        setPageParams(prev => [...prev, nextPageParam]);
        setIsFetchingNextPage(false);
      }
    } catch (err) {
      if (mountedRef.current) {
        setError(err as FetchError);
        setIsFetchingNextPage(false);
      }
    }
  }, [pages, getNextPageParam, fetcher]);

  // Fetch previous page
  const fetchPreviousPage = useCallback(async () => {
    if (!getPreviousPageParam || pages.length === 0) return;

    const firstPage = pages[0];
    const prevPageParam = getPreviousPageParam(firstPage, pages);

    if (prevPageParam === undefined) return;

    setIsFetchingPreviousPage(true);
    try {
      const data = await fetcher(prevPageParam);
      if (mountedRef.current) {
        setPages(prev => [data, ...prev]);
        setPageParams(prev => [prevPageParam, ...prev]);
        setIsFetchingPreviousPage(false);
      }
    } catch (err) {
      if (mountedRef.current) {
        setError(err as FetchError);
        setIsFetchingPreviousPage(false);
      }
    }
  }, [pages, getPreviousPageParam, fetcher]);

  // Check for next/previous pages
  const hasNextPage = useMemo(() => {
    if (!getNextPageParam || pages.length === 0) return false;
    return getNextPageParam(pages[pages.length - 1], pages) !== undefined;
  }, [pages, getNextPageParam]);

  const hasPreviousPage = useMemo(() => {
    if (!getPreviousPageParam || pages.length === 0) return false;
    return getPreviousPageParam(pages[0], pages) !== undefined;
  }, [pages, getPreviousPageParam]);

  return {
    data: pages.length > 0 ? { pages, pageParams } : undefined,
    error,
    isLoading,
    isFetching: isFetchingNextPage || isFetchingPreviousPage,
    isError: error !== null,
    isSuccess: pages.length > 0 && error === null,
    isStale: false,
    fetchNextPage,
    fetchPreviousPage,
    hasNextPage,
    hasPreviousPage,
    isFetchingNextPage,
    isFetchingPreviousPage,
    refetch: async () => {
      // Refetch all pages
      if (initialPageParam === undefined) return [];
      const data = await fetcher(initialPageParam);
      setPages([data]);
      setPageParams([initialPageParam]);
      return [data];
    },
    remove: () => {
      setPages([]);
      setPageParams([]);
      setError(null);
    },
  };
}

// =============================================================================
// Default Export
// =============================================================================

export const queryClient = {
  prefetch: prefetchQuery,
  invalidate: invalidateQueries,
  getData: getQueryData,
  setData: setQueryData,
  clear: () => queryCache.clear(),
};

export default {
  createClient,
  useQuery,
  useMutation,
  useInfiniteQuery,
  queryClient,
};
