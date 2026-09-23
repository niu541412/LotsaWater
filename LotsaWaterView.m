#import "LotsaWaterView.h"
#import "LotsaCore/Random.h"
#import <CoreVideo/CoreVideo.h>

@interface LotsaWaterView ()
-(BOOL)configureSpriteKit;
-(void)updateSceneLayout;
@end


@implementation LotsaWaterView

-(id)initWithFrame:(NSRect)frame isPreview:(BOOL)preview
{
	if((self=[super initWithFrame:frame isPreview:preview]))
	{
		screenshot=nil;
		animationInitialized=NO;
		spriteView=nil;
		scene=nil;
		waterNode=nil;
		waterTexture=nil;

		[self setAnimationTimeInterval:1/60.0];
		[self setConfigName:@"ConfigSheet"];
		[self setSaverName:@"LotsaWater" andDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
			@"2",@"detail",
			@"1",@"accuracy",
			@"0",@"slowMotion",
			@"0.5",@"rainFall",
			@"0.5",@"depth",
			@"1",@"imageFade",
			@"0",@"clockSize",
		nil]];

		[self configureSpriteKit];
    }

    return self;
}

-(BOOL)configureSpriteKit
{
	spriteView=[[SKView alloc] initWithFrame:[self bounds]];
	[spriteView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[spriteView setPreferredFramesPerSecond:60];
	[spriteView setAsynchronous:YES];
	[spriteView setAllowsTransparency:NO];
	[spriteView setDisableDepthStencilBuffer:YES];
	[spriteView setPaused:YES];
	[spriteView setHidden:YES];
	[self setAutoresizesSubviews:YES];
	[self addSubview:spriteView];

	scene=[SKScene sceneWithSize:[self bounds].size];
	[scene setScaleMode:SKSceneScaleModeResizeFill];
	[scene setBackgroundColor:[NSColor blackColor]];

	waterNode=[SKSpriteNode spriteNodeWithColor:[NSColor blackColor] size:[self bounds].size];
	[waterNode setAnchorPoint:CGPointMake(0.5,0.5)];
	[waterNode setBlendMode:SKBlendModeReplace];
	[scene addChild:waterNode];

	NSError *error=nil;
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSURL *shaderURL=[bundle URLForResource:@"LotsaWater" withExtension:@"fsh"];
	NSString *source=shaderURL?[NSString stringWithContentsOfURL:shaderURL
		encoding:NSUTF8StringEncoding error:&error]:nil;
	if(!source)
	{
		NSLog(@"LotsaWater: unable to load SpriteKit shader: %@",error);
		return NO;
	}

	waterTexture=[[SKMutableTexture alloc] initWithSize:CGSizeMake(1,1)
		pixelFormat:(int)kCVPixelFormatType_128RGBAFloat];
	SKTexture *reflection=[SKTexture textureWithCGImage:[[self imageRepFromBundle:@"reflections.png"] CGImage]];
	[reflection setFilteringMode:SKTextureFilteringLinear];

	waterTextureUniform=[SKUniform uniformWithName:@"u_water_texture" texture:waterTexture];
	SKUniform *reflectionUniform=[SKUniform uniformWithName:@"u_reflection_texture" texture:reflection];
	waterSizeUniform=[SKUniform uniformWithName:@"u_water_size" vectorFloat2:(vector_float2){1,1}];
	textureCropUniform=[SKUniform uniformWithName:@"u_texture_crop" vectorFloat4:(vector_float4){0,0,1,1}];
	waterDepthUniform=[SKUniform uniformWithName:@"u_water_depth" float:1];
	fadeUniform=[SKUniform uniformWithName:@"u_fade" float:1];

	SKShader *shader=[SKShader shaderWithSource:source uniforms:@[
		waterTextureUniform,reflectionUniform,waterSizeUniform,
		textureCropUniform,waterDepthUniform,fadeUniform
	]];
	[waterNode setShader:shader];
	[spriteView presentScene:scene];
	[self updateSceneLayout];
	return YES;
}

-(void)updateSceneLayout
{
	NSSize size=[self bounds].size;
	if(size.width<=0||size.height<=0) return;
	[scene setSize:size];
	[waterNode setSize:size];
	[waterNode setPosition:CGPointMake(size.width/2,size.height/2)];
}

-(void)layout
{
	[super layout];
	[self updateSceneLayout];
}

-(void)dealloc
{
//	[screenshot release];
//	[super dealloc];
}

-(void)drawRect:(NSRect)rect
{
	if(!screenshot)
		screenshot=[self grabScreenShot];

	// AppKit drawing coordinates are points, not backing pixels.  Scaling this
	// rect on Retina displays leaves the image anchored in the lower-left.
    [screenshot drawInRect:[self bounds] fromRect:NSZeroRect operation:0 fraction:1.0 respectFlipped:NO hints:NULL];
}

-(void)startAnimationWithDefaults:(ScreenSaverDefaults *)defaults
{
	animationInitialized=NO;
	// Refresh the current desktop wallpaper for every new run.
	screenshot=[self grabScreenShot];

	SeedRandom(time(0));

	int gridsize,max_p;

	switch([defaults integerForKey:@"detail"])
	{
		default: gridsize=24; break;
		case 1: gridsize=32; break;
		case 2: gridsize=48; break;
		case 3: gridsize=64; break;
		case 4: gridsize=96; break;
		case 5: gridsize=128; break;
	}

	switch([defaults integerForKey:@"accuracy"])
	{
		default: max_p=12; break;
		case 1: max_p=16; break;
		case 2: max_p=24; break;
		case 3: max_p=32; break;
		case 4: max_p=64; break;
	}

	double slow=[defaults floatForKey:@"slowMotion"];
	double rain=[defaults floatForKey:@"rainFall"];
	double d=[defaults floatForKey:@"depth"];

	t=0;
	t_next=1;
	t_div=(slow+1)*(slow+1);

	raintime=4*0.9*(rain-1)*(rain-1)+0.1;
	waterdepth=0.2+d*d*4*1.8;

	if(!waterNode||!screenshot)
	{
		[spriteView setHidden:YES];
		return;
	}

	CGImageRef wallpaperImage=[screenshot CGImage];
	if(!wallpaperImage)
	{
		[spriteView setHidden:YES];
		return;
	}
	SKTexture *wallpaperTexture=[SKTexture textureWithCGImage:wallpaperImage];
	[wallpaperTexture setFilteringMode:SKTextureFilteringLinear];
	[waterNode setTexture:wallpaperTexture];

	int tex_w=(int)CGImageGetWidth(wallpaperImage);
	int tex_h=(int)CGImageGetHeight(wallpaperImage);

	// SpriteKit renders in points, but only the aspect ratio is relevant to the
	// simulation and centre crop.
	NSSize viewSize=[self bounds].size;
	int screen_w=(int)viewSize.width;
	int screen_h=(int)viewSize.height;
	if(screen_w<=0||screen_h<=0)
	{
		screen_w=tex_w;
		screen_h=tex_h;
	}

	float screen_scale=1.3/sqrtf((float)(screen_w*screen_w+screen_h*screen_h));
	float screen_fw=(float)screen_w*screen_scale;
	float screen_fh=(float)screen_h*screen_scale;

	// Centre-crop the wallpaper to cover the screen, just like the desktop.
	float tex_u0=0;
	float tex_v0=0;
	float tex_uscale=1;
	float tex_vscale=1;
	float screen_aspect=(float)screen_w/(float)screen_h;
	float texture_aspect=(float)tex_w/(float)tex_h;
	if(texture_aspect>screen_aspect)
	{
		tex_uscale=screen_aspect/texture_aspect;
		tex_u0=(1-tex_uscale)/2;
	}
	else if(texture_aspect<screen_aspect)
	{
		tex_vscale=texture_aspect/screen_aspect;
		tex_v0=(1-tex_vscale)/2;
	}
	water_w=screen_fw;
	water_h=screen_fh;
	[waterSizeUniform setVectorFloat2Value:(vector_float2){water_w,water_h}];
	[textureCropUniform setVectorFloat4Value:(vector_float4){tex_u0,tex_v0,tex_uscale,tex_vscale}];
	[waterDepthUniform setFloatValue:(float)waterdepth];

	InitWater(&wet,gridsize,gridsize,max_p,max_p,1,1,2*water_w,2*water_h);

/*	WaterState rnd;
	InitRandomWaterState(&rnd,&wet);
	AddWaterStateAtTime(&wet,&rnd,0);
	CleanupWaterState(&rnd);*/

	waterTexture=[[SKMutableTexture alloc] initWithSize:CGSizeMake(wet.w,wet.h)
		pixelFormat:(int)kCVPixelFormatType_128RGBAFloat];
	[waterTexture setFilteringMode:SKTextureFilteringLinear];
	[waterTextureUniform setTextureValue:waterTexture];
	animationInitialized=YES;
	[spriteView setHidden:NO];
	[spriteView setPaused:NO];
}

-(void)stopAnimation
{
	[spriteView setPaused:YES];
	[spriteView setHidden:YES];

	// The system can ask a preview instance to stop before it has started,
	// such as while opening the configuration sheet.  Its buffers are not
	// valid until startAnimationWithDefaults: has initialized them.
	if(animationInitialized)
	{
		CleanupWater(&wet);
		animationInitialized=NO;
	}

	waterTexture=nil;
	[waterTextureUniform setTextureValue:nil];
	[waterNode setTexture:nil];

	[super stopAnimation];
}

-(void)animateOneFrame
{
	if(!animationInitialized||!waterTexture) return;

	double dt=[self deltaTime];
	t+=dt/t_div;

	while(t>t_next)
	{
		float x0=RandomFloat()*wet.lx;
		float y0=RandomFloat()*wet.ly;

		WaterState drip1,drip2;
		InitDripWaterState(&drip1,&wet,x0,y0,0.14,-0.01);
		InitDripWaterState(&drip2,&wet,x0,y0,0.07,0.01);
//		softdrip_state drip(0.5*wet->lx,0.5*wet->ly,wet);
		AddWaterStateAtTime(&wet,&drip1,t_next);
		AddWaterStateAtTime(&wet,&drip2,t_next);
		CleanupWaterState(&drip1);
		CleanupWaterState(&drip2);

//		t_next+=0.3;
		t_next+=(5-raintime)*exp(-t_next/10)+raintime;
	}

	CalculateWaterSurfaceAtTime(&wet,t);

	float fade=[[self defaults] floatForKey:@"imageFade"];
	if(![self isPreview]&&t<1) fade=1-(1-fade)*(t*t*(3-2*t));

	int width=wet.w;
	int height=wet.h;
	[waterTexture modifyPixelDataWithBlock:^(void *pixelData,size_t lengthInBytes) {
		size_t required=(size_t)width*(size_t)height*4*sizeof(float);
		if(lengthInBytes<required) return;
		float *pixels=(float *)pixelData;
		for(int index=0;index<width*height;index++)
		{
			pixels[index*4+0]=wet.n[index].x;
			pixels[index*4+1]=wet.n[index].y;
			pixels[index*4+2]=wet.z[index];
			pixels[index*4+3]=1;
		}
	}];
	[fadeUniform setFloatValue:fade];
}

-(void)updateConfigWindow:(NSWindow *)window usingDefaults:(ScreenSaverDefaults *)defaults
{
	[detail setIntValue:[defaults integerForKey:@"detail"]];
	[accuracy setIntValue:[defaults integerForKey:@"accuracy"]];
	[slomo setFloatValue:[defaults floatForKey:@"slowMotion"]];
	[rainfall setFloatValue:[defaults floatForKey:@"rainFall"]];
	[depth setFloatValue:[defaults floatForKey:@"depth"]];
	[imagefade setFloatValue:[defaults floatForKey:@"imageFade"]];

	// The background is always the current desktop wallpaper.  Keep the
	// preview, but remove the obsolete source selector and its "Image:" label.
	[imgsrc setHidden:YES];
	[imageview setEditable:NO];
	NSRect previewFrame=[imageview frame];
	NSSize previewSize=NSMakeSize(240,150);
	previewFrame.origin.x+=(NSWidth(previewFrame)-previewSize.width)/2;
	previewFrame.origin.y+=(NSHeight(previewFrame)-previewSize.height)/2;
	previewFrame.size=previewSize;
	[imageview setFrame:previewFrame];
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	NSString *localizedLabel=[bundle localizedStringForKey:@"106.title" value:@"Image:" table:@"ConfigSheet"];
	for(NSView *candidate in [[imgsrc superview] subviews])
	{
		if([candidate isKindOfClass:[NSTextField class]])
		{
			NSString *title=[(NSTextField *)candidate stringValue];
			if([title isEqualToString:@"Image:"]||[title isEqualToString:localizedLabel])
				[candidate setHidden:YES];
		}
	}

	screenshot=[self grabScreenShot];
	NSImage *image=[[NSImage alloc] init];
	[image addRepresentation:screenshot];
	[imageview setImage:image];
}

-(void)updateDefaults:(ScreenSaverDefaults *)defaults usingConfigWindow:(NSWindow *)window
{
	[defaults setInteger:[detail intValue] forKey:@"detail"];
	[defaults setInteger:[accuracy intValue] forKey:@"accuracy"];
	[defaults setFloat:[slomo floatValue] forKey:@"slowMotion"];
	[defaults setFloat:[rainfall floatValue] forKey:@"rainFall"];
	[defaults setFloat:[depth floatValue] forKey:@"depth"];
	[defaults setFloat:[imagefade floatValue] forKey:@"imageFade"];
}

-(IBAction)pickImageSource:(id)sender
{
	switch([imgsrc indexOfSelectedItem])
	{
		case 0:
		{
			screenshot=[self grabScreenShot];
			NSImage *img=[[NSImage alloc] init];
			[img addRepresentation:screenshot];
			[imageview setImage:img];
		}
		break;
		case 1:
		{
			NSImage *img=[[NSImage alloc] initWithContentsOfFile:[imageview fileName]];
			[imageview setImage:img];
		}
		break;
	}
}

-(IBAction)dropImage:(id)sender
{
	[imgsrc selectItemAtIndex:1];
	[self pickImageSource:imgsrc];
}



+(BOOL)performGammaFade
{
    return NO;
}

@end



@implementation ImagePicker

-(id)initWithCoder:(NSCoder *)coder
{
	if((self=[super initWithCoder:coder]))
	{
		filename=nil;
	}
	return self;
}

-(void)dealloc
{
//	[filename release];
//	[super dealloc];
}

-(void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard=[sender draggingPasteboard];
	NSString *type=[pboard availableTypeFromArray:[NSArray arrayWithObjects:
	NSFilenamesPboardType,NSTIFFPboardType,NSPICTPboardType,nil]];


	if(type==NSFilenamesPboardType)
	{
		[self setFileName:[[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0]];
	}
	else
	{
		NSFileManager *fm=[NSFileManager defaultManager];
		NSString *path=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) objectAtIndex:0];
		NSString *dir=[path stringByAppendingPathComponent:@"LotsaBlankers"];
		if(![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:NO attributes:nil error:NULL];

		NSString *ext=type==NSTIFFPboardType?@"tiff":@"pict";
		NSString *imagename=[[dir stringByAppendingPathComponent:@"LotsaWater"] stringByAppendingPathExtension:ext];
		[[pboard dataForType:type] writeToFile:imagename atomically:NO];

		[self setFileName:imagename];
	}

    [super concludeDragOperation:sender];
}

-(void)setFileName:(NSString *)newname
{
//	[filename autorelease];
//	filename=[newname retain];
}

-(NSString *)fileName { return filename; }

@end

/*			NSUserDefaults *desktopdefs=[[NSUserDefaults alloc] init];
			[desktopdefs addSuiteNamed:@"com.apple.desktop"];
			NSString *desktopname=[[[desktopdefs objectForKey:@"Background"] objectForKey:@"default"] objectForKey:@"ImageFilePath"];
			[desktopdefs release];*/
