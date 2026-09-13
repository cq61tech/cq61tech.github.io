#import "SLRootViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <stdlib.h>

#pragma mark - 1. SLDitherView (Çizgi Kırıcı)
@interface SLDitherView : UIView
@end
@implementation SLDitherView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.alpha = 0.04;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    size_t width = rect.size.width;
    size_t height = rect.size.height;
    size_t bytesPerRow = width * 4;
    uint32_t *pixels = (uint32_t *)malloc(height * bytesPerRow);
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            uint8_t randomGray = arc4random_uniform(256);
            pixels[y * width + x] = (255 << 24) | (randomGray << 16) | (randomGray << 8) | randomGray;
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
    CGContextDrawImage(context, rect, image);
    CGImageRelease(image);
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
}
@end

#pragma mark - 2. SLBottomSheet
@protocol SLBottomSheetDelegate <NSObject>
- (void)didSelectFile:(NSString *)filePath;
@end

@interface SLBottomSheet : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) id<SLBottomSheetDelegate> delegate;
@property (nonatomic, strong) UIView *sheetView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *pathLabel;
@end

@implementation SLBottomSheet
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UIButton *bgButton = [UIButton buttonWithType:UIButtonTypeCustom];
    bgButton.frame = self.view.bounds;
    bgButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [bgButton addTarget:self action:@selector(dismissSheet) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:bgButton];

    CGFloat padding = 20;
    CGFloat sheetHeight = self.view.bounds.size.height * 0.7;
    self.sheetView = [[UIView alloc] initWithFrame:CGRectMake(padding, self.view.bounds.size.height, self.view.bounds.size.width - (padding*2), sheetHeight)];
    self.sheetView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.sheetView.layer.cornerRadius = 24;
    self.sheetView.clipsToBounds = YES;
    self.sheetView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.sheetView];

    if (NSClassFromString(@"UIVisualEffectView")) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.sheetView.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.sheetView addSubview:blurView];
    } else {
        self.sheetView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    }

    UIView *handle = [[UIView alloc] initWithFrame:CGRectMake((self.sheetView.bounds.size.width - 40)/2, 10, 40, 5)];
    handle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    handle.layer.cornerRadius = 2.5;
    handle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.sheetView addSubview:handle];

    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.backButton.frame = CGRectMake(15, 20, 60, 30);
    [self.backButton setTitle:@"Back" forState:UIControlStateNormal];
    [self.backButton setTitleColor:[UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.backButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [self.sheetView addSubview:self.backButton];

    self.pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 20, self.sheetView.bounds.size.width - 160, 30)];
    self.pathLabel.textColor = [UIColor whiteColor];
    self.pathLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.pathLabel.textAlignment = NSTextAlignmentCenter;
    self.pathLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.sheetView addSubview:self.pathLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 60, self.sheetView.bounds.size.width, sheetHeight - 60) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.sheetView addSubview:self.tableView];

    self.currentPath = @"/var/mobile";
    [self loadDirectory];
}

- (void)loadDirectory {
    self.pathLabel.text = [self.currentPath lastPathComponent];
    self.backButton.hidden = [self.currentPath isEqualToString:@"/"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.currentPath error:nil];
    NSMutableArray *filtered = [NSMutableArray array];
    
    for (NSString *item in contents) {
        if ([item hasPrefix:@"."]) continue;
        NSString *fullPath = [self.currentPath stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        
        if (isDir || [[item pathExtension] isEqualToString:@"deb"]) {
            [filtered addObject:@{@"name": item, @"isDir": @(isDir), @"path": fullPath}];
        }
    }
    
    [filtered sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        BOOL isDir1 = [obj1[@"isDir"] boolValue];
        BOOL isDir2 = [obj2[@"isDir"] boolValue];
        if (isDir1 && !isDir2) return NSOrderedAscending;
        if (!isDir1 && isDir2) return NSOrderedDescending;
        return [obj1[@"name"] caseInsensitiveCompare:obj2[@"name"]];
    }];
    
    self.items = filtered;
    [self.tableView reloadData];
}

- (void)goBack {
    self.currentPath = [self.currentPath stringByDeletingLastPathComponent];
    [self loadDirectory];
}

