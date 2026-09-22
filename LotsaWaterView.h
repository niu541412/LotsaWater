#import "LotsaCore/LotsaView.h"
#import "Water.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

#import "LotsaCore/NameMangler.h"
#define LotsaWaterView MangleClassName(LotsaWaterView)
#define ImagePicker MangleClassName(ImagePicker)

@class ImagePicker;

typedef struct
{
	vector_float2 position;
	vector_float2 texCoord;
	vector_float3 normal;
	float intensity;
} LotsaWaterMetalVertex;

typedef struct
{
	vector_float2 waterSize;
} LotsaWaterMetalUniforms;

@interface LotsaWaterView:LotsaView <MTKViewDelegate>
{
	NSBitmapImageRep *screenshot;

	MTKView *metalView;
	id<MTLDevice> metalDevice;
	id<MTLCommandQueue> commandQueue;
	id<MTLRenderPipelineState> pipelineState;
	id<MTLTexture> wallpaperTexture;
	id<MTLTexture> reflectionTexture;
	id<MTLBuffer> vertexBuffer;
	id<MTLBuffer> indexBuffer;
	NSUInteger indexCount;

	double t,t_next,t_div;
	double raintime,waterdepth;

	// Portion of the source image used to fill the current screen.
	float tex_u0,tex_v0,tex_uscale,tex_vscale;
	float water_w,water_h;
	BOOL animationInitialized;

	Water wet;

	IBOutlet NSSlider *detail;
	IBOutlet NSSlider *accuracy;
	IBOutlet NSSlider *slomo;
	IBOutlet NSSlider *depth;
	IBOutlet NSSlider *rainfall;
	IBOutlet NSSlider *imagefade;
	IBOutlet NSPopUpButton *imgsrc;
	IBOutlet LWImagePicker *imageview;
}

-(id)initWithFrame:(NSRect)frame isPreview:(BOOL)preview;
-(void)dealloc;

-(void)startAnimationWithDefaults:(ScreenSaverDefaults *)defaults;
-(void)stopAnimation;
-(void)animateOneFrame;

-(void)updateConfigWindow:(NSWindow *)window usingDefaults:(ScreenSaverDefaults *)defaults;
-(void)updateDefaults:(ScreenSaverDefaults *)defaults usingConfigWindow:(NSWindow *)window;

-(IBAction)pickImageSource:(id)sender;
-(IBAction)dropImage:(id)sender;

+(BOOL)performGammaFade;

@end



@interface LWImagePicker:NSImageView
{
	NSString *filename;
}

-(void)concludeDragOperation:(id <NSDraggingInfo>)sender;
-(void)setFileName:(NSString *)newname;
-(NSString *)fileName;

@end
