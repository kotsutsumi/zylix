# Changelog

All notable changes to Zylix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.19.2] - 2025-12-26

### Fixed

#### Build System
- Make AI dependencies (llama.cpp, whisper.cpp) optional for CI builds
- Added existence check before linking AI libraries

#### Tests
- Exclude sample container directories from structure validation tests
- `apps`, `fullstack`, `games`, `platform-specific`, `showcase`, `templates` properly excluded

## [0.19.1] - 2025-12-26

### Added

#### Integration Platform Bindings (Issues #39-#44)

**iOS Platform (ZylixIntegration.swift)**
- `ZylixMotionFrameProvider` - Camera-based motion tracking via AVFoundation
- `ZylixAudioClipPlayer` - Low-latency audio playback via AVAudioPlayer
- `ZylixIAPStore` - In-App Purchases via StoreKit 2
- `ZylixAdsManager` - AdMob integration placeholder
- `ZylixKeyValueStore` - Persistent storage via UserDefaults
- `ZylixAppLifecycle` - App state management via UIApplication notifications

**Android Platform (ZylixIntegration.kt)**
- `ZylixMotionFrameProvider` - Camera-based motion tracking via CameraX
- `ZylixAudioClipPlayer` - Low-latency audio playback via SoundPool
- `ZylixIAPStore` - In-App Purchases via Google Play Billing
- `ZylixAdsManager` - AdMob integration placeholder
- `ZylixKeyValueStore` - Persistent storage via SharedPreferences
- `ZylixAppLifecycle` - App state management via ProcessLifecycleOwner

#### Tooling & Cross-Platform Fixes (Issues #45-#54)
- CLI command implementations with actual functionality
- Cross-platform compatibility improvements
- AI module stubs for non-native platforms (Core ML, Metal, Whisper)

### Fixed
- Removed watchOS build artifacts from repository

## [0.25.0] - 2025-12-24

### Added

#### Official Sample Projects (Phase 27)
- **Sample Directory Structure**: New organized structure with 6 categories
  - `templates/` - Starter project templates
  - `showcase/` - Feature demonstration samples
  - `apps/` - Full application examples
  - `platform-specific/` - Platform-exclusive features
  - `games/` - Game development samples
  - `fullstack/` - End-to-end fullstack applications

#### Starter Templates
- **Blank App** (`templates/blank-app/`): Minimal Zylix application template
  - Complete Zig core with state management, events, and UI components
  - Build configuration for native and WASM targets
  - Comprehensive documentation and customization guide

#### Component Showcase
- **Component Gallery** (`showcase/component-gallery/`): All UI components showcase
  - Interactive component browser with 6 categories
  - Theme switching (light/dark)
  - Component preview cards with descriptions
  - Comprehensive test coverage

#### Documentation
- **Updated samples/README.md**: Complete catalog of all sample projects
  - 31+ planned samples across all categories
  - Status tracking (Ready/Planned)
  - Getting started guides for new and legacy samples

## [0.24.0] - 2025-12-24

### Added

#### Documentation Enhancement (Phase 26)
- **API Reference Structure**: New `docs/API/` directory with comprehensive module documentation
- **Core Module Docs**: Complete API documentation for State, Events modules
- **Performance Module Docs**: Detailed documentation for all perf sub-modules
- **Site API Reference**: New `/docs/api-reference` page with quick reference guides

#### Documentation Features
- **Module Index**: Organized module listing by category (Core, Feature, Productivity, Performance)
- **Quick Reference**: Code snippets for common patterns (State, Events, Server, Performance)
- **Type Reference**: Complete type definitions for all public types
- **Build Commands**: Cross-compilation reference for all targets

#### Internationalization
- **Japanese Documentation**: Full Japanese translation of API reference (`api-reference.ja.md`)
- **Bilingual Support**: EN/JA pair for all new documentation pages

### Changed
- **Site Documentation**: Updated version reference to v0.23.0
- **Quick Links**: Added API Reference link to documentation index
- **Documentation Structure**: Reorganized for better navigation

## [0.23.0] - 2025-12-24

### Added

#### Performance Optimization Module
- **Core Module**: `core/src/perf/perf.zig` - Unified performance optimization toolkit
- **Profiler**: Performance profiling with section timing and metrics collection

#### Virtual DOM Optimization (`vdom_opt.zig`)
- **VDomOptimizer**: Unified VDOM optimization with diff caching and keyed diffing
- **DiffCache**: LRU-based diff result caching for fast lookups
- **KeyedListDiff**: Longest Increasing Subsequence (LIS) algorithm for keyed lists
- **MemoizationCache**: Component memoization for render optimization
- **DiffOperation**: Patch operations (insert, delete, move, update)

#### Memory Pool and Allocation (`memory.zig`)
- **MemoryPool**: Fixed-size block pool with O(1) alloc/free
- **ObjectPool**: Generic typed object pool with factory support
- **ArenaOptimizer**: Arena allocator with reset and statistics
- **StackAllocator**: LIFO stack-based allocation with save/restore
- **FixedStringBuilder**: Zero-allocation string building

#### Render Batching and Scheduling (`batch.zig`)
- **RenderBatcher**: Combine similar render operations efficiently
- **FrameScheduler**: Frame budget management for target FPS
- **PriorityQueue**: Multi-level priority task queue (critical/high/normal/low/idle)
- **AnimationFrameScheduler**: requestAnimationFrame-style scheduling

#### Error Boundary Components (`error_boundary.zig`)
- **ErrorBoundary**: React-style error isolation with retry support
- **ErrorRecovery**: Fallback strategies (retry, ignore, propagate)
- **ErrorContext**: Rich error context with component stack
- **ErrorSeverity**: Severity levels (low/medium/high/critical)
- **Dropped error tracking**: Counter for allocation failures in error handling

#### Analytics and Crash Reporting (`analytics.zig`)
- **AnalyticsHook**: Custom event tracking with batching
- **CrashReporter**: Crash reporting with breadcrumbs and stack traces
- **ABTest**: A/B testing with deterministic variant assignment
- **EventType**: page_view, user_action, performance, error, custom
- **AnalyticsEvent**: Event with timestamp, properties, and metric values

#### Bundle Size Optimization (`bundle.zig`)
- **BundleAnalyzer**: Module analysis with dependency tracking
- **TreeShaker**: Dead code elimination via export/import analysis
- **CompressionEstimator**: Gzip/Brotli ratio estimation
- **CodeSplitter**: Automatic code splitting suggestions

#### Configuration and Metrics
- **PerfConfig**: Configurable performance settings
- **PerfMetrics**: Real-time performance metrics collection
- **OptimizationLevel**: none, balanced, size, speed

#### Module Exports (`main.zig`)
- **Perf Module**: Full performance module re-export
- **Type Aliases**: VDomOptimizer, MemoryPool, RenderBatcher, etc.

#### Unit Tests
- All modules include comprehensive unit tests
- Memory safety verification with testing allocator
- Edge case coverage for all optimization algorithms

### Fixed
- **Clock skew protection**: Safe i128 to u64 casts in frame timing
- **Memory ownership**: Proper string duplication in CrashReporter and ABTest
- **Error propagation**: ObjectPool.release now returns errors properly

## [0.22.0] - 2025-12-24

### Added

#### Edge Adapters - Universal Edge Computing Module
- **Core Module**: `core/src/edge/edge.zig` - Unified edge adapter factory
- **Platform Support**: Deploy Zylix apps to any major edge platform
- **Unified API**: Common EdgeRequest/EdgeResponse abstractions

