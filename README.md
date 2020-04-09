# IOHijack
Redirect IO (stdout,stderr,..)

## Example

```objc
void gotText(NSString* text) {
  [fileHandle writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
}

IOHijack* stdoutHijacker = [IOHijack hijackerWithFd:fileno(stdout)];
stdoutHijacker.dataCallback = &gotText;
IOHijack* stderrHijacker = [IOHijack hijackerWithFd:fileno(stderr)];
stderrHijacker.dataCallback = &gotText;

[stdoutHijacker startHijacking];
[stderrHijacker startHijacking];


```
