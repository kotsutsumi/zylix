/**
 * Zylix Tooling - C ABI Header
 *
 * This header provides the C interface for integrating Zylix Developer Tooling
 * with platform shells (iOS/Android/Desktop/IDE plugins).
 *
 * Includes APIs for:
 * - Project Scaffolding (#46)
 * - Build Orchestration (#47)
 * - Build Artifact Query (#48)
 * - Target Capability Matrix (#51)
 * - Template Catalog (#52)
 * - File Watcher (#53)
 */

#ifndef ZYLIX_TOOLING_H
#define ZYLIX_TOOLING_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* === Version === */

#define ZYLIX_TOOLING_ABI_VERSION 1

/* === Result Codes === */

typedef enum {
    ZYLIX_TOOLING_OK = 0,
    ZYLIX_TOOLING_ERR_INVALID_ARG = 1,
    ZYLIX_TOOLING_ERR_OUT_OF_MEMORY = 2,
    ZYLIX_TOOLING_ERR_NOT_FOUND = 3,
    ZYLIX_TOOLING_ERR_ALREADY_EXISTS = 4,
    ZYLIX_TOOLING_ERR_PERMISSION_DENIED = 5,
    ZYLIX_TOOLING_ERR_VALIDATION_FAILED = 6,
    ZYLIX_TOOLING_ERR_BUILD_FAILED = 7,
    ZYLIX_TOOLING_ERR_CANCELLED = 8,
    ZYLIX_TOOLING_ERR_NOT_INITIALIZED = 9,
    ZYLIX_TOOLING_ERR_IO_ERROR = 10,
} zylix_tooling_result_t;

/* === Target Platform IDs === */

#define ZYLIX_TARGET_IOS      0
#define ZYLIX_TARGET_ANDROID  1
#define ZYLIX_TARGET_WEB      2
#define ZYLIX_TARGET_MACOS    3
#define ZYLIX_TARGET_WINDOWS  4
#define ZYLIX_TARGET_LINUX    5
#define ZYLIX_TARGET_EMBEDDED 6

/* Target bitmasks for multi-target operations */
#define ZYLIX_TARGET_MASK_IOS      (1 << ZYLIX_TARGET_IOS)
#define ZYLIX_TARGET_MASK_ANDROID  (1 << ZYLIX_TARGET_ANDROID)
#define ZYLIX_TARGET_MASK_WEB      (1 << ZYLIX_TARGET_WEB)
#define ZYLIX_TARGET_MASK_MACOS    (1 << ZYLIX_TARGET_MACOS)
#define ZYLIX_TARGET_MASK_WINDOWS  (1 << ZYLIX_TARGET_WINDOWS)
#define ZYLIX_TARGET_MASK_LINUX    (1 << ZYLIX_TARGET_LINUX)
#define ZYLIX_TARGET_MASK_EMBEDDED (1 << ZYLIX_TARGET_EMBEDDED)
#define ZYLIX_TARGET_MASK_ALL      0x7F

/* === Project Types === */

#define ZYLIX_PROJECT_TYPE_APP       0
#define ZYLIX_PROJECT_TYPE_LIBRARY   1
#define ZYLIX_PROJECT_TYPE_COMPONENT 2
#define ZYLIX_PROJECT_TYPE_PLUGIN    3

/* === Build Modes === */

#define ZYLIX_BUILD_MODE_DEBUG         0
#define ZYLIX_BUILD_MODE_RELEASE       1
#define ZYLIX_BUILD_MODE_RELEASE_SAFE  2
#define ZYLIX_BUILD_MODE_RELEASE_SMALL 3

/* === Build States === */

#define ZYLIX_BUILD_STATE_PENDING    0
#define ZYLIX_BUILD_STATE_PREPARING  1
#define ZYLIX_BUILD_STATE_COMPILING  2
#define ZYLIX_BUILD_STATE_LINKING    3
#define ZYLIX_BUILD_STATE_SIGNING    4
#define ZYLIX_BUILD_STATE_PACKAGING  5
#define ZYLIX_BUILD_STATE_COMPLETED  6
#define ZYLIX_BUILD_STATE_FAILED     7
#define ZYLIX_BUILD_STATE_CANCELLED  8