#### Common Types (`types.zig`)
- **Platform Enum**: cloudflare, vercel, aws_lambda, azure, deno, gcp, fastly, native, unknown
- **EdgeConfig**: Platform-agnostic configuration (timeout, caching, streaming)
- **EdgeRequest**: Unified HTTP request with geo, headers, body
- **EdgeResponse**: Unified HTTP response with fluent API
- **KVStore Interface**: Generic key-value storage abstraction
- **EdgeAdapter Interface**: Base adapter with handle/getKV methods
- **CacheControl**: HTTP cache control header builder
- **GeoInfo**: Geographic location data (country, region, city, lat/long)

#### Cloudflare Workers (`cloudflare.zig`)
- **CloudflareAdapter**: Full Cloudflare Workers integration
- **CloudflareKV**: KV namespace with get/put/delete/list operations
- **D1Database**: SQLite-at-edge with query/execute/batch support
- **R2Bucket**: Object storage with get/put/delete/list
- **CloudflareEnv**: Environment bindings (vars, secrets, KV, D1, R2)
- **Middleware**: Cloudflare-specific headers and context

#### Vercel Edge Functions (`vercel.zig`)
- **VercelAdapter**: Full Vercel Edge integration
- **VercelKV**: Redis-compatible KV with TTL, hash operations
- **VercelBlob**: Blob storage with content-type support
- **EdgeConfigClient**: Global edge configuration access
- **ISR Support**: Incremental Static Regeneration headers

#### AWS Lambda (`aws.zig`)
- **LambdaAdapter**: AWS Lambda and Lambda@Edge integration
- **APIGatewayEvent**: HTTP API v2 event format parsing
- **APIGatewayResponse**: HTTP API v2 response format
- **DynamoDBClient**: Document database with CRUD operations
- **S3Client**: Object storage with presigned URL support
- **LambdaConfig**: Cold start optimization, memory, timeout settings

#### Azure Functions (`azure.zig`)
- **AzureAdapter**: Azure Functions Custom Handler integration
- **AzureHttpRequest/Response**: Azure-specific request/response formats
- **CosmosDBClient**: Document database with partition key support
- **BlobStorageClient**: Azure Blob Storage operations
- **Durable Functions**: Orchestration support configuration

#### Deno Deploy (`deno.zig`)
- **DenoAdapter**: Full Deno Deploy integration
- **DenoKV**: Hierarchical key-value store with versioning
- **AtomicOperation**: Transactional KV operations (check/set/delete)
- **BroadcastChannel**: Real-time pub/sub messaging
- **CronSchedule**: Cron trigger configuration

#### Google Cloud Run (`gcp.zig`)
- **GCPAdapter**: Google Cloud Run integration
- **FirestoreClient**: Document database with collections/documents
- **CloudStorageClient**: GCS bucket operations
- **PubSubClient**: Pub/Sub messaging with topics/subscriptions
- **GCPConfig**: Region, scaling, memory, CPU configuration

#### Fastly Compute@Edge (`fastly.zig`)
- **FastlyAdapter**: Fastly Compute platform integration
- **ConfigStore**: Read-only configuration storage
- **KVStore**: Key-value storage with metadata and generations
- **SecretStore**: Secure secret management (zero-on-free)
- **EdgeDictionary**: Legacy dictionary support
- **FastlyGeo**: Geolocation from request data
- **Request Collapsing**: Cache optimization configuration

#### Unified Edge API (`edge.zig`)
- **UnifiedAdapter**: Platform-agnostic adapter wrapper
- **create()**: Factory function for creating adapters
- **detectPlatform()**: Auto-detect edge platform from environment
- **createAuto()**: Create adapter for detected platform
- **Platform Accessors**: asCloudflare(), asVercel(), asAWS(), etc.
- **edgeMiddleware()**: Common edge headers middleware

#### Module Exports (`main.zig`)
- **Edge Module**: Full edge module re-export
- **Type Aliases**: EdgePlatform, EdgeRequest, EdgeResponse, UnifiedAdapter
- **Adapter Aliases**: CloudflareAdapter, VercelAdapter, LambdaAdapter, etc.

#### Unit Tests
- **Types Tests**: Platform enum, EdgeRequest, EdgeResponse, CacheControl
- **KV Tests**: CloudflareKV, VercelKV, DenoKV operations
- **Storage Tests**: D1Database, R2Bucket, S3Client, CosmosDB, Firestore
- **Adapter Tests**: All adapter init/deinit, platform detection
- **Unified Tests**: UnifiedAdapter creation for all platforms

## [0.21.0] - 2025-12-24

### Added

#### Zylix Server - High-Performance HTTP Server Runtime
- **Core Module**: `core/src/server/server.zig` - Main server application (Zylix)
- **Inspired by Hono.js**: Express-like API with Zig performance
- **Cross-Platform**: Pure Zig implementation, works on all targets

#### HTTP Types (`types.zig`)
- **HTTP Methods**: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, TRACE, CONNECT
- **Status Codes**: Complete HTTP/1.1 status codes (1xx-5xx) with reason phrases
- **Headers**: Case-insensitive header management with iteration support
- **URL Parsing**: Path, query string, and fragment parsing
- **Query Parameters**: QueryParams for URL query handling
- **Cookies**: Full cookie support with SameSite, HttpOnly, Secure attributes
- **Content Types**: Common MIME type constants
- **Server Configuration**: Port, host, max connections, timeouts

#### Request Handling (`request.zig`)
- **Request Struct**: Full HTTP request representation
- **Parsing**: Raw HTTP data parsing into structured request
- **Headers**: Typed header access (header, headers, contentType)
- **Query Params**: URL query parameter extraction
- **Route Params**: Path parameter extraction from routes
- **Body Access**: Raw body, JSON parsing with caching
- **Context Storage**: Middleware context value passing (set/get/getTyped)
- **Request Metadata**: Remote address, user agent, content length
- **RequestBuilder**: Fluent API for constructing test requests

#### Response Handling (`response.zig`)
- **Response Struct**: Full HTTP response representation
- **Fluent API**: Chainable response building
- **Content Types**: text(), html(), json(), jsonValue() helpers
- **Status Codes**: setStatus() with all HTTP status codes
- **Headers**: setHeader(), setContentType() with standard types
- **Cookies**: setCookie() with full cookie options
- **Redirects**: redirect() with permanent/temporary support
- **Error Helpers**: notFound(), badRequest(), unauthorized(), forbidden(), internalError()
- **Serialization**: serialize() to raw HTTP response bytes
- **ResponseBuilder**: Alternative fluent builder pattern

#### Routing System (`router.zig`)
- **Router**: Core router with pattern matching
- **HTTP Method Routes**: get(), post(), put(), delete(), patch(), options(), head(), all()
- **Path Parameters**: `:param` syntax for dynamic routes
- **Wildcard Routes**: `*` matching for catch-all patterns
- **Route Groups**: RouteGroup for prefix-based organization
- **Context**: Request/response context with convenience methods
- **Handler Type**: Standard handler function signature
- **Not Found**: Custom 404 handler support

#### Middleware System (`middleware.zig`)
- **MiddlewareChain**: Composable middleware pipeline
- **Next Function**: Koa-style next() for chain execution
- **MiddlewareFn**: Standard middleware function type
- **Built-in Logger**: Request timing and logging middleware
- **CORS Middleware**: cors() with configurable CorsConfig
- **Security Headers**: secureHeaders() with XSS, frame, MIME protections
- **Recovery**: recovery() for error catching and 500 responses
- **Basic Auth**: basicAuth() with realm and validator config
- **Body Limit**: bodyLimit() with configurable max size
- **ETag**: etag() for cache validation with If-None-Match

