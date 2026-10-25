#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <math.h>

static NSString *const kRoot = @"/var/mobile/Media/IslandPrism";
static NSString *const kConfig = @"/var/mobile/Media/IslandPrism/config.json";
static NSString *const kDisableFlag = @"/var/mobile/Media/IslandPrism/disable-overlay";

@interface IPPassthroughWindow : UIWindow
@end
@implementation IPPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
@end

@interface IslandPrismController : NSObject
@property(nonatomic,strong) IPPassthroughWindow *window;
@property(nonatomic,strong) UIView *island;
@property(nonatomic,strong) UIView *rim;
@property(nonatomic,strong) UIView *backgroundHolder;
@property(nonatomic,strong) UIImageView *backgroundImage;
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) AVPlayerLayer *videoLayer;
@property(nonatomic,strong) UIImageView *left;
@property(nonatomic,strong) UIImageView *right;
@property(nonatomic,strong) NSDictionary *options;
@property(nonatomic,strong) NSTimer *reloadTimer;
@property(nonatomic,strong) NSData *configSnapshot;
@property(nonatomic,strong) NSData *rejectedConfigSnapshot;
@property(nonatomic,assign) unsigned long long rejectedConfigSize;
@property(nonatomic,assign) CGSize lastScreenSize;
@property(nonatomic,assign) BOOL captured;
@property(nonatomic,assign) BOOL disabledByFlag;
@property(nonatomic,assign) CGRect lastIslandBox;
@property(nonatomic,copy) NSString *lastMediaSignature;
@property(nonatomic,assign) BOOL lastDecorationsPaused;
+ (instancetype)shared;
- (void)start;
@end

@implementation IslandPrismController
+ (instancetype)shared { static IslandPrismController *s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; }); return s; }

static CGFloat IPNumber(NSDictionary *d, NSString *k, CGFloat fallback) {
    id v=d[k];
    if (![v respondsToSelector:@selector(doubleValue)]) return fallback;
    double n=[v doubleValue];
    return isfinite(n) ? n : fallback;
}
static BOOL IPBool(NSDictionary *d, NSString *k, BOOL fallback) {
    id v=d[k]; return [v respondsToSelector:@selector(boolValue)] ? [v boolValue] : fallback;
}
static NSString *IPString(NSDictionary *d, NSString *k, NSString *fallback) {
    return [d[k] isKindOfClass:NSString.class] ? d[k] : fallback;
}
static NSString *IPMediaPath(NSString *relative) {
    if (!relative.length) return nil;
    // Prevent paths outside the user-media directory.
    NSString *full=[[kRoot stringByAppendingPathComponent:relative] stringByStandardizingPath];
    if (![full hasPrefix:[kRoot stringByAppendingString:@"/"]]) return nil;
    // Block symlink escapes (including intermediate path components).
    NSString *resolved=[full stringByResolvingSymlinksInPath];
    NSString *resolvedRoot=[kRoot stringByResolvingSymlinksInPath];
    if (![resolved hasPrefix:[resolvedRoot stringByAppendingString:@"/"]]) return nil;
    return full;
}
static UIColor *IPSolid(NSDictionary *options) {
    NSString *hex=IPString(options,@"solidColor",@"#3DDCFF");
    if(hex.length!=7 || ![hex hasPrefix:@"#"]) return UIColor.cyanColor;
    unsigned value=0; NSScanner *scanner=[NSScanner scannerWithString:[hex substringFromIndex:1]];
    if(![scanner scanHexInt:&value] || !scanner.isAtEnd) return UIColor.cyanColor;
    return [UIColor colorWithRed:((value>>16)&255)/255.0 green:((value>>8)&255)/255.0 blue:(value&255)/255.0 alpha:1];
}
static UIColor *IPColor(CGFloat hue) { return [UIColor colorWithHue:hue saturation:0.95 brightness:1 alpha:1]; }

