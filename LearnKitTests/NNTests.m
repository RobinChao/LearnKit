//
//  NNTests.m
//  LearnKit Tests
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "LNKConfusionMatrix.h"
#import "LNKMatrix.h"
#import "LNKNeuralNetClassifier.h"
#import "LNKNeuralNetClassifierPrivate.h"
#import "LNKOptimizationAlgorithm.h"
#import "LNKPredictorPrivate.h"
#import "LNKRegularizationConfiguration.h"
#import "LNKUtilities.h"

@interface NNTests : XCTestCase

@end

@implementation NNTests

#define DACCURACY 0.01

- (LNKNeuralNetClassifier *)_preLearnedClassifierWithRegularization:(BOOL)regularize matrix:(LNKMatrix **)outMatrix {
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *matrixURL = [bundle URLForResource:@"ex3data1_X" withExtension:@"dat"];
	NSURL *outputVectorURL = [bundle URLForResource:@"ex3data1_y" withExtension:@"dat"];
	NSURL *theta1URL = [bundle URLForResource:@"ex3data1_theta1" withExtension:@"dat"];
	NSURL *theta2URL = [bundle URLForResource:@"ex3data1_theta2" withExtension:@"dat"];
	
	LNKMatrix *matrix = [[LNKMatrix alloc] initWithBinaryMatrixAtURL:matrixURL
													 matrixValueType:LNKValueTypeDouble
												   outputVectorAtURL:outputVectorURL
											   outputVectorValueType:LNKValueTypeUInt8
															rowCount:5000 columnCount:400];
	
	LNKOptimizationAlgorithmCG *algorithm = [[LNKOptimizationAlgorithmCG alloc] init];
	
	NSArray<LNKNeuralNetLayer *> *hiddenLayers = @[ [[[LNKNeuralNetSigmoidLayer alloc] initWithUnitCount:25] autorelease] ];
	LNKNeuralNetLayer *outputLayer = [[LNKNeuralNetSigmoidLayer alloc] initWithClasses:[LNKClasses withRange:NSMakeRange(1, 10)]];
	
	LNKNeuralNetClassifier *classifier = [[LNKNeuralNetClassifier alloc] initWithMatrix:matrix
																	 implementationType:LNKImplementationTypeAccelerate
																  optimizationAlgorithm:algorithm
																		   hiddenLayers:hiddenLayers
																			outputLayer:outputLayer];

	if (regularize) {
		classifier.regularizationConfiguration = [LNKRegularizationConfiguration withLambda:1];
	}

	if (outMatrix) {
		*outMatrix = [[matrix retain] autorelease];
	}

	[matrix release];
	[algorithm release];
	[outputLayer release];
	
	NSData *thetaVectorData1 = LNKLoadBinaryMatrixFromFileAtURL(theta1URL, 401 * 25 * sizeof(double));
	NSData *thetaVectorData2 = LNKLoadBinaryMatrixFromFileAtURL(theta2URL,  26 * 10 * sizeof(double));
	
	const LNKFloat *thetaVector1 = (const LNKFloat *)thetaVectorData1.bytes;
	const LNKFloat *thetaVector2 = (const LNKFloat *)thetaVectorData2.bytes;
	[classifier _setThetaVector:thetaVector1 transpose:YES forLayerAtIndex:0 rows:25 columns:401];
	[classifier _setThetaVector:thetaVector2 transpose:YES forLayerAtIndex:1 rows:10 columns:26];
	
	return [classifier autorelease];
}

- (void)test1FeedForwardPrediction {
	LNKMatrix *matrix = nil;
	LNKClassifier *classifier = [self _preLearnedClassifierWithRegularization:NO matrix:&matrix];
	[self measureBlock:^{
		XCTAssertGreaterThanOrEqual([classifier computeClassificationAccuracyOnMatrix:matrix], 0.97, @"Unexpectedly low classification rate");
	}];
}

- (void)test2CostFunction {
	LNKMatrix *matrix = nil;
	LNKClassifier *classifier = [self _preLearnedClassifierWithRegularization:NO matrix:&matrix];
	[self measureBlock:^{
		XCTAssertEqualWithAccuracy(0.287629, [classifier _evaluateCostFunction], DACCURACY, @"Incorrect cost");
	}];
}

- (void)test3CostFunctionRegularized {
	LNKMatrix *matrix = nil;
	LNKClassifier *classifier = [self _preLearnedClassifierWithRegularization:YES matrix:&matrix];
	[self measureBlock:^{
		XCTAssertEqualWithAccuracy(0.383770, [classifier _evaluateCostFunction], DACCURACY, @"Incorrect cost");
	}];
}

- (void)test4Training {
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *matrixURL = [bundle URLForResource:@"ex3data1_X" withExtension:@"dat"];
	NSURL *outputVectorURL = [bundle URLForResource:@"ex3data1_y" withExtension:@"dat"];
	
	LNKMatrix *matrix = [[LNKMatrix alloc] initWithBinaryMatrixAtURL:matrixURL
													 matrixValueType:LNKValueTypeDouble
												   outputVectorAtURL:outputVectorURL
											   outputVectorValueType:LNKValueTypeUInt8
															rowCount:5000 columnCount:400];
	
	LNKOptimizationAlgorithmCG *algorithm = [[LNKOptimizationAlgorithmCG alloc] init];
	algorithm.iterationCount = 400;
	
	NSArray<LNKNeuralNetLayer *> *hiddenLayers = @[ [[[LNKNeuralNetSigmoidLayer alloc] initWithUnitCount:25] autorelease] ];
	LNKNeuralNetLayer *outputLayer = [[LNKNeuralNetSigmoidLayer alloc] initWithClasses:[LNKClasses withRange:NSMakeRange(1, 10)]];
	
	LNKNeuralNetClassifier *classifier = [[LNKNeuralNetClassifier alloc] initWithMatrix:matrix
																	 implementationType:LNKImplementationTypeAccelerate
																  optimizationAlgorithm:algorithm
																		   hiddenLayers:hiddenLayers
																			outputLayer:outputLayer];

	[algorithm release];
	[outputLayer release];
	
	[classifier train];
	
	XCTAssertGreaterThanOrEqual([classifier computeClassificationAccuracyOnMatrix:matrix], 0.95, @"Poor accuracy");
	[matrix release];
	[classifier release];
}

- (void)test5ConfusionMatrix {
	LNKMatrix *matrix = nil;
	LNKClassifier *const classifier = [self _preLearnedClassifierWithRegularization:NO matrix:&matrix];
	LNKConfusionMatrix *const confusionMatrix = [classifier computeConfusionMatrixOnMatrix:matrix];
	LNKClass *const eight = [LNKClass classWithUnsignedInteger:8];
	const LNKSize examples = matrix.rowCount / 10;
	XCTAssertGreaterThanOrEqual([confusionMatrix frequencyForTrueClass:eight predictedClass:eight], 0.8 * examples);
}

@end