#### JSON-RPC 2.0 (`rpc.zig`)
- **RpcServer**: Full JSON-RPC 2.0 server implementation
- **Procedure Registration**: procedure() for method registration
- **Typed Procedures**: typedProcedure() for compile-time type safety
- **Request Handling**: Single and batch request support
- **Error Codes**: Standard JSON-RPC error codes (-32700, -32600, etc.)
- **RpcClient**: Client for building RPC requests
- **Batch Requests**: buildBatchRequest() for multiple calls
- **Router Integration**: mount() to add RPC endpoint to router

#### Main Server API (`server.zig`)
- **Zylix Struct**: Main application entry point
- **Initialization**: init(), initWithConfig() with ServerConfig
- **Middleware API**: use() for adding middleware
- **Routing API**: Full route registration (get, post, put, etc.)
- **Route Groups**: group() for prefix-based organization
- **Request Handling**: handleRequest(), handleRaw() for raw HTTP
- **RPC Integration**: rpcServer() for mounting RPC endpoints
- **Lifecycle**: listen(), close() for server management

#### Module Exports (`main.zig`)
- **Server Module**: Full server module re-export
- **Type Aliases**: Zylix, HttpRequest, HttpResponse, HttpRouter, HttpContext, RpcServer

#### Unit Tests
- **Types Tests**: Headers, URL parsing, cookies, query params
- **Request Tests**: Parsing, headers, body, route params, context
- **Response Tests**: Text, JSON, redirect, error helpers, serialization
- **Router Tests**: Route matching, params, groups, wildcards, 404
- **Middleware Tests**: Chain execution, CORS, security headers
- **RPC Tests**: Server init, client requests, batch, error formatting

## [0.20.0] - 2025-12-24

### Added

#### Zylix mBaaS - Unified Mobile Backend as a Service Module
- **Core Module**: `core/src/mbaas/mbaas.zig` - Unified mBaaS API
- **Multi-Provider Support**: Firebase, Supabase, AWS Amplify with consistent APIs
- **Cross-Platform**: Works on all Zylix targets (iOS, Android, Web/WASM, Desktop)

#### Type System (`types.zig`)
- **User Types**: Unified User struct with UID, email, phone, profile info
- **Auth Providers**: Email, phone, anonymous, Google, Apple, Facebook, Twitter, GitHub, Microsoft
- **Auth States**: Signed in, signed out, error states with callback support
- **Document Types**: Generic document with typed Value fields (string, int, float, bool, array, map)
- **GeoPoint**: Latitude/longitude for geographic data
- **Filter System**: Comprehensive query filters (eq, neq, gt, gte, lt, lte, in, contains, etc.)
- **Storage Types**: FileMetadata, UploadOptions, UploadProgress, DownloadOptions, ListResult
- **Realtime Types**: Subscription, RealtimeEventType (added, modified, removed), RealtimeChange
- **Push Notifications**: NotificationMessage with Android, APNS, and WebPush configs
- **Provider Configs**: FirebaseConfig, SupabaseConfig, AmplifyConfig

#### Firebase Client (`firebase.zig`)
- **Authentication**: Email/password, anonymous, OAuth providers, phone auth
- **Sign In/Out**: signInWithEmail, signInAnonymously, signOut, getCurrentUser
- **Password Reset**: resetPassword, sendPasswordResetEmail
- **Auth State**: onAuthStateChange callback support
- **Firestore**: getDocument, setDocument, updateDocument, deleteDocument
- **Queries**: Query builder with where, orderBy, limit, startAfter
- **Batch Operations**: Batch writes with multiple operations
- **Transactions**: Transaction support with read/write operations
- **Cloud Storage**: uploadBytes, uploadFile, downloadBytes, downloadFile
- **Storage Metadata**: getMetadata, updateMetadata, deleteFile, listFiles
- **Download URLs**: getDownloadURL for public access
- **Realtime**: onSnapshot for document/collection changes, unsubscribe
- **FCM**: sendNotification, subscribeToTopic, unsubscribeFromTopic

#### Supabase Client (`supabase.zig`)
- **Authentication**: Email/password, magic link, OAuth, phone OTP
- **Session Management**: Session tokens, refresh, expiry handling
- **User Management**: signUp, signIn, signOut, updateUser, getCurrentUser
- **Password Reset**: resetPasswordForEmail
- **PostgREST Query Builder**: Fluent API for PostgreSQL queries
- **Query Filters**: eq, neq, gt, gte, lt, lte, like, ilike, in, isNull
- **Query Options**: select, order, limit, offset, single
- **CRUD Operations**: execute (SELECT), insert, update, delete, upsert
- **RPC**: Remote procedure call support for PostgreSQL functions
- **Storage Client**: Bucket-based file storage
- **Bucket Operations**: createBucket, deleteBucket, emptyBucket, listBuckets
- **File Operations**: upload, download, getPublicUrl, createSignedUrl
- **File Management**: list, move, copy, remove
- **Realtime**: Subscribe to table changes (insert, update, delete, all)
- **Realtime Filters**: Filter subscriptions by column values
- **Edge Functions**: invokeFunction for serverless function calls

#### AWS Amplify Client (`amplify.zig`)
- **Cognito Authentication**: signIn, signUp, confirmSignUp, signOut
- **MFA Support**: confirmSignIn with MFA code
- **Password Management**: resetPassword, confirmResetPassword
- **User Attributes**: getAttribute, updateAttribute, getCurrentUser
- **DataStore**: Local-first data with cloud sync
- **Model Operations**: save, query, delete with predicates
- **Predicate System**: eq, ne, gt, ge, lt, le, contains, beginsWith
- **Sync Queue**: Offline operation queueing
- **Observe Changes**: Real-time model change observation
- **S3 Storage**: uploadFile, downloadFile, remove
- **Storage Options**: Access level (guest, protected, private)
- **Upload Progress**: Progress callbacks for large uploads
- **Download URLs**: getUrl for pre-signed S3 URLs
- **List Files**: listFiles with path filtering

#### Unified Client Interface (`mbaas.zig`)
- **Tagged Union**: Client union supporting all three providers
- **Unified Auth**: signInWithEmail, signOut, getCurrentUser across providers
- **Unified Database**: getDocument abstraction
- **Unified Storage**: uploadFile, downloadFile abstraction
- **Unified Realtime**: subscribe, unsubscribe abstraction
- **Factory Functions**: createFirebaseClient, createSupabaseClient, createAmplifyClient
- **Generic Factory**: createClient with provider enum

#### Unit Tests
- **Firebase Tests**: Client initialization, email auth, document operations, storage, realtime
- **Supabase Tests**: Client initialization, email auth, query builder, storage, realtime
- **Amplify Tests**: Client initialization, sign in, DataStore, S3 storage
- **Unified Tests**: Cross-provider client usage, provider enum

## [0.19.0] - 2025-12-24

### Added

#### Zylix Excel - Excel Document Processing Module
- **Core Module**: `core/src/excel/excel.zig` - Unified Excel API
- **XLSX Format**: Full support for Office Open XML spreadsheet format
- **Cross-Platform**: Works on all Zylix targets (iOS, Android, Web/WASM, Desktop)

