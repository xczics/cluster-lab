-- MPI Test Programs 1.0 modulefile for Cluster-Lab
-- Cluster-Lab HPC -- Environment Modules (Lmod)

whatis("Description: MPI Hello World test programs for Cluster-Lab")
whatis("URL: https://github.com/xczics/cluster-lab")
whatis("Category: test")

load("openmpi/4.1.6")

local pkgdir = "/usr/local/mpi-test/1.0"

prepend_path("PATH", pathJoin(pkgdir, "bin"))

setenv("MPI_TEST_DIR", pkgdir)
setenv("MPI_HELLO", pathJoin(pkgdir, "bin/hello_mpi"))
