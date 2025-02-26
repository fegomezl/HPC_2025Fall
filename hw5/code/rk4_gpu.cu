#include <stdio.h>
#include <time.h>
#include <sys/time.h> 
#include <cuda.h>

// System size
#define		N	4096

// Structures for profilling
struct timeval startTime;
struct timeval finishTime;
double timeIntervalLength;

// First RK step
__global__ void CUDA_rk4_0(const double h, const double pow[], const double c[], const double y[], double k[]){
	int my_tid = blockDim.x*blockIdx.x + threadIdx.x;
	if (my_tid < N){
		int j;
		double my_k = pow[my_tid];
		for (j = 0; j < N; j++)
			my_k -= c[my_tid*N+j]*y[j];
		my_k *= h;
		k[my_tid] = my_k;
	}
}

// Second and third RK steps
__global__ void CUDA_rk4_1(const double h, const double pow[], const double c[], const double y[], const double k_old[], double k_new[]){
	int my_tid = blockDim.x*blockIdx.x + threadIdx.x;
	if (my_tid < N){
		int j;
		double my_k = pow[my_tid];
	        for (j = 0; j < N; j++)
			my_k -= c[my_tid*N+j]*(y[j]+0.5*k_old[j]);
		my_k *= h;
		k_new[my_tid] = my_k;
	}
}

// Fourth RK step
__global__ void CUDA_rk4_2(const double h, const double pow[], const double c[], const double y[], 
						   const double k1[], const double k2[], const double k3[], double k4[], double yout[]){
	int my_tid = blockDim.x*blockIdx.x + threadIdx.x;
	if (my_tid < N){
		int j;
		double my_k = pow[my_tid];
	        for (j = 0; j < N; j++)
			my_k -= c[my_tid*N+j]*(y[j]+k3[j]);
		my_k *= h;
		k4[my_tid] = my_k;

		yout[my_tid] = y[my_tid] + (k1[my_tid] + 2*k2[my_tid] + 2*k3[my_tid] + k4[my_tid])/6.0;
	}
}

int main(int argc, char* argv[]){

	// Define variables
	int i, j;
	double h, totalSum;
	double*  y;
	double*  k1;
	double*  k2;
	double*  k3;
	double*  k4;
	double*  pow;
	double*  yout;
	double*  c;

	// Allocate arrays
	cudaMallocManaged(&y, N*sizeof(double));
	cudaMallocManaged(&k1, N*sizeof(double));
	cudaMallocManaged(&k2, N*sizeof(double));
	cudaMallocManaged(&k3, N*sizeof(double));
	cudaMallocManaged(&k4, N*sizeof(double));
	cudaMallocManaged(&pow, N*sizeof(double));
	cudaMallocManaged(&yout, N*sizeof(double));
	cudaMallocManaged(&c, N*N*sizeof(double));

	// Initialize variables
	h = 0.3154;
	totalSum = 0.0;
	for (i = 0; i < N; i++){
		y[i] = i*i;
		pow[i] = 2*i;
		for (j = 0; j < N; j++)
			c[i*N+j] = i*i+j;
	}
	
	// Get the start time
	gettimeofday(&startTime, NULL);

	// Run each RK step in a separate kernel and synchronize device in between
	CUDA_rk4_0<<<N/1024,1024>>>(h, pow, c, y, k1);
	cudaDeviceSynchronize();	

	CUDA_rk4_1<<<N/1024,1024>>>(h, pow, c, y, k1, k2);
	cudaDeviceSynchronize();	

	CUDA_rk4_1<<<N/1024,1024>>>(h, pow, c, y, k2, k3);
	cudaDeviceSynchronize();	

	CUDA_rk4_2<<<N/1024,1024>>>(h, pow, c, y, k1, k2, k3, k4, yout);
	cudaDeviceSynchronize();

	// Get the end time
	gettimeofday(&finishTime, NULL);

	// Check results
	if (argc < 2){
		for (i = 0; i < N; i++)
			totalSum += yout[i];
		printf("Total Sum : %g \n", totalSum);
	}
	
	// Calculate the interval length 
	timeIntervalLength = (double)(finishTime.tv_sec-startTime.tv_sec)*1000000 
	                   + (double)(finishTime.tv_usec-startTime.tv_usec);
	timeIntervalLength = timeIntervalLength/1000;

	// Print the interval length
	if (argc < 2){
		printf("Interval length: %g msec.\n", timeIntervalLength);
	} else { 
		printf("%g\n", timeIntervalLength);
	}

	// Free memory
	cudaFree(y);
	cudaFree(k1);
	cudaFree(k2);
	cudaFree(k3);
	cudaFree(k4);
	cudaFree(pow);
	cudaFree(yout);
	cudaFree(c);

	return 0;
}
