//
//  LNKLinearRegressionPredictor+Analysis.h
//  LearnKit
//
//  Copyright © 2016 Matt Rajca. All rights reserved.
//

#import "LNKLinearRegressionPredictor.h"

NS_ASSUME_NONNULL_BEGIN

@interface LNKLinearRegressionPredictor (Analysis)

/// The returned vector must be freed with `LNKVectorFree`.
- (LNKVector)computeResiduals;
- (LNKVector)computeStandardizedResiduals;

- (LNKFloat)computeAIC;
- (LNKFloat)computeBIC;

@property (nonatomic, readonly) LNKMatrix *hatMatrix;

@end

NS_ASSUME_NONNULL_END
