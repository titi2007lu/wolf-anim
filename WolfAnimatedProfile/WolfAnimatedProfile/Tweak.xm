#import <objc/runtime.h>
// Wolf Animated Profile - avatar & cover dong (GIF / MP4) cho Facebook.
// Chi thay doi hien thi LOCAL tren may ban.
// Mo menu: nhan giu 3 ngon tay ~1 giay tren man hinh bat ky.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define kOverlayTag 0x574C4F56
#define kPrefEnabled @"wl_enabled"
#define kPrefMinSize @"wl_minsize"
#define kPrefDebug   @"wl_debug"
#define kRefreshNote @"WLRefreshNotification"

#pragma mark - Helpers

static NSUserDefaults *WLDefaults(void) { return [NSUserDefaults standardUserDefaults]; }
static BOOL WLEnabled(void) { return [WLDefaults() objectForKey:kPrefEnabled] ? [WLDefaults() boolForKey:kPrefEnabled] : YES; }
static CGFloat WLMinSize(void) { return [WLDefaults() objectForKey:kPrefMinSize] ? [WLDefaults() floatForKey:kPrefMinSize] : 100.0; }
static BOOL WLDebug(void) { return [WLDefaults() boolForKey:kPrefDebug]; }

static NSString *WLDir(void) {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *d = [docs stringByAppendingPathComponent:@"WolfAnim"];
    [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
    return d;
}

static NSArray *WLExts(void) { return @[@"gif", @"mp4", @"mov", @"png", @"jpg"]; }

static NSString *WLFindFile(NSString *slot) {
    for (NSString *e in WLExts()) {
        NSString *p = [WLDir() stringByAppendingPathComponent:[slot stringByAppendingPathExtension:e]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    return nil;
}

static void WLRemoveSlot(NSString *slot) {
    for (NSString *e in WLExts()) {
        [[NSFileManager defaultManager] removeItemAtPath:[[WLDir() stringByAppendingPathComponent:slot] stringByAppendingPathExtension:e] error:nil];
    }
}

static void WLLog(NSString *line) {
    NSString *p = [WLDir() stringByAppendingPathComponent:@"debug.log"];
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!h) { [@"" writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil]; h = [NSFileHandle fileHandleForWritingAtPath:p]; }
    [h seekToEndOfFile];
    [h writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [h closeFile];
}

static UIImage *WLAnimatedImage(NSString *path) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 4; });
    UIImage *c = [cache objectForKey:path];
    if (c) return c;

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return nil;
    size_t n = CGImageSourceGetCount(src);
    NSMutableArray *frames = [NSMutableArray array];
    NSTimeInterval total = 0;
    NSDictionary *opts = @{ (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                            (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                            (id)kCGImageSourceThumbnailMaxPixelSize: @720 };
    for (size_t i = 0; i < n; i++) {
        CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(src, i, (__bridge CFDictionaryRef)opts);
        if (!cg) continue;
        [frames addObject:[UIImage imageWithCGImage:cg]];
        CGImageRelease(cg);
        NSDictionary *props = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
        NSDictionary *g = props[(id)kCGImagePropertyGIFDictionary];
        NSNumber *d = g[(id)kCGImagePropertyGIFUnclampedDelayTime];
        if (d.doubleValue <= 0) d = g[(id)kCGImagePropertyGIFDelayTime];
        total += d.doubleValue > 0.01 ? d.doubleValue : 0.1;
    }
    CFRelease(src);
    if (!frames.count) return nil;
    UIImage *img = frames.count == 1 ? frames[0] : [UIImage animatedImageWithImages:frames duration:total];
    if (img) [cache setObject:img forKey:path];
    return img;
}

#pragma mark - Overlay view

@interface WLAnimView : UIView
@property (nonatomic, strong) UIImageView *iv;
@property (nonatomic, strong) AVQueuePlayer *player;
@property (nonatomic, strong) AVPlayerLooper *looper;
@property (nonatomic, strong) AVPlayerLayer *pl;
- (void)loadPath:(NSString *)path;
@end

@implementation WLAnimView
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.tag = kOverlayTag;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO; // khong chan thao tac cham cua Facebook
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}
- (void)loadPath:(NSString *)path {
    NSString *ext = path.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:path]];
        self.player = [AVQueuePlayer queuePlayerWithItems:@[]];
        self.player.muted = YES;
        self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        self.looper = [AVPlayerLooper playerLooperWithPlayer:self.player templateItem:item];
        self.pl = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.pl.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.layer addSublayer:self.pl];
        [self.player play];
    } else {
        self.iv = [[UIImageView alloc] initWithFrame:self.bounds];
        self.iv.contentMode = UIViewContentModeScaleAspectFill;
        self.iv.clipsToBounds = YES;
        self.iv.image = WLAnimatedImage(path);
        [self addSubview:self.iv];
    }
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.iv.frame = self.bounds;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.pl.frame = self.bounds;
    [CATransaction commit];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self.player play]; else [self.player pause];
}
- (void)dealloc { [self.player pause]; }
@end