#### Workbook Management (`workbook.zig`)
- **Workbook Creation**: Create new Excel workbooks from scratch
- **Workbook Loading**: Parse existing XLSX files from memory or file path
- **Worksheet Management**: Add, get, and remove worksheets by name or index
- **Shared Strings**: Efficient string deduplication for reduced file size
- **Active Sheet**: Track and set the active worksheet
- **Properties**: Title, author, subject, keywords, comments, creation/modification dates

#### Worksheet Operations (`worksheet.zig`)
- **Cell Management**: Set and get cells by row/column or A1 reference notation
- **Cell Types**: String, number, boolean, date, time, datetime, formula, error values
- **Row Heights**: Configurable row heights in points
- **Column Widths**: Configurable column widths in characters
- **Hidden Rows/Columns**: Show/hide rows and columns
- **Merged Cells**: Merge cell ranges with range parsing
- **Dimension Tracking**: Automatic used range detection

#### Cell Operations (`cell.zig`)
- **Value Union**: Type-safe cell value storage (string, number, boolean, date, etc.)
- **A1 Notation**: Parse and format cell references (A1, B2, AA100, etc.)
- **Range Support**: Parse and format cell ranges (A1:C10)
- **Style Index**: Link cells to shared style definitions

#### Style Management (`style.zig`)
- **Style Manager**: Centralized style registry with deduplication
- **Fonts**: Name, size, bold, italic, underline, strikethrough, color
- **Fills**: Pattern fills (none, solid, gray_125) with foreground/background colors
- **Borders**: Left, right, top, bottom, diagonal with style and color
- **Alignment**: Horizontal (general, left, center, right, fill, justify)
- **Alignment**: Vertical (top, center, bottom, justify, distributed)
- **Text Control**: Wrap text, shrink to fit, text rotation, indent
- **Number Formats**: Built-in formats + custom format strings
- **Style Builder**: Fluent API for creating styles

#### Color Support (`types.zig`)
- **RGB Colors**: Full RGB color model with alpha channel
- **Named Colors**: black, white, red, green, blue, yellow, cyan, magenta
- **Hex Conversion**: Convert to/from hexadecimal color strings

#### Date/Time Support (`types.zig`)
- **Date**: Year, month, day with Excel serial number conversion
- **Time**: Hour, minute, second, millisecond with fractional day conversion
- **DateTime**: Combined date and time with full serial number support

#### XLSX Writer (`writer.zig`)
- **ZIP Generation**: Create valid ZIP archives with proper structure
- **CRC-32 Calculation**: Accurate checksums for file integrity
- **Content Types**: Generate [Content_Types].xml
- **Relationships**: Generate _rels/.rels and xl/_rels/workbook.xml.rels
- **Workbook XML**: Generate xl/workbook.xml with sheet references
- **Worksheet XML**: Generate xl/worksheets/sheet{n}.xml with cell data
- **Shared Strings**: Generate xl/sharedStrings.xml for string deduplication
- **Styles XML**: Generate xl/styles.xml with fonts, fills, borders, formats
- **File Output**: Write to file path or return as byte buffer

#### XLSX Reader (`reader.zig`)
- **ZIP Parsing**: Extract files from ZIP archive
- **DEFLATE Decompression**: Decompress compressed entries
- **Shared Strings Parsing**: Load string table for value lookup
- **Workbook Parsing**: Extract sheet names and metadata
- **Worksheet Parsing**: Parse cell values by type (string, number, boolean, etc.)
- **Cell Reference Parsing**: Decode A1 notation references
- **XML Entity Decoding**: Handle &lt;, &gt;, &amp;, &quot;, &apos;

### Fixed
- **Zig 0.15 Compatibility**: Updated all ArrayList/HashMap APIs for Zig 0.15
  - Changed `ArrayList.init(allocator)` to `.{}` with allocator passed to methods
  - Changed `ArrayList.deinit()` to `.deinit(allocator)`
  - Changed `ArrayList.append(item)` to `.append(allocator, item)`
  - Changed `ArrayList.writer()` to `.writer(allocator)`
  - Changed `ArrayList.toOwnedSlice()` to `.toOwnedSlice(allocator)`
  - Changed `AutoHashMap`/`StringHashMap` to `Unmanaged` variants
- **Integer Overflow**: Fixed Date.toSerial() overflow for years > 1989

## [0.18.0] - 2025-12-24

### Added

#### Zylix PDF - PDF Document Processing Module
- **Core Module**: `core/src/pdf/pdf.zig` - Unified PDF API
- **PDF 1.7 Specification**: Full compliance with Adobe PDF 1.7 specification
- **Cross-Platform**: Works on iOS, Android, Web/WASM, and Desktop targets

#### Document Management (`document.zig`)
- **Document Creation**: Create new PDF documents from scratch
- **Document Opening**: Parse existing PDF files from memory or file path
- **Page Management**: Add, insert, remove, and reorder pages
- **Document Merging**: Combine multiple PDF documents
- **Document Splitting**: Split documents into individual pages
- **Metadata**: Title, author, subject, keywords, creator, producer, dates
- **Version Support**: PDF 1.0 through 2.0 version control
- **Compression**: Configurable compression (none, flate, lzw)

#### Page Operations (`page.zig`)
- **Page Sizes**: A0-A10, Letter, Legal, Ledger, Tabloid, custom sizes
- **Orientations**: Portrait and landscape with automatic size adjustment
- **Margins**: Normal, narrow, wide, and custom margin presets
- **Graphics State**: Save/restore state stack with full state management
- **Colors**: RGB color support for fill and stroke operations
- **Line Styles**: Width, cap (butt, round, square), join (miter, round, bevel)
- **Dash Patterns**: Configurable dash patterns with phase offset
- **Transformations**: Translate, scale, rotate coordinate system

#### Text Operations (`text.zig`, `font.zig`)
- **Standard Fonts**: Helvetica, Times-Roman, Courier families (regular, bold, italic)
- **Symbol Fonts**: Symbol, ZapfDingbats
- **Font Metrics**: Accurate character positioning with ascender, descender, line gap
- **Text Drawing**: Position-based text rendering with font and size control
- **Styled Text**: Text with color, font, and size styling
- **Text Blocks**: Multi-line text with paragraph handling and line wrapping
- **Rich Text**: Mixed formatting within text blocks
- **UTF-8 Support**: Proper UTF-8 codepoint iteration for text width calculation
- **TrueType Fonts**: Load and embed custom TrueType fonts (with proper ownership)

#### Graphics Operations (`graphics.zig`)
- **Shapes**: Rectangle, circle, ellipse (stroke, fill, or both)
- **Lines**: Line drawing with configurable style
- **Paths**: Complex path construction with moveTo, lineTo, curveTo, quadTo
- **Path Shapes**: Rounded rectangles, circles, ellipses via path API
- **Bezier Curves**: Cubic and quadratic bezier curve support
- **Gradients**: Linear and radial gradients with color stops
- **Transformation Matrix**: Full 2D transformation matrix operations
- **Blend Modes**: Normal, multiply, screen, overlay, darken, lighten, etc.

#### Image Handling (`image.zig`)
- **Image Formats**: JPEG, PNG (with magic byte detection), GIF, BMP, TIFF
- **Color Spaces**: Grayscale, RGB, RGBA, CMYK, Indexed
- **Image Scaling**: Nearest-neighbor resampling for dimension changes
- **Grayscale Conversion**: Luminosity-based color to grayscale conversion
- **Image Cloning**: Duplicate images with independent data
- **Placement Options**: Position, dimensions, rotation, opacity, fit modes

