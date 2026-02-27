__global__ void vectorAdd(const float* a, const float* b, float* c) {
    int idx = threadIdx.x;
    c[idx] = a[idx] + b[idx];
}

__global__ void vectorSub(const float* a, const float* b, float* c) {
    int idx = threadIdx.x;
    c[idx] = a[idx] - b[idx];
}

__global__ void vectorMul(const float* a, const float* b, float* c) {
    int idx = threadIdx.x;
    c[idx] = a[idx] * b[idx];
}

// BFloat16 Vector Multiply:
#include <cuda_bf16.h>
__global__ void bf16_vector_mul(const __nv_bfloat16* a, const __nv_bfloat16* b, __nv_bfloat16* c) {
    int idx = threadIdx.x;
    c[idx] = __hmul(a[idx], b[idx]);
}

// BFloat16 Fused Multiply-Accumulate:
__global__ void bf16_fma(const __nv_bfloat16* a, const __nv_bfloat16* b, const __nv_bfloat16* c, __nv_bfloat16* result) {
    int idx = threadIdx.x;
    result[idx] = __hfma(a[idx], b[idx], c[idx]);
}

// ReLU Activation Function:
__global__ void relu(const __nv_bfloat16* input, __nv_bfloat16* output) {
    int idx = threadIdx.x;
    output[idx] = __hgt(input[idx], __float2bfloat16(0.0f)) ? input[idx] : __float2bfloat16(0.0f);
}

// ReLU activation function for float:
__global__ void relu_float(const float* input, float* output) {
    int idx = threadIdx.x;
    output[idx] = input[idx] > 0.0f ? input[idx] : 0.0f;
}