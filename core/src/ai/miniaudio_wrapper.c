// miniaudio_wrapper.c
// Simple C wrapper for miniaudio decoder functionality
// This is needed because Zig's @cImport cannot handle miniaudio's complex implementation

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_DEVICE_IO      // We only need decoding, not playback
#define MA_NO_THREADING      // Single-threaded decoding
#define MA_NO_GENERATION     // No waveform generation needed
#include "miniaudio.h"

// Result code
typedef int ma_wrapper_result;

#define MA_WRAPPER_SUCCESS 0
#define MA_WRAPPER_ERROR -1
#define MA_WRAPPER_FILE_NOT_FOUND -2
#define MA_WRAPPER_INVALID_FILE -3
#define MA_WRAPPER_OUT_OF_MEMORY -4

// Opaque decoder context
typedef struct {
    ma_decoder decoder;
    ma_bool32 initialized;
} ma_wrapper_decoder;

// Create decoder context
ma_wrapper_decoder* ma_wrapper_create_decoder(void) {
    ma_wrapper_decoder* ctx = (ma_wrapper_decoder*)malloc(sizeof(ma_wrapper_decoder));
    if (ctx) {
        ctx->initialized = MA_FALSE;
    }
    return ctx;
}

// Free decoder context
void ma_wrapper_free_decoder(ma_wrapper_decoder* ctx) {
    if (ctx) {
        if (ctx->initialized) {
            ma_decoder_uninit(&ctx->decoder);
        }
        free(ctx);
    }
}

// Initialize decoder from file
// Outputs mono f32 samples at specified sample rate (0 = native)
ma_wrapper_result ma_wrapper_init_file(
    ma_wrapper_decoder* ctx,
    const char* filePath,
    unsigned int targetSampleRate
) {
    if (!ctx) return MA_WRAPPER_ERROR;

    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 1, targetSampleRate);
    ma_result result = ma_decoder_init_file(filePath, &config, &ctx->decoder);

    if (result != MA_SUCCESS) {
        switch (result) {
            case MA_DOES_NOT_EXIST:
                return MA_WRAPPER_FILE_NOT_FOUND;
            case MA_INVALID_FILE:
            case MA_INVALID_DATA:
                return MA_WRAPPER_INVALID_FILE;
            case MA_OUT_OF_MEMORY:
                return MA_WRAPPER_OUT_OF_MEMORY;
            default:
                return MA_WRAPPER_ERROR;
        }
    }

    ctx->initialized = MA_TRUE;
    return MA_WRAPPER_SUCCESS;
}

// Initialize decoder from memory
ma_wrapper_result ma_wrapper_init_memory(
    ma_wrapper_decoder* ctx,
    const void* data,
    size_t dataSize,
    unsigned int targetSampleRate
) {
    if (!ctx) return MA_WRAPPER_ERROR;

    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 1, targetSampleRate);
    ma_result result = ma_decoder_init_memory(data, dataSize, &config, &ctx->decoder);

    if (result != MA_SUCCESS) {
        return MA_WRAPPER_ERROR;
    }

    ctx->initialized = MA_TRUE;
    return MA_WRAPPER_SUCCESS;
}

// Get sample rate
unsigned int ma_wrapper_get_sample_rate(ma_wrapper_decoder* ctx) {
    if (!ctx || !ctx->initialized) return 0;

    ma_uint32 sampleRate = 0;
    ma_decoder_get_data_format(&ctx->decoder, NULL, NULL, &sampleRate, NULL, 0);
    return sampleRate;
}

// Get length in PCM frames
unsigned long long ma_wrapper_get_length(ma_wrapper_decoder* ctx) {
    if (!ctx || !ctx->initialized) return 0;

    ma_uint64 length = 0;
    ma_decoder_get_length_in_pcm_frames(&ctx->decoder, &length);
    return length;
}

// Read PCM frames (f32 samples)
// Returns number of frames actually read
unsigned long long ma_wrapper_read_frames(
    ma_wrapper_decoder* ctx,
    float* output,
    unsigned long long frameCount
) {
    if (!ctx || !ctx->initialized) return 0;

    ma_uint64 framesRead = 0;
    ma_decoder_read_pcm_frames(&ctx->decoder, output, frameCount, &framesRead);
    return framesRead;
}

// Seek to frame
ma_wrapper_result ma_wrapper_seek(ma_wrapper_decoder* ctx, unsigned long long frameIndex) {
    if (!ctx || !ctx->initialized) return MA_WRAPPER_ERROR;

    ma_result result = ma_decoder_seek_to_pcm_frame(&ctx->decoder, frameIndex);
    return result == MA_SUCCESS ? MA_WRAPPER_SUCCESS : MA_WRAPPER_ERROR;
}