#### PDF Writing (`writer.zig`)
- **PDF Structure**: Header, body, xref table, trailer generation
- **Object Management**: Automatic object ID allocation and xref tracking
- **Stream Writing**: Content streams with length calculation
- **String Escaping**: Proper PDF string escape sequences
- **Date Formatting**: PDF date format (D:YYYYMMDDHHmmSS)
- **Negative Timestamp Handling**: Clamp pre-epoch timestamps to Unix epoch

#### PDF Parsing (`parser.zig`)
- **Header Parsing**: Version detection from PDF header
- **Cross-Reference Table**: Traditional xref table parsing
- **Object References**: Object number and generation tracking
- **Page Count Heuristic**: Quick page counting with overflow protection

#### Performance Benchmarks (`benchmark/benchmark.zig`)
- **Benchmark Framework**: Reusable benchmark runner with warmup and timing
- **PDF Benchmarks**: Header parsing, version detection performance tests
- **State Benchmarks**: Hash computation, lookup operation tests
- **Animation Benchmarks**: Easing functions, interpolation performance tests
- **NodeFlow Benchmarks**: ID generation, connection validation tests
- **Memory Benchmarks**: Small (64B) and medium (1KB) allocation tests
- **Build Integration**: `zig build bench` command for running benchmarks

### Fixed
- **Memory Safety**: Proper errdefer cleanup in document.open() and document.merge()
- **Graphics State**: restoreState only writes Q operator when state exists
- **Font Ownership**: loadTrueType now copies data for clear ownership semantics
- **UTF-8 Text Width**: getTextWidth uses proper UTF-8 codepoint iteration
- **Integer Overflow**: getPageCount prevents underflow with small documents
- **Integration Memory Leaks**: Fixed Future object leaks in ads.zig and keyvalue.zig tests

## [0.12.0] - 2025-12-24

### Added

#### Zylix Graphics3D - Cross-Platform 3D Graphics Engine
- **Core Module**: `core/src/graphics3d/graphics3d.zig` - Unified 3D graphics API
- **Inspired by**: Three.js and Babylon.js for familiar developer experience
- **Multi-Backend**: Support for Metal, Vulkan, DirectX12, WebGL2, WebGPU

#### 3D Math Types (`types.zig`)
- **Vectors**: Vec2, Vec3, Vec4 with full math operations (add, sub, scale, dot, cross, normalize, lerp)
- **Quaternion**: Rotation representation with axis-angle, euler, slerp support
- **Mat4**: 4x4 matrix for transforms, projections, view matrices, lookAt
- **Color**: RGBA color with preset colors (red, green, blue, white, black, etc.)
- **Transform**: Position, rotation, scale with matrix conversion
- **Bounding Volumes**: AABB, BoundingSphere for culling
- **Ray**: Ray casting with AABB, sphere, plane intersection tests
- **Frustum**: View frustum with 6 planes for culling

#### Camera System (`camera.zig`)
- **Camera**: Perspective and orthographic projection support
- **View Matrix**: Position, target, up vector configuration
- **Frustum Culling**: Built-in frustum extraction for visibility testing
- **Screen-to-World**: Ray casting from screen coordinates
- **Controllers**:
  - OrbitController: Orbit around target with zoom
  - FirstPersonController: FPS-style camera control
  - FlyController: Free-fly camera movement
- **CameraManager**: Multiple camera management

#### Lighting System (`lighting.zig`)
- **LightBase**: Common light properties (color, intensity, shadows, layers)
- **DirectionalLight**: Sun-like light with cascade shadow maps
- **PointLight**: Point source with attenuation (constant, linear, quadratic)
- **SpotLight**: Cone-shaped light with inner/outer angles
- **AreaLight**: Rectangle/disc soft shadows
- **AmbientLight**: Global illumination with optional sky gradient
- **LightManager**: Light management with shadow caster tracking

#### Mesh & Geometry (`mesh.zig`)
- **Vertex Formats**:
  - Vertex: position, normal, uv, color
  - VertexTangent: with tangent for normal mapping
  - VertexSkinned: with bone weights for skeletal animation
  - VertexColored: position and color only
- **Mesh**: Vertices, indices, submeshes, bounds calculation
- **Primitive Types**: Points, lines, line_strip, triangles, triangle_strip, triangle_fan
- **Procedural Geometry**:
  - Cube, Sphere, Cylinder, Plane, Cone, Torus
  - Configurable segments and dimensions

#### Material System (`material.zig`)
- **Texture2D**: 2D textures with filtering and wrapping
- **TextureCube**: Cubemap for skybox and environment mapping
- **TextureFormat**: r8, rg8, rgb8, rgba8, r16f, depth formats
- **Shader**: Vertex/fragment shaders with uniform definitions
- **Material**: PBR material with:
  - Albedo (color + texture)
  - Metallic, Roughness (value + texture)
  - Normal mapping with scale
  - Ambient occlusion
  - Emission (color + texture + strength)
  - Height/parallax mapping
- **Blend Modes**: opaque, alpha_blend, additive, multiply, premultiplied
- **MaterialLibrary**: Preset materials (metal, plastic, rubber, glass, wood, gold, silver, copper, etc.)

#### Scene Graph (`scene.zig`)
- **SceneNode**: Hierarchical scene node with:
  - Parent/child relationships
  - Local and world transforms
  - Transform propagation with dirty flag optimization
  - Mesh, material, camera, light references
  - Layer mask for selective rendering
  - Frustum culling support
- **Scene**: Root node with:
  - Camera and light managers
  - Environment settings (ambient, fog, skybox)
  - Scene statistics
  - Frustum culling helpers

#### Renderer (`renderer.zig`)
- **BackendType**: metal, vulkan, directx12, webgl2, webgpu, opengl, software
- **RenderCapabilities**: Feature detection per backend
- **RenderState**: Viewport, depth, blend, cull, scissor state
- **RenderQueue**: Material-sorted rendering (opaque front-to-back, transparent back-to-front)
- **RenderStats**: Draw calls, triangles, vertices tracking
- **RenderPass**: Multi-pass rendering (shadow, geometry, post-process, UI)
- **DebugDraw**: Debug drawing utilities (line, box, sphere)

### Fixed
- **Core**: Fixed Zig 0.15 `opaque` keyword conflict in BlendMode enum (use `@"opaque"`)
- **Core**: Fixed variable shadowing with Zig primitive type `i0` in mesh.zig
- **Core**: Fixed unused parameter warning in renderer.zig endFrame()

## [0.11.0] - 2025-12-24

### Added

#### Zylix Animation - Cross-Platform Animation System
- **Core Module**: `core/src/animation/animation.zig` - Unified animation API
- **Performance**: Optimized for 60fps on all platforms
- **Composable**: Animations can be combined and layered
- **Platform Optimized**: Native renderers where beneficial

#### Lottie Vector Animation Support
- **Lottie Parser**: `lottie.zig` - JSON-based Lottie animation parsing
- **Layer Types**: Precomp, Solid, Image, Null, Shape, Text, Audio
- **Shape Elements**: Fill, Stroke, Transform, Group, Path, Rectangle, Ellipse, Star
- **Bezier Paths**: Full bezier curve support for vector shapes
- **Animated Values**: Keyframe interpolation with easing
- **Markers**: Named markers for segment playback
- **LottieManager**: Centralized animation management

#### Live2D Character Animation Support
- **Live2D Model**: `live2d.zig` - Cubism SDK integration
- **Motion System**: Motion playback with blending and priority layers
- **Expression System**: Facial expression blending
- **Physics Simulation**: Physics rig for natural hair/cloth movement
- **Eye Blink**: Automatic eye blink controller
- **Lip Sync**: Phoneme-based lip synchronization
- **Standard Parameters**: Common parameter IDs (ParamAngleX, ParamEyeBlink, etc.)
- **Live2DManager**: Centralized model management

