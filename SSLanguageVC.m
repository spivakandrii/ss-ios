#import "SSLanguageVC.h"
#import "SSQuarterliesVC.h"
#import "SSAPIClient.h"

@implementation SSLanguageVC

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

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, startY - 80, w, 30)];
    label.text = @"Оберіть мову / Alegeti limba";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:18];
    label.textColor = [UIColor darkGrayColor];
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:label];

    UIButton *ukBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    ukBtn.frame = CGRectMake((w - btnW) / 2, startY, btnW, btnH);
    [ukBtn setTitle:@"Ukrainska" forState:UIControlStateNormal];
    ukBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    ukBtn.tag = 1;
    [ukBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    ukBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:ukBtn];

    UIButton *roBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    roBtn.frame = CGRectMake((w - btnW) / 2, startY + btnH + gap, btnW, btnH);
    [roBtn setTitle:@"Romana" forState:UIControlStateNormal];
    roBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    roBtn.tag = 2;
    [roBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    roBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:roBtn];

    // Online test button
    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    testBtn.frame = CGRectMake((w - btnW) / 2, startY + (btnH + gap) * 2, btnW, 40);
    [testBtn setTitle:@"Test TLS 1.2 online" forState:UIControlStateNormal];
    testBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    testBtn.tag = 99;
    [testBtn addTarget:self action:@selector(testOnline:) forControlEvents:UIControlEventTouchUpInside];
    testBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:testBtn];
}

- (void)languageTapped:(UIButton *)sender {
    NSString *lang = (sender.tag == 1) ? @"uk" : @"ro";
    [SSAPIClient shared].language = lang;
    [[NSUserDefaults standardUserDefaults] setObject:lang forKey:@"lastLanguage"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    SSQuarterliesVC *vc = [[SSQuarterliesVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)testOnline:(UIButton *)sender {
    [sender setTitle:@"Testing..." forState:UIControlStateNormal];
    sender.enabled = NO;

    [[SSAPIClient shared] testOnlineConnection:^(BOOL success) {
        sender.enabled = YES;
        if (success) {
            [sender setTitle:@"TLS 1.2 OK!" forState:UIControlStateNormal];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OK"
                                                            message:@"TLS 1.2 works! Online mode available."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            [sender setTitle:@"TLS 1.2 FAILED" forState:UIControlStateNormal];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed"
                                                            message:@"TLS 1.2 not supported. Using offline mode."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }];
}

@end