- (void)dismissSheet {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.backgroundColor = [UIColor clearColor];
        self.sheetView.frame = CGRectMake(20, self.view.bounds.size.height, self.view.bounds.size.width - 40, self.sheetView.bounds.size.height);
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

- (void)showInViewController:(UIViewController *)parent {
    [parent addChildViewController:self];
    [parent.view addSubview:self.view];
    self.view.frame = parent.view.bounds;
    
    CGFloat padding = 20;
    CGFloat sheetHeight = parent.view.bounds.size.height * 0.75;
    CGFloat endY = parent.view.bounds.size.height - sheetHeight - padding;
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.sheetView.frame = CGRectMake(padding, endY, parent.view.bounds.size.width - (padding*2), sheetHeight);
    } completion:^(BOOL finished) {
        [self didMoveToParentViewController:parent];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId = [NSString stringWithFormat:@"Cell_%d", (int)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        UIView *bg = [[UIView alloc] init];
        bg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        cell.selectedBackgroundView = bg;
    }
    
    NSDictionary *item = self.items[indexPath.row];
    BOOL isDir = [item[@"isDir"] boolValue];
    cell.textLabel.text = [NSString stringWithFormat:@"%@  %@", isDir ? @"📂" : @"📦", item[@"name"]];
    cell.accessoryType = isDir ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.items[indexPath.row];
    if ([item[@"isDir"] boolValue]) {
        self.currentPath = item[@"path"];
        [self loadDirectory];
    } else {
        [self dismissSheet];
        [self.delegate didSelectFile:item[@"path"]];
    }
}
@end

#pragma mark - 3. SLRootViewController (Ana Motor)
@interface SLRootViewController () <SLBottomSheetDelegate>
@property (nonatomic, strong) CAGradientLayer *mainGradient;
@property (nonatomic, strong) SLDitherView *ditherView;
@property (nonatomic, strong) UIView *gradientContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIView *consoleContainer;
@property (nonatomic, strong) UITextView *consoleTextView;
@property (nonatomic, strong) UIButton *respringButton;
@property (nonatomic, strong) NSArray *logMessages;
@property (nonatomic, assign) NSInteger currentLogIndex;
@end

@implementation SLRootViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setupProGradientBackground];
    [self setupMainUI];
    [self setupConsoleUI];
    self.logMessages = @[@"> initializing payload...", @"> unpacking the .deb...", @"> resolving dependencies...", @"> easter eggs loading...", @"> thanks gemini/gpt", @"> installation complete!"];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.gradientContainer.frame = self.view.bounds;
    self.mainGradient.frame = self.gradientContainer.bounds;
    self.ditherView.frame = self.gradientContainer.bounds;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [UIView animateWithDuration:1.5 delay:0.2 usingSpringWithDamping:0.6 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.titleLabel.alpha = 1.0;
        self.titleLabel.transform = CGAffineTransformIdentity;
        self.selectButton.alpha = 1.0;
        self.selectButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setupProGradientBackground {
    self.gradientContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.gradientContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.gradientContainer];

    self.mainGradient = [CAGradientLayer layer];
    self.mainGradient.colors = @[(id)[UIColor colorWithRed:0.25 green:0.90 blue:0.25 alpha:1.0].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor colorWithRed:0.10 green:0.55 blue:0.95 alpha:1.0].CGColor];
    self.mainGradient.startPoint = CGPointMake(0.0, 0.0);
    self.mainGradient.endPoint = CGPointMake(1.0, 1.0);
    [self.gradientContainer.layer addSublayer:self.mainGradient];
    
    CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
    colorAnimation.toValue = @[(id)[UIColor colorWithRed:0.10 green:0.55 blue:0.95 alpha:1.0].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor colorWithRed:0.25 green:0.90 blue:0.25 alpha:1.0].CGColor];
    colorAnimation.duration = 10.0;
    colorAnimation.autoreverses = YES;
    colorAnimation.repeatCount = HUGE_VALF;
    [self.mainGradient addAnimation:colorAnimation forKey:@"colorChange"];
    
    self.ditherView = [[SLDitherView alloc] initWithFrame:self.gradientContainer.bounds];
    self.ditherView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.gradientContainer addSubview:self.ditherView];
}

