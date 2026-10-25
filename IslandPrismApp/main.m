#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const root=@"/var/mobile/Media/IslandPrism";
static NSString *const config=@"/var/mobile/Media/IslandPrism/config.json";
@interface IPPreviewView : UIView
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) CAShapeLayer *outline;
@property(nonatomic,strong) CAGradientLayer *gradient;
@property(nonatomic,strong) UIImageView *leftIcon;
@property(nonatomic,strong) UIImageView *rightIcon;
@property(nonatomic,strong) UILabel *caption;
- (void)refreshWithSettings:(NSDictionary *)settings;
@end
@implementation IPPreviewView
- (instancetype)initWithFrame:(CGRect)frame { if ((self=[super initWithFrame:frame])) {
    self.backgroundColor=[UIColor colorWithRed:0.075 green:0.085 blue:0.12 alpha:1];
    self.layer.cornerRadius=18; self.clipsToBounds=YES;
    self.gradient=[CAGradientLayer layer]; self.gradient.type=kCAGradientLayerConic;
    NSMutableArray *colors=[NSMutableArray array]; for(int i=0;i<=12;i++) [colors addObject:(id)[UIColor colorWithHue:i/12.0 saturation:1 brightness:1 alpha:1].CGColor];
    self.gradient.colors=colors; [self.layer addSublayer:self.gradient];
    self.outline=[CAShapeLayer layer]; self.outline.fillColor=UIColor.clearColor.CGColor;
    self.gradient.mask=self.outline;
    self.leftIcon=[UIImageView new]; self.rightIcon=[UIImageView new];
    self.leftIcon.contentMode=self.rightIcon.contentMode=UIViewContentModeScaleAspectFit;
    [self addSubview:self.leftIcon]; [self addSubview:self.rightIcon];
    self.caption=[UILabel new]; self.caption.text=@"模拟预览 · 不代表系统实际岛形";
    self.caption.font=[UIFont systemFontOfSize:11]; self.caption.textColor=UIColor.lightGrayColor;
    self.caption.textAlignment=NSTextAlignmentCenter; [self addSubview:self.caption];
} return self; }
- (void)layoutSubviews { [super layoutSubviews]; CGFloat w=126,h=37;
    CGRect r=CGRectMake((self.bounds.size.width-w)/2,39,w,h);
    self.gradient.frame=self.bounds;
    UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(r,1.5,1.5) cornerRadius:h/2];
    self.outline.frame=self.bounds; self.outline.path=p.CGPath;
    CGFloat size=MAX(16,MIN(75,[self.settings[@"sideSize"] doubleValue]?:38));
    CGFloat gap=MAX(0,MIN(60,[self.settings[@"sideGap"] doubleValue]?:10));
    CGFloat y=CGRectGetMidY(r)-size/2;
    self.leftIcon.frame=CGRectMake(CGRectGetMinX(r)-size-gap,y,size,size);
    self.rightIcon.frame=CGRectMake(CGRectGetMaxX(r)+gap,y,size,size);
    self.caption.frame=CGRectMake(0,self.bounds.size.height-26,self.bounds.size.width,18);
    if ([self.settings[@"effect"] isEqual:@"solid"]) self.outline.strokeColor=[self solidColor].CGColor;
    else self.outline.strokeColor=UIColor.whiteColor.CGColor;
    self.outline.lineWidth=MAX(1,MIN(10,[self.settings[@"outlineWidth"] doubleValue]?:2.5));
    self.gradient.colors=[self.settings[@"effect"] isEqual:@"solid"]?@[(id)[self solidColor].CGColor,(id)[self solidColor].CGColor]:self.gradient.colors;
}
- (UIColor *)solidColor { NSString *s=self.settings[@"solidColor"]; if (![s isKindOfClass:NSString.class] || s.length!=7 || ![s hasPrefix:@"#"]) return UIColor.cyanColor;
    unsigned int v=0; NSScanner *scanner=[NSScanner scannerWithString:[s substringFromIndex:1]];
    if (![scanner scanHexInt:&v] || !scanner.isAtEnd) return UIColor.cyanColor;
    return [UIColor colorWithRed:((v>>16)&255)/255.0 green:((v>>8)&255)/255.0 blue:(v&255)/255.0 alpha:1]; }