/* === Optimization Levels === */

#define ZYLIX_OPT_NONE       0
#define ZYLIX_OPT_SIZE       1
#define ZYLIX_OPT_SPEED      2
#define ZYLIX_OPT_AGGRESSIVE 3

/* === Log Levels === */

#define ZYLIX_LOG_DEBUG   0
#define ZYLIX_LOG_INFO    1
#define ZYLIX_LOG_WARNING 2
#define ZYLIX_LOG_ERROR   3

/* === Feature IDs === */

#define ZYLIX_FEATURE_GPU        0
#define ZYLIX_FEATURE_TOUCH      1
#define ZYLIX_FEATURE_METAL      2
#define ZYLIX_FEATURE_VULKAN     3
#define ZYLIX_FEATURE_OPENGL     4
#define ZYLIX_FEATURE_WEBGL      5
#define ZYLIX_FEATURE_HAPTICS    6
#define ZYLIX_FEATURE_CAMERA     7
#define ZYLIX_FEATURE_GPS        8
#define ZYLIX_FEATURE_NFC        9
#define ZYLIX_FEATURE_BLUETOOTH  10
#define ZYLIX_FEATURE_AR         11
#define ZYLIX_FEATURE_BIOMETRICS 12

/* === Support Levels === */

#define ZYLIX_SUPPORT_NONE        0
#define ZYLIX_SUPPORT_EXPERIMENTAL 1
#define ZYLIX_SUPPORT_PARTIAL     2
#define ZYLIX_SUPPORT_FULL        3
#define ZYLIX_SUPPORT_NATIVE      4

/* === Artifact Types === */

#define ZYLIX_ARTIFACT_EXECUTABLE  0
#define ZYLIX_ARTIFACT_LIBRARY     1
#define ZYLIX_ARTIFACT_BUNDLE      2
#define ZYLIX_ARTIFACT_ARCHIVE     3
#define ZYLIX_ARTIFACT_WASM        4
#define ZYLIX_ARTIFACT_SOURCE_MAP  5
#define ZYLIX_ARTIFACT_DEBUG_INFO  6

/* === Template Categories === */

#define ZYLIX_TEMPLATE_CATEGORY_APP       0
#define ZYLIX_TEMPLATE_CATEGORY_LIBRARY   1
#define ZYLIX_TEMPLATE_CATEGORY_COMPONENT 2
#define ZYLIX_TEMPLATE_CATEGORY_PLUGIN    3
#define ZYLIX_TEMPLATE_CATEGORY_EXAMPLE   4

/* === Template Sources === */

#define ZYLIX_TEMPLATE_SOURCE_BUILTIN 0
#define ZYLIX_TEMPLATE_SOURCE_CUSTOM  1
#define ZYLIX_TEMPLATE_SOURCE_REMOTE  2

/* === File Change Types === */

#define ZYLIX_CHANGE_CREATED  0
#define ZYLIX_CHANGE_MODIFIED 1
#define ZYLIX_CHANGE_DELETED  2
#define ZYLIX_CHANGE_RENAMED  3

/* === Input Types === */

#define ZYLIX_INPUT_STRING    0
#define ZYLIX_INPUT_PATH      1
#define ZYLIX_INPUT_BOOLEAN   2
#define ZYLIX_INPUT_INTEGER   3
#define ZYLIX_INPUT_SELECT    4
#define ZYLIX_INPUT_MULTILINE 5

/* ============================================================================
 * STRUCTURES
 * ========================================================================== */

/**
 * Project configuration for creation.
 */
typedef struct {
    const char* name;           /* Project name (required) */
    const char* description;    /* Project description */
    const char* version;        /* Version string (default: "0.1.0") */
    uint8_t     project_type;   /* ZYLIX_PROJECT_TYPE_* */
    const char* template_id;    /* Template ID (can be NULL) */
    const char* author;         /* Author name (can be NULL) */
    const char* license;        /* License identifier (can be NULL) */
    const char* org_id;         /* Organization/bundle ID prefix (can be NULL) */
    bool        init_git;       /* Initialize git repository */
    bool        install_deps;   /* Install dependencies after creation */
} zylix_project_config_t;

