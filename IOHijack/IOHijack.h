#import <Foundation/Foundation.h>

@class IOHijack;
@protocol IOHijackDelegate
- (void)hijacker:(IOHijack*)hijacker gotText: (NSString*)text;
@end

@interface IOHijack : NSObject

// Make a new hijacker with the given original file descriptor.  Hijacking is off by default.
+ (id)hijackerWithFd:(int)fileDescriptor;


@property (weak, nonatomic) id <IOHijackDelegate> delegate;
@property (nonatomic) void (*dataCallback)(NSString* text);


@property (readonly, assign, nonatomic) int fileDescriptor;

// Start/stop the hijacking process.
- (void) startHijacking;
- (void) stopHijacking;

// Start/stop the replication process.
- (void) startReplicating;
- (void) stopReplicating;

@end // IOHijack




