# coding: utf-8

#!python
# cython: boundscheck=True, wraparound=True

import numpy as np
cimport numpy as np

cimport cython

# Library routines
from sptk cimport agexp as _agexp
from sptk cimport gexp as _gexp
from sptk cimport glog as _glog
from sptk cimport mseq as _mseq

# Adaptive mel-generalized cepstrum analysis
from sptk cimport acep as _acep
from sptk cimport agcep as _agcep
from sptk cimport amcep as _amcep

# Mel-generalized cepstrum analysis
from sptk cimport mcep as _mcep
from sptk cimport gcep as _gcep
from sptk cimport mgcep as _mgcep
from sptk cimport uels as _uels
from sptk cimport fftcep as _fftcep
from sptk cimport lpc as _lpc

# LPC, LSP and PARCOR conversions
# TODO
from sptk cimport lpc2c as _lpc2c
from sptk cimport lpc2lsp as _lpc2lsp
from sptk cimport lpc2par as _lpc2par
from sptk cimport par2lpc as _par2lpc
from sptk cimport lsp2sp as _lsp2sp

# Mel-generalized cepstrum conversions
from sptk cimport gnorm as _gnorm
from sptk cimport ignorm as _ignorm
from sptk cimport b2mc as _b2mc

# F0 analysis
from sptk cimport swipe as _swipe

# Window functions
from sptk cimport window as _window

# Waveform generation filters
# TODO

# Utils
# TODO

cimport sptk

import six
from warnings import warn
from pysptk import assert_gamma, assert_fftlen, assert_pade


### Library routines ###

def agexp(r, x, y):
    return _agexp(r, x, y)


def gexp(r, x):
    return _gexp(r, x)


def glog(r, x):
    return _glog(r, x)


def mseq():
    return _mseq()


### Adaptive mel-generalized cepstrum analysis ###

def acep(x, np.ndarray[np.float64_t, ndim=1, mode="c"] c not None,
         lambda_coef=0.98, step=0.1, tau=0.9, pd=4, eps=1.0e-6):
    assert_pade(pd)
    cdef int order = len(c) - 1
    prederr = _acep(x, &c[0], order, lambda_coef, step, tau, pd, eps)
    return prederr


def agcep(x, np.ndarray[np.float64_t, ndim=1, mode="c"] c not None,
          stage=1,
          lambda_coef=0.98, step=0.1, tau=0.9, eps=1.0e-6):
    if stage < 1:
        raise ValueError("stage >= 1 (-1 <= gamma < 0)")
    cdef int order = len(c) - 1
    prederr = _agcep(x, &c[0], order, stage, lambda_coef, step, tau, eps)
    return prederr


def amcep(x, np.ndarray[np.float64_t, ndim=1, mode="c"] b not None,
          alpha=0.41,
          lambda_coef=0.98, step=0.1, tau=0.0, pd=4, eps=1.0e-6):
    assert_pade(pd)
    cdef int order = len(b) - 1
    prederr = _amcep(x, &b[0], order, alpha, lambda_coef, step, tau, pd, eps)
    return prederr


### Mel-generalized cepstrum analysis ###

def mcep(np.ndarray[np.float64_t, ndim=1, mode="c"] windowed not None,
         order=25, alpha=0.35,
         miniter=2,
         maxiter=30,
         threshold=0.001,
         etype=0,
         eps=0.0,
         min_det=1.0e-6,
         itype=0):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] mc
    cdef int windowed_length = windowed.size
    cdef int ret
    mc = np.zeros(order + 1, dtype=np.float64)
    ret = _mcep(&windowed[0], windowed_length, &mc[0],
                order, alpha, miniter, maxiter, threshold, etype, eps,
                min_det, itype)
    assert ret == -1 or ret == 0 or ret == 3 or ret == 4
    if ret == 3:
        raise RuntimeError("failed to compute mcep; error occured in theq")
    elif ret == 4:
        raise RuntimeError(
            "zero(s) are found in periodogram, use eps option to floor")

    return mc