- (void)start {
    // UIKit and window setup must stay on the main thread.
    if (![NSThread isMainThread]) { dispatch_async(dispatch_get_main_queue(), ^{ [self start]; }); return; }
    if (self.window || !UIApplication.sharedApplication) return;
    CGRect screen=UIScreen.mainScreen.bounds;
    self.window=[[IPPassthroughWindow alloc] initWithFrame:screen];
    self.window.windowLevel=UIWindowLevelStatusBar+150;
    self.window.backgroundColor=UIColor.clearColor;
    self.window.userInteractionEnabled=NO;
    UIViewController *vc=[UIViewController new];
    vc.view.backgroundColor=UIColor.clearColor;
    vc.view.userInteractionEnabled=NO;
    self.window.rootViewController=vc;
    self.window.hidden=NO;
    self.island=[UIView new]; self.island.userInteractionEnabled=NO;
    self.island.backgroundColor=UIColor.clearColor;
    [vc.view addSubview:self.island];
    self.backgroundHolder=[UIView new];
    self.backgroundHolder.clipsToBounds=YES;
    [self.island addSubview:self.backgroundHolder];
    self.backgroundImage=[UIImageView new]; self.backgroundImage.contentMode=UIViewContentModeScaleAspectFill;
    self.backgroundImage.clipsToBounds=YES;
    [self.backgroundHolder addSubview:self.backgroundImage];
    self.rim=[UIView new]; self.rim.userInteractionEnabled=NO;
    [self.island addSubview:self.rim];
    self.left=[UIImageView new]; self.right=[UIImageView new];
    self.left.contentMode=self.right.contentMode=UIViewContentModeScaleAspectFit;
    [vc.view addSubview:self.left]; [vc.view addSubview:self.right];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reconfigure) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCaptureState) name:UIScreenCapturedDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCaptureState) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    [self reconfigure];
    self.reloadTimer=[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(checkConfig) userInfo:nil repeats:YES];
}

