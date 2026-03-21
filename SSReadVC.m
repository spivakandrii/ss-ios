#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSReadVC () <UIWebViewDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UISegmentedControl *daySelector;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIToolbar *bottomBar;
@property (nonatomic, assign) NSInteger currentDayIndex;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, copy) NSString *theme; // "light", "dark", "sepia"
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) BOOL fullscreen;
@end

@implementation SSReadVC

- (void)viewDidLoad {
    [super viewDidLoad];

    // Load preferences
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.fontSize = [ud integerForKey:@"fontSize"];
    if (self.fontSize < 14 || self.fontSize > 28) self.fontSize = 18;
    self.theme = [ud stringForKey:@"theme"];
    if (!self.theme) self.theme = [ud boolForKey:@"darkMode"] ? @"dark" : @"light";
    self.fontFamily = [ud stringForKey:@"fontFamily"];
    if (!self.fontFamily) self.fontFamily = @"Georgia, serif";
    [self setupDaySelector];
    [self setupWebView];
    [self setupBottomBar];
    [self setupSpinner];
    [self applyThemeToChrome];

    NSInteger startDay = self.initialDayIndex;
    if (startDay < 0 || startDay >= (NSInteger)self.days.count) startDay = 0;
    self.currentDayIndex = startDay;
    self.daySelector.selectedSegmentIndex = startDay;
    [self loadDay:startDay];
}

- (BOOL)isDark { return [self.theme isEqualToString:@"dark"]; }
- (BOOL)isSepia { return [self.theme isEqualToString:@"sepia"]; }

- (void)applyThemeToChrome {
    if ([self isDark]) {
        self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.navigationController.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.webView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.webView.opaque = NO;
        self.bottomBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.daySelector.tintColor = [UIColor colorWithRed:0.48 green:0.64 blue:0.83 alpha:1.0];
    } else if ([self isSepia]) {
        UIColor *sepiaBg = [UIColor colorWithRed:0.96 green:0.92 blue:0.84 alpha:1.0];
        UIColor *sepiaTint = [UIColor colorWithRed:0.55 green:0.40 blue:0.25 alpha:1.0];
        self.view.backgroundColor = sepiaBg;
        self.navigationController.navigationBar.tintColor = sepiaTint;
        self.webView.backgroundColor = sepiaBg;
        self.webView.opaque = YES;
        self.bottomBar.tintColor = sepiaTint;
        self.daySelector.tintColor = sepiaTint;
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];
        self.webView.backgroundColor = [UIColor whiteColor];
        self.webView.opaque = YES;
        self.bottomBar.tintColor = nil;
        self.daySelector.tintColor = nil;
    }
}

- (void)setupDaySelector {
    NSMutableArray *orderedDays = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *weekdays = [NSArray arrayWithObjects:@"Сб", @"Нд", @"Пн", @"Вт", @"Ср", @"Чт", @"Пт", nil];

    for (NSInteger i = 0; i < (NSInteger)self.days.count; i++) {
        NSDictionary *day = [self.days objectAtIndex:i];
        NSString *dayId = [day objectForKey:@"id"];
        if (dayId.length == 2 && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[dayId characterAtIndex:0]]) {
            [orderedDays addObject:day];
            NSInteger idx = [dayId integerValue] - 1;
            if (idx >= 0 && idx < (NSInteger)weekdays.count) {
                [titles addObject:[weekdays objectAtIndex:idx]];
            } else {
                [titles addObject:dayId];
            }
        }
    }

    for (NSInteger i = 0; i < (NSInteger)self.days.count; i++) {
        NSDictionary *day = [self.days objectAtIndex:i];
        NSString *dayId = [day objectForKey:@"id"];
        if ([dayId isEqualToString:@"commentary"]) {
            [orderedDays addObject:day];
            [titles addObject:@"Дод."];
        } else if ([dayId isEqualToString:@"teacher-comments"]) {
            [orderedDays addObject:day];
            [titles addObject:@"Вчит."];
        }
    }

    self.days = orderedDays;

    self.daySelector = [[UISegmentedControl alloc] initWithItems:titles];
    self.daySelector.segmentedControlStyle = UISegmentedControlStyleBar;
    self.daySelector.selectedSegmentIndex = 0;
    [self.daySelector addTarget:self action:@selector(dayChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.daySelector;
    [self updateDaySelectorMarks];
}

- (void)setupWebView {
    CGFloat barH = 44;
    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - barH);
    self.webView = [[UIWebView alloc] initWithFrame:frame];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = NO;
    [self.view addSubview:self.webView];

    // Tap to toggle fullscreen
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleFullscreen)];
    tap.delegate = self;
    [self.webView addGestureRecognizer:tap];

    // Swipe between days
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeNextDay)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipePrevDay)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.webView addGestureRecognizer:swipeLeft];
    [self.webView addGestureRecognizer:swipeRight];
}

