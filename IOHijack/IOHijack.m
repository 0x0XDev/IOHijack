#import "IOHijack.h"

// pipe() fills in an array of two file descriptors.  Whats written to the write-side
// (file descriptor 1) appears on the the read-side (file descriptor 0). 
enum { kReadSide, kWriteSide };  // The two sides to every pipe()

@interface IOHijack () {
    int _pipe[2];   // populated by pipe()
    CFRunLoopSourceRef _monitorRunLoopSource;  // Notifies us of activity on the pipe.
}
@property (assign, nonatomic) int fileDescriptor;     // The fd we're hijacking
@property (assign, nonatomic) int oldFileDescriptor;  // The original fd, for unhijacking

@property (assign, nonatomic) BOOL hijacking;   // Are we hijacking or replicating?
@property (assign, nonatomic) BOOL replicating;

@end



@implementation IOHijack

+ (id)hijackerWithFd:(int)fileDescriptor {
    IOHijack *hijacker = self.class.new;
    hijacker.fileDescriptor = fileDescriptor;
    return hijacker;
}


- (void)startHijacking {
    if (self.hijacking) return;

    // Unix API is of the "return bad value, set errno" flavor.
    int result;
	
	// Turn off buffering for the stdout FILE (this is important, otherwise you might not see any output:
	setbuf(fdopen(self.fileDescriptor, "w"), NULL);

    // Make a copy of the file descriptor.  The dup2 will close it, but we want it
    // to stick around for restoration and replication.
    self.oldFileDescriptor = dup (self.fileDescriptor);
    if (self.oldFileDescriptor == -1) {
        assert (!"could not dup our fd");
        return;
    }

    // Make the pipe.  Anchor one end of the pipe where the original fd is.
    // The other end will go to a runloop source so we can find bytes written to it.
    result = pipe (_pipe);
    if (result == -1) {
        assert (!"could not make a pipe for standard out");
        return;
    }

    // Replace the file descriptor with one part (the writing side) of the pipe.
    result = dup2 (_pipe[kWriteSide], self.fileDescriptor);
    if (result == -1) {
        assert (!"could not dup2 our fd");
        return;
    }

    // Monitor the reading side of the pipe.
	
	NSFileHandle *wrapped_fh = [NSFileHandle.alloc initWithFileDescriptor: _pipe[kReadSide]];
	[wrapped_fh waitForDataInBackgroundAndNotify];

	wrapped_fh.readabilityHandler = ^(NSFileHandle * _Nonnull fh) {
		NSData *data = fh.availableData;
		if (data.length > 0) { // if data is found, re-register for more data (and print)
			[fh waitForDataInBackgroundAndNotify];
			NSString *str = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self notifyString:str];
			});
			// Now forward on to its original destination.
			if (self.replicating) {
				write(self.oldFileDescriptor, data.bytes, data.length);
			}
		}
	};
    self.hijacking = YES;
}

- (void)stopHijacking {
    if (!self.hijacking) return;

    int result;

    // Replace the file descriptor, which was our pipe, with the original one.
    // This closes the pipe.
    result = dup2 (self.oldFileDescriptor, self.fileDescriptor);
    if (result == -1) {
        assert(!"could not dup2 back");
        return;
    }
	[NSNotificationCenter.defaultCenter removeObserver:self];

    self.hijacking = NO;
}

- (void)startReplicating {
    self.replicating = YES;
}
- (void)stopReplicating {
    self.replicating = NO;
}

// We got some text!  Call the dataCallback!
- (void)notifyString:(NSString *)contents {
	if (self.delegate) [self.delegate hijacker:self gotText:contents];
	if (self.dataCallback) self.dataCallback(contents);
}
@end