/**
 * Project information returned from queries.
 */
typedef struct {
    uint64_t id;                /* Unique project ID */
    char     name[128];         /* Project name */
    char     path[512];         /* Project path */
    int64_t  created_at;        /* Creation timestamp */
    int64_t  modified_at;       /* Last modification timestamp */
} zylix_project_info_t;

/**
 * Build configuration.
 */
typedef struct {
    uint8_t mode;               /* ZYLIX_BUILD_MODE_* */
    uint8_t optimization;       /* ZYLIX_OPT_* */
    bool    sign;               /* Enable code signing */
    bool    parallel;           /* Enable parallel compilation */
    uint8_t max_jobs;           /* Max parallel jobs (0 = auto-detect) */
    bool    incremental;        /* Enable incremental build */
    bool    cache;              /* Enable build cache */
} zylix_build_config_t;

/**
 * Build status information.
 */
typedef struct {
    uint8_t  state;             /* ZYLIX_BUILD_STATE_* */
    float    progress;          /* Progress 0.0 - 1.0 */
    uint32_t files_compiled;    /* Number of files compiled */
    uint32_t files_total;       /* Total files to compile */
    uint32_t errors;            /* Error count */
    uint32_t warnings;          /* Warning count */
    uint64_t elapsed_ms;        /* Elapsed time in milliseconds */
} zylix_build_status_t;

/**
 * Build progress event for callbacks.
 */
typedef struct {
    uint64_t build_id;          /* Build identifier */
    uint8_t  state;             /* ZYLIX_BUILD_STATE_* */
    float    progress;          /* Progress 0.0 - 1.0 */
    int64_t  timestamp;         /* Event timestamp */
} zylix_build_progress_t;

/**
 * Log entry for callbacks.
 */
typedef struct {
    uint64_t build_id;          /* Build identifier */
    uint8_t  level;             /* ZYLIX_LOG_* */
    char     message[512];      /* Log message */
    int64_t  timestamp;         /* Entry timestamp */
} zylix_log_entry_t;

/**
 * Artifact metadata.
 */
typedef struct {
    uint64_t size;              /* File size in bytes */
    char     hash[64];          /* Content hash */
    int64_t  created_at;        /* Creation timestamp */
    int64_t  modified_at;       /* Modification timestamp */
    uint8_t  artifact_type;     /* ZYLIX_ARTIFACT_* */
    uint8_t  target;            /* ZYLIX_TARGET_* */
    uint8_t  build_mode;        /* ZYLIX_BUILD_MODE_* */
    bool     signed_artifact;   /* Whether artifact is code-signed */
} zylix_artifact_metadata_t;

/**
 * Template information.
 */
typedef struct {
    char    id[64];             /* Template identifier */
    char    name[128];          /* Display name */
    char    description[256];   /* Description */
    uint8_t category;           /* ZYLIX_TEMPLATE_CATEGORY_* */
    uint8_t source;             /* ZYLIX_TEMPLATE_SOURCE_* */
    char    version[16];        /* Version string */
} zylix_template_t;

/**
 * Input specification for target-specific configuration.
 */
typedef struct {
    char    name[64];           /* Input field name */
    char    label[64];          /* Display label */
    uint8_t input_type;         /* ZYLIX_INPUT_* */
    bool    required;           /* Whether input is required */
    bool    has_default;        /* Whether default value is set */
    char    default_value[128]; /* Default value if has_default is true */
} zylix_input_spec_t;

/**
 * File change event.
 */
typedef struct {
    uint64_t watch_id;          /* Watch identifier */
    uint8_t  change_type;       /* ZYLIX_CHANGE_* */
    char     path[512];         /* File path */
    bool     is_directory;      /* Whether path is a directory */
    int64_t  timestamp;         /* Event timestamp */
} zylix_file_change_t;

/* ============================================================================
 * CALLBACK TYPES
 * ========================================================================== */

/**
 * Build progress callback function type.
 */
typedef void (*zylix_build_progress_callback_t)(const zylix_build_progress_t* progress);

