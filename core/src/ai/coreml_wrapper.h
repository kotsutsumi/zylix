/**
 * Zylix AI - Core ML C Wrapper
 *
 * C interface for Core ML operations on Apple platforms.
 * This wrapper allows Zig code to interact with Core ML through a C API.
 */

#ifndef ZYLIX_COREML_WRAPPER_H
#define ZYLIX_COREML_WRAPPER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// === Result Codes ===

typedef enum {
    COREML_SUCCESS = 0,
    COREML_ERROR_INVALID_ARG = 1,
    COREML_ERROR_MODEL_NOT_FOUND = 2,
    COREML_ERROR_MODEL_COMPILE = 3,
    COREML_ERROR_MODEL_LOAD = 4,
    COREML_ERROR_INFERENCE = 5,
    COREML_ERROR_MEMORY = 6,
    COREML_ERROR_NOT_AVAILABLE = 7,
    COREML_ERROR_UNSUPPORTED = 8,
    COREML_ERROR_UNKNOWN = -1
} CoreMLResult;

// === Compute Unit Options ===

typedef enum {
    COREML_COMPUTE_ALL = 0,          // Use all available compute units
    COREML_COMPUTE_CPU_ONLY = 1,     // CPU only
    COREML_COMPUTE_CPU_AND_GPU = 2,  // CPU and GPU
    COREML_COMPUTE_CPU_AND_NE = 3    // CPU and Neural Engine
} CoreMLComputeUnits;

// === Model Information ===

typedef struct {
    char name[256];
    char description[512];
    char author[128];
    char version[32];
    uint32_t input_count;
    uint32_t output_count;
    bool is_compiled;
    uint64_t model_size;
} CoreMLModelInfo;

// === Configuration ===

typedef struct {
    CoreMLComputeUnits compute_units;
    bool allow_low_precision;
    bool use_cpu_fallback;
    uint32_t max_batch_size;
    bool optimize_for_neural_engine;
} CoreMLConfig;

// === Opaque Types ===

typedef void* CoreMLModelHandle;

// === Initialization ===

/**
 * Check if Core ML is available on this platform
 */
bool coreml_is_available(void);

/**
 * Get Core ML version string
 */
const char* coreml_version(void);

/**
 * Check if Neural Engine is available
 */
bool coreml_has_neural_engine(void);

/**
 * Get default configuration
 */
CoreMLConfig coreml_default_config(void);

// === Model Loading ===

/**
 * Load a Core ML model from path (.mlmodel or .mlmodelc)
 * Returns model handle on success, NULL on failure
 */
CoreMLModelHandle coreml_load_model(const char* path, CoreMLConfig config, CoreMLResult* result);

/**
 * Load a compiled Core ML model from path (.mlmodelc)
 */
CoreMLModelHandle coreml_load_compiled_model(const char* path, CoreMLConfig config, CoreMLResult* result);

/**
 * Compile and load a .mlmodel file
 * Creates a temporary .mlmodelc in the cache directory
 */
CoreMLModelHandle coreml_compile_and_load(const char* path, CoreMLConfig config, CoreMLResult* result);

/**
 * Free a loaded model
 */
void coreml_free_model(CoreMLModelHandle model);

// === Model Information ===

/**
 * Get model information
 */
CoreMLResult coreml_get_model_info(CoreMLModelHandle model, CoreMLModelInfo* info);

/**
 * Check if model is ready for inference
 */
bool coreml_is_model_ready(CoreMLModelHandle model);

// === Inference ===

/**
 * Run inference with float array input
 * Input shape: [batch_size, input_dim]
 * Output shape: [batch_size, output_dim]
 */
CoreMLResult coreml_predict_float(
    CoreMLModelHandle model,
    const float* input,
    size_t input_size,
    float* output,
    size_t output_size
);

/**
 * Run inference with multi-array input (generic)
 * For models with multiple inputs/outputs
 */
CoreMLResult coreml_predict_multi(
    CoreMLModelHandle model,
    const char** input_names,
    const float** inputs,
    const size_t* input_sizes,
    size_t input_count,
    const char** output_names,
    float** outputs,
    const size_t* output_sizes,
    size_t output_count
);

// === Embedding Models ===

/**
 * Generate embeddings from text tokens
 * tokens: array of token IDs
 * embeddings: output array [embedding_dim]
 */
CoreMLResult coreml_generate_embeddings(
    CoreMLModelHandle model,
    const int32_t* tokens,
    size_t token_count,
    float* embeddings,
    size_t embedding_dim
);

// === Performance ===

/**
 * Warm up the model (run dummy inference)
 */
CoreMLResult coreml_warmup(CoreMLModelHandle model);

/**
 * Get last inference time in milliseconds
 */
double coreml_get_last_inference_time(CoreMLModelHandle model);

// === Utility ===

/**
 * Get human-readable error message
 */
const char* coreml_error_string(CoreMLResult result);

/**
 * Clear any cached models
 */
void coreml_clear_cache(void);

#ifdef __cplusplus
}
#endif

#endif // ZYLIX_COREML_WRAPPER_H
