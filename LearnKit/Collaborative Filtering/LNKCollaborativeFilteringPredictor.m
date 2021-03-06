//
//  LNKCollaborativeFilteringPredictor.m
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKCollaborativeFilteringPredictor.h"

#import "LNKAccelerate.h"
#import "LNKCollaborativeFilteringPredictorPrivate.h"
#import "LNKMatrix.h"
#import "LNKOptimizationAlgorithm.h"
#import "LNKPredictorPrivate.h"
#import "LNKRegularizationConfiguration.h"

@interface LNKCollaborativeFilteringPredictor () < LNKOptimizationAlgorithmDelegate >

@end

@implementation LNKCollaborativeFilteringPredictor {
	LNKMatrix *_indicatorMatrix;
	LNKSize _featureCount;
	LNKFloat *_unrolledGradient;
}

+ (NSArray<Class> *)supportedAlgorithms {
	return @[ [LNKOptimizationAlgorithmCG class] ];
}

+ (NSArray<NSNumber *> *)supportedImplementationTypes {
	return @[ @(LNKImplementationTypeAccelerate) ];
}

- (instancetype)initWithMatrix:(LNKMatrix *)outputMatrix indicatorMatrix:(LNKMatrix *)indicatorMatrix implementationType:(LNKImplementationType)implementationType optimizationAlgorithm:(id<LNKOptimizationAlgorithm>)algorithm featureCount:(NSUInteger)featureCount {
#pragma unused(implementationType)
	
	if (featureCount == 0)
		[NSException raise:NSInvalidArgumentException format:@"The feature count must be greater than 0"];
	
	if (!indicatorMatrix)
		[NSException raise:NSInvalidArgumentException format:@"The indicator matrix must not be nil"];
	
	self = [self initWithMatrix:outputMatrix optimizationAlgorithm:algorithm];
	if (self) {
		_featureCount = featureCount;
		_indicatorMatrix = [indicatorMatrix retain];
		
		const LNKSize userCount = outputMatrix.columnCount;
		const LNKSize rowCount = outputMatrix.rowCount;
		const LNKSize unrolledRowCount = rowCount + userCount;
		
		_unrolledGradient = LNKFloatAlloc(unrolledRowCount * _featureCount);
	}
	return self;
}

- (LNKFloat)_evaluateCostFunction {
	LNKMatrix *outputMatrix = self.matrix;
	const LNKSize userCount = outputMatrix.columnCount;
	const LNKSize rowCount = outputMatrix.rowCount;
	const LNKFloat *dataMatrix = _unrolledGradient;
	const LNKFloat *thetaMatrix = _unrolledGradient + rowCount * _featureCount;
	
	LNKFloat *thetaTranspose = LNKFloatAlloc(userCount * _featureCount);
	LNK_mtrans(thetaMatrix, thetaTranspose, _featureCount, userCount);
	
	// 1/2 * sum((((X * Theta') - Y) ^ 2) * R)
	const LNKSize resultSize = rowCount * userCount;
	LNKFloat *result = LNKFloatAlloc(resultSize);
	LNK_mmul(dataMatrix, UNIT_STRIDE, thetaTranspose, UNIT_STRIDE, result, UNIT_STRIDE, rowCount, userCount, _featureCount);
	
	LNK_vsub(outputMatrix.matrixBuffer, UNIT_STRIDE, result, UNIT_STRIDE, result, UNIT_STRIDE, resultSize);
	LNK_vmul(result, UNIT_STRIDE, result, UNIT_STRIDE, result, UNIT_STRIDE, resultSize);
	LNK_vmul(result, UNIT_STRIDE, _indicatorMatrix.matrixBuffer, UNIT_STRIDE, result, UNIT_STRIDE, resultSize);
	
	LNKFloat sum;
	LNK_vsum(result, UNIT_STRIDE, &sum, resultSize);
	free(result);
	
	LNKFloat regularizationTerm = 0;
	
	NSAssert([self.algorithm isKindOfClass:[LNKOptimizationAlgorithmCG class]], @"Unexpected algorithm");
	
	if (_regularizationConfiguration != nil) {
		// Re-use the theta transpose matrix to compute the theta square.
		LNK_vmul(thetaTranspose, UNIT_STRIDE, thetaTranspose, UNIT_STRIDE, thetaTranspose, UNIT_STRIDE, userCount * _featureCount);
		
		LNKFloat *dataSquare = LNKFloatAlloc(rowCount * _featureCount);
		LNK_vmul(dataMatrix, UNIT_STRIDE, dataMatrix, UNIT_STRIDE, dataSquare, UNIT_STRIDE, rowCount * _featureCount);
		
		LNKFloat thetaSum, dataSum;
		LNK_vsum(thetaTranspose, UNIT_STRIDE, &thetaSum, userCount * _featureCount);
		LNK_vsum(dataSquare, UNIT_STRIDE, &dataSum, rowCount * _featureCount);
		free(dataSquare);
		
		// ... + lambda / 2 * (sum(Theta^2) + sum(X^2))
		regularizationTerm = _regularizationConfiguration.lambda / 2 * (thetaSum + dataSum);
	}
	
	free(thetaTranspose);
	
	return 0.5 * sum + regularizationTerm;
}

