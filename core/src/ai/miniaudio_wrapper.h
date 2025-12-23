// miniaudio_wrapper.h
// Simple C wrapper for miniaudio decoder functionality

#ifndef MINIAUDIO_WRAPPER_H
#define MINIAUDIO_WRAPPER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Result codes
#define MA_WRAPPER_SUCCESS 0
#define MA_WRAPPER_ERROR -1
#define MA_WRAPPER_FILE_NOT_FOUND -2
#define MA_WRAPPER_INVALID_FILE -3
#define MA_WRAPPER_OUT_OF_MEMORY -4

// Opaque decoder context
typedef struct ma_wrapper_decoder ma_wrapper_decoder;

// Create decoder context
ma_wrapper_decoder* ma_wrapper_create_decoder(void);

// Free decoder context
void ma_wrapper_free_decoder(ma_wrapper_decoder* ctx);

// Initialize decoder from file
// Outputs mono f32 samples at specified sample rate (0 = native)
int ma_wrapper_init_file(
    ma_wrapper_decoder* ctx,
    const char* filePath,
    unsigned int targetSampleRate
);

// Initialize decoder from memory
int ma_wrapper_init_memory(
    ma_wrapper_decoder* ctx,
    const void* data,
    size_t dataSize,
    unsigned int targetSampleRate
);

// Get output sample rate
unsigned int ma_wrapper_get_sample_rate(ma_wrapper_decoder* ctx);

// Get length in PCM frames
unsigned long long ma_wrapper_get_length(ma_wrapper_decoder* ctx);

// Read PCM frames (f32 samples)
// Returns number of frames actually read
unsigned long long ma_wrapper_read_frames(
    ma_wrapper_decoder* ctx,
    float* output,
    unsigned long long frameCount
);

// Seek to frame
int ma_wrapper_seek(ma_wrapper_decoder* ctx, unsigned long long frameIndex);

#ifdef __cplusplus
}
#endif

#endif // MINIAUDIO_WRAPPER_H
