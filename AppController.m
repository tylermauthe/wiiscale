#import "AppController.h"

@implementation AppController

#pragma mark Window

- (id)init
{
    self = [super init];
    if (self) {
		weightSampleIndex = 0;
        weightReadCount = 0;
		if(!discovery) {
			[self performSelector:@selector(doDiscovery:) withObject:self afterDelay:0.0f];
		}
    }
    return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)awakeFromNib {
    
    NSImage *imageFromBundle = [NSImage imageNamed:@"lightning.png"];
    [statusImage setImage: imageFromBundle];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(expansionPortChanged:)
												 name:@"WiiRemoteExpansionPortChangedNotification"
											   object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
}

#pragma mark NSApplication

- (void)cleanUpConnection
{
    if(discovery) {
        [discovery stop];
        [discovery release];
        discovery = nil;
    }
    
    if(wii) {
        [wii closeConnection];
        [wii release];
        wii = nil;
    }
}

- (void) applicationWillTerminate:(NSApplication *)sender {
    [self cleanUpConnection];
}

#pragma mark Wii Balance Board

- (IBAction)confirmSaveData:(id)sender {
    NSString *csvPath = @"~/Desktop/weight.csv";
    csvPath = [csvPath stringByExpandingTildeInPath];
    
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:csvPath];
    
    NSData *weightData;
    if(file!=nil)
    {
        weightData = [self csvDataValueFromFloat:confirmedWeight withDelimeter:@","];
        [file truncateFileAtOffset:[file seekToEndOfFile]];
        [file writeData:weightData];
    }
    else
    {
        weightData = [self csvDataValueFromFloat:confirmedWeight];
        [[NSFileManager defaultManager] createFileAtPath:csvPath contents:weightData attributes:nil];
    }
    [self resetWindowAfterSaveData];
}

- (NSData *) csvDataValueFromFloat:(float)value {
    return [[NSString stringWithFormat:@"%f",value]
                dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *) csvDataValueFromFloat:(float)value withDelimeter: (NSString *)delimeter{
    return [[NSString stringWithFormat:[delimeter stringByAppendingString:@"%f"],value]
            dataUsingEncoding:NSUTF8StringEncoding];
}

- (IBAction)cancelSaveData:(id)sender {
    [self resetWindowAfterSaveData];
}

- (void)resetWindowAfterSaveData {
    [self.window removeChildWindow:saveWindow];
    [saveWindow close];
    haveConfirmedWeight = NO;
    sent = NO;
}

- (void)setUIToSearching {
    [spinner startAnimation:self];
    [bbstatus setStringValue:@"Searching..."];
    [fileConnect setTitle:@"Stop Searching for Balance Board"];
    [status setStringValue:@"Press the red 'sync' button..."];
}

- (IBAction)doDiscovery:(id)sender {
	
	if(!discovery) {
		discovery = [[WiiRemoteDiscovery alloc] init];
		[discovery setDelegate:self];
		[discovery start];
		
		[self setUIToSearching];
	}
    else {
        [self cleanUpConnection];
        
        [spinner stopAnimation:self];
        [bbstatus setStringValue:@"Disconnected"];
        [fileConnect setTitle:@"Connect to Balance Board"];
        [status setStringValue:@""];
	}
}

- (IBAction)doTare:(id)sender {
	tare = 0.0 - lastWeight;
}

#pragma mark Magic?

- (void)expansionPortChanged:(NSNotification *)nc{
    
	WiiRemote* tmpWii = (WiiRemote*)[nc object];
	
	// Check that the Wiimote reporting is the one we're connected to.
	if (![[tmpWii address] isEqualToString:[wii address]]){
		return;
	}
	
	if ([wii isExpansionPortAttached]){
		[wii setExpansionPortEnabled:YES];
	}
}

#pragma mark WiiRemoteDelegate methods

- (void) buttonChanged:(WiiButtonType) type isPressed:(BOOL) isPressed
{
	[self doTare:self];
}

- (void) wiiRemoteDisconnected:(IOBluetoothDevice*) device
{
	[spinner stopAnimation:self];
	[bbstatus setStringValue:@"Disconnected"];
	
	[device closeConnection];
}

#pragma mark WiiRemoteDelegate methods (optional)

// cooked values from the Balance Beam
- (void) balanceBeamKilogramsChangedTopRight:(float)topRight
                                 bottomRight:(float)bottomRight
                                     topLeft:(float)topLeft
                                  bottomLeft:(float)bottomLeft {
	if(!haveConfirmedWeight) {
        lastWeight = topRight + bottomRight + topLeft + bottomLeft;
        
        if(!tare) {
            [self doTare:self];
        }
        
        float trueWeight = lastWeight + tare;
        
        if(trueWeight > 10.0) {
            weightSamples[weightSampleIndex] = trueWeight;
            weightSampleIndex = (weightSampleIndex + 1) % 100;
            
            float sum = 0;
            float sum_sqrs = 0;
            
            for (int i = 0; i < 100; i++)
            {
                sum += weightSamples[i];
                sum_sqrs += weightSamples[i] * weightSamples[i];
            }
            
            avgWeight = sum / 100.0;
            float var = sum_sqrs / 100.0 - (avgWeight * avgWeight);
            float std_dev = sqrt(var);
            
            if(!sent)
                [status setStringValue:@"Please hold still..."];
            else
            {
                haveConfirmedWeight = YES;
                confirmedWeight = trueWeight;
                NSLog(@"%f",confirmedWeight);
                [self saveData];
                [status setStringValue:[NSString stringWithFormat:@"Sent weight of %4.1fkg.  Thanks!", avgWeight]];
            }
            
            if(std_dev < 0.1 && !sent)
            {
                weightReadCount++;
                if(weightReadCount>0)
                    sent = YES;
            }
            
        } else {
            sent = NO;
            [status setStringValue:@"Tap the button to tare, then step on..."];
        }
        
        [weight setStringValue:[NSString stringWithFormat:@"%4.1fkg  %4.1flbs", MAX(0.0, trueWeight), MAX(0.0, (trueWeight) * 2.20462262)]];
    }
}

- (void) saveData {
    //NSLog(@"%f",confirmedWeight);
    [weightToSave setStringValue:[[NSString alloc] initWithFormat:@"%f",confirmedWeight]];
    [self.window addChildWindow:saveWindow ordered:NSWindowAbove];
}

#pragma mark WiiRemoteDiscoveryDelegate methods

- (void) WiiRemoteDiscovered:(WiiRemote*)wiimote {
	
	[wii release];
	wii = [wiimote retain];
	[wii setDelegate:self];
    
	[spinner stopAnimation:self];
	[bbstatus setStringValue:@"Connected"];
	
	[status setStringValue:@"Tap the button to tare, then step on..."];
}

- (void) WiiRemoteDiscoveryError:(int)code {
	
	NSLog(@"Error: %u", code);
    
	// Keep trying...
	[spinner stopAnimation:self];
	[discovery stop];
	sleep(1);
	[discovery start];
	[spinner startAnimation:self];
}

- (void) willStartWiimoteConnections {
    
}
@end
