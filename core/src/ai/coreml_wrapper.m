/**
 * Zylix AI - Core ML Wrapper Implementation
 *
 * Objective-C implementation for Core ML operations.
 * Provides C API for Zig interoperability.
 */

#import <Foundation/Foundation.h>

// Core ML is only available on Apple platforms
#if defined(__APPLE__)

#import <CoreML/CoreML.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

#include "coreml_wrapper.h"

// === Internal Model Context ===

@interface ZylixCoreMLModel : NSObject
@property (nonatomic, strong) MLModel *model;
@property (nonatomic, strong) NSURL *modelURL;
@property (nonatomic, assign) CoreMLConfig config;
@property (nonatomic, assign) double lastInferenceTime;
@property (nonatomic, assign) BOOL isReady;
@end

@implementation ZylixCoreMLModel
@end

// === Initialization ===

bool coreml_is_available(void) {
    // Core ML is available on iOS 11+, macOS 10.13+, tvOS 11+, watchOS 4+
#if defined(__APPLE__)
    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        return true;
    }
#endif
    return false;
}

const char* coreml_version(void) {
    static char version[32] = "Unknown";

#if defined(__APPLE__)
    if (@available(macOS 10.15, iOS 13.0, *)) {
        // Core ML 3.0+
        snprintf(version, sizeof(version), "CoreML 3.0+");
    } else if (@available(macOS 10.14, iOS 12.0, *)) {
        // Core ML 2.0
        snprintf(version, sizeof(version), "CoreML 2.0");
    } else if (@available(macOS 10.13, iOS 11.0, *)) {
        // Core ML 1.0
        snprintf(version, sizeof(version), "CoreML 1.0");
    }
#endif

    return version;
}

bool coreml_has_neural_engine(void) {
#if defined(__APPLE__)
    // Neural Engine is available on A11+ (iPhone 8+) and M1+
    if (@available(macOS 11.0, iOS 11.0, *)) {
        // Check for Apple Silicon on Mac
#if TARGET_OS_OSX
        // On macOS 11+, we can assume M1+ has Neural Engine
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        // ARM64 Mac = Apple Silicon = Neural Engine
        #if defined(__arm64__)
            return true;
        #else
            return false;
        #endif
#else
        // iOS devices: A11+ have Neural Engine
        // We can't easily detect the chip, so return true for modern iOS
        return true;
#endif
    }
#endif
    return false;
}

CoreMLConfig coreml_default_config(void) {
    CoreMLConfig config = {
        .compute_units = COREML_COMPUTE_ALL,
        .allow_low_precision = true,
        .use_cpu_fallback = true,
        .max_batch_size = 1,
        .optimize_for_neural_engine = coreml_has_neural_engine()
    };
    return config;
}

// === Model Loading ===

static MLComputeUnits convertComputeUnits(CoreMLComputeUnits units) {
    switch (units) {
        case COREML_COMPUTE_CPU_ONLY:
            return MLComputeUnitsCPUOnly;
        case COREML_COMPUTE_CPU_AND_GPU:
            if (@available(macOS 10.14, iOS 12.0, *)) {
                return MLComputeUnitsCPUAndGPU;
            }
            return MLComputeUnitsCPUOnly;
        case COREML_COMPUTE_CPU_AND_NE:
            if (@available(macOS 12.0, iOS 15.0, *)) {
                return MLComputeUnitsCPUAndNeuralEngine;
            }
            return MLComputeUnitsAll;
        case COREML_COMPUTE_ALL:
        default:
            return MLComputeUnitsAll;
    }
}

CoreMLModelHandle coreml_load_model(const char* path, CoreMLConfig config, CoreMLResult* result) {
    if (!coreml_is_available()) {
        if (result) *result = COREML_ERROR_NOT_AVAILABLE;
        return NULL;
    }

    if (!path) {
        if (result) *result = COREML_ERROR_INVALID_ARG;
        return NULL;
    }

    @autoreleasepool {
        NSString *modelPath = [NSString stringWithUTF8String:path];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];

        if (![[NSFileManager defaultManager] fileExistsAtPath:modelPath]) {
            if (result) *result = COREML_ERROR_MODEL_NOT_FOUND;
            return NULL;
        }

        // Check if it's a compiled model or needs compilation
        NSString *extension = [modelPath pathExtension];
        BOOL isCompiled = [extension isEqualToString:@"mlmodelc"] ||
                          [extension isEqualToString:@"mlpackage"];

        if (!isCompiled && [extension isEqualToString:@"mlmodel"]) {
            // Need to compile first
            return coreml_compile_and_load(path, config, result);
        }

        return coreml_load_compiled_model(path, config, result);
    }
}

