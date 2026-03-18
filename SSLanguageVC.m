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
    CGFloat startY = h / 2 - btnH - gap / 2;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, startY - 80, w, 30)];
    label.text = @"Оберіть мову / Alegeți limba";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:18];
    label.textColor = [UIColor darkGrayColor];
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:label];

    UIButton *ukBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    ukBtn.frame = CGRectMake((w - btnW) / 2, startY, btnW, btnH);
    [ukBtn setTitle:@"🇺🇦 Українська" forState:UIControlStateNormal];
    ukBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    ukBtn.tag = 1;
    [ukBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    ukBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:ukBtn];

    UIButton *roBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    roBtn.frame = CGRectMake((w - btnW) / 2, startY + btnH + gap, btnW, btnH);
    [roBtn setTitle:@"🇷🇴 Română" forState:UIControlStateNormal];
    roBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    roBtn.tag = 2;
    [roBtn addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    roBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:roBtn];
}

- (void)languageTapped:(UIButton *)sender {
    NSString *lang = (sender.tag == 1) ? @"uk" : @"ro";
    [SSAPIClient shared].language = lang;

    SSQuarterliesVC *vc = [[SSQuarterliesVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
