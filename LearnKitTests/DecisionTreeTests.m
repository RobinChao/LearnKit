//
//  DecisionTreeTests.m
//  LearnKit Tests
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "LNKMatrixCSV.h"
#import "LNKDecisionTreeClassifier.h"
#import "LNKRandomForestClassifier.h"

@interface DecisionTreeTests : XCTestCase
@end

@implementation DecisionTreeTests

- (void)testWaitTimesSet {
	NSBundle *bundle = [NSBundle bundleForClass:self.class];
	NSURL *matrixURL = [bundle URLForResource:@"WillWait" withExtension:@"csv"];
	
	LNKMatrix *matrix = [[LNKMatrix alloc] initWithCSVFileAtURL:matrixURL];
	
	LNKDecisionTreeClassifier *classifier = [[LNKDecisionTreeClassifier alloc] initWithMatrix:matrix
																		   implementationType:LNKImplementationTypeAccelerate
																		optimizationAlgorithm:nil
																					  classes:[LNKClasses withCount:2]]; /* binary */
	[matrix release];
	
	[classifier registerBooleanValueForColumnAtIndex:0];
	[classifier registerBooleanValueForColumnAtIndex:1];
	[classifier registerBooleanValueForColumnAtIndex:2];
	[classifier registerBooleanValueForColumnAtIndex:3];
	[classifier registerCategoricalValues:3 forColumnAtIndex:4];
	[classifier registerCategoricalValues:3 forColumnAtIndex:5];
	[classifier registerBooleanValueForColumnAtIndex:6];
	[classifier registerBooleanValueForColumnAtIndex:7];
	[classifier registerCategoricalValues:4 forColumnAtIndex:8];
	[classifier registerCategoricalValues:4 forColumnAtIndex:9];
	
	[classifier validate];
	[classifier train];
	
	const LNKFloat accuracy = [classifier computeClassificationAccuracyOnMatrix:matrix];
	XCTAssertEqualWithAccuracy(accuracy, 1.0, 0.01);
	
	const LNKSize newExampleLength = 10;
	LNKFloat newExample[newExampleLength] = { 0, 0, 0, 1, 1, 2, 1, 0, 3, 0 };
	LNKClass *class = [classifier predictValueForFeatureVector:LNKVectorCreateUnsafe(newExample, newExampleLength)];
	XCTAssertEqual(class.unsignedIntegerValue, 1UL);
	
	[classifier release];
}

- (void)testHiring {
	NSBundle *bundle = [NSBundle bundleForClass:self.class];
	NSURL *matrixURL = [bundle URLForResource:@"Hiring" withExtension:@"csv"];
	LNKMatrix *matrix = [[LNKMatrix alloc] initWithCSVFileAtURL:matrixURL];
	XCTAssertNotNil(matrix);

	LNKDecisionTreeClassifier *classifier = [[LNKDecisionTreeClassifier alloc] initWithMatrix:matrix
																		   implementationType:LNKImplementationTypeAccelerate
																		optimizationAlgorithm:nil
																					  classes:[LNKClasses withCount:2]]; /* binary */
	[matrix release];

	[classifier registerCategoricalValues:3 forColumnAtIndex:0];
	[classifier registerCategoricalValues:3 forColumnAtIndex:1];
	[classifier registerBooleanValueForColumnAtIndex:2];
	[classifier registerBooleanValueForColumnAtIndex:3];

	[classifier validate];
	[classifier train];

	const LNKSize newExampleLength = 4;
	LNKFloat newExample1[newExampleLength] = { 0, 0, 1, 0 };
	LNKFloat newExample2[newExampleLength] = { 0, 0, 1, 1 };
	LNKClass *class1 = [classifier predictValueForFeatureVector:LNKVectorCreateUnsafe(newExample1, newExampleLength)];
	XCTAssertEqual(class1.unsignedIntegerValue, 1UL);
	LNKClass *class2 = [classifier predictValueForFeatureVector:LNKVectorCreateUnsafe(newExample2, newExampleLength)];
	XCTAssertEqual(class2.unsignedIntegerValue, 0UL);

	[classifier release];
}

- (void)testHiringRandomForest {
	NSBundle *bundle = [NSBundle bundleForClass:self.class];
	NSURL *matrixURL = [bundle URLForResource:@"Hiring" withExtension:@"csv"];
	LNKMatrix *matrix = [[LNKMatrix alloc] initWithCSVFileAtURL:matrixURL];
	XCTAssertNotNil(matrix);

	LNKRandomForestClassifier *classifier = [[LNKRandomForestClassifier alloc] initWithMatrix:matrix
																		   implementationType:LNKImplementationTypeAccelerate
																		optimizationAlgorithm:nil
																					  classes:[LNKClasses withCount:2]]; /* binary */
	classifier.maxExampleCount = 6;
	[matrix release];

	[classifier registerCategoricalValues:3 forColumnAtIndex:0];
	[classifier registerCategoricalValues:3 forColumnAtIndex:1];
	[classifier registerBooleanValueForColumnAtIndex:2];
	[classifier registerBooleanValueForColumnAtIndex:3];

	[classifier validate];
	[classifier train];

	const LNKSize newExampleLength = 4;
	LNKFloat newExample1[newExampleLength] = { 0, 0, 1, 0 };
	LNKFloat newExample2[newExampleLength] = { 0, 0, 1, 1 };
	LNKClass *class1 = [classifier predictValueForFeatureVector:LNKVectorCreateUnsafe(newExample1, newExampleLength)];
	XCTAssertEqual(class1.unsignedIntegerValue, 1UL);
	LNKClass *class2 = [classifier predictValueForFeatureVector:LNKVectorCreateUnsafe(newExample2, newExampleLength)];
	XCTAssertEqual(class2.unsignedIntegerValue, 0UL);

	[classifier release];
}

@end