CoreMLModelHandle coreml_load_compiled_model(const char* path, CoreMLConfig config, CoreMLResult* result) {
    if (!coreml_is_available()) {
        if (result) *result = COREML_ERROR_NOT_AVAILABLE;
        return NULL;
    }

    @autoreleasepool {
        NSString *modelPath = [NSString stringWithUTF8String:path];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];

        NSError *error = nil;
        MLModel *model = nil;

        if (@available(macOS 10.14, iOS 12.0, *)) {
            MLModelConfiguration *mlConfig = [[MLModelConfiguration alloc] init];
            mlConfig.computeUnits = convertComputeUnits(config.compute_units);

            if (@available(macOS 12.0, iOS 15.0, *)) {
                mlConfig.allowLowPrecisionAccumulationOnGPU = config.allow_low_precision;
            }

            model = [MLModel modelWithContentsOfURL:modelURL configuration:mlConfig error:&error];
        } else {
            model = [MLModel modelWithContentsOfURL:modelURL error:&error];
        }

        if (error || !model) {
            NSLog(@"Failed to load Core ML model: %@", error.localizedDescription);
            if (result) *result = COREML_ERROR_MODEL_LOAD;
            return NULL;
        }

        ZylixCoreMLModel *wrapper = [[ZylixCoreMLModel alloc] init];
        wrapper.model = model;
        wrapper.modelURL = modelURL;
        wrapper.config = config;
        wrapper.isReady = YES;
        wrapper.lastInferenceTime = 0;

        if (result) *result = COREML_SUCCESS;
        return (__bridge_retained void*)wrapper;
    }
}

CoreMLModelHandle coreml_compile_and_load(const char* path, CoreMLConfig config, CoreMLResult* result) {
    if (!coreml_is_available()) {
        if (result) *result = COREML_ERROR_NOT_AVAILABLE;
        return NULL;
    }

    @autoreleasepool {
        NSString *modelPath = [NSString stringWithUTF8String:path];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];

        NSError *error = nil;

        // Compile the model
        NSURL *compiledURL = [MLModel compileModelAtURL:modelURL error:&error];

        if (error || !compiledURL) {
            NSLog(@"Failed to compile Core ML model: %@", error.localizedDescription);
            if (result) *result = COREML_ERROR_MODEL_COMPILE;
            return NULL;
        }

        // Load the compiled model
        MLModel *model = nil;

        if (@available(macOS 10.14, iOS 12.0, *)) {
            MLModelConfiguration *mlConfig = [[MLModelConfiguration alloc] init];
            mlConfig.computeUnits = convertComputeUnits(config.compute_units);

            model = [MLModel modelWithContentsOfURL:compiledURL configuration:mlConfig error:&error];
        } else {
            model = [MLModel modelWithContentsOfURL:compiledURL error:&error];
        }

        if (error || !model) {
            NSLog(@"Failed to load compiled Core ML model: %@", error.localizedDescription);
            if (result) *result = COREML_ERROR_MODEL_LOAD;
            return NULL;
        }

        ZylixCoreMLModel *wrapper = [[ZylixCoreMLModel alloc] init];
        wrapper.model = model;
        wrapper.modelURL = compiledURL;
        wrapper.config = config;
        wrapper.isReady = YES;
        wrapper.lastInferenceTime = 0;

        if (result) *result = COREML_SUCCESS;
        return (__bridge_retained void*)wrapper;
    }
}

void coreml_free_model(CoreMLModelHandle model) {
    if (model) {
        ZylixCoreMLModel *wrapper = (__bridge_transfer ZylixCoreMLModel*)model;
        wrapper.model = nil;
        wrapper.isReady = NO;
        // ARC will clean up
    }
}

// === Model Information ===