#pragma mark - Detection & attach

static NSString *WLChain(UIView *v) {
    NSMutableString *s = [NSMutableString string];
    UIView *x = v; int d = 0;
    while (x && d < 6) { [s appendFormat:@"%@>", NSStringFromClass([x class])]; x = x.superview; d++; }
    return s;
}

static BOOL WLMatch(NSString *chain, NSArray *keys) {
    NSString *l = chain.lowercaseString;
    for (NSString *k in keys) if ([l containsString:k]) return YES;
    return NO;
}

static void WLAttach(UIImageView *v) {
    if (!WLEnabled() || !v.window) return;
    if ([v.superview isKindOfClass:[WLAnimView class]]) return;
    if ([v isKindOfClass:[WLAnimView class]]) return;

    CGSize s = v.bounds.size;
    if (s.width < 40 || s.height < 40) return;

    NSString *chain = WLChain(v);
    CGFloat ratio = s.width / s.height;
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;

    if (WLDebug()) {
        static NSMutableSet *seen; if (!seen) seen = [NSMutableSet set];
        NSString *line = [NSString stringWithFormat:@"%@ size=%.0fx%.0f", chain, s.width, s.height];
        if (![seen containsObject:line]) { [seen addObject:line]; WLLog(line); }
    }

    NSString *slot = nil;
    if (ratio > 1.6 && s.width >= screenW * 0.8 && WLMatch(chain, @[@"cover"])) {
        slot = @"cover";
    } else if (fabs(ratio - 1.0) < 0.12 && s.width >= WLMinSize() &&
               WLMatch(chain, @[@"profilepic", @"profilephoto", @"profileimage", @"avatar", @"profilehead"])) {
        slot = @"avatar";
    }
    if (!slot) return;

    NSString *file = WLFindFile(slot);
    if (!file) return;

    WLAnimView *existing = (WLAnimView *)[v viewWithTag:kOverlayTag];
    if (existing) { existing.frame = v.bounds; return; }

    WLAnimView *o = [[WLAnimView alloc] initWithFrame:v.bounds];
    o.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if ([slot isEqualToString:@"avatar"]) {
        o.layer.cornerRadius = v.layer.cornerRadius > 0 ? v.layer.cornerRadius : s.width / 2.0;
    }
    [o loadPath:file];
    [v addSubview:o];
}

static void WLRefreshTree(UIView *v, BOOL removeOnly) {
    if ([v isKindOfClass:[UIImageView class]]) {
        UIView *o = [v viewWithTag:kOverlayTag];
        if (o) [o removeFromSuperview];
        if (!removeOnly) WLAttach((UIImageView *)v);
    }
    for (UIView *sub in [v.subviews copy]) WLRefreshTree(sub, removeOnly);
}

static void WLRefreshAll(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *w in [UIApplication sharedApplication].windows) WLRefreshTree(w, NO);
    });
}

%hook UIImageView
- (void)didMoveToWindow {
    %orig;
    if (!self.window || !WLEnabled()) return;
    __weak UIImageView *weakSelf = self;
    // doi layout xong roi moi do kich thuoc
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIImageView *s = weakSelf; if (s) WLAttach(s);
    });
}
%end