#### Animation Timeline System
- **Timeline Controller**: `timeline.zig` - Keyframe-based timeline animation
- **Property Tracks**: Track any property type with keyframes
- **Sequence Builder**: Chain animations sequentially
- **Parallel Groups**: Run animations simultaneously
- **Markers**: Named time points for synchronization
- **Playback Control**: Play, pause, stop, seek, reverse
- **Loop Modes**: None, loop, ping-pong, count-based

#### Animation State Machine
- **State Machine**: `state_machine.zig` - Animation state management
- **States**: Named states with animation assignments
- **Transitions**: Automatic and manual state transitions
- **Conditions**: Parameter-based transition conditions
- **Comparison Operators**: Equal, not equal, greater, less, etc.
- **Parameters**: Bool, int, float, trigger types
- **Animation Layers**: Multi-layer animation blending
- **Animation Controller**: High-level controller with multiple layers

#### Easing Functions Library
- **30+ Easing Functions**: `easing.zig` - Comprehensive easing library
- **Quadratic**: easeInQuad, easeOutQuad, easeInOutQuad
- **Cubic**: easeInCubic, easeOutCubic, easeInOutCubic
- **Quartic**: easeInQuart, easeOutQuart, easeInOutQuart
- **Quintic**: easeInQuint, easeOutQuint, easeInOutQuint
- **Sinusoidal**: easeInSine, easeOutSine, easeInOutSine
- **Exponential**: easeInExpo, easeOutExpo, easeInOutExpo
- **Circular**: easeInCirc, easeOutCirc, easeInOutCirc
- **Back**: easeInBack, easeOutBack, easeInOutBack
- **Elastic**: easeInElastic, easeOutElastic, easeInOutElastic
- **Bounce**: easeInBounce, easeOutBounce, easeInOutBounce
- **Cubic Bezier**: Custom bezier curves (CSS-style)
- **Spring Physics**: Spring-based easing with stiffness/damping

#### Common Animation Types
- **Time Types**: `types.zig` - TimeMs, DurationMs, NormalizedTime, FrameNumber
- **Geometry**: Point2D, Size2D, Rect2D, Transform2D, Matrix3x3
- **Color**: RGBA color with alpha
- **Playback**: PlaybackState, LoopMode, PlayDirection
- **Blend Modes**: Normal, add, multiply, screen, overlay
- **Fill Modes**: Forwards, backwards, both, none
- **Events**: AnimationEvent with callbacks

#### iOS Platform Implementation
- **ZylixAnimation.swift**: Native iOS animation support
  - ZylixEasing with all standard easing functions
  - ZylixTimeline with CADisplayLink updates
  - ZylixLottieAnimation with JSON loading/playback
  - ZylixAnimationManager singleton
  - SwiftUI views (ZylixLottieView, ZylixTimelineView)
  - View modifiers (zylixAnimatedOpacity, zylixAnimatedScale, etc.)

#### Android Platform Implementation
- **ZylixAnimation.kt**: Native Android animation support
  - ZylixEasing object with all easing functions
  - ZylixTimeline with Choreographer.FrameCallback
  - ZylixLottieAnimation with JSONObject parsing
  - ZylixAnimationManager singleton object
  - Jetpack Compose UI (ZylixLottieView, ZylixTimelineView)
  - Compose modifiers (zylixAnimatedOpacity, zylixAnimatedScale, etc.)

#### Web Platform Implementation
- **zylix-animation.js**: Web animation support
  - Easing object with all standard easing functions
  - CubicBezier factory for custom bezier curves
  - Timeline class with requestAnimationFrame
  - PropertyTrack for keyframe animation
  - LottieAnimation with JSON loading
  - AnimationManager singleton
  - Utility functions (tween, lerp, animateStyle)
- **animation-test.html**: Interactive demo page
  - Easing function preview with visual curves
  - Timeline animation demo with controls
  - State machine demo with character animation
  - Simple animation demos (fade, scale, rotate, bounce, shake, spring)

### Changed
- Module version updated to v0.11.0

### Fixed
- **Core**: Migrated all animation module files to Zig 0.15 ArrayList API
  - `timeline.zig`: PropertyTrack, Timeline, ParallelGroup ArrayList usage
  - `state_machine.zig`: Transition, StateMachine, AnimationController
  - `lottie.zig`: BezierPath, AnimatedValue, Layer, Animation
  - `live2d.zig`: MotionCurve, Motion, PhysicsRig, Model
- **Core**: Fixed Timeline.getDuration() to calculate dynamically from tracks
- **Core**: Fixed memory leak in track deinit_fn (added allocator.destroy)
- **Docs**: Added CLAUDE.md with quality verification checklist

## [0.10.0] - 2025-12-24

### Added

#### Zylix Device - Cross-Platform Device Features Module
- **Core Module**: `core/src/device/device.zig` - Unified device features API
- **Privacy Aware**: Platform-specific permission handling
- **Cross-Platform**: Same API across iOS, Android, macOS, Windows, Linux, Web

#### Location Services
- **GPS/Location**: `location.zig` - Location updates and tracking
- **Geofencing**: Region monitoring with enter/exit events
- **Geocoding**: Address to coordinate conversion
- **Accuracy Levels**: Best, navigation, 10m, 100m, 1km, 3km

#### Camera Access
- **Photo Capture**: `camera.zig` - Camera preview and photo capture
- **Video Recording**: Video recording with quality settings
- **Camera Selection**: Front/back camera switching
- **Flash Control**: Auto, on, off, torch modes
- **Focus Modes**: Auto, continuous, locked

#### Sensor Integration
- **Motion Sensors**: `sensors.zig` - Accelerometer, gyroscope, magnetometer
- **Device Motion**: Combined sensor data with attitude (pitch, roll, yaw)
- **Barometer**: Atmospheric pressure and altitude
- **Pedometer**: Step counting and distance
- **Heart Rate**: Health sensor support (watchOS)
- **Compass**: Heading/direction data

#### Notification System
- **Local Notifications**: `notifications.zig` - Scheduled notifications
- **Push Support**: Token-based push notification registration
- **Triggers**: Immediate, interval, calendar, location-based
- **Actions**: Interactive notification actions and categories
- **Sound Support**: Custom notification sounds

#### Audio System
- **Audio Playback**: `audio.zig` - Audio file playback
- **Audio Recording**: Voice and sound recording
- **Session Management**: Audio session categories
- **Background Audio**: Background playback support

#### Background Processing
- **Background Tasks**: `background.zig` - Background task scheduling
- **Background Fetch**: Periodic background data fetching
- **Background Sync**: Data synchronization in background
- **Transfer Tasks**: Background upload/download support
- **Task Constraints**: Network, charging, battery, idle constraints

#### Haptic Feedback
- **Haptics Engine**: `haptics.zig` - Haptic feedback generation
- **Impact Styles**: Light, medium, heavy, soft, rigid
- **Notification Types**: Success, warning, error haptics
- **Custom Patterns**: Transient, continuous, pause elements

#### Permission Handling
- **Permission Manager**: `permissions.zig` - Unified permission API
- **Permission Types**: Camera, microphone, location, photos, notifications, etc.
- **Status Tracking**: Authorized, denied, restricted, not determined
- **Rationale Support**: Android-style permission rationale

