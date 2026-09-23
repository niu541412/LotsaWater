#import "LotsaCore/LotsaView.h"
#import "Water.h"

#import <SpriteKit/SpriteKit.h>
#import <simd/simd.h>

#import "LotsaCore/NameMangler.h"
#define LotsaWaterView MangleClassName(LotsaWaterView)
#define ImagePicker MangleClassName(ImagePicker)

@class ImagePicker;

@interface LotsaWaterView:LotsaView
{
	NSBitmapImageRep *screenshot;

	SKView *spriteView;
	SKScene *scene;
	SKSpriteNode *waterNode;
	SKSpriteNode *shadeNode;
	SKSpriteNode *reflectionNode;
	SKMutableTexture *surfaceTexture;
	SKUniform *shadeSurfaceUniform;
	SKUniform *reflectionSurfaceUniform;

	double t,t_next,t_div;
	double raintime,waterdepth;

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
