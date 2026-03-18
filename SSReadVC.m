#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSReadVC () <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UISegmentedControl *daySelector;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) NSInteger currentDayIndex;
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
    NSMutableArray *titles = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.days.count; i++) {
        NSDictionary *day = [self.days objectAtIndex:i];
        NSString *dayId = [day objectForKey:@"id"];
        if (dayId.length >= 2) {
            [titles addObject:dayId];
        } else {
            [titles addObject:[NSString stringWithFormat:@"%ld", (long)(i + 1)]];
        }
    }

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

        if (error || ![result isKindOfClass:[NSArray class]]) {
            [self.webView loadHTMLString:@"<html><body><h2>Помилка завантаження</h2></body></html>" baseURL:nil];
            return;
        }

        NSArray *reads = result;
        NSMutableString *html = [NSMutableString string];
        [html appendString:@"<html><head><meta charset='utf-8'>"];
        [html appendString:@"<meta name='viewport' content='width=device-width, initial-scale=1.0'>"];
        [html appendString:@"<style>"];
        [html appendString:@"body { font-family: Georgia, serif; font-size: 18px; line-height: 1.6; padding: 16px; color: #333; background: #fefefe; }"];
        [html appendString:@"h1, h2, h3 { color: #2E4161; }"];
        [html appendString:@"blockquote { border-left: 3px solid #2E4161; padding-left: 12px; margin-left: 0; color: #555; font-style: italic; }"];
        [html appendString:@"a { color: #2E4161; }"];
        [html appendString:@"hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }"];
        [html appendString:@"</style></head><body>"];

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

        [html appendString:@"</body></html>"];
        [self.webView loadHTMLString:html baseURL:nil];
    }];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:request.URL];
        return NO;
    }
    return YES;
}

@end