#### Zylix Gesture - Advanced Gesture Recognition Module
- **Core Module**: `core/src/gesture/gesture.zig` - Unified gesture API
- **Platform Optimized**: Native feel on each platform
- **Composable**: Multiple gestures can work simultaneously

#### Gesture Recognizers
- **Tap Recognizer**: `recognizers.zig` - Single and multi-tap detection
- **Long Press**: Long press with configurable duration
- **Pan Gesture**: Dragging/panning with velocity tracking
- **Swipe Gesture**: Directional swipes (up, down, left, right)
- **Pinch Gesture**: Two-finger pinch for zooming
- **Rotation Gesture**: Two-finger rotation detection

#### Drag and Drop
- **Drag Manager**: `drag_drop.zig` - Cross-platform drag and drop
- **Platform Aware**: Long-press on mobile, direct drag on desktop
- **Drop Targets**: Configurable drop target registration
- **Data Types**: Text, URL, file, image, custom data
- **Drop Operations**: Copy, move, link operations

#### iOS Platform Implementation
- **ZylixDevice.swift**: Native device features using iOS frameworks
  - CoreLocation for GPS/location services
  - AVFoundation for camera and audio
  - CoreMotion for sensors (accelerometer, gyroscope)
  - UserNotifications for local/push notifications
  - CoreHaptics for haptic feedback
- **ZylixGesture.swift**: UIKit gesture recognizers with SwiftUI modifiers
  - All gesture types (Tap, LongPress, Pan, Swipe, Pinch, Rotation, EdgePan)
  - ZylixGestureManager singleton for centralized management
  - SwiftUI View extensions (zylixOnTap, zylixOnLongPress, etc.)
- **DeviceTestView.swift**: Interactive test UI for device features

#### Android Platform Implementation
- **ZylixDevice.kt**: Native device features using Android frameworks
  - LocationManager for GPS services
  - CameraX for camera access
  - SensorManager for motion sensors
  - NotificationManager for notifications
  - Vibrator/VibratorManager for haptics
  - MediaRecorder for audio recording
- **ZylixGesture.kt**: Jetpack Compose gesture support
  - Complete gesture type system matching Zig core
  - Compose Modifier extensions for all gesture types
  - StateFlow-based gesture state tracking
- **DeviceTestScreen.kt**: Compose-based test UI

#### Web Platform Implementation
- **zylix-device.js**: Web APIs for device features
  - Geolocation API for location services
  - Vibration API for haptic feedback
  - Generic Sensor API for accelerometer/gyroscope
  - Notification API for web notifications
  - MediaDevices API for camera/microphone
- **zylix-gesture.js**: Pointer Events API integration
  - Touch tracking with multi-finger support
  - All recognizer types with event callbacks
  - ZylixGestureManager and convenience functions
- **device-test.html**: Interactive test page for device features
- **gesture-test.html**: Interactive test page for gesture recognition

### Changed
- Module version updated to v0.10.0
- Device module follows same patterns as AI module

## [0.9.0] - 2025-12-24

### Added

#### Zylix AI - On-Device AI Inference Module
- **Core Module**: `core/src/ai/ai.zig` - Unified AI inference API
- **Privacy First**: All processing on-device, no external network calls
- **Offline Operation**: Full functionality without internet connection

#### Embedding Model Support
- **Text Embedding**: `embedding.zig` - Text to vector conversion
- **Semantic Search**: Cosine similarity for vector comparison
- **RAG Support**: Foundation for retrieval-augmented generation

#### Large Language Model (LLM) Support
- **Text Generation**: `llm.zig` - Chat and completion
- **Chat Format**: System/User/Assistant message roles
- **Streaming**: Real-time token generation support
- **Context Length**: Configurable up to 32K tokens

#### Vision Language Model (VLM) Support
- **Image Analysis**: `vlm.zig` - Image understanding
- **OCR**: Text extraction from images
- **Visual QA**: Question answering about images
- **Formats**: RGB, RGBA, Grayscale, BGR, BGRA

#### Whisper Speech-to-Text
- **Transcription**: `whisper.zig` - Audio to text
- **Streaming**: `whisper_stream.zig` - Real-time transcription
- **Multi-language**: Support for multiple languages
- **Timestamps**: Word-level timing information

#### Audio Processing
- **Decoder**: `audio_decoder.zig` - Multi-format audio decoding
- **Formats**: MP3, FLAC, OGG, WAV support via miniaudio
- **Sample Rates**: Automatic resampling to 16kHz for Whisper

#### Platform-Specific Backends
- **Apple Metal**: `metal.zig` - GPU acceleration for macOS/iOS
- **Core ML**: `coreml.zig` - Apple ML framework integration
- **llama.cpp**: `llama_cpp.zig` - GGUF model support
- **mtmd.cpp**: `mtmd_cpp.zig` - Multimodal support

### Changed

#### Website UI/UX
- **Design Tokens**: Unified CSS custom properties (:root variables) for consistent styling
- **Hero Section**: Reduced badge opacity, improved CTA hierarchy with gradient/shadow differentiation
- **Card Styling**: Enhanced borders (rgba(255,255,255,0.12)) and shadows for visual separation
- **Sidebar Navigation**: Active state highlighting with left border accent and background
- **Tables**: Improved styling and mobile responsiveness with horizontal scroll
- **Japanese Typography**: Adjusted letter-spacing (0.01em) and line-height for readability
- **Mobile**: 44px minimum tap targets, header backdrop opacity, improved spacing
- **Accessibility**: Focus states, reduced motion support, semantic improvements

## [0.8.1] - 2025-12-23

### Breaking Changes

