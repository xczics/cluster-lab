-- GCC 13.3.0 modulefile for Cluster-Lab
-- Cluster-Lab HPC -- Environment Modules (Lmod)

whatis("Description: GNU Compiler Collection 13.3.0")
whatis("URL: https://gcc.gnu.org/")
whatis("Category: compiler")

family("compiler")
prepend_path("PATH", "/usr/bin")
prepend_path("MANPATH", "/usr/share/man")

setenv("CC", "gcc")
setenv("CXX", "g++")
setenv("FC", "gfortran")
setenv("F77", "gfortran")
