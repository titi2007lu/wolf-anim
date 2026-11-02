// Wolf Animated Profile v2 - avatar & cover dong (GIF / MP4) cho Facebook.
// Chi hien thi tren may ban. Mo menu: nhan giu 3 ngon tay ~1 giay.
// v2: khong doan ten class nua - ban cham truc tiep vao avatar/cover de gan.

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

#define kOverlayTag 0x574C4F56
#define kPickTag    0x574C5049
#define kPrefEnabled @"wl_enabled"

#pragma mark - Helpers

static NSUserDefaults *WLDefaults(void) { return [NSUserDefaults standardUserDefaults]; }
static BOOL WLEnabled(void) { return [WLDefaults() objectForKey:kPrefEnabled] ? [WLDefaults() boolForKey:kPrefEnabled] : YES; }

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
    for (NSString *e in WLExts())
        [[NSFileManager defaultManager] removeItemAtPath:[[WLDir() stringByAppendingPathComponent:slot] stringByAppendingPathExtension:e] error:nil];
    [WLDefaults() removeObjectForKey:[@"wl_anchor_" stringByAppendingString:slot]];
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
        self.userInteractionEnabled = NO;
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

#pragma mark - Find / attach / remember

static UIWindow *WLKeyWindow(void) {
    UIWindow *best = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isHidden || w.windowLevel > UIWindowLevelNormal) continue;
        if (w.isKeyWindow) return w;
        if (!best) best = w;
    }
    return best;
}

static UIViewController *WLTopVC(void) {
    UIViewController *vc = WLKeyWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static UIViewController *WLOwnerVC(UIView *v) {
    UIResponder *r = v;
    while (r) { if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r; r = r.nextResponder; }
    return nil;
}

static NSString *WLChain(UIView *v) {
    NSMutableString *s = [NSMutableString string];
    UIView *x = v; int d = 0;
    while (x && d < 6) { [s appendFormat:@"%@ > ", NSStringFromClass([x class])]; x = x.superview; d++; }
    return s;
}

// Tu view bi cham, di nguoc len tim view co hinh dang giong avatar (vuong) / cover (ngang rong).
static UIView *WLResolve(UIView *hit, NSString *slot) {
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    UIView *x = hit; int d = 0;
    while (x && d < 14) {
        if (![x isKindOfClass:[UIWindow class]] && x.tag != kOverlayTag) {
            CGSize s = x.bounds.size;
            if (s.height > 1) {
                CGFloat r = s.width / s.height;
                if ([slot isEqualToString:@"avatar"]) {
                    if (s.width >= 60 && s.width <= sw * 0.8 && fabs(r - 1.0) < 0.15) return x;
                } else {
                    if (s.width >= sw * 0.8 && r > 1.4 && r < 4.5) return x;
                }
            }
        }
        x = x.superview; d++;
    }
    return nil;
}

static void WLAttachTo(UIView *target, NSString *slot) {
    NSString *file = WLFindFile(slot);
    if (!file) return;
    UIView *old = [target viewWithTag:kOverlayTag];
    if (old) [old removeFromSuperview];
    WLAnimView *o = [[WLAnimView alloc] initWithFrame:target.bounds];
    o.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if ([slot isEqualToString:@"avatar"]) {
        CGSize s = target.bounds.size;
        o.layer.cornerRadius = MIN(s.width, s.height) / 2.0;
    }
    [o loadPath:file];
    o.layer.zPosition = 1000;
    [target addSubview:o];
}

static void WLSaveAnchor(UIView *target, NSString *slot) {
    UIWindow *w = target.window;
    if (!w) return;
    CGRect fr = [target convertRect:target.bounds toView:w];
    UIViewController *vc = WLOwnerVC(target);
    NSDictionary *d = @{ @"vc": NSStringFromClass([vc class]) ?: @"",
                         @"cls": NSStringFromClass([target class]),
                         @"x": @(CGRectGetMidX(fr)), @"y": @(CGRectGetMidY(fr)),
                         @"w": @(fr.size.width), @"h": @(fr.size.height) };
    [WLDefaults() setObject:d forKey:[@"wl_anchor_" stringByAppendingString:slot]];
}

static void WLRestoreFor(UIViewController *vc) {
    if (!WLEnabled() || !vc.isViewLoaded || !vc.view.window) return;
    NSString *vcn = NSStringFromClass([vc class]);
    UIWindow *w = vc.view.window;
    for (NSString *slot in @[@"avatar", @"cover"]) {
        NSDictionary *a = [WLDefaults() objectForKey:[@"wl_anchor_" stringByAppendingString:slot]];
        if (!a || ![a[@"vc"] isEqualToString:vcn] || !WLFindFile(slot)) continue;
        CGPoint p = CGPointMake([a[@"x"] doubleValue], [a[@"y"] doubleValue]);
        UIView *hit = [w hitTest:p withEvent:nil];
        UIView *t = WLResolve(hit, slot);
        if (!t || ![NSStringFromClass([t class]) isEqualToString:a[@"cls"]]) continue;
        CGRect fr = [t convertRect:t.bounds toView:w];
        if (fabs(fr.size.width - [a[@"w"] doubleValue]) > 4 || fabs(fr.size.height - [a[@"h"] doubleValue]) > 4) continue;
        if ([t viewWithTag:kOverlayTag]) continue;
        WLAttachTo(t, slot);
    }
}

static void WLRemoveOverlays(UIView *v) {
    for (UIView *s in [v.subviews copy]) {
        if (s.tag == kOverlayTag) [s removeFromSuperview]; else WLRemoveOverlays(s);
    }
}
static void WLRemoveAllOverlays(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) WLRemoveOverlays(w);
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (![WLDefaults() objectForKey:@"wl_anchor_avatar"] && ![WLDefaults() objectForKey:@"wl_anchor_cover"]) return;
    __weak UIViewController *ws = self;
    for (NSNumber *d in @[@0.6, @1.5, @3.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *s = ws; if (s) WLRestoreFor(s);
        });
    }
}
%end

