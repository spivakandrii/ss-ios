#import "SSLanguageVC.h"
#import "SSQuarterliesVC.h"
#import "SSAPIClient.h"
#import "SSHTTPClient.h"
#import <QuartzCore/QuartzCore.h>

@implementation SSLanguageVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    self.view.backgroundColor = dark ? [UIColor blackColor] : [UIColor whiteColor];
    self.navigationController.navigationBar.tintColor = dark
        ? [UIColor colorWithWhite:0.15 alpha:1.0]
        : [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];

    // Update label and buttons
    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            ((UILabel *)sub).textColor = dark ? [UIColor whiteColor] : [UIColor darkGrayColor];
        }
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            btn.layer.cornerRadius = 8;
            btn.layer.borderWidth = 1;
            if (dark) {
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                btn.layer.borderColor = [[UIColor colorWithWhite:0.4 alpha:1.0] CGColor];
                btn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
            } else {
                [btn setTitleColor:[UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0] forState:UIControlStateNormal];
                btn.layer.borderColor = [[UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:0.3] CGColor];
                btn.backgroundColor = [UIColor whiteColor];
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Суботня Школа";
    self.view.backgroundColor = [UIColor whiteColor];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat btnW = 280;
    CGFloat btnH = 60;
    CGFloat gap = 20;
    CGFloat startY = h / 2 - btnH - gap;

    UIButton *ukBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    ukBtn.frame = CGRectMake((w - btnW) / 2, startY, btnW, btnH);
    [ukBtn setTitle:@"Ukrainian" forState:UIControlStateNormal];
    ukBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    ukBtn.tag = 1;
    [ukBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    ukBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:ukBtn];

    UIButton *roBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    roBtn.frame = CGRectMake((w - btnW) / 2, startY + btnH + gap, btnW, btnH);
    [roBtn setTitle:@"Romana" forState:UIControlStateNormal];
    roBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    roBtn.tag = 2;
    [roBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    roBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:roBtn];

    UIButton *tlsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    tlsBtn.frame = CGRectMake((w - btnW) / 2, startY + (btnH + gap) * 2, btnW, 40);
    [tlsBtn setTitle:@"Test TLS 1.2" forState:UIControlStateNormal];
    tlsBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [tlsBtn addTarget:self action:@selector(testTLS) forControlEvents:UIControlEventTouchUpInside];
    tlsBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:tlsBtn];
}

- (void)testTLS {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [SSHTTPClient fetchURL:@"https://sabbath-school.adventech.io/api/v2/uk/quarterlies"];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg;
            if (data) {
                msg = [NSString stringWithFormat:@"TLS 1.2 OK! Отримано %lu байт", (unsigned long)data.length];
            } else {
                msg = @"TLS не працює — дані не отримано";
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"TLS Test" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        });
    });
}

- (void)languageTapped:(UIButton *)sender {
    NSString *lang = (sender.tag == 1) ? @"uk" : @"ro";
    [SSAPIClient shared].language = lang;
    [[NSUserDefaults standardUserDefaults] setObject:lang forKey:@"lastLanguage"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    SSQuarterliesVC *vc = [[SSQuarterliesVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