CoreMLResult coreml_get_model_info(CoreMLModelHandle model, CoreMLModelInfo* info) {
    if (!model || !info) {
        return COREML_ERROR_INVALID_ARG;
    }

    @autoreleasepool {
        ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
        MLModel *mlModel = wrapper.model;

        if (!mlModel) {
            return COREML_ERROR_MODEL_LOAD;
        }

        memset(info, 0, sizeof(CoreMLModelInfo));

        MLModelDescription *desc = mlModel.modelDescription;

        // Model metadata
        NSDictionary *metadata = desc.metadata;

        NSString *name = metadata[MLModelDescriptionKey] ?: @"Unknown";
        strncpy(info->name, [name UTF8String], sizeof(info->name) - 1);

        NSString *author = metadata[MLModelAuthorKey] ?: @"Unknown";
        strncpy(info->author, [author UTF8String], sizeof(info->author) - 1);

        NSString *version = metadata[MLModelVersionStringKey] ?: @"1.0";
        strncpy(info->version, [version UTF8String], sizeof(info->version) - 1);

        // Input/output counts
        info->input_count = (uint32_t)desc.inputDescriptionsByName.count;
        info->output_count = (uint32_t)desc.outputDescriptionsByName.count;

        info->is_compiled = YES; // If we loaded it, it's compiled

        // Get file size
        NSError *error = nil;
        NSDictionary *attrs = [[NSFileManager defaultManager]
                               attributesOfItemAtPath:[wrapper.modelURL path]
                               error:&error];
        if (attrs) {
            info->model_size = [attrs fileSize];
        }

        return COREML_SUCCESS;
    }
}

bool coreml_is_model_ready(CoreMLModelHandle model) {
    if (!model) return false;

    ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
    return wrapper.isReady;
}

// === Inference ===

CoreMLResult coreml_predict_float(
    CoreMLModelHandle model,
    const float* input,
    size_t input_size,
    float* output,
    size_t output_size
) {
    if (!model || !input || !output) {
        return COREML_ERROR_INVALID_ARG;
    }

    @autoreleasepool {
        ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
        MLModel *mlModel = wrapper.model;

        if (!mlModel || !wrapper.isReady) {
            return COREML_ERROR_MODEL_LOAD;
        }

        NSDate *startTime = [NSDate date];

        // Get input description
        MLModelDescription *desc = mlModel.modelDescription;
        NSString *inputName = desc.inputDescriptionsByName.allKeys.firstObject;

        if (!inputName) {
            return COREML_ERROR_INVALID_ARG;
        }

        // Create input multi-array
        NSError *error = nil;
        MLMultiArray *inputArray = [[MLMultiArray alloc]
                                    initWithShape:@[@(input_size)]
                                    dataType:MLMultiArrayDataTypeFloat32
                                    error:&error];

        if (error) {
            NSLog(@"Failed to create input array: %@", error.localizedDescription);
            return COREML_ERROR_MEMORY;
        }

        // Copy input data
        float *arrayPtr = (float*)inputArray.dataPointer;
        memcpy(arrayPtr, input, input_size * sizeof(float));

        // Create feature provider
        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc]
             initWithDictionary:@{inputName: inputArray}
             error:&error];

        if (error) {
            NSLog(@"Failed to create feature provider: %@", error.localizedDescription);
            return COREML_ERROR_INFERENCE;
        }

        // Run prediction
        id<MLFeatureProvider> prediction = [mlModel predictionFromFeatures:provider error:&error];

        if (error) {
            NSLog(@"Prediction failed: %@", error.localizedDescription);
            return COREML_ERROR_INFERENCE;
        }

        // Get output
        NSString *outputName = desc.outputDescriptionsByName.allKeys.firstObject;
        MLFeatureValue *outputValue = [prediction featureValueForName:outputName];

        if (!outputValue || outputValue.type != MLFeatureTypeMultiArray) {
            return COREML_ERROR_INFERENCE;
        }

        MLMultiArray *outputArray = outputValue.multiArrayValue;
        size_t copySize = MIN(output_size, (size_t)outputArray.count);

        float *outputPtr = (float*)outputArray.dataPointer;
        memcpy(output, outputPtr, copySize * sizeof(float));

        // Record timing
        wrapper.lastInferenceTime = -[startTime timeIntervalSinceNow] * 1000.0;

        return COREML_SUCCESS;
    }
}

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
) {
    if (!model || !input_names || !inputs || !input_sizes ||
        !output_names || !outputs || !output_sizes) {
        return COREML_ERROR_INVALID_ARG;
    }

    @autoreleasepool {
        ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
        MLModel *mlModel = wrapper.model;

        if (!mlModel || !wrapper.isReady) {
            return COREML_ERROR_MODEL_LOAD;
        }

        NSDate *startTime = [NSDate date];
        NSError *error = nil;

        // Create input dictionary
        NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];

        for (size_t i = 0; i < input_count; i++) {
            NSString *name = [NSString stringWithUTF8String:input_names[i]];

            MLMultiArray *array = [[MLMultiArray alloc]
                                   initWithShape:@[@(input_sizes[i])]
                                   dataType:MLMultiArrayDataTypeFloat32
                                   error:&error];

            if (error) {
                return COREML_ERROR_MEMORY;
            }

            float *ptr = (float*)array.dataPointer;
            memcpy(ptr, inputs[i], input_sizes[i] * sizeof(float));

            inputDict[name] = array;
        }

        // Create feature provider
        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&error];

        if (error) {
            return COREML_ERROR_INFERENCE;
        }

        // Run prediction
        id<MLFeatureProvider> prediction = [mlModel predictionFromFeatures:provider error:&error];

        if (error) {
            return COREML_ERROR_INFERENCE;
        }

        // Get outputs
        for (size_t i = 0; i < output_count; i++) {
            NSString *name = [NSString stringWithUTF8String:output_names[i]];
            MLFeatureValue *value = [prediction featureValueForName:name];

            if (!value || value.type != MLFeatureTypeMultiArray) {
                continue;
            }

            MLMultiArray *array = value.multiArrayValue;
            size_t copySize = MIN(output_sizes[i], (size_t)array.count);

            float *ptr = (float*)array.dataPointer;
            memcpy(outputs[i], ptr, copySize * sizeof(float));
        }

        wrapper.lastInferenceTime = -[startTime timeIntervalSinceNow] * 1000.0;

        return COREML_SUCCESS;
    }
}

