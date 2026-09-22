#import "LotsaWaterView.h"
#import "LotsaCore/Random.h"

@interface LotsaWaterView ()
-(BOOL)configureMetal;
-(id<MTLTexture>)textureFromBitmapImageRep:(NSBitmapImageRep *)imageRep;
@end


@implementation LotsaWaterView

-(id)initWithFrame:(NSRect)frame isPreview:(BOOL)preview
{
	if((self=[super initWithFrame:frame isPreview:preview]))
	{
		screenshot=nil;
		animationInitialized=NO;
		metalView=nil;
		metalDevice=nil;
		commandQueue=nil;
		pipelineState=nil;

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

		[self configureMetal];
    }

    return self;
}

-(BOOL)configureMetal
{
	metalDevice=MTLCreateSystemDefaultDevice();
	if(!metalDevice)
	{
		NSLog(@"LotsaWater: Metal is not available on this Mac");
		return NO;
	}

	metalView=[[MTKView alloc] initWithFrame:[self bounds] device:metalDevice];
	[metalView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[metalView setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
	[metalView setClearColor:MTLClearColorMake(0,0,0,1)];
	[metalView setFramebufferOnly:YES];
	[metalView setDelegate:self];
	[metalView setPaused:YES];
	[metalView setEnableSetNeedsDisplay:YES];
	[metalView setHidden:YES];
	[self setAutoresizesSubviews:YES];
	[self addSubview:metalView];

	commandQueue=[metalDevice newCommandQueue];
	NSError *error=nil;
	NSBundle *bundle=[NSBundle bundleForClass:[self class]];
	id<MTLLibrary> library=[metalDevice newDefaultLibraryWithBundle:bundle error:&error];
	if(!library)
	{
		NSLog(@"LotsaWater: unable to load Metal shaders: %@",error);
		return NO;
	}

	id<MTLFunction> vertexFunction=[library newFunctionWithName:@"lotsaWaterVertex"];
	id<MTLFunction> fragmentFunction=[library newFunctionWithName:@"lotsaWaterFragment"];
	if(!vertexFunction||!fragmentFunction)
	{
		NSLog(@"LotsaWater: Metal shader functions are missing");
		return NO;
	}

	MTLRenderPipelineDescriptor *descriptor=[[MTLRenderPipelineDescriptor alloc] init];
	[descriptor setVertexFunction:vertexFunction];
	[descriptor setFragmentFunction:fragmentFunction];
	[[descriptor colorAttachments][0] setPixelFormat:[metalView colorPixelFormat]];
	pipelineState=[metalDevice newRenderPipelineStateWithDescriptor:descriptor error:&error];
	if(!pipelineState)
	{
		NSLog(@"LotsaWater: unable to create Metal pipeline: %@",error);
		return NO;
	}

	return YES;
}

-(id<MTLTexture>)textureFromBitmapImageRep:(NSBitmapImageRep *)imageRep
{
	CGImageRef image=[imageRep CGImage];
	if(!image||!metalDevice) return nil;

	NSUInteger width=CGImageGetWidth(image);
	NSUInteger height=CGImageGetHeight(image);
	NSUInteger bytesPerRow=width*4;
	NSMutableData *pixels=[NSMutableData dataWithLength:bytesPerRow*height];
	CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
	CGContextRef context=CGBitmapContextCreate([pixels mutableBytes],width,height,8,bytesPerRow,
		colorSpace,kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	if(!context)
	{
		NSLog(@"LotsaWater: unable to create a BGRA bitmap context");
		return nil;
	}

	// CGBitmapContext and Metal use opposite display-space Y directions here;
	// drawing without an extra transform keeps the wallpaper upright onscreen.
	CGContextDrawImage(context,CGRectMake(0,0,width,height),image);
	CGContextRelease(context);

	MTLTextureDescriptor *descriptor=[MTLTextureDescriptor
		texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
		width:width height:height mipmapped:NO];
	[descriptor setUsage:MTLTextureUsageShaderRead];
	id<MTLTexture> texture=[metalDevice newTextureWithDescriptor:descriptor];
	if(!texture)
	{
		NSLog(@"LotsaWater: unable to allocate a Metal texture");
		return nil;
	}

	[texture replaceRegion:MTLRegionMake2D(0,0,width,height)
		mipmapLevel:0
		withBytes:[pixels bytes]
		bytesPerRow:bytesPerRow];
	return texture;
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

	if(!pipelineState||!screenshot)
	{
		[metalView setHidden:YES];
		return;
	}

	[metalView setHidden:NO];
	[metalView layoutSubtreeIfNeeded];
	NSRect backingBounds=[metalView convertRectToBacking:[metalView bounds]];
	[metalView setDrawableSize:backingBounds.size];

	wallpaperTexture=[self textureFromBitmapImageRep:screenshot];
	reflectionTexture=[self textureFromBitmapImageRep:[self imageRepFromBundle:@"reflections.png"]];
	if(!wallpaperTexture||!reflectionTexture)
	{
		[metalView setHidden:YES];
		return;
	}

	int tex_w=(int)[wallpaperTexture width];
	int tex_h=(int)[wallpaperTexture height];

	// The wallpaper file is often larger than the display (and may have a
	// different aspect ratio).  It is a texture size, not the Metal viewport.
	int screen_w=(int)NSWidth(backingBounds);
	int screen_h=(int)NSHeight(backingBounds);
	if(screen_w<=0||screen_h<=0)
	{
		screen_w=tex_w;
		screen_h=tex_h;
	}

	float screen_scale=1.3/sqrtf((float)(screen_w*screen_w+screen_h*screen_h));
	float screen_fw=(float)screen_w*screen_scale;
	float screen_fh=(float)screen_h*screen_scale;

	// Centre-crop the wallpaper to cover the screen, just like a desktop
	// background.  Metal samples the cropped area with normalized coordinates.
	tex_u0=0;
	tex_v0=0;
	tex_uscale=1;
	tex_vscale=1;
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

	InitWater(&wet,gridsize,gridsize,max_p,max_p,1,1,2*water_w,2*water_h);

/*	WaterState rnd;
	InitRandomWaterState(&rnd,&wet);
	AddWaterStateAtTime(&wet,&rnd,0);
	CleanupWaterState(&rnd);*/

	NSUInteger vertexCount=(NSUInteger)wet.w*(NSUInteger)wet.h;
	indexCount=(NSUInteger)(wet.w-1)*(NSUInteger)(wet.h-1)*6;
	vertexBuffer=[metalDevice newBufferWithLength:vertexCount*sizeof(LotsaWaterMetalVertex)
		options:MTLResourceStorageModeShared];
	indexBuffer=[metalDevice newBufferWithLength:indexCount*sizeof(uint32_t)
		options:MTLResourceStorageModeShared];
	if(!vertexBuffer||!indexBuffer)
	{
		CleanupWater(&wet);
		[metalView setHidden:YES];
		return;
	}

	LotsaWaterMetalVertex *vertices=(LotsaWaterMetalVertex *)[vertexBuffer contents];
	int i=0;
	for(int y=0;y<wet.h;y++)
	for(int x=0;x<wet.w;x++)
	{
		float fx=(float)x/(float)(wet.w-1);
		float fy=(float)y/(float)(wet.h-1);

		vertices[i].position=(vector_float2){fx,fy};
		vertices[i].texCoord=(vector_float2){fx,fy};
		vertices[i].normal=(vector_float3){0,0,1};
		vertices[i].intensity=1;

		i++;
	}

	uint32_t *indices=(uint32_t *)[indexBuffer contents];
	NSUInteger index=0;
	for(int y=0;y<wet.h-1;y++)
	for(int x=0;x<wet.w-1;x++)
	{
		uint32_t topLeft=(uint32_t)(y*wet.w+x);
		uint32_t topRight=topLeft+1;
		uint32_t bottomLeft=topLeft+(uint32_t)wet.w;
		uint32_t bottomRight=bottomLeft+1;
		indices[index++]=topLeft;
		indices[index++]=bottomLeft;
		indices[index++]=topRight;
		indices[index++]=topRight;
		indices[index++]=bottomLeft;
		indices[index++]=bottomRight;
	}

	animationInitialized=YES;
}

-(void)stopAnimation
{
	// The system can ask a preview instance to stop before it has started,
	// such as while opening the configuration sheet.  Its buffers are not
	// valid until startAnimationWithDefaults: has initialized them.
	if(animationInitialized)
	{
		CleanupWater(&wet);
		animationInitialized=NO;
	}

	vertexBuffer=nil;
	indexBuffer=nil;
	wallpaperTexture=nil;
	reflectionTexture=nil;
	indexCount=0;
	[metalView setHidden:YES];

	[super stopAnimation];
}

-(void)animateOneFrame
{
	if(!animationInitialized||!pipelineState) return;

	int i;

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

//		t_next+=0.3;
		t_next+=(5-raintime)*exp(-t_next/10)+raintime;
	}

	CalculateWaterSurfaceAtTime(&wet,t);

	float fade=[[self defaults] floatForKey:@"imageFade"];
	if(![self isPreview]&&t<1) fade=1-(1-fade)*(t*t*(3-2*t));

	LotsaWaterMetalVertex *vertices=(LotsaWaterMetalVertex *)[vertexBuffer contents];
	i=0;
	for(int y=0;y<wet.h;y++)
	for(int x=0;x<wet.w;x++)
	{
		float u0=vertices[i].position.x;
		float v0=vertices[i].position.y;

		float n=1.333f;
		float col_intensity=3.0f;

		float d=wet.z[i]+waterdepth;
		float n_abs2=vec3sq(wet.n[i]);
		float cos_a=wet.n[i].z/sqrtf(n_abs2);
		float sin_a=sqrtf(1.0f-cos_a*cos_a);
		float sin_b=sin_a/n;
		float cos_b=sqrtf(1.0f-sin_b*sin_b);
		float sin_ab=sin_a*cos_b-cos_a*sin_b;
		float dx=wet.n[i].x;
		float dy=wet.n[i].y;
		float r=sqrtf(dx*dx+dy*dy);

		if(r>0.000001f)
		{
			vertices[i].texCoord.x=tex_u0+(u0-dx/r*sin_ab*d/water_w)*tex_uscale;
			vertices[i].texCoord.y=tex_v0+(v0-dy/r*sin_ab*d/water_h)*tex_vscale;
		}
		else
		{
			vertices[i].texCoord.x=tex_u0+u0*tex_uscale;
			vertices[i].texCoord.y=tex_v0+v0*tex_vscale;
		}
		vertices[i].normal=(vector_float3){wet.n[i].x,wet.n[i].y,wet.n[i].z};

		float c=-(wet.n[i].x+wet.n[i].y)*col_intensity+1.0f;
		if(c<0.0f) c=0.0f;
		if(c>1.0f) c=1.0f;

		vertices[i].intensity=c*fade;

		i++;
	}

	// Never draw synchronously from ScreenSaverView's animation callback.  All
	// third-party savers share WallpaperLegacyExtension on current macOS; a
	// synchronous drawable wait here can stall previews and configuration
	// sheets for every legacy saver.  Let AppKit perform the MTKView draw in its
	// normal display pass instead.
	[metalView setNeedsDisplay:YES];
}

-(void)drawInMTKView:(MTKView *)view
{
	if(!animationInitialized||!pipelineState) return;

	MTLRenderPassDescriptor *passDescriptor=[view currentRenderPassDescriptor];
	id<CAMetalDrawable> drawable=[view currentDrawable];
	if(!passDescriptor||!drawable) return;

	LotsaWaterMetalUniforms uniforms={ .waterSize={water_w,water_h} };
	id<MTLCommandBuffer> commandBuffer=[commandQueue commandBuffer];
	id<MTLRenderCommandEncoder> encoder=[commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
	[encoder setRenderPipelineState:pipelineState];
	[encoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
	[encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
	[encoder setFragmentTexture:wallpaperTexture atIndex:0];
	[encoder setFragmentTexture:reflectionTexture atIndex:1];
	[encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
		indexCount:indexCount
		indexType:MTLIndexTypeUInt32
		indexBuffer:indexBuffer
		indexBufferOffset:0];
	[encoder endEncoding];
	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
}

-(void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
	// The water mesh is rebuilt when the screen saver starts.  MTKView still
	// requires this delegate method even though no per-resize work is needed.
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
