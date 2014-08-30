import sys
import mpiimport; mpiimport.install(tmpdir='/tmp', verbose=False,
        disable=len(sys.argv)==2)
import numpy

from mpi4py import MPI
mpiimport.tall.end()

class Rotator(object):
    def __init__(self, comm):
        self.comm = comm
    def __enter__(self):
        for i in range(self.comm.rank):
            self.comm.barrier()
    def __exit__(self, type, value, tb):
        for i in range(self.comm.rank, self.comm.size):
            self.comm.barrier()

with Rotator(MPI.COMM_WORLD):
    print mpiimport.COMM_WORLD.rank, MPI

if MPI.COMM_WORLD.rank == 0:
    print mpiimport.tio
    print mpiimport.tload
    print mpiimport.tloadlocal
    print mpiimport.tloadfile
    print mpiimport.tcomm
    print mpiimport.tfind
    print mpiimport.tall
    print mpiimport.bytescomm
