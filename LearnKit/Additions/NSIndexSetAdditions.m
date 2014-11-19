//
//  NSIndexSetAdditions.m
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "NSIndexSetAdditions.h"

@implementation NSIndexSet (Additions)

- (NSIndexSet *)indexSetByRemovingIndex:(NSUInteger)index {
	if (![self containsIndex:index])
		return self;
	
	NSMutableIndexSet *mutableSelf = [self mutableCopy];
	[mutableSelf removeIndex:index];
	
	NSIndexSet *immutableCopy = [mutableSelf copy];
	[mutableSelf release];
	
	return [immutableCopy autorelease];
}

@end
