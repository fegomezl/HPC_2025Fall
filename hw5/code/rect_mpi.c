#include <stdio.h>
#include <math.h>
#include <mpi.h>

// System size
#define		N	1048576

// Find first index of pid for a load-balanced partition of N items
int partition_index(long size, long pid, long nproc);

int main(int argc, char* argv[]){

	// Define variables
	int pid, nproc;
	int first_index, last_index, i;
	double h;
	double local_area, area;
	double local_start, local_end, local_elapsed, elapsed;

	// Start MPI code
	MPI_Init(&argc, &argv);
	MPI_Comm_rank(MPI_COMM_WORLD, &pid);
	MPI_Comm_size(MPI_COMM_WORLD, &nproc);

	// Initialize variables
	first_index = partition_index(N, pid, nproc);
	last_index = partition_index(N, pid+1, nproc);
	h = 10.0/N;
	area = 0.0;
	local_area = 0.0;

	// Get the start time
	MPI_Barrier(MPI_COMM_WORLD);
	local_start = MPI_Wtime();

	// Calculate local area
	for (i = first_index; i < last_index; i++)
		local_area += cos(i*h)*h;
	// Accumulate sum in master processor
	MPI_Reduce(&local_area, &area, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

	// Get the end time
	local_end = MPI_Wtime();
	local_elapsed = (local_end - local_start)*1000; // Time in ms
	MPI_Reduce(&local_elapsed, &elapsed, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

	// Check results
	if (pid == 0 && argc == 1)
		printf("Result : %.2lf \n", area);

	// Print the interval lenght
	if (pid == 0){
		if (argc == 1)
			printf("Interval length: %g msec.\n", elapsed);
		else
			printf("%d\t%g\n", nproc, elapsed);
	}

	// Finish program
	MPI_Finalize();

	return 0;
}

// Find first index of pid for a load-balanced partition of N items
int partition_index(long size, long pid, long nproc){
	int ratio = size/nproc;
	int reminder = size%nproc;

	if (pid < reminder){
		return (ratio+1)*pid;
	} else if (pid < nproc) { 
		return ratio*pid + reminder;
	} else {
		return size;
	}
}
