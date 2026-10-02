#import <UIKit/UIKit.h>
#import <rootless.h>

@interface WAMessage : NSObject
- (NSUInteger)footerStatus;
@end

@interface WAReceiptTableViewCell : UITableViewCell
- (UILabel *)messageStatusIcon;
@end

static UIColor *gDelivered;
static UIColor *gRead;
static CFStringRef const kPreferencesDomain = CFSTR("com.liamschwie.ticktint");

static UIColor *ColorFromHex(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *hex = [(NSString *)value stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6 && hex.length != 8) return nil;

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd) return nil;

    CGFloat alpha = 1.0;
    if (hex.length == 8) {
        alpha = (rgb & 0xFF) / 255.0;
        rgb >>= 8;
    }
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:alpha];
}

static UIColor *ColorForStatus(NSInteger status) {
    if (status == 5) return gDelivered;
    if (status == 6) return gRead;
    return nil;
}

static NSAttributedString *TintGlyph(NSAttributedString *original, UIColor *color,
                                      NSString *glyph) {
    if (!color || ![original isKindOfClass:NSAttributedString.class]) return original;
    NSRange range = [original.string rangeOfString:glyph];
    if (range.location == NSNotFound) return original;

    NSMutableAttributedString *tinted = [original mutableCopy];
    [tinted addAttribute:NSForegroundColorAttributeName value:color range:range];
    return tinted;
}

%hook WAMessageStatusSlice

- (NSAttributedString *)attributedStringForSliceModel:(id)model
                                        footerStatus:(NSUInteger)status
                                         messageType:(int)messageType {
    return TintGlyph(%orig, ColorForStatus(status), @"\uE711");
}

%end

%hook WAMessage

- (NSAttributedString *)prefixForMessageWithFont:(UIFont *)font
                                   senderName:(NSString *)senderName
                          includeMessageStatus:(BOOL)includeStatus
                          includingIconStatusV3:(BOOL)includeStatusV3
                      includingMessageTypeSymbol:(BOOL)includeType
                                    preferRTL:(BOOL)preferRTL {
    NSAttributedString *original = %orig;
    return TintGlyph(original, ColorForStatus([self footerStatus]), @"\uE701");
}

%end

%hook WAReceiptTableViewCell

- (void)setReceiptType:(NSInteger)receiptType forUserJID:(id)userJID forMessage:(id)message {
    %orig;
    UIColor *color = ColorForStatus(receiptType == 1 ? 6 : receiptType == 2 ? 5 : -1);
    if (!color) return;

    UILabel *icon = [self messageStatusIcon];
    NSAttributedString *original = icon.attributedText;
    NSAttributedString *tinted = TintGlyph(original, color, @"\uE701");
    if (tinted != original) icon.attributedText = tinted;
}

%end

%ctor {
    CFPreferencesAppSynchronize(kPreferencesDomain);
    id delivered = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("Delivered"), kPreferencesDomain));
    id read = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("Read"), kPreferencesDomain));
    id mobileStatuses = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("Statuses"), kPreferencesDomain));
    NSDictionary *savedStatuses = [mobileStatuses isKindOfClass:NSDictionary.class]
        ? mobileStatuses : nil;

    NSString *path = ROOT_PATH_NS(@"/Library/Preferences/com.liamschwie.ticktint.plist");
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    NSDictionary *statuses = [prefs[@"Statuses"] isKindOfClass:NSDictionary.class]
        ? prefs[@"Statuses"] : nil;

    // The Settings pane writes this file; sandboxed WhatsApp can't see its CFPreferences.
    gDelivered = ColorFromHex(prefs[@"Delivered"]) ?: ColorFromHex(delivered)
        ?: ColorFromHex(savedStatuses[@"5"]) ?: ColorFromHex(statuses[@"5"])
        ?: [UIColor colorWithRed:1 green:0.176 blue:0.333 alpha:1];
    gRead = ColorFromHex(prefs[@"Read"]) ?: ColorFromHex(read)
        ?: ColorFromHex(savedStatuses[@"6"]) ?: ColorFromHex(statuses[@"6"])
        ?: [UIColor colorWithRed:0 green:0.784 blue:0.325 alpha:1];
    if (gDelivered || gRead) %init;
}
