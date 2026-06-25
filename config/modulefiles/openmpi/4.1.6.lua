-- OpenMPI 4.1.6 modulefile for Cluster-Lab
-- Cluster-Lab HPC -- Environment Modules (Lmod)

whatis("Description: Open MPI 4.1.6")
whatis("URL: https://www.open-mpi.org/")
whatis("Category: mpi")

family("mpi")

load("gcc/13.3.0")

prepend_path("PATH", "/usr/bin")
prepend_path("LD_LIBRARY_PATH", "/usr/lib/aarch64-linux-gnu")
prepend_path("MANPATH", "/usr/share/man")

setenv("CC", "mpicc")
setenv("CXX", "mpicxx")
setenv("FC", "mpifort")
setenv("F77", "mpif77")

setenv("MPICC", "mpicc")
setenv("MPICXX", "mpicxx")
setenv("MPIFC", "mpifort")
setenv("MPIF77", "mpif77")
setenv("MPI_HOME", "/usr/lib/aarch64-linux-gnu/openmpi")
