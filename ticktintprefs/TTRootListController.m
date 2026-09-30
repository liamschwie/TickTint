#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <rootless.h>
#import <math.h>

static CFStringRef const kPreferencesDomain = CFSTR("com.liamschwie.ticktint");

@interface TTRootListController : PSListController <UIColorPickerViewControllerDelegate>
@end

@implementation TTRootListController {
    NSString *_selectedKey;
    UIColorPickerViewController *_picker;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"CHECKMARK COLORS"];
    [group setProperty:@"Close and reopen WhatsApp to apply changes."
                forKey:@"footerText"];

    PSSpecifier *delivered = [PSSpecifier preferenceSpecifierNamed:@"Delivered"
        target:self set:NULL get:NULL detail:Nil cell:PSLinkCell edit:Nil];
    delivered.identifier = @"Delivered";
    delivered->action = @selector(openColorPicker:);
    [delivered setProperty:@YES forKey:@"enabled"];

    PSSpecifier *read = [PSSpecifier preferenceSpecifierNamed:@"Read"
        target:self set:NULL get:NULL detail:Nil cell:PSLinkCell edit:Nil];
    read.identifier = @"Read";
    read->action = @selector(openColorPicker:);
    [read setProperty:@YES forKey:@"enabled"];

    _specifiers = [NSMutableArray arrayWithObjects:group, delivered, read, nil];
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TickTint";
}

- (UIColor *)colorForKey:(NSString *)key {
    id stored = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                             kPreferencesDomain));
    UIColor *color = [self colorFromHex:stored];
    if (color) return color;

    id mobileStatuses = CFBridgingRelease(CFPreferencesCopyAppValue(
        CFSTR("Statuses"), kPreferencesDomain));
    NSDictionary *savedStatuses = [mobileStatuses isKindOfClass:NSDictionary.class]
        ? mobileStatuses : nil;
    NSString *oldKey = [key isEqualToString:@"Delivered"] ? @"5" : @"6";
    color = [self colorFromHex:savedStatuses[oldKey]];
    if (color) return color;

    NSString *path = ROOT_PATH_NS(@"/Library/Preferences/com.liamschwie.ticktint.plist");
    NSDictionary *legacy = [NSDictionary dictionaryWithContentsOfFile:path];
    color = [self colorFromHex:legacy[key]];
    if (color) return color;

    NSDictionary *statuses = [legacy[@"Statuses"] isKindOfClass:NSDictionary.class]
        ? legacy[@"Statuses"] : nil;
    color = [self colorFromHex:statuses[oldKey]];
    return color ?: ([key isEqualToString:@"Delivered"]
        ? [UIColor colorWithRed:1 green:0.176 blue:0.333 alpha:1]
        : [UIColor colorWithRed:0 green:0.784 blue:0.325 alpha:1]);
}

- (UIColor *)colorFromHex:(id)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *hex = [(NSString *)value stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6 && hex.length != 8) return nil;

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd) return nil;
    CGFloat alpha = 1;
    if (hex.length == 8) {
        alpha = (rgb & 0xFF) / 255.0;
        rgb >>= 8;
    }
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:alpha];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    if (![specifier.identifier isEqualToString:@"Delivered"] &&
        ![specifier.identifier isEqualToString:@"Read"]) return cell;

    UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 47, 28)];
    UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 2, 24, 24)];
    swatch.backgroundColor = [self colorForKey:specifier.identifier];
    swatch.layer.cornerRadius = 12;
    swatch.layer.borderWidth = 0.5;
    swatch.layer.borderColor = UIColor.separatorColor.CGColor;
    [accessory addSubview:swatch];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"chevron.right"]];
    chevron.frame = CGRectMake(36, 8, 7, 12);
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.tintColor = UIColor.tertiaryLabelColor;
    [accessory addSubview:chevron];

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = accessory;
    return cell;
}

- (void)openColorPicker:(PSSpecifier *)specifier {
    NSString *key = specifier.identifier;
    if (![key isEqualToString:@"Delivered"] && ![key isEqualToString:@"Read"]) return;

    _selectedKey = key;
    _picker = [UIColorPickerViewController new];
    _picker.delegate = self;
    _picker.supportsAlpha = NO;
    _picker.selectedColor = [self colorForKey:key];
    [self presentViewController:_picker animated:YES completion:nil];
}

- (void)saveColor:(UIColor *)color fromPicker:(UIColorPickerViewController *)picker {
    if (picker != _picker || !_selectedKey) return;
    CGFloat red, green, blue, alpha;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return;

    NSString *hex = [NSString stringWithFormat:@"#%02X%02X%02X",
        (unsigned)lround(MIN(1, MAX(0, red)) * 255),
        (unsigned)lround(MIN(1, MAX(0, green)) * 255),
        (unsigned)lround(MIN(1, MAX(0, blue)) * 255)];
    id oldValue = CFBridgingRelease(CFPreferencesCopyAppValue(
        (__bridge CFStringRef)_selectedKey, kPreferencesDomain));
    if ([hex isEqualToString:oldValue]) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)_selectedKey,
                             (__bridge CFPropertyListRef)hex, kPreferencesDomain);
    CFPreferencesAppSynchronize(kPreferencesDomain);
    [self.tableView reloadData];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)viewController
                   didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    if (!continuously) [self saveColor:color fromPicker:viewController];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    [self saveColor:viewController.selectedColor fromPicker:viewController];
    _picker = nil;
    _selectedKey = nil;
}

@end