#pragma mark - UI helpers

static void WLAlert(NSString *title, NSString *msg) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [WLTopVC() presentViewController:a animated:YES completion:nil];
}

@interface WLTarget : NSObject
+ (instancetype)shared;
- (void)onLongPress:(UILongPressGestureRecognizer *)g;
- (void)onPickTap:(UITapGestureRecognizer *)g;
- (void)onPickCancel:(UIButton *)b;
@end

static void WLStartPick(NSString *slot) {
    UIWindow *w = WLKeyWindow();
    if (!w) return;
    UIView *old = [w viewWithTag:kPickTag]; if (old) [old removeFromSuperview];
    UIView *ov = [[UIView alloc] initWithFrame:w.bounds];
    ov.tag = kPickTag;
    ov.accessibilityIdentifier = slot;
    ov.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 70, w.bounds.size.width - 32, 90)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont boldSystemFontOfSize:17];
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    l.layer.cornerRadius = 12; l.clipsToBounds = YES;
    l.text = [slot isEqualToString:@"avatar"]
        ? @"Cham vao GIUA AVATAR cua ban\n(mo trang ca nhan truoc khi cham)"
        : @"Cham vao ANH BIA cua ban\n(mo trang ca nhan truoc khi cham)";
    [ov addSubview:l];

    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(w.bounds.size.width / 2 - 50, w.bounds.size.height - 120, 100, 44);
    b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [b setTitle:@"Huy" forState:UIControlStateNormal];
    b.backgroundColor = [UIColor whiteColor]; b.layer.cornerRadius = 10;
    [b addTarget:[WLTarget shared] action:@selector(onPickCancel:) forControlEvents:UIControlEventTouchUpInside];
    [ov addSubview:b];

    UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:[WLTarget shared] action:@selector(onPickTap:)];
    [ov addGestureRecognizer:t];
    [w addSubview:ov];
}

