//
//  CoreGraphics.h
//  RACObjC
//
//  GNUstep only, for the specs. gnustep-base already defines CGFloat,
//  CGPoint, CGSize and CGRect (CoreFoundation/CFCGTypes.h); this adds the
//  constructors, comparisons and zero values the specs use.
//

#import <Foundation/Foundation.h>

static inline CGPoint CGPointMake(CGFloat x, CGFloat y) {
	CGPoint point = { x, y };
	return point;
}

static inline CGSize CGSizeMake(CGFloat width, CGFloat height) {
	CGSize size = { width, height };
	return size;
}

static inline CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
	CGRect rect = { { x, y }, { width, height } };
	return rect;
}

static inline bool CGPointEqualToPoint(CGPoint point1, CGPoint point2) {
	return point1.x == point2.x && point1.y == point2.y;
}

static inline bool CGSizeEqualToSize(CGSize size1, CGSize size2) {
	return size1.width == size2.width && size1.height == size2.height;
}

static inline bool CGRectEqualToRect(CGRect rect1, CGRect rect2) {
	return CGPointEqualToPoint(rect1.origin, rect2.origin) && CGSizeEqualToSize(rect1.size, rect2.size);
}

#define CGPointZero CGPointMake(0, 0)
#define CGSizeZero CGSizeMake(0, 0)
#define CGRectZero CGRectMake(0, 0, 0, 0)