- (const LNKFloat *)_computeGradient {
	LNKMatrix *outputMatrix = self.matrix;
	const LNKSize userCount = outputMatrix.columnCount;
	const LNKSize rowCount = outputMatrix.rowCount;
	const LNKSize unrolledRowCount = rowCount + userCount;
	const LNKFloat *dataMatrix = _unrolledGradient;
	const LNKFloat *thetaMatrix = _unrolledGradient + rowCount * _featureCount;
	
	LNKFloat *unrolledGradient = LNKFloatCalloc(unrolledRowCount * _featureCount);
	
	LNKFloat *dataGradient = unrolledGradient;
	LNKFloat *thetaGradient = unrolledGradient + rowCount * _featureCount;
	
	const BOOL regularizationEnabled = _regularizationConfiguration != nil;
	const LNKFloat lambda = _regularizationConfiguration.lambda;
	
	for (LNKSize exampleIndex = 0; exampleIndex < rowCount; exampleIndex++) {
		const LNKFloat *example = dataMatrix + _featureCount * exampleIndex;
		const LNKFloat *output = [outputMatrix rowAtIndex:exampleIndex];
		const LNKFloat *indicator = [_indicatorMatrix rowAtIndex:exampleIndex];
		
		LNKFloat *dataGradientLocation = dataGradient + exampleIndex * _featureCount;
		
		for (LNKSize userIndex = 0; userIndex < userCount; userIndex++) {
			if (indicator[userIndex]) {
				// inner = (X(example,:) . Theta(user,:)) - Y(example,user)
				const LNKFloat *user = thetaMatrix + userIndex * _featureCount;
				
				LNKFloat result;
				LNK_dotpr(example, UNIT_STRIDE, user, UNIT_STRIDE, &result, _featureCount);
				
				const LNKFloat inner = result - output[userIndex];
				
				// X_gradient += inner * Theta(user,:)
				LNK_vsma(user, UNIT_STRIDE, &inner, dataGradientLocation, UNIT_STRIDE, dataGradientLocation, UNIT_STRIDE, _featureCount);
				
				// Theta_gradient += inner * X(example,:)
				LNKFloat *const thetaGradientLocation = thetaGradient + userIndex * _featureCount;
				LNK_vsma(example, UNIT_STRIDE, &inner, thetaGradientLocation, UNIT_STRIDE, thetaGradientLocation, UNIT_STRIDE, _featureCount);
			}
		}
		
		if (regularizationEnabled) {
			// X_gradient(example,:) += lambda * X(example,:)
			LNK_vsma(example, UNIT_STRIDE, &lambda, dataGradientLocation, UNIT_STRIDE, dataGradientLocation, UNIT_STRIDE, _featureCount);
		}
	}
	
	if (regularizationEnabled) {
		for (LNKSize userIndex = 0; userIndex < userCount; userIndex++) {
			LNKFloat *const thetaGradientLocation = thetaGradient + userIndex * _featureCount;
			
			// Theta_gradient(user,:) += lambda * Theta(user,:)
			LNK_vsma(thetaMatrix + userIndex * _featureCount, UNIT_STRIDE, &lambda, thetaGradientLocation, UNIT_STRIDE, thetaGradientLocation, UNIT_STRIDE, _featureCount);
		}
	}
	
	return unrolledGradient;
}

