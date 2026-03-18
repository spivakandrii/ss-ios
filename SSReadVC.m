#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSReadVC () <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UISegmentedControl *daySelector;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) NSInteger currentDayIndex;
@property (nonatomic, strong) NSDictionary *bibleVerses; // verse key -> HTML
@end

@implementation SSReadVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    [self setupDaySelector];
    [self setupWebView];
    [self setupSpinner];

    self.currentDayIndex = 0;
    [self loadDay:0];
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
    self.daySelector.selectedSegmentIndex = 0;
    [self.daySelector addTarget:self action:@selector(dayChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.daySelector;
}

- (void)setupWebView {
    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    self.webView = [[UIWebView alloc] initWithFrame:frame];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = NO;
    [self.view addSubview:self.webView];
}

- (void)setupSpinner {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];
}

- (void)dayChanged:(UISegmentedControl *)sender {
    [self loadDay:sender.selectedSegmentIndex];
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

        // Build bible verses lookup from first read's bible array
        NSMutableDictionary *verses = [NSMutableDictionary dictionary];
        if (reads.count > 0) {
            NSDictionary *firstRead = [reads objectAtIndex:0];
            NSArray *bibleArr = [firstRead objectForKey:@"bible"];
            if ([bibleArr isKindOfClass:[NSArray class]] && bibleArr.count > 0) {
                // Use first translation (UKR)
                NSDictionary *translation = [bibleArr objectAtIndex:0];
                NSDictionary *verseDict = [translation objectForKey:@"verses"];
                if ([verseDict isKindOfClass:[NSDictionary class]]) {
                    [verses addEntriesFromDictionary:verseDict];
                }
            }
        }
        self.bibleVerses = verses;

        // Build bible verses JSON for JavaScript
        NSMutableString *versesJS = [NSMutableString stringWithString:@"var bibleVerses = {"];
        NSArray *allKeys = [verses allKeys];
        for (NSInteger i = 0; i < (NSInteger)allKeys.count; i++) {
            NSString *key = [allKeys objectAtIndex:i];
            NSString *val = [verses objectForKey:key];
            // Escape for JS string
            val = [val stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            val = [val stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            val = [val stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
            val = [val stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            [versesJS appendFormat:@"'%@':'%@'", key, val];
            if (i < (NSInteger)allKeys.count - 1) [versesJS appendString:@","];
        }
        [versesJS appendString:@"};"];

        NSMutableString *html = [NSMutableString string];
        [html appendString:@"<html><head><meta charset='utf-8'>"];
        [html appendString:@"<meta name='viewport' content='width=device-width, initial-scale=1.0'>"];
        [html appendString:@"<style>"];
        [html appendString:@"body { font-family: Georgia, serif; font-size: 18px; line-height: 1.6; padding: 16px; color: #333; background: #fefefe; }"];
        [html appendString:@"h1, h2, h3 { color: #2E4161; }"];
        [html appendString:@"blockquote { border-left: 3px solid #2E4161; padding-left: 12px; margin-left: 0; color: #555; font-style: italic; }"];
        [html appendString:@"a.verse { color: #2E4161; text-decoration: underline; cursor: pointer; }"];
        [html appendString:@"a { color: #2E4161; }"];
        [html appendString:@"hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }"];
        [html appendString:@"#verse-popup { display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.5); z-index:999; }"];
        [html appendString:@"#verse-content { position:absolute; top:10%; left:5%; right:5%; max-height:75%; overflow-y:auto; "];
        [html appendString:@"background:#fff; border-radius:12px; padding:20px; box-shadow:0 4px 20px rgba(0,0,0,0.3); "];
        [html appendString:@"font-family:Georgia,serif; font-size:17px; line-height:1.6; color:#333; }"];
        [html appendString:@"#verse-content h2 { color:#2E4161; font-size:20px; margin:8px 0; }"];
        [html appendString:@"#verse-content sup { color:#888; font-size:12px; }"];
        [html appendString:@"#verse-close { position:absolute; top:12px; right:16px; font-size:28px; color:#999; cursor:pointer; z-index:1000; }"];
        [html appendString:@"</style></head><body>"];

        // Popup overlay
        [html appendString:@"<div id='verse-popup' onclick='closeVerse()'><span id='verse-close'>&times;</span><div id='verse-content'></div></div>"];

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
        [html appendString:@"document.addEventListener('click', function(e) {"];
        [html appendString:@"  var el = e.target;"];
        [html appendString:@"  while(el && el.tagName !== 'A') el = el.parentElement;"];
        [html appendString:@"  if(!el || !el.classList.contains('verse')) return;"];
        [html appendString:@"  e.preventDefault();"];
        [html appendString:@"  var key = el.getAttribute('verse');"];
        [html appendString:@"  if(!key) return;"];
        [html appendString:@"  var text = bibleVerses[key];"];
        [html appendString:@"  if(!text) { text = '<p>Текст не знайдено</p>'; }"];
        [html appendString:@"  document.getElementById('verse-content').innerHTML = text;"];
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
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        // Don't open external links - verse links handled by JS
        return NO;
    }
    return YES;
}

@end