- (void)checkConfig {
    NSData *current=[NSData dataWithContentsOfFile:kConfig];
    BOOL hasNewConfig = ![current isEqualToData:self.configSnapshot] && ![current isEqualToData:self.rejectedConfigSnapshot];
    if (hasNewConfig || !CGSizeEqualToSize(UIScreen.mainScreen.bounds.size,self.lastScreenSize)) [self reconfigure];
    BOOL disabled=[[NSFileManager defaultManager] fileExistsAtPath:kDisableFlag];
    if (disabled!=self.disabledByFlag) [self updateCaptureState];
    BOOL now=UIScreen.mainScreen.isCaptured;
    if (now!=self.captured) [self updateCaptureState];
}
- (void)updateCaptureState {
    self.captured=UIScreen.mainScreen.isCaptured;
    self.disabledByFlag=[[NSFileManager defaultManager] fileExistsAtPath:kDisableFlag];
    BOOL hide=IPBool(self.options,@"hideOnCapture",NO) && self.captured;
    BOOL lowPower=[NSProcessInfo processInfo].lowPowerModeEnabled && IPBool(self.options,@"pauseInLowPower",NO);
    self.window.hidden=self.disabledByFlag || hide || lowPower || !IPBool(self.options,@"enabled",YES);
    // Stop expensive image sequence animation while the overlay is not visible.
    if (self.window.hidden) { [self.left stopAnimating]; [self.right stopAnimating]; [self.backgroundImage stopAnimating]; }
    else { if (self.left.animationImages.count>1) [self.left startAnimating]; if (self.right.animationImages.count>1) [self.right startAnimating]; if (self.backgroundImage.animationImages.count>1) [self.backgroundImage startAnimating]; }
    // Pause Core Animation work when decorations are invisible; restore when visible.
    BOOL pauseDecorations=self.window.hidden;
    if (pauseDecorations != self.lastDecorationsPaused) {
        self.lastDecorationsPaused=pauseDecorations;
        CFTimeInterval now=[self.rim.layer convertTime:CACurrentMediaTime() fromLayer:nil];
        if (pauseDecorations) { self.rim.layer.speed=0; self.rim.layer.timeOffset=now; }
        else {
            CFTimeInterval paused=self.rim.layer.timeOffset;
            self.rim.layer.speed=1; self.rim.layer.timeOffset=0; self.rim.layer.beginTime=0;
            self.rim.layer.beginTime=[self.rim.layer convertTime:CACurrentMediaTime() fromLayer:nil]-paused;
        }
    }
    if (hide || self.window.hidden) [self.player pause];
    else if (self.player && self.player.rate==0) [self.player play];
    // Capture behavior affects this overlay only, never system-owned island pixels.
    if (IPBool(self.options,@"captureCover",NO) && self.captured) {
        // Do not draw an opaque fake cover over system Live Activities.
        self.backgroundHolder.backgroundColor=UIColor.clearColor;
    } else { self.backgroundHolder.backgroundColor=UIColor.clearColor; }
}
- (NSArray<UIImage *> *)framesAt:(NSString *)relative {
    NSString *folder=IPMediaPath(relative);
    BOOL isDir=NO;
    if (!folder || ![[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir] || !isDir) return @[];
    NSArray *files=[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    NSMutableArray *imgs=[NSMutableArray array];
    NSUInteger decodedPixels=0;
    for (NSString *file in files) {
        if (![[file.pathExtension lowercaseString] isEqualToString:@"png"]) continue;
        NSString *item=[folder stringByAppendingPathComponent:file];
        NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:item error:nil];
        if ([attributes fileSize] > 2 * 1024 * 1024) continue;
        UIImage *img=[UIImage imageWithContentsOfFile:item];
        // Cap decoded image memory per side (roughly 24 MiB).
        if (!img || img.size.width * img.scale * img.size.height * img.scale > 700000) continue;
        NSUInteger pixels=(NSUInteger)(img.size.width*img.scale)*(NSUInteger)(img.size.height*img.scale);
        if (decodedPixels + pixels > 6000000) break;
        decodedPixels += pixels;
        [imgs addObject:img];
        if (imgs.count>=120) break;
    }
    return imgs;
}
- (void)setFramesFor:(UIImageView *)view folder:(NSString *)folder fps:(CGFloat)fps {
    [view stopAnimating]; view.animationImages=nil; view.image=nil;
    NSArray *imgs=[self framesAt:folder];
    if (imgs.count==1) view.image=imgs.firstObject;
    if (imgs.count>1) { view.animationImages=imgs; view.animationDuration=imgs.count/MAX(1,MIN(30,fps)); view.animationRepeatCount=0; [view startAnimating]; }
}
- (void)clearAnimationLayers {
    [self.rim.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [self.rim.layer removeAllAnimations];
    self.rim.layer.shadowOpacity=0;
}
- (void)drawRim:(CGRect)b {
    [self clearAnimationLayers];
    NSString *effect=IPString(self.options,@"effect",@"rainbow");
    CGFloat width=MAX(1,MIN(10,IPNumber(self.options,@"outlineWidth",2.5)));
    CGRect rect=CGRectInset(b,width/2+1,width/2+1);
    CGFloat radius=rect.size.height/2;
    UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    CAShapeLayer *stroke=[CAShapeLayer layer]; stroke.frame=b;
    stroke.path=path.CGPath; stroke.fillColor=UIColor.clearColor.CGColor;
    stroke.strokeColor=UIColor.whiteColor.CGColor; stroke.lineWidth=width;
    stroke.lineCap=kCALineCapRound;
    if ([effect isEqualToString:@"solid"]) {
        stroke.strokeColor=IPSolid(self.options).CGColor;
        [self.rim.layer addSublayer:stroke];
    } else {
        CAGradientLayer *grad=[CAGradientLayer layer]; grad.frame=b;
        grad.type=kCAGradientLayerConic;
        grad.startPoint=CGPointMake(0.5,0.5); grad.endPoint=CGPointMake(0.5,0);
        NSMutableArray *colors=[NSMutableArray array];
        for (NSUInteger i=0;i<=12;i++) [colors addObject:(id)IPColor((CGFloat)i/12.0).CGColor];
        grad.colors=colors; grad.mask=stroke;
        [self.rim.layer addSublayer:grad];
        CABasicAnimation *rotation=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotation.fromValue=@0; rotation.toValue=@(M_PI*2);
        rotation.duration=[effect isEqualToString:@"meteor"]?1.25:4.0;
        rotation.repeatCount=HUGE_VALF;
        if ([effect isEqualToString:@"rainbow"] || [effect isEqualToString:@"meteor"]) [grad addAnimation:rotation forKey:@"spin"];
        if ([effect isEqualToString:@"meteor"]) {
            grad.colors=@[(id)[UIColor clearColor].CGColor,(id)[UIColor clearColor].CGColor,(id)UIColor.cyanColor.CGColor,(id)UIColor.whiteColor.CGColor,(id)[UIColor clearColor].CGColor];
            grad.locations=@[@0,@0.55,@0.85,@0.93,@1];
        }
        if ([effect isEqualToString:@"stage"]) {
            CABasicAnimation *pulse=[CABasicAnimation animationWithKeyPath:@"opacity"];
            pulse.fromValue=@0.25; pulse.toValue=@1; pulse.duration=0.36; pulse.autoreverses=YES; pulse.repeatCount=HUGE_VALF;
            [grad addAnimation:pulse forKey:@"pulse"];
        }
        if ([effect isEqualToString:@"marquee"]) {
            stroke.strokeStart=0.01; stroke.strokeEnd=0.20;
            CABasicAnimation *moving=[CABasicAnimation animationWithKeyPath:@"strokeStart"];
            moving.fromValue=@(-0.20); moving.toValue=@1; moving.duration=1.5; moving.repeatCount=HUGE_VALF;
            [stroke addAnimation:moving forKey:@"marchStart"];
            CABasicAnimation *end=[CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            end.fromValue=@0; end.toValue=@1.20; end.duration=1.5; end.repeatCount=HUGE_VALF;
            [stroke addAnimation:end forKey:@"marchEnd"];
        }
    }
    if (IPBool(self.options,@"glow",YES)) {
        self.rim.layer.shadowColor=UIColor.systemPinkColor.CGColor;
        self.rim.layer.shadowRadius=12;
        self.rim.layer.shadowOpacity=MIN(1,MAX(0,IPNumber(self.options,@"glowIntensity",0.8)));
        self.rim.layer.shadowOffset=CGSizeZero;
        self.rim.layer.shadowPath=path.CGPath;
        CAKeyframeAnimation *glow=[CAKeyframeAnimation animationWithKeyPath:@"shadowColor"];
        NSMutableArray *c=[NSMutableArray array];
        for (NSUInteger i=0;i<=8;i++) [c addObject:(id)IPColor((CGFloat)i/8).CGColor];
        glow.values=c; glow.duration=3.2; glow.repeatCount=HUGE_VALF;
        [self.rim.layer addAnimation:glow forKey:@"glowColors"];
    }
}
- (void)setBackground {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [self.player pause]; self.player=nil;
    [self.videoLayer removeFromSuperlayer]; self.videoLayer=nil;
    [self.backgroundImage stopAnimating];
    self.backgroundImage.animationImages=nil;
    self.backgroundImage.image=nil;
    NSString *file=IPMediaPath(IPString(self.options,@"background",@""));
    if (!file || ![[NSFileManager defaultManager] fileExistsAtPath:file]) return;
    NSDictionary *info=[[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
    if ([info fileSize] > 40 * 1024 * 1024) return;
    NSString *ext=file.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mp4"]) {
        self.player=[AVPlayer playerWithURL:[NSURL fileURLWithPath:file]];
        self.player.muted=YES; self.player.actionAtItemEnd=AVPlayerActionAtItemEndNone;
        self.videoLayer=[AVPlayerLayer playerLayerWithPlayer:self.player];
        self.videoLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
        self.videoLayer.frame=self.backgroundHolder.bounds;
        [self.backgroundHolder.layer insertSublayer:self.videoLayer atIndex:0];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loopMovie:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
        [self.player play];
    } else if ([ext isEqualToString:@"gif"]) {
        CGImageSourceRef src=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:file],NULL);
        if (src) {
            size_t count=MIN(CGImageSourceGetCount(src),60);
            NSUInteger decodedPixels=0;
            NSMutableArray *arr=[NSMutableArray array];
            NSTimeInterval duration=0;
            for(size_t i=0;i<count;i++) {
                CGImageRef cg=CGImageSourceCreateImageAtIndex(src,i,NULL);
                if(cg) {
                    NSUInteger pixels=(NSUInteger)CGImageGetWidth(cg)*(NSUInteger)CGImageGetHeight(cg);
                    if (pixels>700000 || decodedPixels+pixels>6000000) { CGImageRelease(cg); break; }
                    decodedPixels+=pixels;
                    [arr addObject:[UIImage imageWithCGImage:cg]]; CGImageRelease(cg);
                }
                CFDictionaryRef props=CGImageSourceCopyPropertiesAtIndex(src,i,NULL);
                NSDictionary *d=CFBridgingRelease(props) ?: @{};
                NSNumber *t=d[(NSString *)kCGImagePropertyGIFDictionary][(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
                if (!t) t=d[(NSString *)kCGImagePropertyGIFDictionary][(NSString *)kCGImagePropertyGIFDelayTime];
                duration+=MAX(0.02,t ? t.doubleValue:0.1);
            }
            CFRelease(src);
            if(arr.count) {
                self.backgroundImage.animationImages=arr;
                self.backgroundImage.animationDuration=MAX(0.1,duration);
                [self.backgroundImage startAnimating];
            }
        }
    } else if ([ext isEqualToString:@"png"] || [ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
        self.backgroundImage.image=[UIImage imageWithContentsOfFile:file];
    }
    self.backgroundImage.alpha=MAX(0,MIN(1,IPNumber(self.options,@"backgroundAlpha",1)));
}
- (void)loopMovie:(NSNotification *)note {
    if (note.object==self.player.currentItem && !self.window.hidden) { [self.player seekToTime:kCMTimeZero]; [self.player play]; }
}
- (NSString *)mediaStampFor:(NSString *)path {
    if (!path.length) return @"none";
    NSFileManager *fm=NSFileManager.defaultManager;
    NSDictionary *attr=[fm attributesOfItemAtPath:path error:nil];
    if (!attr) return @"missing";
    BOOL isDir=[attr[NSFileType] isEqualToString:NSFileTypeDirectory];
    if (!isDir) return [NSString stringWithFormat:@"%@:%@", attr[NSFileModificationDate], attr[NSFileSize]];
    NSArray *names=[[fm contentsOfDirectoryAtPath:path error:nil] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *stamp=[NSMutableString stringWithFormat:@"%lu",(unsigned long)names.count];
    // Bound the metadata scan to the same 120 frames used by the decoder.
    NSUInteger count=0;
    for (NSString *name in names) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"png"]) continue;
        NSDictionary *item=[fm attributesOfItemAtPath:[path stringByAppendingPathComponent:name] error:nil];
        [stamp appendFormat:@"|%@:%@:%@",name,item[NSFileModificationDate],item[NSFileSize]];
        if (++count>=120) break;
    }
    return stamp;
}
- (void)reconfigure {
    NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:kConfig error:nil];
    // Ignore unexpectedly huge configs in SpringBoard (normal config is only a few KB).
    if (attributes && [attributes fileSize] > 256 * 1024) {
        // Avoid re-reading or repeatedly logging a rejected oversized file.
        unsigned long long size = [attributes fileSize];
        if (self.rejectedConfigSize != size) NSLog(@"[IslandPrism] Ignoring oversized config");
        self.rejectedConfigSize = size;
        return;
    }
    self.rejectedConfigSize = 0;
    NSData *data=[NSData dataWithContentsOfFile:kConfig];
    NSError *parseError=nil;
    id parsed=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError] : nil;
    // Malformed/partially-written config must not reset a running SpringBoard overlay.
    if (data && ![parsed isKindOfClass:NSDictionary.class]) {
        if (![data isEqualToData:self.rejectedConfigSnapshot]) NSLog(@"[IslandPrism] Ignoring invalid config: %@", parseError);
        self.rejectedConfigSnapshot = [data copy];
        return;
    }
    self.options=[parsed isKindOfClass:NSDictionary.class] ? parsed : @{};
    self.configSnapshot=[data copy];
    self.rejectedConfigSnapshot=nil;
    self.lastScreenSize=UIScreen.mainScreen.bounds.size;
    if (!self.window) return;
    self.window.frame=UIScreen.mainScreen.bounds;
    self.window.rootViewController.view.frame=self.window.bounds;
    CGRect screen=UIScreen.mainScreen.bounds;
    // Tuned for iPhone 14 Pro Max (430x932pt); intentionally does not alter the physical cutout.
    // iOS 16 has no stable public API exposing Dynamic Island expanded bounds.
    // User-selectable geometry presets: automatic is conservative and falls back
    // to compact rather than guessing private SpringBoard classes.
    NSString *mode=IPString(self.options,@"islandMode",@"compact");
    // Auto is intentionally compact until an iOS 16.5 live-activity integration is
    // measured and tested. We must not misrepresent it as native-state detection.
    CGFloat islandWidth=126, islandHeight=37, islandY=11;
    if ([mode isEqualToString:@"expanded"]) { islandWidth=MAX(126,MIN(screen.size.width-36,330)); islandHeight=90; islandY=9; }
    if ([mode isEqualToString:@"custom"]) {
        islandWidth=MAX(90,MIN(screen.size.width-20,IPNumber(self.options,@"islandWidth",126)));
        islandHeight=MAX(28,MIN(160,IPNumber(self.options,@"islandHeight",37)));
        islandY=MAX(0,MIN(90,IPNumber(self.options,@"islandY",11)));
    }
    CGRect box=CGRectMake((screen.size.width-islandWidth)/2,islandY,islandWidth,islandHeight);
    BOOL geometryChanged=!CGRectEqualToRect(self.lastIslandBox,box);
    self.lastIslandBox=box;
    self.island.frame=box;
    self.backgroundHolder.frame=self.island.bounds;
    self.backgroundHolder.layer.cornerRadius=islandHeight/2;
    self.backgroundImage.frame=self.backgroundHolder.bounds;
    self.videoLayer.frame=self.backgroundHolder.bounds;
    self.rim.frame=self.island.bounds;
    CGFloat size=MAX(16,MIN(75,IPNumber(self.options,@"sideSize",38)));
    CGFloat gap=MAX(0,MIN(60,IPNumber(self.options,@"sideGap",10)));
    CGFloat y=CGRectGetMidY(box)-size/2;
    self.left.frame=CGRectMake(CGRectGetMinX(box)-gap-size+MAX(-70,MIN(70,IPNumber(self.options,@"leftOffsetX",0))),y+MAX(-70,MIN(70,IPNumber(self.options,@"leftOffsetY",0))),size,size);
    self.right.frame=CGRectMake(CGRectGetMaxX(box)+gap+MAX(-70,MIN(70,IPNumber(self.options,@"rightOffsetX",0))),y+MAX(-70,MIN(70,IPNumber(self.options,@"rightOffsetY",0))),size,size);
    (void)geometryChanged; // Layout recalculated when screen size or settings change.
    [self drawRim:self.rim.bounds];
    // Only reload decoded media when media-related settings or source timestamps change.
    // Geometry, glow, and toggles shouldn't repeatedly decode hundreds of frames.
    NSString *bg=IPString(self.options,@"background",@"");
    NSString *lf=IPString(self.options,@"leftFolder",@"left");
    NSString *rf=IPString(self.options,@"rightFolder",@"right");
    CGFloat fps=IPNumber(self.options,@"fps",12);
    NSString *mediaSignature=[NSString stringWithFormat:@"%@|%@|%@|%.2f|%.2f|%.2f|%.2f|%@|%@|%@",
        bg, lf, rf, fps, IPNumber(self.options,@"leftFPS",fps),
        IPNumber(self.options,@"rightFPS",fps), IPNumber(self.options,@"backgroundAlpha",1),
        [self mediaStampFor:IPMediaPath(bg)], [self mediaStampFor:IPMediaPath(lf)],
        [self mediaStampFor:IPMediaPath(rf)]];
    if (![mediaSignature isEqualToString:self.lastMediaSignature]) {
        self.lastMediaSignature=mediaSignature;
        [self setBackground];
        [self setFramesFor:self.left folder:lf fps:IPNumber(self.options,@"leftFPS",fps)];
        [self setFramesFor:self.right folder:rf fps:IPNumber(self.options,@"rightFPS",fps)];
    }
    [self updateCaptureState];
}
@end

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[IslandPrismController shared] start];
        });
    }
}
