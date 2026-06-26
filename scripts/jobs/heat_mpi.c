/**
 * heat_mpi.c — Parallel 2D Heat Equation Solver (MPI)
 * 
 * Solves ∂u/∂t = α(∂²u/∂x² + ∂²u/∂y²) using finite differences
 * on an N×N grid with N_ITER iterations.
 * 
 * Usage: mpirun -np 4 ./heat_mpi [N] [N_ITER]
 *   N      : grid size (default: 200)
 *   N_ITER : iterations (default: 10000)
 * 
 * For ~2min runtime on 2 nodes × 2 cores: ./heat_mpi 200 10000
 */

#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define ALPHA 0.01   /* thermal diffusivity */
#define DX    0.01   /* grid spacing */

/* Wall-clock timing helper */
double walltime(void) {
    return MPI_Wtime();
}

int main(int argc, char **argv) {
    int rank, nprocs, i, j, iter;
    int N = 200;         /* grid size (default) */
    int N_ITER = 10000;  /* iterations (default) */
    double *u, *u_new, *u_global = NULL;
    int rows_per_proc, row_start, row_end;
    double t_start, t_end, t_comp = 0.0, t_comm = 0.0;
    double residual = 0.0, global_residual;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);

    /* Parse arguments */
    if (argc > 1) N = atoi(argv[1]);
    if (argc > 2) N_ITER = atoi(argv[2]);

    /* Domain decomposition: divide rows among processes */
    rows_per_proc = N / nprocs;
    if (N % nprocs != 0 && rank == 0) {
        fprintf(stderr, "Warning: N=%d not divisible by %d procs\n", N, nprocs);
    }
    row_start = rank * rows_per_proc;
    row_end = (rank == nprocs - 1) ? N : row_start + rows_per_proc;
    rows_per_proc = row_end - row_start;

    /* Allocate local arrays with halo rows (top and bottom) */
    u     = (double*)calloc((rows_per_proc + 2) * N, sizeof(double));
    u_new = (double*)calloc((rows_per_proc + 2) * N, sizeof(double));

    /* Initial condition: hot spot in the center */
    for (i = 1; i <= rows_per_proc; i++) {
        int gi = row_start + i - 1;
        for (j = 0; j < N; j++) {
            double x = (j - N/2.0) * DX;
            double y = (gi - N/2.0) * DX;
            double r2 = x*x + y*y;
            u[i * N + j] = exp(-r2 / 0.01);
        }
    }

    /* MPI type for passing a row (N doubles) */
    MPI_Datatype MPI_ROW;
    MPI_Type_contiguous(N, MPI_DOUBLE, &MPI_ROW);
    MPI_Type_commit(&MPI_ROW);

    if (rank == 0) {
        printf("Heat Equation Solver (MPI)\n");
        printf("  Grid:       %d x %d\n", N, N);
        printf("  Iterations: %d\n", N_ITER);
        printf("  Processes:  %d\n", nprocs);
        printf("  Rows/proc:  %d\n", rows_per_proc);
        printf("  Alpha:      %f\n", ALPHA);
        printf("  dx:         %f\n", DX);
        printf("---\n");
    }

    t_start = walltime();

    /* Main time-stepping loop */
    for (iter = 0; iter < N_ITER; iter++) {
        double t0, t1;

        /* Exchange halo rows with neighbours */
        t0 = walltime();
        MPI_Request reqs[4];
        int left  = (rank > 0) ? rank - 1 : MPI_PROC_NULL;
        int right = (rank < nprocs - 1) ? rank + 1 : MPI_PROC_NULL;

        /* Send bottom row to right neighbour, receive from left */
        MPI_Isend(&u[rows_per_proc * N], 1, MPI_ROW, right, 0, MPI_COMM_WORLD, &reqs[0]);
        MPI_Irecv(&u[0], 1, MPI_ROW, left, 0, MPI_COMM_WORLD, &reqs[1]);

        /* Send top row to left neighbour, receive from right */
        MPI_Isend(&u[1 * N], 1, MPI_ROW, left, 1, MPI_COMM_WORLD, &reqs[2]);
        MPI_Irecv(&u[(rows_per_proc + 1) * N], 1, MPI_ROW, right, 1, MPI_COMM_WORLD, &reqs[3]);

        MPI_Waitall(4, reqs, MPI_STATUSES_IGNORE);
        t1 = walltime();
        t_comm += (t1 - t0);

        /* Compute finite difference update */
        t0 = walltime();
        residual = 0.0;
        for (i = 1; i <= rows_per_proc; i++) {
            for (j = 0; j < N; j++) {
                int left_j  = (j > 0) ? j - 1 : j;
                int right_j = (j < N - 1) ? j + 1 : j;
                double d2x = (u[i * N + left_j] - 2*u[i * N + j] + u[i * N + right_j]) / (DX*DX);
                double d2y = (u[(i-1) * N + j] - 2*u[i * N + j] + u[(i+1) * N + j]) / (DX*DX);
                u_new[i * N + j] = u[i * N + j] + ALPHA * (d2x + d2y);
                residual += (u_new[i * N + j] - u[i * N + j]) * (u_new[i * N + j] - u[i * N + j]);
            }
        }
        t1 = walltime();
        t_comp += (t1 - t0);

        /* Swap arrays */
        double *tmp = u; u = u_new; u_new = tmp;

        /* Report progress every 1000 iterations */
        if (iter % 1000 == 0 && iter > 0) {
            MPI_Allreduce(&residual, &global_residual, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
            global_residual = sqrt(global_residual) / (N * N);
            if (rank == 0) {
                printf("  Iter %5d: residual = %.6e  (comp: %.2fs, comm: %.2fs)\n",
                       iter, global_residual, t_comp, t_comm);
            }
        }
    }

    /* Final residual */
    MPI_Allreduce(&residual, &global_residual, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
    global_residual = sqrt(global_residual) / (N * N);

    t_end = walltime();

    if (rank == 0) {
        printf("---\n");
        printf("Completed %d iterations\n", N_ITER);
        printf("Final residual: %.6e\n", global_residual);
        printf("Total time:     %.2f s\n", t_end - t_start);
        printf("Compute time:   %.2f s (%.1f%%)\n", t_comp, 100*t_comp/(t_end-t_start));
        printf("Comm time:      %.2f s (%.1f%%)\n", t_comm, 100*t_comm/(t_end-t_start));
    }

    /* Cleanup */
    free(u);
    free(u_new);
    MPI_Type_free(&MPI_ROW);
    MPI_Finalize();
    return 0;
}
