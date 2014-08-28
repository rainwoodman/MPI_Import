from distutils.core import setup, Extension

setup(
    name='mpiimport', version="0.1",
    ext_modules = [
        Extension("mpiimport", ["mpiimport.c"])]
    )