- (void)refreshWithSettings:(NSDictionary *)settings { self.settings=settings;
    [self.gradient removeAllAnimations];
    NSString *effect=settings[@"effect"]?:@"rainbow";
    if (![effect isEqual:@"solid"]) { NSMutableArray *colors=[NSMutableArray array]; for(int i=0;i<=12;i++) [colors addObject:(id)[UIColor colorWithHue:i/12.0 saturation:1 brightness:1 alpha:1].CGColor]; self.gradient.colors=colors;
        CABasicAnimation *a=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"]; a.fromValue=@0; a.toValue=@(M_PI*2); a.duration=[effect isEqual:@"meteor"]?1.25:4; a.repeatCount=HUGE_VALF;
        [self.gradient addAnimation:a forKey:@"spin"]; }
    NSString *base=@"/var/mobile/Media/IslandPrism";
    for (int side=0;side<2;side++) { NSString *folder=side?@"right":@"left"; UIImageView *v=side?self.rightIcon:self.leftIcon;
        [v stopAnimating]; v.animationImages=nil; v.image=nil;
        NSArray *files=[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[base stringByAppendingPathComponent:folder] error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        NSMutableArray *frames=[NSMutableArray array]; for(NSString *f in files) { if (![[f.pathExtension lowercaseString] isEqual:@"png"]) continue;
            UIImage *img=[UIImage imageWithContentsOfFile:[[base stringByAppendingPathComponent:folder] stringByAppendingPathComponent:f]];
            if(img) [frames addObject:img]; if(frames.count>=60) break; }
        if(frames.count==1) v.image=frames.firstObject; else if(frames.count>1) {v.animationImages=frames;
            CGFloat fps=MAX(1,MIN(30,[settings[side?@"rightFPS":@"leftFPS"] doubleValue]?:12));
            v.animationDuration=frames.count/fps; [v startAnimating]; }
    }
    [self setNeedsLayout];
}
@end
@interface IPAppController : UITableViewController <UIDocumentPickerDelegate, UIColorPickerViewControllerDelegate>
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,copy) NSString *importTarget;
@property(nonatomic,copy) NSString *colorKey;
@property(nonatomic,strong) IPPreviewView *preview;
@end
@implementation IPAppController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"灵动幻彩岛"; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(loadSettings)]; self.items=@[
@{ @"label":@"灵动岛布局模式",@"key":@"islandMode",@"type":@"islandMode" },
@{ @"label":@"自定义岛宽 (90–410)",@"key":@"islandWidth",@"type":@"number",@"min":@90,@"max":@410 },
@{ @"label":@"自定义岛高 (28–160)",@"key":@"islandHeight",@"type":@"number",@"min":@28,@"max":@160 },
@{ @"label":@"自定义顶部 Y (0–90)",@"key":@"islandY",@"type":@"number",@"min":@0,@"max":@90 },
@{ @"label":@"纯色光圈颜色 (#RRGGBB)",@"key":@"solidColor",@"type":@"color" },
@{ @"label":@"左侧独立帧率 (1–30)",@"key":@"leftFPS",@"type":@"number",@"min":@1,@"max":@30 },
@{ @"label":@"右侧独立帧率 (1–30)",@"key":@"rightFPS",@"type":@"number",@"min":@1,@"max":@30 },
@{ @"label":@"左侧水平偏移 (-70–70)",@"key":@"leftOffsetX",@"type":@"number",@"min":@-70,@"max":@70 },
@{ @"label":@"右侧水平偏移 (-70–70)",@"key":@"rightOffsetX",@"type":@"number",@"min":@-70,@"max":@70 },
@{ @"label":@"左侧垂直偏移 (-70–70)",@"key":@"leftOffsetY",@"type":@"number",@"min":@-70,@"max":@70 },
@{ @"label":@"右侧垂直偏移 (-70–70)",@"key":@"rightOffsetY",@"type":@"number",@"min":@-70,@"max":@70 },
@{ @"label":@"启用灵动岛美化",@"key":@"enabled",@"type":@"bool" },
@{ @"label":@"紧急停用覆盖层（最多3秒生效）",@"type":@"rescue" },
@{ @"label":@"启用七彩阴影",@"key":@"glow",@"type":@"bool" },
@{ @"label":@"录屏时隐藏插件覆盖层",@"key":@"hideOnCapture",@"type":@"bool" },
@{ @"label":@"边框样式",@"key":@"effect",@"type":@"effect" },
@{ @"label":@"边框粗细 (1–10)",@"key":@"outlineWidth",@"type":@"number",@"min":@1,@"max":@10 },
@{ @"label":@"阴影强度 (0–1)",@"key":@"glowIntensity",@"type":@"number",@"min":@0,@"max":@1 },
@{ @"label":@"背景透明度 (0–1)",@"key":@"backgroundAlpha",@"type":@"number",@"min":@0,@"max":@1 },
@{ @"label":@"PNG 动画帧率 (1–30)",@"key":@"fps",@"type":@"number",@"min":@1,@"max":@30 },
@{ @"label":@"侧边动画尺寸 (16–75)",@"key":@"sideSize",@"type":@"number",@"min":@16,@"max":@75 },
@{ @"label":@"侧边间距 (0–60)",@"key":@"sideGap",@"type":@"number",@"min":@0,@"max":@60 },
@{ @"label":@"导入背景 PNG/JPG/GIF/MP4",@"type":@"import",@"target":@"background" },
@{ @"label":@"导入左侧 PNG 序列（逐个导入）",@"type":@"import",@"target":@"left" },
@{ @"label":@"导入右侧 PNG 序列（逐个导入）",@"type":@"import",@"target":@"right" },
@{ @"label":@"清空背景",@"type":@"clear" }
]; self.preview=[[IPPreviewView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,150)];
self.tableView.tableHeaderView=self.preview; [self loadSettings]; }
- (void)loadSettings { NSData *d=[NSData dataWithContentsOfFile:config]; id o=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil; self.settings=[o isKindOfClass:NSDictionary.class]?[o mutableCopy]:[NSMutableDictionary dictionary]; [self.tableView reloadData]; [self.preview refreshWithSettings:self.settings]; }
- (void)save { [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil]; NSData *d=[NSJSONSerialization dataWithJSONObject:self.settings options:NSJSONWritingPrettyPrinted error:nil]; NSError *writeError=nil; BOOL saved=(d && [d writeToFile:config options:NSDataWritingAtomic error:&writeError]); if (!saved) { NSLog(@"[IslandPrism] Save failed: %@",writeError); [self show:@"设置保存失败，请检查文件权限和可用空间"]; } [self.tableView reloadData]; [self.preview refreshWithSettings:self.settings]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)index { NSDictionary *item=self.items[index.row]; UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil]; c.textLabel.text=item[@"label"]; c.textLabel.font=[UIFont systemFontOfSize:14]; NSString *type=item[@"type"]; NSString *key=item[@"key"]; if ([type isEqual:@"bool"]) { UISwitch *sw=[UISwitch new]; sw.on=[self.settings[key] boolValue]; sw.tag=index.row; [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; c.accessoryView=sw; } else if (key) { c.detailTextLabel.text=[self.settings[key] description]?:@"默认"; c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; } else { c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; } return c; }
- (void)toggle:(UISwitch *)s { NSString *key=self.items[s.tag][@"key"]; self.settings[key]=@(s.on); [self save]; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)index { [t deselectRowAtIndexPath:index animated:YES]; NSDictionary *item=self.items[index.row]; NSString *type=item[@"type"]; NSString *key=item[@"key"]; if ([type isEqual:@"color"]) {
    UIColorPickerViewController *picker=[UIColorPickerViewController new];
    picker.supportsAlpha=NO;
    // iOS 14+ picker is native; selection is written in its delegate.
    self.colorKey=key;
    picker.delegate=self; [self presentViewController:picker animated:YES completion:nil];
}
else if ([type isEqual:@"islandMode"]) {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"灵动岛形状" message:@"自动模式当前回退到紧凑形状；展开需手动选择。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *labels=@{@"auto":@"自动（紧凑回退）",@"compact":@"紧凑",@"expanded":@"展开",@"custom":@"自定义"};
    for (NSString *mode in @[@"auto",@"compact",@"expanded",@"custom"]) [a addAction:[UIAlertAction actionWithTitle:labels[mode] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ self.settings[key]=mode; [self save]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView=t; a.popoverPresentationController.sourceRect=[t rectForRowAtIndexPath:index];
    [self presentViewController:a animated:YES completion:nil];
}
else if ([type isEqual:@"effect"]) { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"选择边框光效" message:nil preferredStyle:UIAlertControllerStyleActionSheet]; NSDictionary *choices=@{@"rainbow":@"彩虹环",@"meteor":@"彩虹流星",@"stage":@"舞台灯",@"marquee":@"跑马灯",@"solid":@"纯色线框"}; for (NSString *k in @[@"rainbow",@"meteor",@"stage",@"marquee",@"solid"]) [a addAction:[UIAlertAction actionWithTitle:choices[k] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ self.settings[key]=k; [self save]; }]]; [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; a.popoverPresentationController.sourceView=t; a.popoverPresentationController.sourceRect=[t rectForRowAtIndexPath:index]; [self presentViewController:a animated:YES completion:nil]; }
else if ([type isEqual:@"number"]) { UIAlertController *a=[UIAlertController alertControllerWithTitle:item[@"label"] message:@"输入有效范围内的数值" preferredStyle:UIAlertControllerStyleAlert]; [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.keyboardType=UIKeyboardTypeDecimalPad; f.text=[self.settings[key] description]; }]; [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ NSString *v=a.textFields.firstObject.text; NSScanner *scan=[NSScanner scannerWithString:v]; double n=0; if ([scan scanDouble:&n] && scan.isAtEnd && isfinite(n) && n >= [item[@"min"] doubleValue] && n <= [item[@"max"] doubleValue]) { self.settings[key]=@(n); [self save]; } else { [self show:@"数值不在有效范围内"]; } }]]; [self presentViewController:a animated:YES completion:nil]; }
else if ([type isEqual:@"import"]) { self.importTarget=item[@"target"]; UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image",@"public.movie",@"public.data"] inMode:UIDocumentPickerModeImport]; picker.delegate=self; picker.allowsMultipleSelection=![self.importTarget isEqual:@"background"]; [self presentViewController:picker animated:YES completion:nil]; }
else if ([type isEqual:@"rescue"]) {
    NSString *flag=[root stringByAppendingPathComponent:@"disable-overlay"];
    BOOL exists=[[NSFileManager defaultManager] fileExistsAtPath:flag];
    if (exists) [[NSFileManager defaultManager] removeItemAtPath:flag error:nil];
    else { [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        [@"disabled" writeToFile:flag atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
    [self show:exists?@"已移除紧急停用标记，覆盖层可恢复。":@"已创建停用标记，覆盖层将在下次轮询时隐藏。"];
}
else if ([type isEqual:@"clear"]) { self.settings[@"background"]=@""; [self save]; }
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls { BOOL background=[self.importTarget isEqual:@"background"]; NSString *dest=background?root:[root stringByAppendingPathComponent:self.importTarget]; [[NSFileManager defaultManager] createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:nil]; NSUInteger count=0; for (NSURL *url in urls) { NSString *ext=url.pathExtension.lowercaseString; BOOL okay=background?[@[@"png",@"jpg",@"jpeg",@"gif",@"mp4"] containsObject:ext]:[ext isEqual:@"png"]; if (!okay) continue;
    NSDictionary *attr=[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
    unsigned long long limit=background?40ULL*1024*1024:2ULL*1024*1024;
    if ([attr fileSize]>limit) continue;
    NSString *name=background?[NSString stringWithFormat:@"background.%@",ext]:[NSString stringWithFormat:@"frame-%@.png",NSUUID.UUID.UUIDString]; NSString *to=[dest stringByAppendingPathComponent:name]; [[NSFileManager defaultManager] removeItemAtPath:to error:nil]; if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:to] error:nil]) { count++; if (background) self.settings[@"background"]=name; } } [self save]; [self show:[NSString stringWithFormat:@"已导入 %lu 个文件",(unsigned long)count]]; }
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    CGFloat r=0,g=0,b=0,a=0;
    if(![viewController.selectedColor getRed:&r green:&g blue:&b alpha:&a]) return;
    self.settings[self.colorKey?:@"solidColor"]=[NSString stringWithFormat:@"#%02X%02X%02X",(int)round(r*255),(int)round(g*255),(int)round(b*255)]; [self save];
}
- (void)show:(NSString *)s { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"IslandPrism" message:s preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; }
@end
@interface IPAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation IPAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts { self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[IPAppController new]]; [self.window makeKeyAndVisible]; return YES; }
@end
int main(int argc, char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(IPAppDelegate.class)); } }