- (void)swipeNextDay {
    NSInteger next = self.currentDayIndex + 1;
    if (next < (NSInteger)self.days.count) {
        [self markCurrentDayRead];
        self.daySelector.selectedSegmentIndex = next;
        [self loadDay:next];
    }
}

- (void)swipePrevDay {
    NSInteger prev = self.currentDayIndex - 1;
    if (prev >= 0) {
        [self markCurrentDayRead];
        self.daySelector.selectedSegmentIndex = prev;
        [self loadDay:prev];
    }
}

- (void)toggleFullscreen {
    // Don't toggle if popup is open
    NSString *popupVisible = [self.webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('verse-popup').style.display"];
    if ([popupVisible isEqualToString:@"block"]) return;

    // Don't toggle if last tap was on a link
    NSString *wasLink = [self.webView stringByEvaluatingJavaScriptFromString:@"window._lastTapOnLink||''"];
    [self.webView stringByEvaluatingJavaScriptFromString:@"window._lastTapOnLink=''"];
    if ([wasLink isEqualToString:@"1"]) return;

    self.fullscreen = !self.fullscreen;
    [UIView animateWithDuration:0.3 animations:^{
        [self.navigationController setNavigationBarHidden:self.fullscreen animated:NO];
        self.bottomBar.alpha = self.fullscreen ? 0.0 : 1.0;
    } completion:^(BOOL finished) {
        self.bottomBar.hidden = self.fullscreen;
        // Resize webView to fill
        CGFloat barH = self.fullscreen ? 0 : 44;
        self.webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - barH);
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)setupBottomBar {
    CGFloat barH = 44;
    CGRect barFrame = CGRectMake(0, self.view.bounds.size.height - barH, self.view.bounds.size.width, barH);
    self.bottomBar = [[UIToolbar alloc] initWithFrame:barFrame];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UIBarButtonItem *fontDown = [[UIBarButtonItem alloc] initWithTitle:@"A-" style:UIBarButtonItemStyleBordered target:self action:@selector(fontSmaller)];
    UIBarButtonItem *fontUp = [[UIBarButtonItem alloc] initWithTitle:@"A+" style:UIBarButtonItemStyleBordered target:self action:@selector(fontLarger)];
    UIBarButtonItem *fontPicker = [[UIBarButtonItem alloc] initWithTitle:@"Aa" style:UIBarButtonItemStyleBordered target:self action:@selector(showFontPicker)];
    NSString *themeTitle = [self isDark] ? @"Sepia" : [self isSepia] ? @"Light" : @"Dark";
    UIBarButtonItem *nightToggle = [[UIBarButtonItem alloc] initWithTitle:themeTitle style:UIBarButtonItemStyleBordered target:self action:@selector(cycleTheme)];
    UIBarButtonItem *noteBtn = [[UIBarButtonItem alloc] initWithTitle:@"Note" style:UIBarButtonItemStyleBordered target:self action:@selector(showNotes)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    [self.bottomBar setItems:[NSArray arrayWithObjects:fontDown, flex, fontUp, flex, fontPicker, flex, nightToggle, flex, noteBtn, nil]];
    [self.view addSubview:self.bottomBar];
}

- (void)fontSmaller {
    if (self.fontSize > 14) {
        self.fontSize -= 2;
        [self savePrefsAndReload];
    }
}

- (void)fontLarger {
    if (self.fontSize < 28) {
        self.fontSize += 2;
        [self savePrefsAndReload];
    }
}

- (void)cycleTheme {
    if ([self.theme isEqualToString:@"light"]) {
        self.theme = @"dark";
    } else if ([self.theme isEqualToString:@"dark"]) {
        self.theme = @"sepia";
    } else {
        self.theme = @"light";
    }
    [self applyThemeToChrome];
    // Update button title — shows what NEXT theme will be
    NSString *next = [self isDark] ? @"Sepia" : [self isSepia] ? @"Light" : @"Dark";
    // Find theme button (second to last, before Note)
    NSArray *items = self.bottomBar.items;
    UIBarButtonItem *themeBtn = [items objectAtIndex:[items count] - 3]; // flex, themeBtn, flex, noteBtn
    themeBtn.title = next;
    [self savePrefsAndReload];
}

- (void)showFontPicker {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Шрифт"
                                                      delegate:self
                                             cancelButtonTitle:@"Скасувати"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Georgia (serif)", @"Helvetica", @"Palatino", @"Courier", nil];
    [sheet showFromToolbar:self.bottomBar];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *font = nil;
    switch (buttonIndex) {
        case 0: font = @"Georgia, serif"; break;
        case 1: font = @"Helvetica, sans-serif"; break;
        case 2: font = @"Palatino, serif"; break;
        case 3: font = @"Courier, monospace"; break;
        default: return; // Cancel
    }
    self.fontFamily = font;
    [[NSUserDefaults standardUserDefaults] setObject:font forKey:@"fontFamily"];
    [self savePrefsAndReload];
}

- (NSString *)noteKey {
    NSDictionary *day = [self.days objectAtIndex:self.currentDayIndex];
    NSString *dayId = [day objectForKey:@"id"];
    return [NSString stringWithFormat:@"note_%@_%@_%@", self.quarterlyId, self.lessonId, dayId];
}

- (void)showNotes {
    UIViewController *noteVC = [[UIViewController alloc] init];
    noteVC.title = @"Нотатки";

    UITextView *textView = [[UITextView alloc] initWithFrame:noteVC.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.font = [UIFont systemFontOfSize:16];
    textView.text = [[NSUserDefaults standardUserDefaults] stringForKey:[self noteKey]];
    textView.tag = 100;

    if ([self isDark]) {
        noteVC.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        textView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        textView.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    } else if ([self isSepia]) {
        noteVC.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.92 blue:0.84 alpha:1.0];
        textView.backgroundColor = [UIColor colorWithRed:0.94 green:0.89 blue:0.80 alpha:1.0];
        textView.textColor = [UIColor colorWithRed:0.36 green:0.25 blue:0.20 alpha:1.0];
    }

    [noteVC.view addSubview:textView];

    noteVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(dismissNotes)];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:noteVC];
    if ([self isDark]) {
        nav.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    } else if ([self isSepia]) {
        nav.navigationBar.tintColor = [UIColor colorWithRed:0.55 green:0.40 blue:0.25 alpha:1.0];
    }
    [self presentModalViewController:nav animated:YES];
}

- (void)dismissNotes {
    UINavigationController *nav = (UINavigationController *)[self modalViewController];
    UIViewController *noteVC = [[nav viewControllers] objectAtIndex:0];
    UITextView *textView = (UITextView *)[noteVC.view viewWithTag:100];
    if (textView) {
        NSString *text = textView.text;
        if (text.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:text forKey:[self noteKey]];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self noteKey]];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [self dismissModalViewControllerAnimated:YES];
}

