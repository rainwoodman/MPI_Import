
LDSHARED="$(MPICC) -shared"
mpiimport.so: mpiimport.c
	LDSHARED=$(LDSHARED) CC=$(MPICC) python setup.py build_ext --inplace
mpiimport.c: mpiimport.pyx libmpi.pxd
	cython -2 mpiimport.pyx