@implementation WLTarget
+ (instancetype)shared { static WLTarget *t; static dispatch_once_t o; dispatch_once(&o, ^{ t = [WLTarget new]; }); return t; }
- (void)onLongPress:(UILongPressGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan) { extern void WLShowMenu(void); WLShowMenu(); } }
- (void)onPickCancel:(UIButton *)b { [b.superview removeFromSuperview]; }
- (void)onPickTap:(UITapGestureRecognizer *)g {
    UIView *ov = g.view;
    NSString *slot = ov.accessibilityIdentifier;
    UIWindow *w = ov.window;
    CGPoint p = [g locationInView:w];
    ov.hidden = YES;
    UIView *hit = [w hitTest:p withEvent:nil];
    ov.hidden = NO;
    UIView *t = WLResolve(hit, slot);
    if (!t) {
        WLAlert(@"Chua nhan ra", [NSString stringWithFormat:@"Cham vao: %@\n\nHay cham lai vao giua avatar/anh bia (hoac gui chuoi tren cho nguoi ho tro).", WLChain(hit)]);
        return;
    }
    [ov removeFromSuperview];
    WLAttachTo(t, slot);
    WLSaveAnchor(t, slot);
    WLAlert(@"Da gan", [NSString stringWithFormat:@"%@\nKich thuoc: %.0f x %.0f\n%@", slot, t.bounds.size.width, t.bounds.size.height, WLChain(t)]);
}
@end

#pragma mark - Picker

@interface WLPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *slot;
+ (instancetype)shared;
@end

@implementation WLPicker
+ (instancetype)shared { static WLPicker *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [WLPicker new]; }); return p; }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSString *slot = self.slot;
    NSURL *movie = info[UIImagePickerControllerMediaURL];
    NSURL *imgURL = info[UIImagePickerControllerImageURL];
    NSString *dst = nil;
    NSString *dir = WLDir();
    NSString *base = [dir stringByAppendingPathComponent:slot];
    if (movie) {
        WLRemoveSlot(slot);
        dst = [base stringByAppendingPathExtension:@"mp4"];
        [[NSFileManager defaultManager] copyItemAtURL:movie toURL:[NSURL fileURLWithPath:dst] error:nil];
    } else if (imgURL) {
        NSData *d = [NSData dataWithContentsOfURL:imgURL];
        if (d.length) {
            WLRemoveSlot(slot);
            BOOL gif = d.length > 4 && memcmp(d.bytes, "GIF8", 4) == 0;
            NSString *ext = gif ? @"gif" : (imgURL.pathExtension.length ? imgURL.pathExtension.lowercaseString : @"jpg");
            if (![WLExts() containsObject:ext]) ext = @"jpg";
            dst = [base stringByAppendingPathExtension:ext];
            [d writeToFile:dst atomically:YES];
        }
    }
    [picker dismissViewControllerAnimated:YES completion:^{
        if (dst) WLStartPick(slot);
        else WLAlert(@"Loi", @"Khong doc duoc file da chon.");
    }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }
@end

static void WLPick(NSString *slot) {
    UIImagePickerController *p = [UIImagePickerController new];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.mediaTypes = @[@"public.image", @"public.movie"];
    [WLPicker shared].slot = slot;
    p.delegate = [WLPicker shared];
    [WLTopVC() presentViewController:p animated:YES completion:nil];
}

void WLShowMenu(void) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Wolf Animated Profile"
        message:@"Chon GIF / MP4 roi cham vao avatar hoac anh bia de gan" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Chon avatar dong" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLPick(@"avatar"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Chon nen (cover) dong" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLPick(@"cover"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Gan lai avatar (khong doi anh)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLStartPick(@"avatar"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Gan lai nen (khong doi anh)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ WLStartPick(@"cover"); }]];
    [a addAction:[UIAlertAction actionWithTitle:(WLEnabled() ? @"Tat tinh nang" : @"Bat tinh nang") style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [WLDefaults() setBool:!WLEnabled() forKey:kPrefEnabled];
        if (!WLEnabled()) WLRemoveAllOverlays();
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Xoa tat ca" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){
        WLRemoveSlot(@"avatar"); WLRemoveSlot(@"cover"); WLRemoveAllOverlays();
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Dong" style:UIAlertActionStyleCancel handler:nil]];
    [WLTopVC() presentViewController:a animated:YES completion:nil];
}

%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    static const void *kKey = &kKey;
    if (!objc_getAssociatedObject(self, kKey)) {
        UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:[WLTarget shared] action:@selector(onLongPress:)];
        g.numberOfTouchesRequired = 3;
        g.minimumPressDuration = 1.0;
        g.cancelsTouchesInView = NO;
        [self addGestureRecognizer:g];
        objc_setAssociatedObject(self, kKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end