- (void)loadThetaMatrix:(LNKMatrix *)thetaMatrix {
	NSParameterAssert(thetaMatrix);
	NSParameterAssert(thetaMatrix.columnCount == _featureCount);
	
	LNKMatrix *outputMatrix = self.matrix;
	const LNKSize userCount = outputMatrix.columnCount;
	const LNKSize rowCount = outputMatrix.rowCount;
	
	LNKFloatCopy(_unrolledGradient + _featureCount * rowCount, thetaMatrix.matrixBuffer, userCount * thetaMatrix.columnCount);
}

- (void)loadDataMatrix:(LNKMatrix *)dataMatrix {
	NSParameterAssert(dataMatrix);
	NSParameterAssert(dataMatrix.columnCount == _featureCount);
	
	const LNKSize rowCount = self.matrix.rowCount;
	LNKFloatCopy(_unrolledGradient, dataMatrix.matrixBuffer, rowCount * _featureCount);
}

- (void)train {
	NSAssert([self.algorithm isKindOfClass:[LNKOptimizationAlgorithmCG class]], @"Unexpected algorithm");
	LNKOptimizationAlgorithmCG *algorithm = self.algorithm;
	
	const LNKSize totalCount = [self _totalUnitCount];
	const LNKFloat epsilon = 1.5;
	
	for (LNKSize n = 0; n < totalCount; n++) {
		_unrolledGradient[n] = (((LNKFloat) arc4random_uniform(UINT32_MAX) / UINT32_MAX) - 0.5) * 2 * epsilon;
	}
	
	[algorithm runWithParameterVector:LNKVectorCreateUnsafe(_unrolledGradient, totalCount) rowCount:self.matrix.rowCount delegate:self];
}

- (LNKSize)_totalUnitCount {
	LNKMatrix *matrix = self.matrix;
	const LNKSize userCount = matrix.columnCount;
	const LNKSize rowCount = matrix.rowCount;
	const LNKSize unrolledRowCount = rowCount + userCount;
	return unrolledRowCount * _featureCount;
}

- (void)optimizationAlgorithmWillBeginWithInputVector:(const LNKFloat *)inputVector {
	LNKFloatCopy(_unrolledGradient, inputVector, [self _totalUnitCount]);
}

- (LNKFloat)costForOptimizationAlgorithm {
	return [self _evaluateCostFunction];
}

- (void)computeGradientForOptimizationAlgorithm:(LNKFloat *)gradientVector inRange:(LNKRange)range {
#pragma unused(range)
	const LNKFloat *gradient = [self _computeGradient];
	LNKFloatCopy(gradientVector, gradient, [self _totalUnitCount]);
	free((void *)gradient);
}

- (NSIndexSet *)findTopK:(LNKSize)k predictionsForUser:(LNKSize)userIndex {
	if (k == 0)
		[NSException raise:NSInvalidArgumentException format:@"The parameter k must be greater than 0"];
	
	LNKMatrix *outputMatrix = self.matrix;
	const LNKSize userCount = outputMatrix.columnCount;
	const LNKSize rowCount = outputMatrix.rowCount;
	
	const LNKFloat *dataMatrix = _unrolledGradient;
	const LNKFloat *thetaMatrix = _unrolledGradient + rowCount * _featureCount;
	
	LNKFloat *predictions = LNKFloatAlloc(userCount * rowCount);
	LNK_mmul(dataMatrix, UNIT_STRIDE, thetaMatrix, UNIT_STRIDE, predictions, UNIT_STRIDE, rowCount, userCount, _featureCount);
	
	NSMutableArray<NSDictionary *> *results = [NSMutableArray new];
	
	for (LNKSize row = 0; row < rowCount; row++) {
		LNKFloat prediction = predictions[row * _featureCount + userIndex];
		
		[results addObject:@{ @"prediction": @(prediction), @"index": @(row) }];
	}
	
	free(predictions);
	[results sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"prediction" ascending:NO] ]];
	
	NSMutableIndexSet *indices = [NSMutableIndexSet new];
	
	for (LNKSize n = 0; n < k; n++) {
		NSDictionary *result = results[n];
		[indices addIndex:[result[@"index"] unsignedIntegerValue]];
	}
	
	[results release];
	
	return [indices autorelease];
}

- (void)dealloc {
	free(_unrolledGradient);
	
	[_indicatorMatrix release];
	[_regularizationConfiguration release];
	
	[super dealloc];
}

@end