- (void)savePrefsAndReload {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:self.fontSize forKey:@"fontSize"];
    [ud setObject:self.theme forKey:@"theme"];
    [ud removeObjectForKey:@"darkMode"];
    [ud synchronize];
    [self loadDay:self.currentDayIndex];
}

- (void)setupSpinner {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];
}

- (void)dayChanged:(UISegmentedControl *)sender {
    [self markCurrentDayRead];
    [self loadDay:sender.selectedSegmentIndex];
}

- (void)markCurrentDayRead {
    if (self.currentDayIndex >= (NSInteger)self.days.count) return;
    NSDictionary *day = [self.days objectAtIndex:self.currentDayIndex];
    NSString *dayId = [day objectForKey:@"id"];
    NSString *key = [NSString stringWithFormat:@"read_%@_%@_%@", self.quarterlyId, self.lessonId, dayId];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateDaySelectorMarks];
}

- (BOOL)isDayRead:(NSInteger)index {
    if (index >= (NSInteger)self.days.count) return NO;
    NSDictionary *day = [self.days objectAtIndex:index];
    NSString *dayId = [day objectForKey:@"id"];
    NSString *key = [NSString stringWithFormat:@"read_%@_%@_%@", self.quarterlyId, self.lessonId, dayId];
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)updateDaySelectorMarks {
    for (NSInteger i = 0; i < (NSInteger)self.days.count; i++) {
        NSString *title = [self.daySelector titleForSegmentAtIndex:i];
        // Remove existing checkmark
        title = [title stringByReplacingOccurrencesOfString:@"\u2713 " withString:@""];
        if ([self isDayRead:i]) {
            title = [NSString stringWithFormat:@"\u2713 %@", title];
        }
        [self.daySelector setTitle:title forSegmentAtIndex:i];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Restore navbar when leaving
    if (self.fullscreen) {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }
    [self markCurrentDayRead];
}

- (void)loadDay:(NSInteger)index {
    if (index >= (NSInteger)self.days.count) return;

    self.currentDayIndex = index;
    NSDictionary *day = [self.days objectAtIndex:index];
    NSString *dayId = [day objectForKey:@"id"];

    [self.spinner startAnimating];
    self.webView.hidden = YES;

    [[SSAPIClient shared] fetchDayReadForQuarterly:self.quarterlyId
                                            lesson:self.lessonId
                                               day:dayId
                                        completion:^(id result, NSError *error) {
        [self.spinner stopAnimating];
        self.webView.hidden = NO;

        if (error || !result) {
            [self.webView loadHTMLString:@"<html><body><h2>Помилка завантаження</h2></body></html>" baseURL:nil];
            return;
        }

        NSArray *reads;
        if ([result isKindOfClass:[NSDictionary class]]) {
            reads = [NSArray arrayWithObject:result];
        } else if ([result isKindOfClass:[NSArray class]]) {
            reads = result;
        } else {
            reads = [NSArray array];
        }

        // Build bible verses lookup for ALL translations
        NSMutableArray *translationNames = [NSMutableArray array];
        NSMutableDictionary *allTranslations = [NSMutableDictionary dictionary]; // name -> {key: html}
        if (reads.count > 0) {
            NSDictionary *firstRead = [reads objectAtIndex:0];
            NSArray *bibleArr = [firstRead objectForKey:@"bible"];
            if ([bibleArr isKindOfClass:[NSArray class]]) {
                for (NSDictionary *translation in bibleArr) {
                    NSString *name = [translation objectForKey:@"name"];
                    NSDictionary *verseDict = [translation objectForKey:@"verses"];
                    if (name && [verseDict isKindOfClass:[NSDictionary class]]) {
                        [translationNames addObject:name];
                        [allTranslations setObject:verseDict forKey:name];
                    }
                }
            }
        }

        // Build JS: bibleVerses = { 'UKR': { 'key': 'html', ... }, 'CUV': { ... } }
        NSMutableString *versesJS = [NSMutableString stringWithString:@"var bibleVerses={"];
        for (NSInteger t = 0; t < (NSInteger)translationNames.count; t++) {
            NSString *tName = [translationNames objectAtIndex:t];
            NSDictionary *verses = [allTranslations objectForKey:tName];
            [versesJS appendFormat:@"'%@':{", tName];
            NSArray *allKeys = [verses allKeys];
            for (NSInteger i = 0; i < (NSInteger)allKeys.count; i++) {
                NSString *key = [allKeys objectAtIndex:i];
                NSString *val = [verses objectForKey:key];
                val = [val stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
                val = [val stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                val = [val stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
                val = [val stringByReplacingOccurrencesOfString:@"\r" withString:@""];
                [versesJS appendFormat:@"'%@':'%@'", key, val];
                if (i < (NSInteger)allKeys.count - 1) [versesJS appendString:@","];
            }
            [versesJS appendString:@"}"];
            if (t < (NSInteger)translationNames.count - 1) [versesJS appendString:@","];
        }
        [versesJS appendString:@"};"];

        // Build JS array of translation names
        [versesJS appendString:@"var translationNames=["];
        for (NSInteger t = 0; t < (NSInteger)translationNames.count; t++) {
            [versesJS appendFormat:@"'%@'", [translationNames objectAtIndex:t]];
            if (t < (NSInteger)translationNames.count - 1) [versesJS appendString:@","];
        }
        [versesJS appendString:@"];"];

        NSMutableString *html = [NSMutableString string];
        [html appendString:@"<html><head><meta charset='utf-8'>"];
        [html appendString:@"<meta name='viewport' content='width=device-width, initial-scale=1.0'>"];
        [html appendString:@"<style>"];
        // Theme colors
        NSString *bodyBg, *bodyColor, *headingColor, *quoteColor, *linkColor, *hrColor;
        NSString *popupBg, *popupOverlay, *popupColor, *popupShadow;
        NSString *btnBg, *btnBorder, *btnColor, *btnActiveBg, *btnActiveColor;
        NSString *supColor, *closeColor;

        if ([self isDark]) {
            bodyBg = @"#1a1a1a"; bodyColor = @"#ccc"; headingColor = @"#7ba4d4";
            quoteColor = @"#999"; linkColor = @"#7ba4d4"; hrColor = @"#333";
            popupBg = @"#2a2a2a"; popupOverlay = @"rgba(0,0,0,0.7)"; popupColor = @"#ccc"; popupShadow = @"rgba(0,0,0,0.5)";
            btnBg = @"#2a2a2a"; btnBorder = @"#7ba4d4"; btnColor = @"#7ba4d4"; btnActiveBg = @"#7ba4d4"; btnActiveColor = @"#1a1a1a";
            supColor = @"#666"; closeColor = @"#666";
        } else if ([self isSepia]) {
            bodyBg = @"#f5ebe0"; bodyColor = @"#5c4033"; headingColor = @"#6b4226";
            quoteColor = @"#8b7355"; linkColor = @"#6b4226"; hrColor = @"#d4c4a8";
            popupBg = @"#f0e4d0"; popupOverlay = @"rgba(0,0,0,0.4)"; popupColor = @"#5c4033"; popupShadow = @"rgba(0,0,0,0.2)";
            btnBg = @"#f0e4d0"; btnBorder = @"#6b4226"; btnColor = @"#6b4226"; btnActiveBg = @"#6b4226"; btnActiveColor = @"#f5ebe0";
            supColor = @"#a08060"; closeColor = @"#a08060";
        } else {
            bodyBg = @"#fefefe"; bodyColor = @"#333"; headingColor = @"#2E4161";
            quoteColor = @"#555"; linkColor = @"#2E4161"; hrColor = @"#ddd";
            popupBg = @"#fff"; popupOverlay = @"rgba(0,0,0,0.5)"; popupColor = @"#333"; popupShadow = @"rgba(0,0,0,0.3)";
            btnBg = @"#fff"; btnBorder = @"#2E4161"; btnColor = @"#2E4161"; btnActiveBg = @"#2E4161"; btnActiveColor = @"#fff";
            supColor = @"#888"; closeColor = @"#999";
        }

        [html appendFormat:@"body { font-family: %@; font-size: %ldpx; line-height: 1.6; padding: 16px; color: %@; background: %@; }", self.fontFamily, (long)self.fontSize, bodyColor, bodyBg];
        [html appendFormat:@"h1, h2, h3 { color: %@; }", headingColor];
        [html appendFormat:@"blockquote { border-left: 3px solid %@; padding-left: 12px; margin-left: 0; color: %@; font-style: italic; }", headingColor, quoteColor];
        [html appendFormat:@"a.verse { color: %@; text-decoration: underline; cursor: pointer; }", linkColor];
        [html appendFormat:@"a { color: %@; }", linkColor];
        [html appendFormat:@"hr { border: none; border-top: 1px solid %@; margin: 20px 0; }", hrColor];
        [html appendFormat:@"#verse-popup { display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:%@; z-index:999; }", popupOverlay];
        [html appendString:@"#verse-content { position:absolute; top:10%%; left:5%%; right:5%%; max-height:75%%; overflow-y:auto; "];
        [html appendFormat:@"background:%@; border-radius:12px; padding:20px; box-shadow:0 4px 20px %@; ", popupBg, popupShadow];
        [html appendFormat:@"font-family:%@; font-size:%ldpx; line-height:1.6; color:%@; }", self.fontFamily, (long)(self.fontSize - 1), popupColor];
        [html appendFormat:@"#verse-content h2 { color:%@; font-size:20px; margin:8px 0; }", headingColor];
        [html appendFormat:@"#verse-content sup { color:%@; font-size:12px; }", supColor];
        [html appendFormat:@"#verse-close { position:absolute; top:12px; right:16px; font-size:28px; color:%@; cursor:pointer; z-index:1000; }", closeColor];
        [html appendString:@"#verse-translations { margin-bottom:12px; }"];
        [html appendFormat:@"#verse-translations button { padding:6px 14px; margin-right:6px; margin-bottom:4px; border:1px solid %@; border-radius:6px; background:%@; color:%@; font-size:14px; cursor:pointer; }", btnBorder, btnBg, btnColor];
        [html appendFormat:@"#verse-translations button.active { background:%@; color:%@; }", btnActiveBg, btnActiveColor];
        [html appendString:@"</style></head><body>"];

        // Popup overlay
        [html appendString:@"<div id='verse-popup' onclick='closeVerse()'><span id='verse-close'>&times;</span><div id='verse-content' onclick='event.stopPropagation()'><div id='verse-translations'></div><div id='verse-text'></div></div></div>"];

        NSString *dayLabel = [self.daySelector titleForSegmentAtIndex:self.currentDayIndex];
        dayLabel = [dayLabel stringByReplacingOccurrencesOfString:@"\u2713 " withString:@""];

        for (NSDictionary *read in reads) {
            NSString *title = [read objectForKey:@"title"];
            NSString *date = [read objectForKey:@"date"];
            NSString *content = [read objectForKey:@"content"];
            if (title) {
                [html appendFormat:@"<h2>%@</h2>", title];
                if (date) {
                    NSString *sub = [self isDark] ? @"color:#888;" : [self isSepia] ? @"color:#a08060;" : @"color:#999;";
                    [html appendFormat:@"<p style='margin:-8px 0 12px 0;font-size:14px;%@'>%@, %@</p>", sub, dayLabel, date];
                }
            }
            if (content) {
                [html appendString:content];
            }
            [html appendString:@"<hr>"];
        }

        // JavaScript for verse popups
        [html appendString:@"<script>"];
        [html appendString:versesJS];
        [html appendFormat:@"var lang='%@';", [SSAPIClient shared].language];
        [html appendString:@"var currentKey='';"];
        // Inject saved translation from NSUserDefaults
        NSString *savedKey = [NSString stringWithFormat:@"bible_%@", [SSAPIClient shared].language];
        NSString *savedTrans = [[NSUserDefaults standardUserDefaults] stringForKey:savedKey];
        if (savedTrans) {
            [html appendFormat:@"var savedTranslation='%@';", savedTrans];
        } else {
            [html appendString:@"var savedTranslation=null;"];
        }
        [html appendString:@"function getSavedTranslation(){return savedTranslation||translationNames[0];}"];
        [html appendString:@"function saveTranslation(t){savedTranslation=t;location.href='ss://save/'+t;}"];
        [html appendString:@"function showVerse(key,trans){"];
        [html appendString:@"  var t=trans||getSavedTranslation();"];
        [html appendString:@"  if(!bibleVerses[t])t=translationNames[0];"];
        [html appendString:@"  var text=bibleVerses[t]?bibleVerses[t][key]:null;"];
        [html appendString:@"  if(!text)text='<p>Текст не знайдено</p>';"];
        [html appendString:@"  document.getElementById('verse-text').innerHTML=text;"];
        [html appendString:@"  var btns=document.getElementById('verse-translations');btns.innerHTML='';"];
        [html appendString:@"  for(var i=0;i<translationNames.length;i++){"];
        [html appendString:@"    var b=document.createElement('button');b.textContent=translationNames[i];"];
        [html appendString:@"    if(translationNames[i]===t)b.className='active';"];
        [html appendString:@"    b.setAttribute('data-t',translationNames[i]);"];
        [html appendString:@"    b.onclick=function(e){e.stopPropagation();var tn=this.getAttribute('data-t');saveTranslation(tn);showVerse(currentKey,tn);};"];
        [html appendString:@"    btns.appendChild(b);"];
        [html appendString:@"  }"];
        [html appendString:@"}"];
        [html appendString:@"document.addEventListener('click', function(e) {"];
        [html appendString:@"  var el = e.target;"];
        [html appendString:@"  while(el && el.tagName !== 'A') el = el.parentElement;"];
        [html appendString:@"  if(!el || !el.classList.contains('verse')) return;"];
        [html appendString:@"  e.preventDefault();"];
        [html appendString:@"  var key = el.getAttribute('verse');"];
        [html appendString:@"  if(!key) return;"];
        [html appendString:@"  currentKey=key;"];
        [html appendString:@"  showVerse(key);"];
        [html appendString:@"  document.getElementById('verse-popup').style.display = 'block';"];
        [html appendString:@"});"];
        [html appendString:@"function closeVerse() { document.getElementById('verse-popup').style.display = 'none'; }"];
        [html appendString:@"document.addEventListener('touchstart',function(e){var el=e.target;while(el&&el.tagName!=='A')el=el.parentElement;window._lastTapOnLink=el?'1':'';},true);"];
        [html appendString:@"</script>"];

        [html appendString:@"</body></html>"];
        [self.webView loadHTMLString:html baseURL:nil];
    }];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *urlStr = [[request URL] absoluteString];
    // Intercept ss://save/<translation> from JS
    if ([urlStr hasPrefix:@"ss://save/"]) {
        NSString *trans = [urlStr substringFromIndex:10];
        NSString *savedKey = [NSString stringWithFormat:@"bible_%@", [SSAPIClient shared].language];
        [[NSUserDefaults standardUserDefaults] setObject:trans forKey:savedKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return NO;
    }
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        return NO;
    }
    return YES;
}

@end