/**
 * Build log callback function type.
 */
typedef void (*zylix_build_log_callback_t)(const zylix_log_entry_t* entry);

/**
 * File change callback function type.
 */
typedef void (*zylix_file_change_callback_t)(const zylix_file_change_t* change);

/* ============================================================================
 * LIFECYCLE FUNCTIONS
 * ========================================================================== */

/**
 * Initialize Zylix Tooling.
 * Must be called before any other tooling function.
 *
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_tooling_init(void);

/**
 * Shutdown Zylix Tooling.
 * Releases all resources.
 *
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_tooling_deinit(void);

/**
 * Get Tooling ABI version.
 * Can be called before init.
 *
 * @return ABI version number
 */
uint32_t zylix_tooling_get_version(void);

/**
 * Check if tooling is initialized.
 *
 * @return true if initialized
 */
bool zylix_tooling_is_initialized(void);

/* ============================================================================
 * PROJECT SCAFFOLDING API (#46)
 * ========================================================================== */

/**
 * Create a new project.
 *
 * @param template_id   Template identifier (e.g., "app", "library")
 * @param targets_mask  Bitmask of ZYLIX_TARGET_MASK_* values
 * @param output_dir    Output directory path
 * @param config        Project configuration
 * @return Project ID on success, negative error code on failure
 */
int64_t zylix_project_create(
    const char* template_id,
    uint8_t targets_mask,
    const char* output_dir,
    const zylix_project_config_t* config
);

/**
 * Validate an existing project.
 *
 * @param project_id  Project identifier
 * @return ZYLIX_TOOLING_OK if valid, error code otherwise
 */
int32_t zylix_project_validate(uint64_t project_id);

/**
 * Get project information by name.
 *
 * @param name  Project name
 * @return Pointer to project info, NULL if not found
 */
const zylix_project_info_t* zylix_project_get_info(const char* name);

/**
 * Get number of registered projects.
 *
 * @return Project count
 */
uint32_t zylix_project_count(void);

/**
 * Delete a project from the registry.
 *
 * @param name  Project name
 * @return ZYLIX_TOOLING_OK on success, error code otherwise
 */
int32_t zylix_project_delete(const char* name);

/* ============================================================================
 * BUILD ORCHESTRATION API (#47)
 * ========================================================================== */

/**
 * Start a new build.
 *
 * @param project_name  Project name
 * @param target        Target platform (ZYLIX_TARGET_*)
 * @param config        Build configuration
 * @return Build ID on success, negative error code on failure
 */
int64_t zylix_build_start(
    const char* project_name,
    uint8_t target,
    const zylix_build_config_t* config
);

/**
 * Cancel a running build.
 *
 * @param build_id  Build identifier
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_build_cancel(uint64_t build_id);

/**
 * Get build status.
 *
 * @param build_id  Build identifier
 * @return Pointer to build status, NULL if not found
 */
const zylix_build_status_t* zylix_build_get_status(uint64_t build_id);

/**
 * Set build progress callback.
 *
 * @param callback  Progress callback function (NULL to disable)
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_build_set_progress_callback(zylix_build_progress_callback_t callback);

/**
 * Set build log callback.
 *
 * @param callback  Log callback function (NULL to disable)
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_build_set_log_callback(zylix_build_log_callback_t callback);

/**
 * Get number of active builds.
 *
 * @return Active build count
 */
uint32_t zylix_build_active_count(void);

/**
 * Get total number of builds (including completed).
 *
 * @return Total build count
 */
uint32_t zylix_build_total_count(void);

/* ============================================================================
 * BUILD ARTIFACT QUERY API (#48)
 * ========================================================================== */

/**
 * Get artifact count for a build.
 *
 * @param build_id  Build identifier
 * @return Number of artifacts
 */
uint32_t zylix_artifacts_count(uint64_t build_id);

/**
 * Get artifact metadata by path.
 *
 * @param path  Artifact path
 * @return Pointer to metadata, NULL if not found
 */
const zylix_artifact_metadata_t* zylix_artifacts_get_metadata(const char* path);

