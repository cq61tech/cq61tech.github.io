#import <UIKit/UIKit.h>

%hook UIWindow
- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}
- (void)setAlpha:(CGFloat)alpha {
    %orig(0.0);
}
// Apple zorla ekrana getirmeye calisirsa reddet
- (void)makeKeyAndVisible {
    return;
}
%end
