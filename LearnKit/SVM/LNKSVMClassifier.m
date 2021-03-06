//
//  LNKSVMClassifier.m
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKSVMClassifier.h"

#import "LNKAccelerate.h"
#import "LNKClassifierPrivate.h"
#import "LNKMatrix.h"
#import "LNKOptimizationAlgorithm.h"
#import "LNKPredictorPrivate.h"
#import "LNKRegularizationConfiguration.h"

@implementation LNKSVMClassifier {
	LNKFloat *_theta;
}

+ (NSArray<Class> *)supportedAlgorithms {
	return @[ [LNKOptimizationAlgorithmStochasticGradientDescent class] ];
}

+ (NSArray<NSNumber *> *)supportedImplementationTypes {
	return @[ @(LNKImplementationTypeAccelerate) ];
}

+ (Class)_classForImplementationType:(LNKImplementationType)implementationType optimizationAlgorithm:(Class)algorithm {
#pragma unused(implementationType)
#pragma unused(algorithm)
	
	return [self class];
}

- (instancetype)initWithMatrix:(LNKMatrix *)matrix implementationType:(LNKImplementationType)implementation optimizationAlgorithm:(id<LNKOptimizationAlgorithm>)algorithm classes:(LNKClasses *)classes {
	if (classes.count != 2) {
		[NSException raise:NSInvalidArgumentException format:@"Two output classes must be specified"];
	}

	if (matrix.hasBiasColumn) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Bias columns are added to matrices automatically by SVM classifiers." userInfo:nil];
	}

	LNKMatrix *const workingMatrix = [matrix matrixByAddingBiasColumn];
	
	if (!(self = [super initWithMatrix:workingMatrix implementationType:implementation optimizationAlgorithm:algorithm classes:classes])) {
		return nil;
	}
	
	_theta = LNKFloatCalloc(workingMatrix.columnCount);
	
	return self;
}

- (void)train {
	NSAssert([self.algorithm isKindOfClass:[LNKOptimizationAlgorithmStochasticGradientDescent class]], @"Unexpected algorithm");
	LNKOptimizationAlgorithmStochasticGradientDescent *algorithm = self.algorithm;
	
	LNKMatrix *matrix = self.matrix;
	const LNKSize epochCount = algorithm.iterationCount;
	const LNKSize stepCount = algorithm.stepCount;
	const LNKSize columnCount = matrix.columnCount;
	const LNKFloat *outputVector = matrix.outputVector;
	const LNKFloat lambda = _regularizationConfiguration.lambda;
	
	LNKFloat *workgroupCC = LNKFloatAlloc(columnCount);
	LNKFloat *workgroupCC2 = LNKFloatAlloc(columnCount);
	
	id <LNKAlpha> alphaBox = algorithm.alpha;
	
	for (LNKSize epoch = 0; epoch < epochCount; epoch++) {
		const LNKFloat alpha = [alphaBox valueWithEpoch:epoch];
		
		for (LNKSize step = 0; step < stepCount; step++) {
			const LNKSize index = arc4random_uniform((uint32_t)matrix.rowCount);
			const LNKFloat *row = [matrix rowAtIndex:index];
			const LNKFloat output = outputVector[index];
			
			// Gradient (if y_k (Theta . x) >= 1):
			//     Theta -= alpha * (lambda * Theta)
			// Else:
			//     Theta -= alpha * (lambda * Theta - y_k * x)
			LNKFloat inner;
			LNK_dotpr(row, UNIT_STRIDE, _theta, UNIT_STRIDE, &inner, columnCount);
			inner *= output;
			
			if (inner >= 1) {
				LNK_vsmul(_theta, UNIT_STRIDE, &lambda, workgroupCC, UNIT_STRIDE, columnCount);
			}
			else {
				LNK_vsmul(_theta, UNIT_STRIDE, &lambda, workgroupCC, UNIT_STRIDE, columnCount);
				const LNKFloat negOutput = -output;
				LNK_vsma(row, UNIT_STRIDE, &negOutput, workgroupCC, UNIT_STRIDE, workgroupCC, UNIT_STRIDE, columnCount);
			}

			const LNKFloat negAlpha = -alpha;
			LNK_vsma(workgroupCC, UNIT_STRIDE, &negAlpha, _theta, UNIT_STRIDE, _theta, UNIT_STRIDE, columnCount);
		}
	}
	
	free(workgroupCC);
	free(workgroupCC2);
}

- (LNKFloat)_evaluateCostFunction {
	// Hinge-loss cost function: sum over N: max(0, 1 - y_k (Theta . x + b)) + 0.5 * lambda * Theta^T Theta
	LNKMatrix *const matrix = self.matrix;
	const LNKSize rowCount = matrix.rowCount;
	const LNKSize columnCount = matrix.columnCount;
	const LNKFloat *const outputVector = matrix.outputVector;
	const LNKFloat lambda = _regularizationConfiguration.lambda;

	LNKFloat cost = 0;

	for (LNKSize exampleIndex = 0; exampleIndex < rowCount; exampleIndex++) {
		LNKFloat y = 0;
		LNK_dotpr(_theta, UNIT_STRIDE, [matrix rowAtIndex:exampleIndex], UNIT_STRIDE, &y, columnCount);
		//TODO: include the +b term
		
		cost += MAX(0, 1 - outputVector[exampleIndex] * y);
	}

	LNKFloat thetaSquared = 0;
	LNK_dotpr(_theta, UNIT_STRIDE, _theta, UNIT_STRIDE, &thetaSquared, columnCount);
	cost += 0.5 * lambda * thetaSquared;

	return cost;
}

- (id)predictValueForFeatureVector:(LNKVector)featureVector {
	if (!featureVector.data)
		[NSException raise:NSInvalidArgumentException format:@"The feature vector must not be NULL"];
	
	const LNKSize columnCount = self.matrix.columnCount;
	const LNKSize biasOffset = 1;

	if (columnCount != featureVector.length + biasOffset) {
		[NSException raise:NSInvalidArgumentException format:@"The length of the feature vector must match the number of columns in the training matrix"];
	}

	LNKFloat *featuresWithBias = LNKFloatAlloc(featureVector.length + biasOffset);
	featuresWithBias[0] = 1;
	LNKFloatCopy(featuresWithBias + biasOffset, featureVector.data, featureVector.length);
	
	LNKFloat result;
	LNK_dotpr(featuresWithBias, UNIT_STRIDE, _theta, UNIT_STRIDE, &result, columnCount + biasOffset);

	free(featuresWithBias);
	
	return @(result);
}

- (LNKFloat)computeClassificationAccuracyOnMatrix:(LNKMatrix *)matrix {
	const LNKSize rowCount = matrix.rowCount;
	const LNKSize columnCount = matrix.columnCount;
	const LNKFloat *outputVector = matrix.outputVector;
	
	LNKSize hits = 0;
	
	for (LNKSize m = 0; m < rowCount; m++) {
		id predictedValue = [self predictValueForFeatureVector:LNKVectorCreateUnsafe([matrix rowAtIndex:m], columnCount)];
		NSAssert([predictedValue isKindOfClass:[NSNumber class]], @"Unexpected value");
		
		const LNKFloat value = [predictedValue LNKFloatValue];
		
		if (value * outputVector[m] > 0)
			hits++;
	}
	
	return (LNKFloat)hits / rowCount;
}

- (void)dealloc {
	free(_theta);
	[_regularizationConfiguration release];
	
	[super dealloc];
}

@end