def gcep(np.ndarray[np.float64_t, ndim=1, mode="c"] windowed not None,
         order=25, gamma=0.0,
         miniter=2,
         maxiter=30,
         threshold=0.001,
         etype=0,
         eps=0.0,
         min_det=1.0e-6,
         itype=0,
         norm=False):
    assert_gamma(gamma)

    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] gc
    cdef int windowed_length = windowed.size
    cdef int ret
    gc = np.zeros(order + 1, dtype=np.float64)
    ret = _gcep(&windowed[0], windowed_length, &gc[0], order,
                gamma, miniter, maxiter, threshold, etype, eps, min_det, itype)
    assert ret == -1 or ret == 0 or ret == 3
    if ret == 3:
        raise RuntimeError("failed to compute gcep; error occured in theq")

    if not norm:
        _ignorm(&gc[0], &gc[0], order, gamma)

    return gc


def mgcep(np.ndarray[np.float64_t, ndim=1, mode="c"] windowed not None,
          order=25, alpha=0.35, gamma=0.0,
          num_recursions=None,
          miniter=2,
          maxiter=30,
          threshold=0.001,
          etype=0,
          eps=0.0,
          min_det=1.0e-6,
          itype=0,
          otype=0):
    assert_gamma(gamma)

    if num_recursions is None:
        num_recursions = windowed.size - 1

    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] mgc
    cdef int windowed_length = windowed.size
    cdef int ret
    mgc = np.zeros(order + 1, dtype=np.float64)
    ret = _mgcep(&windowed[0], windowed_length, &mgc[0],
                 order, alpha, gamma, num_recursions, miniter, maxiter,
                 threshold, etype, eps, min_det, itype)
    assert ret == -1 or ret == 0 or ret == 3
    if ret == 3:
        raise RuntimeError("failed to compute mgcep; error occured in theq")

    if otype == 0 or otype == 1 or otype == 2 or otype == 4:
        _ignorm(&mgc[0], &mgc[0], order, gamma)

    if otype == 0 or otype == 2 or otype == 4:
        _b2mc(&mgc[0], &mgc[0], order, alpha)

    if otype == 2 or otype == 4:
        _gnorm(&mgc[0], &mgc[0], order, gamma)

    cdef int i = 0
    cdef double g = gamma
    if otype == 4 or otype == 5:
        for i in six.moves.range(1, mgc.size):
            mgc[i] *= g

    return mgc


def uels(np.ndarray[np.float64_t, ndim=1, mode="c"] windowed not None,
         order=25,
         miniter=2,
         maxiter=30,
         threshold=0.001,
         etype=0,
         eps=0.0,
         itype=0):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] c
    cdef int windowed_length = len(windowed)
    cdef int ret
    c = np.zeros(order + 1, dtype=np.float64)
    ret = _uels(&windowed[0], windowed_length, &c[0], order,
                miniter, maxiter, threshold, etype, eps, itype)
    assert ret == -1 or ret == 0 or ret == 3
    if ret == 3:
        raise RuntimeError(
            "zero(s) are found in periodogram, use eps option to floor")

    return c


def fftcep(np.ndarray[np.float64_t, ndim=1, mode="c"] logsp not None,
           order=25,
           num_iter=0,
           acceleration_factor=0.0):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] c
    cdef int logsp_length = len(logsp)
    c = np.zeros(order + 1, dtype=np.float64)
    _fftcep(&logsp[0], logsp_length, &c[0], order + 1,
            num_iter, acceleration_factor)

    return c


def lpc(np.ndarray[np.float64_t, ndim=1, mode="c"] windowed not None,
        order=25,
        min_det=1.0e-6):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] a
    cdef int windowed_length = len(windowed)
    cdef int ret
    a = np.zeros(order + 1, dtype=np.float64)
    ret = _lpc(&windowed[0], windowed_length, &a[0], order, min_det)
    assert ret == -2 or ret == -1 or ret == 0
    if ret == -2:
        warn("failed to compute `stable` LPC. Please try again with different paramters")
    elif ret == -1:
        raise RuntimeError(
            "failed to compute LPC. Please try again with different parameters")

    return a

### LPC, LSP and PARCOR conversions ###

