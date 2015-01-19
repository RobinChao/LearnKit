//
//  LNKNeuralNetClassifier.h
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKClassifier.h"
#import "LNKNeuralNetLayer.h"

/// For neural network classifiers, the only supported algorithm is CG.
/// Predicted values are of type LNKClass.
@interface LNKNeuralNetClassifier : LNKClassifier

// Each neural network has an input layer whose size is equal to the matrix's feature count,
// an output layer whose size is equal to the number of classes, and at least one hidden layer.

/// At least one hidden layer must be specified.
/// The matrix must have a bias column.
- (instancetype)initWithMatrix:(LNKMatrix *)matrix
			implementationType:(LNKImplementationType)implementation
		 optimizationAlgorithm:(id<LNKOptimizationAlgorithm>)algorithm
				  hiddenLayers:(NSArray *)layers
					   classes:(LNKClasses *)classes NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithMatrix:(LNKMatrix *)matrix
			implementationType:(LNKImplementationType)implementation
		 optimizationAlgorithm:(id<LNKOptimizationAlgorithm>)algorithm
					   classes:(LNKClasses *)classes NS_UNAVAILABLE;

@property (nonatomic, readonly) LNKSize hiddenLayerCount;

- (LNKNeuralNetLayer *)hiddenLayerAtIndex:(LNKSize)index;

#warning TODO: assert correct values
#warning TODO: better way of specifying classes

@end
