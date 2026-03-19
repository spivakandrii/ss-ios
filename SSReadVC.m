#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSReadVC () <UIWebViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UISegmentedControl *daySelector;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIToolbar *bottomBar;
@property (nonatomic, assign) NSInteger currentDayIndex;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, assign) BOOL darkMode;
@property (nonatomic, copy) NSString *fontFamily;
@end

@implementation SSReadVC

- (void)viewDidLoad {
    [super viewDidLoad];

    // Load preferences
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.fontSize = [ud integerForKey:@"fontSize"];
    if (self.fontSize < 14 || self.fontSize > 28) self.fontSize = 18;
    self.darkMode = [ud boolForKey:@"darkMode"];
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

- (void)applyThemeToChrome {
    if (self.darkMode) {
        self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.navigationController.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.webView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.webView.opaque = NO;
        self.bottomBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.daySelector.tintColor = [UIColor colorWithRed:0.48 green:0.64 blue:0.83 alpha:1.0];
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

- (void)setupBottomBar {
    CGFloat barH = 44;
    CGRect barFrame = CGRectMake(0, self.view.bounds.size.height - barH, self.view.bounds.size.width, barH);
    self.bottomBar = [[UIToolbar alloc] initWithFrame:barFrame];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UIBarButtonItem *fontDown = [[UIBarButtonItem alloc] initWithTitle:@"A-" style:UIBarButtonItemStyleBordered target:self action:@selector(fontSmaller)];
    UIBarButtonItem *fontUp = [[UIBarButtonItem alloc] initWithTitle:@"A+" style:UIBarButtonItemStyleBordered target:self action:@selector(fontLarger)];
    UIBarButtonItem *fontPicker = [[UIBarButtonItem alloc] initWithTitle:@"Aa" style:UIBarButtonItemStyleBordered target:self action:@selector(showFontPicker)];
    UIBarButtonItem *nightToggle = [[UIBarButtonItem alloc] initWithTitle:self.darkMode ? @"Light" : @"Night" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleNightMode)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    [self.bottomBar setItems:[NSArray arrayWithObjects:fontDown, flex, fontUp, flex, fontPicker, flex, nightToggle, nil]];
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

- (void)toggleNightMode {
    self.darkMode = !self.darkMode;
    [self applyThemeToChrome];
    // Update button title
    NSMutableArray *items = [NSMutableArray arrayWithArray:self.bottomBar.items];
    UIBarButtonItem *nightBtn = [items lastObject];
    nightBtn.title = self.darkMode ? @"Light" : @"Night";
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

- (void)savePrefsAndReload {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:self.fontSize forKey:@"fontSize"];
    [ud setBool:self.darkMode forKey:@"darkMode"];
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
        if (self.darkMode) {
            [html appendFormat:@"body { font-family: %@; font-size: %ldpx; line-height: 1.6; padding: 16px; color: #ccc; background: #1a1a1a; }", self.fontFamily, (long)self.fontSize];
            [html appendString:@"h1, h2, h3 { color: #7ba4d4; }"];
            [html appendString:@"blockquote { border-left: 3px solid #7ba4d4; padding-left: 12px; margin-left: 0; color: #999; font-style: italic; }"];
            [html appendString:@"a.verse { color: #7ba4d4; text-decoration: underline; cursor: pointer; }"];
            [html appendString:@"a { color: #7ba4d4; }"];
            [html appendString:@"hr { border: none; border-top: 1px solid #333; margin: 20px 0; }"];
            [html appendString:@"#verse-popup { display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.7); z-index:999; }"];
            [html appendString:@"#verse-content { position:absolute; top:10%; left:5%; right:5%; max-height:75%; overflow-y:auto; "];
            [html appendString:@"background:#2a2a2a; border-radius:12px; padding:20px; box-shadow:0 4px 20px rgba(0,0,0,0.5); "];
            [html appendFormat:@"font-family:%@; font-size:%ldpx; line-height:1.6; color:#ccc; }", self.fontFamily, (long)(self.fontSize - 1)];
            [html appendString:@"#verse-content h2 { color:#7ba4d4; font-size:20px; margin:8px 0; }"];
            [html appendString:@"#verse-content sup { color:#666; font-size:12px; }"];
            [html appendString:@"#verse-close { position:absolute; top:12px; right:16px; font-size:28px; color:#666; cursor:pointer; z-index:1000; }"];
            [html appendString:@"#verse-translations { margin-bottom:12px; }"];
            [html appendString:@"#verse-translations button { padding:6px 14px; margin-right:6px; margin-bottom:4px; border:1px solid #7ba4d4; border-radius:6px; background:#2a2a2a; color:#7ba4d4; font-size:14px; cursor:pointer; }"];
            [html appendString:@"#verse-translations button.active { background:#7ba4d4; color:#1a1a1a; }"];
        } else {
            [html appendFormat:@"body { font-family: %@; font-size: %ldpx; line-height: 1.6; padding: 16px; color: #333; background: #fefefe; }", self.fontFamily, (long)self.fontSize];
            [html appendString:@"h1, h2, h3 { color: #2E4161; }"];
            [html appendString:@"blockquote { border-left: 3px solid #2E4161; padding-left: 12px; margin-left: 0; color: #555; font-style: italic; }"];
            [html appendString:@"a.verse { color: #2E4161; text-decoration: underline; cursor: pointer; }"];
            [html appendString:@"a { color: #2E4161; }"];
            [html appendString:@"hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }"];
            [html appendString:@"#verse-popup { display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.5); z-index:999; }"];
            [html appendString:@"#verse-content { position:absolute; top:10%; left:5%; right:5%; max-height:75%; overflow-y:auto; "];
            [html appendString:@"background:#fff; border-radius:12px; padding:20px; box-shadow:0 4px 20px rgba(0,0,0,0.3); "];
            [html appendFormat:@"font-family:%@; font-size:%ldpx; line-height:1.6; color:#333; }", self.fontFamily, (long)(self.fontSize - 1)];
            [html appendString:@"#verse-content h2 { color:#2E4161; font-size:20px; margin:8px 0; }"];
            [html appendString:@"#verse-content sup { color:#888; font-size:12px; }"];
            [html appendString:@"#verse-close { position:absolute; top:12px; right:16px; font-size:28px; color:#999; cursor:pointer; z-index:1000; }"];
            [html appendString:@"#verse-translations { margin-bottom:12px; }"];
            [html appendString:@"#verse-translations button { padding:6px 14px; margin-right:6px; margin-bottom:4px; border:1px solid #2E4161; border-radius:6px; background:#fff; color:#2E4161; font-size:14px; cursor:pointer; }"];
            [html appendString:@"#verse-translations button.active { background:#2E4161; color:#fff; }"];
        }
        [html appendString:@"</style></head><body>"];

        // Popup overlay
        [html appendString:@"<div id='verse-popup' onclick='closeVerse()'><span id='verse-close'>&times;</span><div id='verse-content' onclick='event.stopPropagation()'><div id='verse-translations'></div><div id='verse-text'></div></div></div>"];

        for (NSDictionary *read in reads) {
            NSString *title = [read objectForKey:@"title"];
            NSString *content = [read objectForKey:@"content"];
            if (title) {
                [html appendFormat:@"<h2>%@</h2>", title];
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
