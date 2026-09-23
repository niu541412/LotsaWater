#import "LotsaView.h"

#import <sys/time.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

@interface LotsaView ()
-(void)localizeConfigView:(NSView *)rootView;
-(void)addScreenCaptureButtonToView:(NSView *)contentView;
-(void)updateScreenCaptureButton;
-(IBAction)requestScreenCaptureAccess:(id)sender;
-(NSBitmapImageRep *)captureWallpaperForScreen:(NSScreen *)screen API_AVAILABLE(macos(14.0));
@end



@implementation LotsaView

-(id)initWithFrame:(NSRect)frame isPreview:(BOOL)preview
{
	if((self=[super initWithFrame:frame isPreview:preview]))
	{
		ispreview=preview;

		savername=nil;
		configname=nil;
		clockwin=nil;
		clockpopup=nil;

		prevtime=starttime=0;

    }

    return self;
}

-(void)dealloc
{
//	[configname release];
//	[clockwin stopTimers];
//	[clockwin release];
//
//	[super dealloc];
}

-(void)finalize
{
	[clockwin stopTimers];
	[super finalize];
}

-(void)startAnimation
{
	[super startAnimation];

	if(!clockwin&&!ispreview)
	{
		int clocksize=[[self defaults] integerForKey:@"clockSize"];
		if(clocksize)
		{
			float divider;
			switch(clocksize)
			{
				case 1: divider=40; break;
				case 2: divider=24; break;
				default: divider=16; break;
			}

			clockwin=[[LotsaClockWindow alloc] initWithFont:[NSFont fontWithName:@"Futura-CondensedExtraBold" size:(double)self.frame.size.width/divider]];
			NSSize size=[clockwin frame].size;

			[clockwin setFrameOrigin:NSMakePoint(self.frame.size.width-size.width,self.frame.size.height-size.height)];
			[[self window] addChildWindow:clockwin ordered:NSWindowAbove];
		}
	}

	[self startAnimationWithDefaults:[self defaults]];
	prevtime=starttime=0;
}

-(void)startAnimationWithDefaults:(ScreenSaverDefaults *)defaults
{
}

-(BOOL)hasConfigureSheet
{
	return configname?YES:NO;
}

-(NSWindow *)configureSheet
{
	if(!configwindow)
	{
		NSNib *nib=[[NSNib alloc] initWithNibNamed:configname bundle:[NSBundle bundleForClass:[self class]]];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}
	if(!configwindow) return nil;

	ScreenSaverDefaults *defaults=[self defaults];
	[self updateConfigWindow:configwindow usingDefaults:defaults];
	[clockpopup selectItemAtIndex:[[self defaults] integerForKey:@"clockSize"]];
	[self localizeConfigView:[configwindow contentView]];
	[self addScreenCaptureButtonToView:[configwindow contentView]];
	[self updateScreenCaptureButton];

	return configwindow;
}

-(void)addScreenCaptureButtonToView:(NSView *)contentView
{
	if([contentView viewWithTag:541412]) return;
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSString *title=[bundle localizedStringForKey:@"ScreenCapture.allow"
		value:@"Allow Desktop Capture" table:@"ConfigSheet"];
	NSButton *button=[NSButton buttonWithTitle:title target:self
		action:@selector(requestScreenCaptureAccess:)];
	[button setTag:541412];
	[button setBezelStyle:NSBezelStyleRounded];
	[button setFrame:NSMakeRect(362,84,195,28)];
	[button setAutoresizingMask:NSViewMinXMargin|NSViewMaxYMargin];
	[contentView addSubview:button];
}

-(void)updateScreenCaptureButton
{
	NSButton *button=(NSButton *)[[configwindow contentView] viewWithTag:541412];
	if(!button) return;
	BOOL allowed=CGPreflightScreenCaptureAccess();
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	[button setTitle:[bundle localizedStringForKey:
		allowed?@"ScreenCapture.allowed":@"ScreenCapture.allow"
		value:allowed?@"Desktop Capture Allowed":@"Allow Desktop Capture"
		table:@"ConfigSheet"]];
	[button setEnabled:!allowed];
}

