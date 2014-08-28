include "libmpi.pxd"
import cPickle

cdef class Comm(object):
    cdef MPI_Comm comm
    cdef readonly int rank
    cdef readonly int size

    def bcast(self, obj, root=0):
        cdef int n
        cdef bytes buf

        if self.rank == root:
            buf = cPickle.dumps(obj)
            n = len(buf)
        MPI_Bcast(&n, 1, MPI_INT, root, self.comm)

        if self.rank != root:
            buf = bytes(' ' * n)

        MPI_Bcast(<char*>buf, n, MPI_BYTE, root, self.comm)
        return cPickle.loads(buf)
cdef bind(MPI_Comm comm):
    self = Comm()
    self.comm = comm
    MPI_Comm_rank(self.comm, &self.rank)
    MPI_Comm_size(self.comm, &self.size)
    return self

MPI_Init(NULL, NULL)
COMM_WORLD = bind(MPI_COMM_WORLD)

import imp
import sys
import posix

__all__ = ['install']

_tmpdir = '/tmp'
_tmpfiles = []
d = {
        imp.PY_SOURCE: "source",
        imp.PY_COMPILED: "compiled",
        imp.PKG_DIRECTORY: "pkg",
        imp.C_BUILTIN: "builtin",
        imp.C_EXTENSION: "extension",
        imp.PY_FROZEN: "frozen"}
verbose = posix.environ.get('PYTHON_MPIIMPORT_VERBOSE', 0)
 
def tempnam(dir, prefix, suffix):
    l = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    s = posix.urandom(16)
    u = ''.join([l[ord(a) % len(l)] for a in s])
    return dir + '/' + prefix + u + suffix

def mkstemp(dir='', suffix='', prefix='', mode='w+', fmode=0600):
    i = 0
    while i < 100:
        fn = tempnam(dir, prefix, suffix)
        try:
            fd = posix.open(fn, posix.O_CREAT | posix.O_EXCL, fmode)
        except OSError:
            i = i + 1
            continue
        f = open(fn, mode)
        posix.close(fd)
        return f
    raise OSError("failed to create a tempfile");

def loadcextensionfromstring(fullname, string, pathname, description):
#    try:
        with mkstemp(dir=_tmpdir, prefix=fullname.split('.')[-1] + '-', suffix=description[0]) as file:
            file.write(string)
            _tmpfiles.append(file.name)
            name = file.name

        if verbose:
            print 'module', fullname, 'using', name, 'via mpi'

        with open(name, mode=description[1]) as f2:
            #print file, pathname, description
            mod = imp.load_module(fullname, f2, pathname, description)
            #print mod
        return mod 
#    except Exception as e:
#        print 'exception', e

if hasattr(sys, 'exitfunc'):
    oldexitfunc = sys.exitfunc
else:
    oldexitfunc = lambda : None

def cleanup():
    global _tmpfiles
    for f in _tmpfiles:
    #    print 'removing', f
        posix.unlink(f)
    _tmpfiles = []
    oldexitfunc()

sys.exitfunc = cleanup

class Loader(object):
    def __init__(self, file, pathname, description):
        self.file = file
        self.pathname = pathname
        self.description = description
    def load_module(self, fullname):
        mod = sys.modules.setdefault(fullname, imp.new_module(fullname))
        if self.file:
            if self.description[-1] == imp.PY_SOURCE:
                #mod.__file__ = "<%s>" % self.__class__.__name__
                #mod.__package__ = fullname.rpartition('.')[0]
                #print type(bytes(self.file)), fullname
                #exec self.file in mod.__dict__
                loadcextensionfromstring(fullname, self.file, self.pathname, self.description) 
            elif self.description[-1] == imp.C_EXTENSION:
                #print "loading extension"
                loadcextensionfromstring(fullname, self.file, self.pathname, self.description) 
            else:
                if verbose:
                    print 'module', fullname, 'using', self.file
                self.file = open(self.file, self.description[1])
                mod = imp.load_module(fullname, self.file, self.pathname, self.description)
        else:
            mod = imp.load_module(fullname, self.file, self.pathname, self.description)
        mod.__loader__ = self
        return mod

class Finder(object):
    def __init__(self, comm):
        self.comm = comm
        self.rank = comm.rank
    def find_module(self, fullname, path=None):
        file, pathname, description = None, None, None
        if self.rank == 0:
            try:
                file, pathname, description = imp.find_module(fullname, path)
                if file:
                    if description[-1] == imp.PY_SOURCE:
                        #print 'finding python module', file.name
                        s = file.read()
                        file.close()
                        file = s
                    elif description[-1] == imp.C_EXTENSION:
                        #print 'finding extension', file.name
                        s = file.read()
                        file.close()
                        file = s
                    else:
                        #print 'finding file by name', d[description[-1]]
                        file = file.name
                    
            except ImportError as e:
                file = e
                pass
        file, pathname, description = self.comm.bcast((file, pathname, description))

        if isinstance(file, Exception):
            return None
        return Loader(file, pathname, description)

def install(comm=COMM_WORLD, tmpdir='/tmp'):
    global _tmpdir
    _tmpdir = tmpdir
    sys.meta_path.append(Finder(comm))
    import site
