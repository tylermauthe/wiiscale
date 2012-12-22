#import <Cocoa/Cocoa.h>

#import "WiiRemote.h"
#import "WiiRemoteDiscovery.h"

@interface AppController : NSWindowController<WiiRemoteDelegate, WiiRemoteDiscoveryDelegate, NSApplicationDelegate> {
    
	IBOutlet NSProgressIndicator* spinner;
	IBOutlet NSTextField* weight;
	IBOutlet NSTextField* status;
	IBOutlet NSTextField* bbstatus;
	IBOutlet NSMenuItem* fileConnect;
	IBOutlet NSMenuItem* fileTare;
    IBOutlet NSImageView *statusImage;
    IBOutlet NSWindow *saveWindow;
    IBOutlet NSTextField *weightToSave;
    
	WiiRemoteDiscovery* discovery;
	WiiRemote* wii;
	
	float tare;
	float avgWeight;
	float sentWeight;
	float lastWeight;
	float weightSamples[100];
	int weightSampleIndex;
    int weightReadCount;
	BOOL sent;
	float height_cm;
    
    float confirmedWeight;
    bool haveConfirmedWeight;
}
- (IBAction)confirmSaveData:(id)sender;
- (IBAction)cancelSaveData:(id)sender;
- (IBAction)doDiscovery:(id)sender;
- (IBAction)doTare:(id)sender;
@end