/**
 * Export artifact to destination.
 *
 * @param path      Source artifact path
 * @param dest      Destination path
 * @param compress  Whether to compress the artifact
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_artifacts_export(
    const char* path,
    const char* dest,
    bool compress
);

/**
 * Verify artifact integrity.
 *
 * @param path  Artifact path
 * @param hash  Expected hash
 * @return true if hash matches
 */
bool zylix_artifacts_verify(const char* path, const char* hash);

/* ============================================================================
 * TARGET CAPABILITY MATRIX API (#51)
 * ========================================================================== */

/**
 * Check if a target supports a feature.
 *
 * @param target   Target platform (ZYLIX_TARGET_*)
 * @param feature  Feature ID (ZYLIX_FEATURE_*)
 * @return true if feature is supported
 */
bool zylix_targets_supports_feature(uint8_t target, uint8_t feature);

/**
 * Get feature support level for a target.
 *
 * @param target   Target platform (ZYLIX_TARGET_*)
 * @param feature  Feature ID (ZYLIX_FEATURE_*)
 * @return Support level (ZYLIX_SUPPORT_*)
 */
uint8_t zylix_targets_get_support_level(uint8_t target, uint8_t feature);

/**
 * Get required input specifications for a target.
 *
 * @param target  Target platform (ZYLIX_TARGET_*)
 * @param count   Pointer to receive the count of specs
 * @return Pointer to array of input specs, NULL if none
 */
const zylix_input_spec_t* zylix_targets_get_input_specs(uint8_t target, uint32_t* count);

/**
 * Get number of supported targets.
 *
 * @return Target count (7)
 */
uint32_t zylix_targets_count(void);

/**
 * Check if two targets are compatible for shared code.
 *
 * @param target1  First target (ZYLIX_TARGET_*)
 * @param target2  Second target (ZYLIX_TARGET_*)
 * @return true if targets are compatible
 */
bool zylix_targets_are_compatible(uint8_t target1, uint8_t target2);

/* ============================================================================
 * TEMPLATE CATALOG API (#52)
 * ========================================================================== */

/**
 * Get number of available templates.
 *
 * @return Template count
 */
uint32_t zylix_templates_count(void);

/**
 * Get template by index.
 *
 * @param index  Template index (0-based)
 * @return Pointer to template, NULL if index out of range
 */
const zylix_template_t* zylix_templates_get(uint32_t index);

/**
 * Get template by ID.
 *
 * @param id  Template identifier
 * @return Pointer to template, NULL if not found
 */
const zylix_template_t* zylix_templates_get_by_id(const char* id);

/**
 * Check if a template exists.
 *
 * @param id  Template identifier
 * @return true if template exists
 */
bool zylix_templates_exists(const char* id);

/* ============================================================================
 * FILE WATCHER API (#53)
 * ========================================================================== */

/**
 * Start watching a path for changes.
 *
 * @param path       Path to watch
 * @param recursive  Whether to watch subdirectories
 * @return Watch ID on success, 0 on failure
 */
uint64_t zylix_fs_watch(const char* path, bool recursive);

/**
 * Stop watching a path.
 *
 * @param watch_id  Watch identifier
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_fs_unwatch(uint64_t watch_id);

/**
 * Set file change callback.
 *
 * @param callback  Change callback function (NULL to disable)
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_fs_set_callback(zylix_file_change_callback_t callback);

/**
 * Pause watching a path.
 *
 * @param watch_id  Watch identifier
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_fs_pause(uint64_t watch_id);

/**
 * Resume watching a path.
 *
 * @param watch_id  Watch identifier
 * @return ZYLIX_TOOLING_OK on success
 */
int32_t zylix_fs_resume(uint64_t watch_id);

/**
 * Get number of active watches.
 *
 * @return Active watch count
 */
uint32_t zylix_fs_active_count(void);

/**
 * Get total number of watches.
 *
 * @return Total watch count
 */
uint32_t zylix_fs_total_count(void);

/**
 * Check if a path is being watched.
 *
 * @param path  Path to check
 * @return true if path is being watched
 */
bool zylix_fs_is_watching(const char* path);

/**
 * Stop all active watches.
 */
void zylix_fs_stop_all(void);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_TOOLING_H */
