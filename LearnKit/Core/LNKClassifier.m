//
//  LNKClassifier.m
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKClassifier.h"

#import "LNKClassifierPrivate.h"
#import "LNKConfusionMatrixPrivate.h"
#import "LNKMatrix.h"
#import "LNKMatrixPrivate.h"

@implementation LNKClassifier {
	NSMapTable *_classesToProbabilities;
}

- (instancetype)initWithMatrix:(LNKMatrix *)matrix implementationType:(LNKImplementationType)implementation optimizationAlgorithm:(id<LNKOptimizationAlgorithm>)algorithm classes:(LNKClasses *)classes {
	NSParameterAssert(classes);
	
	if (!(self = [super initWithMatrix:matrix implementationType:implementation optimizationAlgorithm:algorithm]))
		return nil;
	
	_classes = [classes retain];
	
	return self;
}

- (void)_didPredictProbability:(LNKFloat)probability forClass:(LNKClass *)class {
	NSParameterAssert(class);
	
	if (!_classesToProbabilities)
		_classesToProbabilities = [[NSMapTable strongToStrongObjectsMapTable] retain];
	
	[_classesToProbabilities setObject:[NSNumber numberWithLNKFloat:probability] forKey:class];
}

- (void)_predictValueForFeatureVector:(LNKVector)featureVector {
#pragma unused(featureVector)
	
	NSAssertNotReachable(@"%s should be implemented by subclasses", __PRETTY_FUNCTION__);
}

- (id)predictValueForFeatureVector:(LNKVector)featureVector {
	NSParameterAssert(featureVector.data);
	NSParameterAssert(featureVector.length);

	[self _predictValueForFeatureVector:featureVector];

	LNKFloat bestProbability = -1;
	LNKClass *bestClass = nil;
	
	for (LNKClass *class in _classes) {
		LNKFloat probability = [[_classesToProbabilities objectForKey:class] LNKFloatValue];
		
		if (probability > bestProbability) {
			bestClass = class;
			bestProbability = probability;
		}
	}
	
	return bestClass;
}

- (LNKFloat)computeClassificationAccuracyOnMatrix:(LNKMatrix *)matrix {
	if (!matrix)
		[NSException raise:NSInvalidArgumentException format:@"The matrix must not be nil"];

	const LNKSize rowCount = matrix.rowCount;
	const LNKSize columnCount = matrix.columnCount;
	const LNKFloat *matrixBuffer = matrix.matrixBuffer;
	const LNKFloat *outputVector = matrix.outputVector;
	
	LNKSize hits = 0;
	
	for (LNKSize m = 0; m < rowCount; m++) {
		id predictedValue = [self predictValueForFeatureVector:LNKVectorCreateUnsafe(_ROW_IN_MATRIX_BUFFER(m), columnCount)];
		
		if ([predictedValue isEqual:[LNKClass classWithUnsignedInteger:outputVector[m]]])
			hits++;
	}
	
	return (LNKFloat)hits / rowCount;
}

- (LNKConfusionMatrix *)computeConfusionMatrixOnMatrix:(LNKMatrix *)matrix {
	if (!matrix) {
		[NSException raise:NSInvalidArgumentException format:@"The matrix must not be nil"];
	}

	const LNKSize rowCount = matrix.rowCount;
	const LNKSize columnCount = matrix.columnCount;
	const LNKFloat *const matrixBuffer = matrix.matrixBuffer;
	const LNKFloat *const outputVector = matrix.outputVector;

	LNKConfusionMatrix *const confusionMatrix = [[LNKConfusionMatrix alloc] init];

	for (LNKSize m = 0; m < rowCount; m++) {
		id predictedValue = [self predictValueForFeatureVector:LNKVectorCreateUnsafe(_ROW_IN_MATRIX_BUFFER(m), columnCount)];

		if (![predictedValue isKindOfClass:[LNKClass class]]) {
			continue;
		}

		LNKClass *const predictedClass = predictedValue;
		LNKClass *const trueClass = [LNKClass classWithUnsignedInteger:outputVector[m]];

		[confusionMatrix _incrementFrequencyForTrueClass:trueClass predictedClass:predictedClass];
	}

	return [confusionMatrix autorelease];
}

- (void)dealloc {
	[_classesToProbabilities release];
	[_classes release];
	[super dealloc];
}

@end
