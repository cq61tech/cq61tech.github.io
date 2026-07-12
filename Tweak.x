#import <UIKit/UIKit.h>

@interface ASTMenuButton : UIView
@end

%hook ASTMenuButton
// Buton her baslatildiginda (init) direkt gizle
- (id)initWithFrame:(CGRect)frame {
    id orig = %orig;
    [orig setHidden:YES];
    [orig setAlpha:0.0];
    return orig;
}

// Ekran tazelendiginde tekrar gizle
- (void)layoutSubviews {
    self.hidden = YES;
    self.alpha = 0.0;
    %orig;
}

// Apple zorla gizliligi kaldirirsa tekrar geri gonder
- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}
%end