- (void)setupMainUI {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    
    // Ekrana tam ortalamak için dinamik hesap (Başlık:60 + Boşluk:20 + Buton:60 = 140)
    CGFloat totalHeight = 140;
    CGFloat startY = (screenHeight - totalHeight) / 2 - 30; // Estetik duruş için hafifçe yukarı kaydırdık
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, startY, screenWidth, 60)];
    self.titleLabel.text = @"selectra1n";
    self.titleLabel.font = [UIFont systemFontOfSize:52 weight:UIFontWeightHeavy];
    // Keskin Monet Siyahı (RGB bazlı zindan siyahı)
    self.titleLabel.textColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0]; 
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.titleLabel.alpha = 0.0;
    self.titleLabel.transform = CGAffineTransformMakeTranslation(0, 50);
    [self.view addSubview:self.titleLabel];

    self.selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.selectButton.frame = CGRectMake((screenWidth - 240)/2, startY + 80, 240, 60);
    [self.selectButton setTitle:@"Select a .deb file" forState:UIControlStateNormal];
    [self.selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.selectButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    self.selectButton.layer.cornerRadius = 20;
    self.selectButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.selectButton.alpha = 0.0;
    self.selectButton.transform = CGAffineTransformMakeTranslation(0, 50);
    [self.selectButton addTarget:self action:@selector(openCustomPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectButton];
}

- (void)setupConsoleUI {
    self.consoleContainer = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 320)/2, (self.view.bounds.size.height - 400)/2, 320, 400)];
    self.consoleContainer.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    self.consoleContainer.layer.cornerRadius = 15;
    self.consoleContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.consoleContainer.alpha = 0.0;
    self.consoleContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [self.view addSubview:self.consoleContainer];

    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 30)];
    headerLabel.text = @"Installing...";
    headerLabel.font = [UIFont boldSystemFontOfSize:20];
    headerLabel.textColor = [UIColor whiteColor];
    [self.consoleContainer addSubview:headerLabel];

    self.consoleTextView = [[UITextView alloc] initWithFrame:CGRectMake(15, 60, 290, 250)];
    self.consoleTextView.backgroundColor = [UIColor clearColor];
    self.consoleTextView.textColor = [UIColor greenColor];
    self.consoleTextView.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:14];
    self.consoleTextView.editable = NO;
    self.consoleTextView.selectable = NO;
    [self.consoleContainer addSubview:self.consoleTextView];

    self.respringButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.respringButton.frame = CGRectMake(20, 330, 280, 50);
    [self.respringButton setTitle:@"finished respring" forState:UIControlStateNormal];
    [self.respringButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.respringButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.respringButton.alpha = 0.0;
    [self.respringButton addTarget:self action:@selector(respringDevice) forControlEvents:UIControlEventTouchUpInside];
    [self.consoleContainer addSubview:self.respringButton];
}

- (void)openCustomPicker {
    [UIView animateWithDuration:0.1 animations:^{
        self.selectButton.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.selectButton.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            SLBottomSheet *sheet = [[SLBottomSheet alloc] init];
            sheet.delegate = self;
            [sheet showInViewController:self];
        }];
    }];
}

- (void)didSelectFile:(NSString *)filePath {
    [UIView animateWithDuration:0.4 animations:^{
        self.titleLabel.alpha = 0.0;
        self.selectButton.alpha = 0.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.6 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.consoleContainer.alpha = 1.0;
            self.consoleContainer.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            self.currentLogIndex = 0;
            self.consoleTextView.text = [NSString stringWithFormat:@"> target: %@\n", [filePath lastPathComponent]];
            [self printNextLogStream];
        }];
    }];
}

- (void)printNextLogStream {
    if (self.currentLogIndex < self.logMessages.count) {
        self.consoleTextView.text = [NSString stringWithFormat:@"%@\n%@", self.consoleTextView.text, self.logMessages[self.currentLogIndex]];
        [self.consoleTextView scrollRangeToVisible:NSMakeRange(self.consoleTextView.text.length - 1, 1)];
        self.currentLogIndex++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self printNextLogStream];
        });
    } else {
        [UIView animateWithDuration:0.5 animations:^{ self.respringButton.alpha = 1.0; }];
    }
}
- (void)respringDevice { system("killall -9 SpringBoard"); }
@end