#### ABI v2 Migration
- **ABI Version**: Bumped from 1 to 2
- **zylix_copy_string**: Signature changed - added `src_len` parameter
  - Old: `zylix_copy_string(src, dst, dst_len)`
  - New: `zylix_copy_string(src, src_len, dst, dst_len)`
  - **Migration Required**: All platform bindings (Swift, Kotlin, C#) must be updated to pass the source length parameter

### Added

#### watchOS Support
- **Core**: watchOS platform support in Zig driver
- **Core**: SimulatorType extended with Apple Watch device types
  - Apple Watch Series 9 (41mm, 45mm)
  - Apple Watch Series 10 (42mm, 46mm)
  - Apple Watch Ultra 2
  - Apple Watch SE (40mm, 44mm)
- **Core**: watchOS-specific configuration options
  - `is_watchos` flag
  - `watchos_version` setting
  - `companion_device_udid` for paired iPhone
- **Core**: watchOS-specific actions
  - `rotateDigitalCrown()` - Digital Crown rotation
  - `pressSideButton()` - Side button press
  - `doublePresssSideButton()` - Double press for Apple Pay
  - `getCompanionDeviceInfo()` - Companion device information

#### Language Bindings
- **TypeScript**: `@zylix/test` npm package (v0.8.0)
  - Full platform support (Web, iOS, watchOS, Android, macOS)
  - 10 selector types (testId, accessibilityId, XPath, CSS, etc.)
  - Element actions (tap, type, swipe, longPress, etc.)
  - Complete TypeScript type definitions
  - ESM + CommonJS dual exports
- **Python**: `zylix-test` PyPI package (v0.8.0)
  - Full async/await support
  - Full platform support (Web, iOS, watchOS, Android, macOS)
  - 10 selector types
  - Complete type annotations (mypy strict compatible)
  - PEP 561 typed package

#### CI/CD
- **GitHub Actions**: Comprehensive CI workflow
  - Core build (Ubuntu, macOS, Windows) with Zig 0.15.2
  - iOS/watchOS build with Swift
  - Android build with Kotlin/Gradle (JDK 17)
  - Windows build with .NET 8.0
  - Web tests with Node.js 20
  - Documentation build with Hugo
- **GitHub Actions**: Release workflow for automated releases

#### E2E Testing
- **Core**: E2E test framework (`core/src/test/e2e/`)
  - Web E2E tests (ChromeDriver)
  - iOS/watchOS E2E tests (WebDriverAgent)
  - Android E2E tests (Appium/UIAutomator2)
  - Desktop E2E tests (macOS/Windows/Linux)

#### Sample Demos
- **Samples**: Platform-specific test demos (`samples/test-demos/`)
  - Web (Playwright)
  - iOS (Swift/WebDriverAgent)
  - watchOS (Swift/WDA + Digital Crown)
  - Android (Kotlin/Appium)
  - macOS (Swift/Accessibility Bridge)

#### Documentation
- **API Reference**: Comprehensive API documentation
- **Platform Guides**: Setup guides for all platforms

## [0.7.0] - 2025-12-22

### Added

#### Component Library Expansion
- **Core**: 57 component types defined in Zig core (up from 9)
- **Core**: New component categories: Form, Layout, Navigation, Feedback, Data Display

#### Native Platform Support
- **iOS**: Full SwiftUI implementations for all 57 component types
- **Android**: Full Jetpack Compose implementations for all 57 component types
- **Windows**: Full WinUI 3 implementations for all 57 component types
- **macOS**: SwiftUI component implementations

#### New Components
- **Form**: DatePicker, TimePicker, FileInput, ColorPicker
- **Layout**: AspectRatio, SafeArea
- **Navigation**: Drawer, Breadcrumb, Pagination
- **Feedback**: Toast, Modal, Skeleton
- **Data Display**: Table, Tooltip, Accordion, Carousel

### Fixed

#### Android
- Gradle dependencies for Jetpack Compose and Navigation
- OkHttp dependency for networking
- `ExperimentalMaterial3Api` opt-in for dropdown menus
- `SelectBuilder` type mismatch in coroutines
- Variable shadowing in `apply` blocks (ZylixHotReload)

## [0.6.2] - 2025-12-21

### Fixed

#### Security
- **Web**: XSS vulnerability in error overlay by escaping dynamic content
- **Web**: Command injection in browser opening function using spawn with arguments array
- **Web**: Added development mode check for dynamic code execution

#### Concurrency
- **Windows**: CancellationTokenSource reuse issue after cancellation
- **Windows**: Multi-frame WebSocket message handling
- **Windows**: Blocking .Wait() calls causing deadlocks (replaced with fire-and-forget)
- **Windows**: Thread-safety issue in file watcher debounce using Interlocked
- **Android**: ConcurrentModificationException in callback iteration using toList()
- **Android**: Reconnect backoff jitter to prevent thundering herd
- **Android**: disconnect() to properly reset state and cancel pending jobs

### Added
- **Android**: removeNavigateCallback() and clearNavigateCallbacks() for memory leak prevention
- **Android**: Deep link handling to preserve query parameters
- **Android**: URL decoding for query parameters
- **Web**: JSON.parse error handling for malformed messages

## [0.6.1] - 2025-12-21

### Fixed

#### Security (Sample Applications)
- **All Samples**: Added escapeHtml, escapeAttr, escapeUrl utilities for XSS prevention
- **All Samples**: Replaced inline onclick handlers with data-action event delegation
- **All Samples**: Secure ID generation using crypto.randomUUID() with fallback

#### Applications Fixed
- todo-pro: XSS prevention, event delegation, secure IDs
- dashboard: XSS prevention, event delegation
- chat: XSS prevention, event delegation, secure message IDs
- e-commerce: XSS prevention, event delegation, secure cart handling
- notes: XSS prevention, event delegation, secure note IDs

## [0.6.0] - 2025-12-21

### Added

#### Sample Applications
- **todo-pro**: Advanced todo app with categories, priorities, and due dates
- **dashboard**: Analytics dashboard with charts and metrics
- **chat**: Real-time chat application with rooms and messages
- **e-commerce**: Shopping cart with product catalog and checkout
- **notes**: Note-taking app with folders and tags

#### Platform Features
- **All Platforms**: Router module with navigation guards and deep linking
- **All Platforms**: Hot reload client with state preservation
- **All Platforms**: Async utilities with promises and futures
- **All Platforms**: Component library with common UI elements

#### Documentation
- Comprehensive ROADMAP.md with development phases
- ROADMAP.ja.md Japanese translation
- Sample applications README

## [0.5.0] - 2025-12-21

### Added

#### GitHub Configuration
- Comprehensive README with project documentation
- Contributing guidelines (CONTRIBUTING.md)
- Security policy (SECURITY.md)
- GitHub issue templates (bug report, feature request)
- Pull request template
- CODEOWNERS file
- Dependabot configuration
- GitHub Actions CI/CD workflows

### Changed
- Updated documentation structure

## [0.1.0] - 2025-12-21

### Added

#### Documentation Website
- Hugo-based documentation site with Hextra theme
- Multilingual support structure
- Platform-specific tutorials for all 6 platforms
- API reference documentation
- Getting started guides

#### Windows Platform (Phase 11)
- WinUI 3 integration with native Windows UI
- C# bindings for Zylix core
- Todo demo application
- Full state management and event handling

#### Linux Platform (Phase 10)
- GTK4 native application support
- C bindings with GObject integration
- Todo demo application
- Cross-desktop compatibility

#### macOS Platform (Phase 9)
- SwiftUI native application support
- Swift bindings for Zylix core
- Todo demo application
- macOS-specific UI patterns

#### Android Platform (Phase 8)
- Jetpack Compose integration
- Kotlin bindings via JNI
- Todo demo application
- Material Design support

#### iOS Platform (Phase 7)
- SwiftUI integration
- Swift bindings for Zylix core
- Todo demo application
- iOS-specific UI patterns

#### Web Platform (Phase 6)
- WebAssembly (WASM) compilation
- JavaScript interop layer
- Todo demo application
- Browser-based rendering

#### Core Framework (Phases 1-5)
- Virtual DOM implementation with efficient diffing algorithm
- Declarative UI DSL for component definition
- Flexbox layout engine
- CSS utility system
- State management with reactive updates
- Event system with cross-platform support
- C ABI layer for language bindings
- Component lifecycle management

### Fixed
- Memory optimization for WASM builds (reduced array sizes)
- JNI bridge compatibility with Zig C ABI signatures

## [0.0.1] - 2025-12-01

### Added
- Initial project scaffolding
- Core library structure
- Platform directory organization
- Project planning documentation
- Apache 2.0 license

[Unreleased]: https://github.com/kotsutsumi/zylix/compare/v0.11.0...HEAD
[0.11.0]: https://github.com/kotsutsumi/zylix/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/kotsutsumi/zylix/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/kotsutsumi/zylix/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/kotsutsumi/zylix/compare/v0.8.0...v0.8.1
[0.7.0]: https://github.com/kotsutsumi/zylix/compare/v0.6.2...v0.7.0
[0.6.2]: https://github.com/kotsutsumi/zylix/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/kotsutsumi/zylix/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/kotsutsumi/zylix/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kotsutsumi/zylix/compare/v0.1.0...v0.5.0
[0.1.0]: https://github.com/kotsutsumi/zylix/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kotsutsumi/zylix/releases/tag/v0.0.1
