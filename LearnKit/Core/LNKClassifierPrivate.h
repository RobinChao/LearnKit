//
//  LNKClassifierPrivate.h
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKClassifier.h"

@interface LNKClassifier (Private)

/// Instead of overriding -predictValueForFeatureVector:, classifiers should override the following method and provide probabilities for all classes.
- (void)_predictValueForFeatureVector:(LNKVector)featureVector;

- (void)_didPredictProbability:(LNKFloat)probability forClass:(LNKClass *)class;

@end