CoreMLResult coreml_generate_embeddings(
    CoreMLModelHandle model,
    const int32_t* tokens,
    size_t token_count,
    float* embeddings,
    size_t embedding_dim
) {
    if (!model || !tokens || !embeddings) {
        return COREML_ERROR_INVALID_ARG;
    }

    // For embedding models, we need to convert tokens to float input
    // This is a simplified implementation - real embedding models may need different handling

    @autoreleasepool {
        // Convert tokens to float array
        float *float_tokens = (float*)malloc(token_count * sizeof(float));
        if (!float_tokens) {
            return COREML_ERROR_MEMORY;
        }

        for (size_t i = 0; i < token_count; i++) {
            float_tokens[i] = (float)tokens[i];
        }

        CoreMLResult result = coreml_predict_float(model, float_tokens, token_count,
                                                    embeddings, embedding_dim);

        free(float_tokens);
        return result;
    }
}

// === Performance ===

CoreMLResult coreml_warmup(CoreMLModelHandle model) {
    if (!model) {
        return COREML_ERROR_INVALID_ARG;
    }

    @autoreleasepool {
        ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
        MLModel *mlModel = wrapper.model;

        if (!mlModel) {
            return COREML_ERROR_MODEL_LOAD;
        }

        // Get input description
        MLModelDescription *desc = mlModel.modelDescription;
        MLFeatureDescription *inputDesc = desc.inputDescriptionsByName.allValues.firstObject;

        if (!inputDesc || inputDesc.type != MLFeatureTypeMultiArray) {
            // Can't warmup without knowing input shape
            return COREML_SUCCESS;
        }

        // Create dummy input
        NSError *error = nil;
        MLMultiArray *dummyInput = [[MLMultiArray alloc]
                                    initWithShape:inputDesc.multiArrayConstraint.shape
                                    dataType:MLMultiArrayDataTypeFloat32
                                    error:&error];

        if (error) {
            return COREML_SUCCESS; // Warmup is optional
        }

        // Zero out the array
        memset(dummyInput.dataPointer, 0, dummyInput.count * sizeof(float));

        // Create feature provider
        NSString *inputName = desc.inputDescriptionsByName.allKeys.firstObject;
        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc]
             initWithDictionary:@{inputName: dummyInput}
             error:&error];

        if (error) {
            return COREML_SUCCESS;
        }

        // Run dummy prediction
        [mlModel predictionFromFeatures:provider error:&error];

        return COREML_SUCCESS;
    }
}

double coreml_get_last_inference_time(CoreMLModelHandle model) {
    if (!model) return 0.0;

    ZylixCoreMLModel *wrapper = (__bridge ZylixCoreMLModel*)model;
    return wrapper.lastInferenceTime;
}

// === Utility ===

