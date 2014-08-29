import mpiimport; mpiimport.install(tmpdir='/tmp', verbose=False)
from mpi4py import MPI
#import numpy
#numpy.test()
#import die
if MPI.COMM_WORLD.rank == 0:
    print mpiimport.tio
    print mpiimport.tload
    print mpiimport.tloadlocal
    print mpiimport.tloadfile
    print mpiimport.tcomm
    print mpiimport.tfind
    mpiimport.tall.end()
    print mpiimport.tall

