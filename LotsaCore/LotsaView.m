#import "LotsaView.h"

#import <sys/time.h>
#import <CommonCrypto/CommonDigest.h>

@interface LotsaView ()
-(void)localizeConfigView:(NSView *)rootView;
-(NSBitmapImageRep *)cachedWallpaperForURL:(NSURL *)wallpaperURL screen:(NSScreen *)screen;
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

	return configwindow;
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

	// Workspace keeps returning the configured URL even after the source image
	// has been removed.  Prefer WallpaperAgent's decoded cache in that case (and
	// avoid depending on access to the original file), then fall back to the
	// public source URL when the private cache is unavailable.
	NSURL *wallpaperURL=[[NSWorkspace sharedWorkspace] desktopImageURLForScreen:targetScreen];
	if(wallpaperURL)
	{
		NSBitmapImageRep *cached=[self cachedWallpaperForURL:wallpaperURL screen:targetScreen];
		if(cached) return cached;

		NSData *wallpaperData=[NSData dataWithContentsOfURL:wallpaperURL];
		NSBitmapImageRep *wallpaper=wallpaperData?
			[NSBitmapImageRep imageRepWithData:wallpaperData]:nil;
		if(wallpaper) return wallpaper;
	}

	return nil;
}

-(NSBitmapImageRep *)cachedWallpaperForURL:(NSURL *)wallpaperURL screen:(NSScreen *)screen
{
	NSString *sourcePath=[wallpaperURL path];
	NSData *pathData=[sourcePath dataUsingEncoding:NSUTF8StringEncoding];
	if(!pathData) return nil;

	unsigned char digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256([pathData bytes],(CC_LONG)[pathData length],digest);
	NSMutableString *hash=[NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
	for(NSUInteger index=0;index<CC_SHA256_DIGEST_LENGTH;index++)
		[hash appendFormat:@"%02x",digest[index]];

	NSString *cacheDirectory=[NSHomeDirectory() stringByAppendingPathComponent:
		@"Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches/"
		 @"com.apple.wallpaper.caches/extension-com.apple.wallpaper.extension.image"];
	NSArray<NSString *> *entries=[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:cacheDirectory error:nil];
	if(!entries) return nil;

	CGFloat scale=[screen backingScaleFactor];
	NSInteger pixelWidth=(NSInteger)lrint(NSWidth([screen frame])*scale);
	NSInteger pixelHeight=(NSInteger)lrint(NSHeight([screen frame])*scale);
	NSString *hashPrefix=[hash stringByAppendingString:@"-"];
	NSString *displayPrefix=[NSString stringWithFormat:@"%@%ld-%ld-",hashPrefix,
		(long)pixelWidth,(long)pixelHeight];
	NSString *bestExact=nil,*bestFallback=nil;
	NSDate *bestExactDate=nil,*bestFallbackDate=nil;

	for(NSString *entry in entries)
	{
		if(![entry hasPrefix:hashPrefix]||![[entry pathExtension] isEqualToString:@"bmp"])
			continue;
		NSString *path=[cacheDirectory stringByAppendingPathComponent:entry];
		NSDate *date=[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil]
			objectForKey:NSFileModificationDate];
		if(!bestFallbackDate||[date compare:bestFallbackDate]==NSOrderedDescending)
		{
			bestFallback=path;
			bestFallbackDate=date;
		}
		if([entry hasPrefix:displayPrefix]&&
			(!bestExactDate||[date compare:bestExactDate]==NSOrderedDescending))
		{
			bestExact=path;
			bestExactDate=date;
		}
	}

	NSString *cachePath=bestExact?bestExact:bestFallback;
	NSData *cacheData=cachePath?[NSData dataWithContentsOfFile:cachePath]:nil;
	return cacheData?[NSBitmapImageRep imageRepWithData:cacheData]:nil;
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
