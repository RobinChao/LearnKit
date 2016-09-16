//
//  LNKAccelerate.h
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import <Accelerate/Accelerate.h>

#define UNIT_STRIDE 1

#if USE_DOUBLE_PRECISION

#define LNK_vfill		vDSP_vfillD
#define LNK_vclr		vDSP_vclrD
#define LNK_vmean		vDSP_meanvD
#define LNK_vsadd		vDSP_vsaddD
#define LNK_dotpr		vDSP_dotprD
#define LNK_vadd		vDSP_vaddD
#define LNK_vdiv		vDSP_vdivD
#define LNK_vsub		vDSP_vsubD
#define LNK_vsdiv		vDSP_vsdivD
#define LNK_mmul		vDSP_mmulD
#define LNK_mmov		vDSP_mmovD
#define LNK_vmul		vDSP_vmulD
#define LNK_vsmul		vDSP_vsmulD
#define LNK_vsmsa		vDSP_vsmsaD
#define LNK_vneg		vDSP_vnegD
#define LNK_vsma		vDSP_vsmaD
#define LNK_svdiv		vDSP_svdivD
#define LNK_vsum		vDSP_sveD
#define LNK_vsq			vDSP_vsqD
#define LNK_minv		vDSP_minvD
#define LNK_maxv		vDSP_maxvD
#define LNK_vlog		vvlog
#define LNK_vexp		vvexp
#define LNK_vtanh		vvtanh
#define LNK_vpows		vvpows

#define LNK_sqrt		sqrt
#define LNK_pow			pow
#define LNK_exp			exp
#define LNK_fabs		fabs
#define LNKLog			log
#define LNKLog2			log2
#define LNK_strtoflt(str)	strtod((str), NULL)

/// Computes the euclidean distance between the two vectors.
#define LNKVectorDistance(vector1, vector2, outDistance, n) vDSP_distancesqD((vector1), UNIT_STRIDE, (vector2), UNIT_STRIDE, (outDistance), (n))

#else

#define LNK_vfill		vDSP_vfill
#define LNK_vclr		vDSP_vclr
#define LNK_vmean		vDSP_meanv
#define LNK_vsadd		vDSP_vsadd
#define LNK_dotpr		vDSP_dotpr
#define LNK_vadd		vDSP_vadd
#define LNK_vdiv		vDSP_vdiv
#define LNK_vsub		vDSP_vsub
#define LNK_vsdiv		vDSP_vsdiv
#define LNK_mmul		vDSP_mmul
#define LNK_mmov		vDSP_mmov
#define LNK_vmul		vDSP_vmul
#define LNK_vsmul		vDSP_vsmul
#define LNK_vneg		vDSP_vneg
#define LNK_vsma		vDSP_vsma
#define LNK_vsmsa		vDSP_vsmsa
#define LNK_svdiv		vDSP_svdiv
#define LNK_vsum		vDSP_sve
#define LNK_vsq			vDSP_vsq
#define LNK_minv		vDSP_minv
#define LNK_maxv		vDSP_maxv
#define LNK_vlog		vvlogf
#define LNK_vexp		vvexpf
#define LNK_vtanh		vvtanhf
#define LNK_vpows		vvpowsf

#define LNK_sqrt		sqrtf
#define LNK_pow			powf
#define LNK_exp			expf
#define LNK_fabs		fabsf
#define LNKLog			logf
#define LNKLog2			log2f
#define LNK_strtoflt(str,len)	strtof((str), NULL)

/// Computes the euclidean distance between the two vectors.
#define LNKVectorDistance(vector1, vector2, outDistance, n) vDSP_distancesq((vector1), UNIT_STRIDE, (vector2), UNIT_STRIDE, (outDistance), (n))

#endif

/* In-place operations */

void LNK_mtrans(const LNKFloat *source, LNKFloat *dest, vDSP_Length N, vDSP_Length M);

/// Inverts a matrix of dimensions n * n.
void LNK_minvert(LNKFloat *matrix, LNKSize n);

/// Applies the sigmoid function to every element of the vector.
void LNK_vsigmoid(LNKFloat *vector, LNKSize n);

/* Out-of-place operations */

/// Applies the gradient of the sigmoid function to every element of the sigmoid vector.
void LNK_vsigmoidgrad(const LNKFloat *vector, LNKFloat *outVector, LNKSize n);

/// Computes the standard deviation of the elements in the vector.
LNKFloat LNK_vsd(LNKVector vector, LNKSize stride, LNKFloat *workgroup, LNKFloat mean, BOOL inSample);

/// Computes the determinant of the n * n matrix.
LNKFloat LNK_mdet(const LNKFloat *matrix, LNKSize n);

LNKFloat LNK_vlogsumexp(const LNKFloat *vector, LNKSize n);
