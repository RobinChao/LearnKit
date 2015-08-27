//
//  LNKFastArray.m
//  LearnKit
//
//  Copyright (c) 2014 Matt Rajca. All rights reserved.
//

#import "LNKFastArray.h"

#define DEFAULT_COUNT 128

struct _LNKFastArray {
	LNKSize count;
	LNKSize capacity;
	LNKSize elementWidth;
	void *buffer;
};

LNKFastArrayRef LNKFastArrayCreate(LNKSize elementWidth) {
	NSCAssert(elementWidth, @"The element width must be greater than 0");
	
	LNKFastArrayRef array = malloc(sizeof(LNKFastArray));
	array->capacity = DEFAULT_COUNT;
	array->count = 0;
	array->elementWidth = elementWidth;
	array->buffer = malloc(elementWidth * DEFAULT_COUNT);
	return array;
}

void LNKFastArrayFree(LNKFastArrayRef array) {
	NSCAssert(array, @"The array must not be NULL");
	
	free(array->buffer);
	free(array);
}

void LNKFastArrayAddElement(LNKFastArrayRef array, void *bytes) {
	NSCAssert(array, @"The array must not be NULL");
	NSCAssert(bytes, @"The bytes buffer must not be NULL");
	
	if (array->count == array->capacity) {
		array->capacity *= 2;
		array->buffer = realloc(array->buffer, array->capacity * array->elementWidth);
	}
	
	char *buffer = (char *)array->buffer;
	memcpy(&buffer[array->count * array->elementWidth], bytes, array->elementWidth);
	array->count++;
}

void *LNKFastArrayElementAtIndex(LNKFastArrayRef array, LNKSize index) {
	NSCAssert(array, @"The array must not be NULL");
	NSCAssert(index < array->count, @"The index must be within bounds");
	
	char *bytes = (char *)array->buffer;
	return &bytes[index * array->elementWidth];
}

LNKSize LNKFastArrayElementCount(LNKFastArrayRef array) {
	NSCAssert(array, @"The array must not be NULL");
	
	return array->count;
}
