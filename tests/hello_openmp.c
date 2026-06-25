#include <omp.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    int max_threads = omp_get_max_threads();

    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        int nthreads = omp_get_num_threads();
        char hostname[256];
        gethostname(hostname, sizeof(hostname));

        #pragma omp critical
        printf("Hello from OpenMP thread %d of %d on %s\n", tid, nthreads, hostname);
    }

    printf("Max threads available: %d\n", max_threads);
    return 0;
}