#pragma mark - Picker & menu

@interface WLPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *slot;
+ (instancetype)shared;
@end

@implementation WLPicker
+ (instancetype)shared { static WLPicker *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [WLPicker new]; }); return p; }

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSString *dst = nil;
    NSURL *movie = info[UIImagePickerControllerMediaURL];
    NSURL *imgURL = info[UIImagePickerControllerImageURL];
    WLRemoveSlot(self.slot);
    if (movie) {
        dst = [[WLDir() stringByAppendingPathComponent:self.slot] stringByAppendingPathExtension:@"mp4"];
        [[NSFileManager defaultManager] copyItemAtURL:movie toURL:[NSURL fileURLWithPath:dst] error:nil];
    } else if (imgURL) {
        NSData *d = [NSData dataWithContentsOfURL:imgURL];
        BOOL gif = d.length > 4 && memcmp(d.bytes, "GIF8", 4) == 0;
        NSString *ext = gif ? @"gif" : (imgURL.pathExtension.length ? imgURL.pathExtension.lowercaseString : @"jpg");
        if (![WLExts() containsObject:ext]) ext = @"jpg";
        dst = [[WLDir() stringByAppendingPathComponent:self.slot] stringByAppendingPathExtension:ext];
        [d writeToFile:dst atomically:YES];
    }
    [picker dismissViewControllerAnimated:YES completion:^{ WLRefreshAll(); }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }
@end

static UIViewController *WLTopVC(void) {
    UIWindow *key = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) if (w.isKeyWindow) { key = w; break; }
    UIViewController *vc = key.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void WLPick(NSString *slot) {
    UIImagePickerController *p = [UIImagePickerController new];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.mediaTypes = @[@"public.image", @"public.movie"];
    p.videoExportPreset = AVAssetExportPresetPassthrough;
    [WLPicker shared].slot = slot;
    p.delegate = [WLPicker shared];
    [WLTopVC() presentViewController:p animated:YES completion:nil];
}

static void WLShowMenu(void) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Wolf Animated Profile"
        message:@"Chon GIF / MP4 (hoac anh tinh)" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Chon avatar dong" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLPick(@"avatar"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Chon nen (cover) dong" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLPick(@"cover"); }]];
    [a addAction:[UIAlertAction actionWithTitle:(WLEnabled() ? @"Tat tinh nang" : @"Bat tinh nang") style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [WLDefaults() setBool:!WLEnabled() forKey:kPrefEnabled];
        for (UIWindow *w in [UIApplication sharedApplication].windows) WLRefreshTree(w, !WLEnabled());
    }]];
    [a addAction:[UIAlertAction actionWithTitle:(WLDebug() ? @"Tat log debug" : @"Bat log debug (Documents/WolfAnim/debug.log)") style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [WLDefaults() setBool:!WLDebug() forKey:kPrefDebug];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Xoa tat ca" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){
        WLRemoveSlot(@"avatar"); WLRemoveSlot(@"cover");
        for (UIWindow *w in [UIApplication sharedApplication].windows) WLRefreshTree(w, YES);
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Dong" style:UIAlertActionStyleCancel handler:nil]];
    [WLTopVC() presentViewController:a animated:YES completion:nil];
}

@interface WLGestureTarget : NSObject
+ (instancetype)shared;
- (void)onLongPress:(UILongPressGestureRecognizer *)g;
@end
@implementation WLGestureTarget
+ (instancetype)shared { static WLGestureTarget *t; static dispatch_once_t o; dispatch_once(&o, ^{ t = [WLGestureTarget new]; }); return t; }
- (void)onLongPress:(UILongPressGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan) WLShowMenu(); }
@end

%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    static const void *kKey = &kKey;
    if (!objc_getAssociatedObject(self, kKey)) {
        UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:[WLGestureTarget shared] action:@selector(onLongPress:)];
        g.numberOfTouchesRequired = 3;
        g.minimumPressDuration = 1.0;
        g.cancelsTouchesInView = NO;
        [self addGestureRecognizer:g];
        objc_setAssociatedObject(self, kKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end