const char* coreml_error_string(CoreMLResult result) {
    switch (result) {
        case COREML_SUCCESS: return "Success";
        case COREML_ERROR_INVALID_ARG: return "Invalid argument";
        case COREML_ERROR_MODEL_NOT_FOUND: return "Model file not found";
        case COREML_ERROR_MODEL_COMPILE: return "Failed to compile model";
        case COREML_ERROR_MODEL_LOAD: return "Failed to load model";
        case COREML_ERROR_INFERENCE: return "Inference failed";
        case COREML_ERROR_MEMORY: return "Memory allocation failed";
        case COREML_ERROR_NOT_AVAILABLE: return "Core ML not available";
        case COREML_ERROR_UNSUPPORTED: return "Unsupported operation";
        default: return "Unknown error";
    }
}

void coreml_clear_cache(void) {
    @autoreleasepool {
        // Clear compiled model cache
        NSURL *cacheURL = [[NSFileManager defaultManager]
                           URLForDirectory:NSCachesDirectory
                           inDomain:NSUserDomainMask
                           appropriateForURL:nil
                           create:NO
                           error:nil];

        if (cacheURL) {
            NSURL *mlCacheURL = [cacheURL URLByAppendingPathComponent:@"com.apple.CoreML"];
            [[NSFileManager defaultManager] removeItemAtURL:mlCacheURL error:nil];
        }
    }
}

#else // Not Apple platform

// Stub implementations for non-Apple platforms

bool coreml_is_available(void) { return false; }
const char* coreml_version(void) { return "Not available"; }
bool coreml_has_neural_engine(void) { return false; }

CoreMLConfig coreml_default_config(void) {
    CoreMLConfig config = {0};
    return config;
}

CoreMLModelHandle coreml_load_model(const char* path, CoreMLConfig config, CoreMLResult* result) {
    (void)path; (void)config;
    if (result) *result = COREML_ERROR_NOT_AVAILABLE;
    return NULL;
}

CoreMLModelHandle coreml_load_compiled_model(const char* path, CoreMLConfig config, CoreMLResult* result) {
    (void)path; (void)config;
    if (result) *result = COREML_ERROR_NOT_AVAILABLE;
    return NULL;
}

CoreMLModelHandle coreml_compile_and_load(const char* path, CoreMLConfig config, CoreMLResult* result) {
    (void)path; (void)config;
    if (result) *result = COREML_ERROR_NOT_AVAILABLE;
    return NULL;
}

void coreml_free_model(CoreMLModelHandle model) { (void)model; }

CoreMLResult coreml_get_model_info(CoreMLModelHandle model, CoreMLModelInfo* info) {
    (void)model; (void)info;
    return COREML_ERROR_NOT_AVAILABLE;
}

bool coreml_is_model_ready(CoreMLModelHandle model) {
    (void)model;
    return false;
}

CoreMLResult coreml_predict_float(CoreMLModelHandle model, const float* input, size_t input_size,
                                   float* output, size_t output_size) {
    (void)model; (void)input; (void)input_size; (void)output; (void)output_size;
    return COREML_ERROR_NOT_AVAILABLE;
}

CoreMLResult coreml_predict_multi(CoreMLModelHandle model, const char** input_names,
                                   const float** inputs, const size_t* input_sizes, size_t input_count,
                                   const char** output_names, float** outputs,
                                   const size_t* output_sizes, size_t output_count) {
    (void)model; (void)input_names; (void)inputs; (void)input_sizes; (void)input_count;
    (void)output_names; (void)outputs; (void)output_sizes; (void)output_count;
    return COREML_ERROR_NOT_AVAILABLE;
}

CoreMLResult coreml_generate_embeddings(CoreMLModelHandle model, const int32_t* tokens,
                                         size_t token_count, float* embeddings, size_t embedding_dim) {
    (void)model; (void)tokens; (void)token_count; (void)embeddings; (void)embedding_dim;
    return COREML_ERROR_NOT_AVAILABLE;
}

CoreMLResult coreml_warmup(CoreMLModelHandle model) {
    (void)model;
    return COREML_ERROR_NOT_AVAILABLE;
}

double coreml_get_last_inference_time(CoreMLModelHandle model) {
    (void)model;
    return 0.0;
}

const char* coreml_error_string(CoreMLResult result) {
    (void)result;
    return "Core ML not available on this platform";
}

void coreml_clear_cache(void) {}

#endif // __APPLE__
