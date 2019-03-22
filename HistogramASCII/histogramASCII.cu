#include "wb.h"
#include <bits/stdc++.h>
using namespace std;

#define NUM_BINS 128
#define CEIL(a, b) ((a-1)/b +1)

#define CUDA_CHECK(ans) { gpuAssert((ans), __FILE__, __LINE__); }

inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort = true) {
	
	if (code != cudaSuccess) {
		fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code),
		file, line);

		if (abort)
			exit(code);
	}
}

__global__ void compute(unsigned int *deviceInput, unsigned int *deviceBins, int *length){
	int idx = blockDim.x*blockIdx.x + threadIdx.x;
	__shared__ unsigned int hist[NUM_BINS];
	if(idx<128){
		hist[idx]=0;
	}
	__syncthreads();
	if(idx<length[0]){
		atomicAdd(&hist[deviceInput[idx]], 1);
	}
	__syncthreads();
	if(idx<128){
		atomicAdd(&deviceBins[idx], hist[idx]);
	}
}

int main(int argc, char *argv[]) {
	
	wbArg_t args;
	int inputLength;
	unsigned int *hostInput;
	unsigned int *hostBins;
	unsigned int *deviceInput;
	unsigned int *deviceBins;
	int *length;

	args = wbArg_read(argc, argv);

	wbTime_start(Generic, "Importing data and creating memory on host");
	hostInput = (unsigned int *)wbImportChar(wbArg_getInputFile(args, 0), &inputLength);
	hostBins = (unsigned int *)calloc(NUM_BINS, sizeof(unsigned int));
	wbTime_stop(Generic, "Importing data and creating memory on host");

	wbLog(TRACE, "The input length is ", inputLength);
	wbLog(TRACE, "The number of bins is ", NUM_BINS);

	wbTime_start(GPU, "Allocating GPU memory.");
	// Allocating GPU memory
	cudaMalloc((void **)&deviceInput, inputLength * sizeof(uint));
	cudaMalloc((void **)&deviceBins, NUM_BINS * sizeof(uint));
	cudaMalloc((void **)&length, sizeof(int));
	CUDA_CHECK(cudaDeviceSynchronize());
	wbTime_stop(GPU, "Allocating GPU memory.");

	wbTime_start(GPU, "Copying input memory to the GPU.");
	// Copying memory to the GPU
	cudaMemcpy(deviceInput, hostInput, inputLength * sizeof(uint), cudaMemcpyHostToDevice);
	cudaMemcpy(deviceBins, hostBins, NUM_BINS * sizeof(uint), cudaMemcpyHostToDevice);
	cudaMemcpy(length, &inputLength, sizeof(int), cudaMemcpyHostToDevice);
	CUDA_CHECK(cudaDeviceSynchronize());
	wbTime_stop(GPU, "Copying input memory to the GPU.");

	// Launch kernel
	compute<<< CEIL(inputLength, 1024), 1024 >>>(deviceInput, deviceBins, length);
	wbLog(TRACE, "Launching kernel");
	wbTime_start(Compute, "Performing CUDA computation");
	// Kernel computation
	
	wbTime_stop(Compute, "Performing CUDA computation");

	wbTime_start(Copy, "Copying output memory to the CPU");
	// Copying the GPU memory back to the CPU
	cudaMemcpy(hostBins, deviceBins, NUM_BINS * sizeof(uint), cudaMemcpyDeviceToHost);
	CUDA_CHECK(cudaDeviceSynchronize());
	wbTime_stop(Copy, "Copying output memory to the CPU");

	wbTime_start(GPU, "Freeing GPU Memory");
	// Freeing the GPU memory
	cudaFree(deviceBins);
	cudaFree(deviceInput);
	wbTime_stop(GPU, "Freeing GPU Memory");

	// Verify correctness
	wbSolution(args, hostBins, NUM_BINS);

	free(hostBins);
	free(hostInput);
}