def lpc2c(np.ndarray[np.float64_t, ndim=1, mode="c"] src_lpc not None,
          dst_order):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] dst_ceps
    cdef int src_order = len(src_lpc) - 1
    dst_ceps = np.zeros(dst_order + 1, dtype=np.float64)
    _lpc2c(&src_lpc[0], src_order, &dst_ceps[0], dst_order)
    return dst_ceps


def lpc2lsp(np.ndarray[np.float64_t, ndim=1, mode="c"] src_lpc not None,
            numsp=512, maxiter=4, eps=1.0e-6, loggain=False, otype=0,
            fs=None):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] dst_lsp
    cdef int order = len(src_lpc) - 1
    dst_lsp = np.zeros_like(src_lpc)
    _lpc2lsp(&src_lpc[0], &dst_lsp[0], order, numsp, maxiter, eps)

    if otype == 0:
        dst_lsp[1:] *= 2 * np.pi
    elif otype == 2 or otype == 3:
        if fs is None:
            raise ValueError("fs must be specified when otype == 2 or 3")
        dst_lsp[1:] *= fs

    if otype == 3:
        dst_lsp[1:] *= 1000.0

    if loggain:
        dst_lsp[0] = np.log(src_lpc[0])
    else:
        dst_lsp[0] = src_lpc[0]

    return dst_lsp


def lpc2par(np.ndarray[np.float64_t, ndim=1, mode="c"] src_lpc not None):
    cdef np.ndarray[np.float64_t, ndim=1, mode="c"] dst_par
    dst_par = np.zeros_like(src_lpc)
    cdef int order = len(src_lpc) - 1
    _lpc2par(&src_lpc[0], &dst_par[0], order)
    return dst_par


def par2lpc(np.ndarray[np.float64_t, ndim=1, mode="c"] src_par not None):
    cdef np.ndarray[np.float64_t, ndim=1, mode="c"] dst_lpc
    dst_lpc = np.zeros_like(src_par)
    cdef int order = len(src_par) - 1
    _par2lpc(&src_par[0], &dst_lpc[0], order)
    return dst_lpc


# assume lsp has loggain at src_lsp[0]
def lsp2sp(np.ndarray[np.float64_t, ndim=1, mode="c"] src_lsp not None,
           fftlen=256):
    cdef np.ndarray[np.float64_t, ndim=1, mode="c"] sp
    cdef int sp_length = fftlen>>1 + 1
    sp = np.zeros(sp_length, dtype=np.float64)
    cdef int order = len(src_lsp) - 1
    _lsp2sp(&src_lsp[0], order, &sp[0], sp_length, 1)
    return sp

### Mel-generalized cepstrum conversions ###


### F0 analysis ###

def swipe(np.ndarray[np.float64_t, ndim=1, mode="c"] x not None,
          fs, hopsize,
          min=50.0, max=800.0, threshold=0.3, otype=1):
    if not otype in six.moves.range(0, 3):
        raise ValueError("otype must be 0, 1, or 2")

    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] f0
    cdef int x_length = x.size
    cdef int expected_len = int(x_length / hopsize) + 1

    f0 = np.zeros(expected_len, dtype=np.float64)

    _swipe(&x[0], &f0[0], x_length, fs, hopsize, min, max, threshold, otype)
    return f0


### Window functions ###

cdef __window(Window window_type, np.ndarray[np.float64_t, ndim=1, mode="c"] x,
              int size, int normalize):
    if normalize < 0 or normalize > 2:
        raise ValueError("normalize must be 0, 1 or 2")
    cdef double g = _window(window_type, &x[0], size, normalize)
    return x


def blackman(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = BLACKMAN
    return __window(window_type, x, x.size, normalize)


def hamming(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = HAMMING
    return __window(window_type, x, x.size, normalize)


def hanning(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = HANNING
    return __window(window_type, x, x.size, normalize)


def bartlett(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = BARTLETT
    return __window(window_type, x, x.size, normalize)


def trapezoid(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = TRAPEZOID
    return __window(window_type, x, x.size, normalize)


def rectangular(n, normalize=1):
    cdef np.ndarray[np.float64_t, ndim = 1, mode = "c"] x
    x = np.ones(n, dtype=np.float64)
    cdef Window window_type = RECTANGULAR
    return __window(window_type, x, x.size, normalize)