-(IBAction)requestScreenCaptureAccess:(id)sender
{
	BOOL allowed=CGPreflightScreenCaptureAccess()||CGRequestScreenCaptureAccess();
	[self updateScreenCaptureButton];
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSAlert *alert=[[NSAlert alloc] init];
	if(allowed)
	{
		[alert setMessageText:[bundle localizedStringForKey:@"ScreenCapture.granted.title"
			value:@"Screen capture is allowed" table:@"ConfigSheet"]];
		[alert setInformativeText:[bundle localizedStringForKey:@"ScreenCapture.granted.message"
			value:@"Close Screen Saver settings and reopen it before testing LotsaWater."
			table:@"ConfigSheet"]];
		[alert addButtonWithTitle:[bundle localizedStringForKey:@"ScreenCapture.ok"
			value:@"OK" table:@"ConfigSheet"]];
		[alert beginSheetModalForWindow:configwindow completionHandler:nil];
		return;
	}

	[alert setMessageText:[bundle localizedStringForKey:@"ScreenCapture.required.title"
		value:@"Screen capture permission is required" table:@"ConfigSheet"]];
	[alert setInformativeText:[bundle localizedStringForKey:@"ScreenCapture.required.message"
		value:@"Enable the screen saver host in Privacy & Security, then reopen Screen Saver settings."
		table:@"ConfigSheet"]];
	[alert addButtonWithTitle:[bundle localizedStringForKey:@"ScreenCapture.openSettings"
		value:@"Open Privacy Settings" table:@"ConfigSheet"]];
	[alert addButtonWithTitle:[bundle localizedStringForKey:@"ScreenCapture.cancel"
		value:@"Cancel" table:@"ConfigSheet"]];
	[alert beginSheetModalForWindow:configwindow completionHandler:^(NSModalResponse response) {
		if(response==NSAlertFirstButtonReturn)
		{
			NSURL *url=[NSURL URLWithString:
				@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
	}];
}

-(void)localizeConfigView:(NSView *)rootView
{
	// This project still uses a compiled legacy NIB.  Modern nib localization
	// does not apply its external strings table to those archived controls, so
	// localize their visible titles after unarchiving.
	NSDictionary *keys=@{
		@"OK":@"83.title", @"Cancel":@"84.title",
		@"Detail:":@"86.title", @"Accuracy:":@"87.title",
		@"High":@"88.title", @"Low":@"89.title",
		@"Slow motion:":@"93.title", @"Slow":@"94.title",
		@"Normal":@"95.title", @"Rainfall:":@"98.title",
		@"Water depth:":@"99.title", @"Pouring":@"100.title",
		@"Gentle":@"101.title", @"Deep":@"102.title",
		@"Shallow":@"103.title", @"Image:":@"106.title",
		@"None":@"69.title", @"Small":@"71.title",
		@"Medium":@"68.title", @"Large":@"70.title",
		@"Dark":@"109.title", @"Dimming:":@"111.title",
		@"Clock:":@"112.title"
	};
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSCharacterSet *whitespace=[NSCharacterSet whitespaceAndNewlineCharacterSet];

	if([rootView isKindOfClass:[NSPopUpButton class]])
	{
		for(NSMenuItem *item in [(NSPopUpButton *)rootView itemArray])
		{
			NSString *english=[[item title] stringByTrimmingCharactersInSet:whitespace];
			NSString *key=[keys objectForKey:english];
			if(key) [item setTitle:[bundle localizedStringForKey:key value:english table:@"ConfigSheet"]];
		}
	}
	else if([rootView isKindOfClass:[NSButton class]])
	{
		NSButton *button=(NSButton *)rootView;
		NSString *english=[[button title] stringByTrimmingCharactersInSet:whitespace];
		NSString *key=[keys objectForKey:english];
		if(key) [button setTitle:[bundle localizedStringForKey:key value:english table:@"ConfigSheet"]];
	}
	else if([rootView isKindOfClass:[NSTextField class]])
	{
		NSTextField *field=(NSTextField *)rootView;
		NSString *english=[[field stringValue] stringByTrimmingCharactersInSet:whitespace];
		NSString *key=[keys objectForKey:english];
		if(key) [field setStringValue:[bundle localizedStringForKey:key value:english table:@"ConfigSheet"]];
	}

	for(NSView *subview in [rootView subviews]) [self localizeConfigView:subview];
}



-(void)setSaverName:(NSString *)name andDefaults:(NSDictionary *)defdic
{
//	[savername autorelease];
//	savername=[name retain];
	[self setSaverDefaults:defdic];
}

-(void)setSaverDefaults:(NSDictionary *)defdic
{
	[[self defaults] registerDefaults:defdic];
}

-(void)setConfigName:(NSString *)name
{
//	[configname autorelease];
//	configname=[name retain];
    configname = name;
}

-(ScreenSaverDefaults *)defaults
{
	if(savername) return [ScreenSaverDefaults defaultsForModuleWithName:savername];
	return [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
}

-(void)updateConfigWindow:(NSWindow *)window usingDefaults:(ScreenSaverDefaults *)defaults
{
}

-(void)updateDefaults:(ScreenSaverDefaults *)defaults usingConfigWindow:(NSWindow *)window
{
}

-(IBAction)configOk:(id)sender
{
	ScreenSaverDefaults *defaults=[self defaults];

	[self updateDefaults:defaults usingConfigWindow:configwindow];
	if(clockpopup) [defaults setInteger:[clockpopup indexOfSelectedItem] forKey:@"clockSize"];

	[defaults synchronize];

	[[NSApplication sharedApplication] endSheet:configwindow];
}

-(IBAction)configCancel:(id)sender
{
	[[NSApplication sharedApplication] endSheet:configwindow];
}

-(IBAction)configDefaults:(id)sender
{
	ScreenSaverDefaults *defaults=[self defaults];

	NSEnumerator *enumerator=[[defaults dictionaryRepresentation] keyEnumerator];
	NSString *key;
	while((key=[enumerator nextObject])) [defaults removeObjectForKey:key];

	[self updateConfigWindow:configwindow usingDefaults:defaults];
	[clockpopup selectItemAtIndex:[[self defaults] integerForKey:@"clockSize"]];

	[defaults synchronize];
}



-(BOOL)isPreview { return ispreview; }



-(double)absoluteTime
{
	struct timeval tv;
	gettimeofday(&tv,0);
	return (double)tv.tv_sec+((double)tv.tv_usec)/1000000.0;
}

-(double)time
{
	if(!starttime)
	{
		starttime=[self absoluteTime];
		return 0;
	}
	else return [self absoluteTime]-starttime;
}

-(double)deltaTime
{
	if(!prevtime)
	{
		prevtime=[self absoluteTime];
		return 0;
	}
	else
	{
		double time=[self absoluteTime];
		double dt=time-prevtime;
		prevtime=time;
		if(dt>0.1) dt=0.1;
		return dt;
	}
}




-(NSBitmapImageRep *)grabScreenShot
{
	NSScreen *targetScreen=[[self window] screen];
	if(!targetScreen) targetScreen=[NSScreen mainScreen];

	// Capture the composited wallpaper window rather than reopening its source
	// file.  This preserves the crop and processing selected in System Settings
	// and also works when the original image is unavailable to the saver host.
	if(@available(macOS 14.0,*))
	{
		NSBitmapImageRep *captured=[self captureWallpaperForScreen:targetScreen];
		if(captured) return captured;
	}

	// ScreenCaptureKit needs Screen Recording permission.  Keep the source file
	// path as a permission-free fallback where Workspace exposes one.
	NSURL *wallpaperURL=[[NSWorkspace sharedWorkspace] desktopImageURLForScreen:targetScreen];
	if(wallpaperURL)
	{
		NSData *wallpaperData=[NSData dataWithContentsOfURL:wallpaperURL];
		NSBitmapImageRep *wallpaper=nil;
		CGImageSourceRef source=wallpaperData?CGImageSourceCreateWithData(
			(__bridge CFDataRef)wallpaperData,NULL):NULL;
		if(source)
		{
			NSDictionary *properties=CFBridgingRelease(
				CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
			NSInteger width=[[properties objectForKey:(id)kCGImagePropertyPixelWidth] integerValue];
			NSInteger height=[[properties objectForKey:(id)kCGImagePropertyPixelHeight] integerValue];
			if(MAX(width,height)>4096)
			{
				NSDictionary *options=@{
					(id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
					(id)kCGImageSourceCreateThumbnailWithTransform:@YES,
					(id)kCGImageSourceThumbnailMaxPixelSize:@4096
				};
				CGImageRef image=CGImageSourceCreateThumbnailAtIndex(source,0,
					(__bridge CFDictionaryRef)options);
				if(image)
				{
					wallpaper=[[NSBitmapImageRep alloc] initWithCGImage:image];
					CGImageRelease(image);
				}
			}
			CFRelease(source);
		}
		if(!wallpaper)
			wallpaper=[NSBitmapImageRep imageRepWithData:wallpaperData];
		if(wallpaper) return wallpaper;
	}

	// Keep the historical window capture as a fallback for desktops that do
	// not expose a readable wallpaper file (for example, some managed setups).
	NSInteger windowid=[[self window] windowNumber];
	NSRect bounds=[[[self window] screen] frame];

	// Mavericks workaround: If the second window is loginwindow, use it as the base instead,
	// because it would otherwise block the view.
    NSArray *windows=(id)CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionAll,kCGNullWindowID));
	if([windows count]>2)
	{
		NSDictionary *second=[windows objectAtIndex:1];
		NSString *owner=[second objectForKey:(NSString *)kCGWindowOwnerName];
		if([owner isEqual:@"loginwindow"])
		{
			windowid=[[second objectForKey:(NSString *)kCGWindowNumber] integerValue];
		}
	}

	// Geez Lousie, isn't there a sane way to convert these coordinate systems?
	NSRect mainscreen=[[NSScreen mainScreen] frame];
	NSEnumerator *enumerator=[[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while((screen=[enumerator nextObject]))
	{
		NSRect frame=[screen frame];
		if(frame.origin.x==0&&frame.origin.y==0) mainscreen=frame;
	}

	bounds.origin.y=-bounds.origin.y-bounds.size.height+mainscreen.size.height;

	CGImageRef image=CGWindowListCreateImage(NSRectToCGRect(bounds),
	kCGWindowListOptionOnScreenBelowWindow,
	windowid,kCGWindowImageBoundsIgnoreFraming|kCGWindowImageBestResolution);
    
	NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithCGImage:image];
	CGImageRelease(image);
    
	return rep;
}

-(NSBitmapImageRep *)captureWallpaperForScreen:(NSScreen *)screen
{
	NSNumber *screenNumber=[[screen deviceDescription] objectForKey:@"NSScreenNumber"];
	if(!screenNumber) return nil;
	CGDirectDisplayID displayID=(CGDirectDisplayID)[screenNumber unsignedIntValue];

	__block NSBitmapImageRep *captured=nil;
	dispatch_semaphore_t finished=dispatch_semaphore_create(0);
	[SCShareableContent getShareableContentExcludingDesktopWindows:NO
		onScreenWindowsOnly:YES completionHandler:^(SCShareableContent *content,NSError *error) {
		if(!content||error)
		{
			NSLog(@"LotsaWater: ScreenCaptureKit could not enumerate content: %@",error);
			dispatch_semaphore_signal(finished);
			return;
		}

		SCDisplay *display=nil;
		for(SCDisplay *candidate in [content displays])
			if([candidate displayID]==displayID) { display=candidate; break; }
		if(!display)
		{
			NSLog(@"LotsaWater: ScreenCaptureKit did not expose display %u",displayID);
			dispatch_semaphore_signal(finished);
			return;
		}

		SCWindow *wallpaperWindow=nil;
		CGFloat largestIntersection=0;
		for(SCWindow *candidate in [content windows])
		{
			SCRunningApplication *owner=[candidate owningApplication];
			if(![[owner bundleIdentifier] isEqualToString:@"com.apple.WindowManager"]||
				![[candidate title] isEqualToString:@"Wallpaper"])
				continue;
			CGRect intersection=CGRectIntersection([candidate frame],[display frame]);
			CGFloat area=CGRectIsNull(intersection)?0:
				intersection.size.width*intersection.size.height;
			if(area>largestIntersection)
			{
				largestIntersection=area;
				wallpaperWindow=candidate;
			}
		}
		if(!wallpaperWindow)
		{
			NSLog(@"LotsaWater: ScreenCaptureKit did not expose the Wallpaper window");
			dispatch_semaphore_signal(finished);
			return;
		}

		SCContentFilter *filter=[[SCContentFilter alloc]
			initWithDesktopIndependentWindow:wallpaperWindow];
		SCStreamConfiguration *configuration=[[SCStreamConfiguration alloc] init];
		CGFloat scale=MAX(1,[filter pointPixelScale]);
		CGFloat width=[wallpaperWindow frame].size.width*scale;
		CGFloat height=[wallpaperWindow frame].size.height*scale;
		CGFloat downscale=MIN(1,4096/MAX(width,height));
		[configuration setWidth:MAX(1,(size_t)lrint(width*downscale))];
		[configuration setHeight:MAX(1,(size_t)lrint(height*downscale))];
		[configuration setShowsCursor:NO];
		[configuration setScalesToFit:YES];

		[SCScreenshotManager captureImageWithFilter:filter configuration:configuration
			completionHandler:^(CGImageRef image,NSError *captureError) {
			if(image&&!captureError)
				captured=[[NSBitmapImageRep alloc] initWithCGImage:image];
			else
				NSLog(@"LotsaWater: ScreenCaptureKit wallpaper capture failed: %@",captureError);
			dispatch_semaphore_signal(finished);
		}];
	}];

	// Never let a permission prompt or an unavailable capture service wedge the
	// screen saver host.  On the main thread, continue pumping the run loop:
	// ScreenCaptureKit may deliver part of its asynchronous work there.
	BOOL completed=NO;
	if([NSThread isMainThread])
	{
		NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
		while([deadline timeIntervalSinceNow]>0)
		{
			if(dispatch_semaphore_wait(finished,DISPATCH_TIME_NOW)==0)
			{
				completed=YES;
				break;
			}
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
				beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
		}
	}
	else
	{
		dispatch_time_t timeout=dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC);
		completed=dispatch_semaphore_wait(finished,timeout)==0;
	}
	if(!completed)
	{
		NSLog(@"LotsaWater: ScreenCaptureKit wallpaper capture timed out");
		return nil;
	}
	return captured;
}

-(NSBitmapImageRep *)imageRepFromBundle:(NSString *)name
{
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSString *path=[bundle pathForResource:name ofType:nil];
	return [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:path]];
}

@end




@implementation LotsaClockWindow

-(id)initWithFont:(NSFont *)font
{
	view=[[LotsaClockView alloc] initWithFont:font];
	NSSize size=[view bounds].size;

	if((self=[super initWithContentRect:NSMakeRect(0,0,size.width,size.height) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]))
	{
		[[self contentView] addSubview:view];

		[self setBackgroundColor:[NSColor clearColor]];
		[self setOpaque:NO];
		[self setAlphaValue:0];
		[self display];

		prevminutes=[[NSCalendarDate calendarDate] minuteOfHour];
		clocktimer=[NSTimer scheduledTimerWithTimeInterval:1
		target:self selector:@selector(clockTick:) userInfo:nil repeats:YES];

		fadeticks=0;
		fadetimer=[NSTimer scheduledTimerWithTimeInterval:1.0/30.0
		target:self selector:@selector(fadeTick:) userInfo:nil repeats:YES];
	}
	return self;
}

-(void)dealloc
{
//	[super dealloc];
}

-(void)clockTick:(NSTimer *)timer
{
	int minutes=[[NSCalendarDate calendarDate] minuteOfHour];
	//if(minutes!=prevminutes)
	{
		[view setNeedsDisplay:YES];
		prevminutes=minutes;
	}
}

-(void)fadeTick:(NSTimer *)timer
{
	fadeticks++;

	if(fadeticks>30)
	{
		float t=(float)(fadeticks-30)/60;
		[self setAlphaValue:t*t*(3-2*t)];
		if(fadeticks==90)
		{
			[fadetimer invalidate];
			fadetimer=nil;
		}
	}
}

-(void)stopTimers
{
	[clocktimer invalidate];
	[fadetimer invalidate];
	clocktimer=nil;
	fadetimer=nil;
}

@end



@implementation LotsaClockView

-(id)initWithFont:(NSFont *)f
{
	stroke=[f pointSize]/6;

	NSSize size=[[self pathFromString:@"88:88" atPoint:NSMakePoint(stroke,stroke) font:f] bounds].size;
	NSRect rect=NSMakeRect(0,0,size.width+2*stroke,size.height+2*stroke);

	if((self=[super initWithFrame:rect]))
	{
//		font=[f retain];
        font = f;
	}
	return self;
}

-(void)dealloc
{
//	[font release];
//	[super dealloc];
}

-(void)drawRect:(NSRect)rect
{
	NSString *str=[[NSDate date] descriptionWithCalendarFormat:@"%H:%M" timeZone:nil locale:nil];
	NSBezierPath *path=[self pathFromString:str atPoint:NSMakePoint(stroke,stroke) font:font];
	[path setLineWidth:stroke];
	[path setMiterLimit:stroke/4];

//	[[NSColor redColor] set]; [NSBezierPath fillRect:[[self contentView] bounds]];
	[[NSColor blackColor] set]; [path stroke];
	[[NSColor whiteColor] set]; [path fill];
}

-(NSBezierPath *)pathFromString:(NSString *)str atPoint:(NSPoint)point font:(NSFont *)f
{
	NSTextView *textview=[[NSTextView alloc] init];
	[textview setString:str];
	[textview setFont:f];

	NSLayoutManager *layoutManager=[textview layoutManager];
	NSRange range=[layoutManager glyphRangeForCharacterRange:NSMakeRange(0,[str length]) actualCharacterRange:NULL];
	NSGlyph *glyphs=(NSGlyph *)malloc(sizeof(NSGlyph)*range.length*2);
	[layoutManager getGlyphs:glyphs range:range];

	NSBezierPath *path=[NSBezierPath bezierPath];
	[path moveToPoint:point];
	[path appendBezierPathWithGlyphs:glyphs count:range.length inFont:f];

	free(glyphs);
//	[textview release];

	return path;
}

@end
