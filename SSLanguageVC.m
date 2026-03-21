#import "SSLanguageVC.h"
#import "SSQuarterliesVC.h"
#import "SSAPIClient.h"
#import "SSHTTPClient.h"
#import <QuartzCore/QuartzCore.h>

@interface SSLanguageVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray *allLanguages;
@end

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

    for (UIView *sub in self.view.subviews) {
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
    CGFloat btnH = 55;
    CGFloat gap = 16;
    CGFloat totalH = btnH * 4 + gap * 3;
    CGFloat startY = (h - totalH) / 2;

    NSArray *titles = [NSArray arrayWithObjects:@"Українська", @"Română", @"English", @"Other languages...", nil];
    NSArray *codes = [NSArray arrayWithObjects:@"uk", @"ro", @"en", @"other", nil];

    for (int i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake((w - btnW) / 2, startY + i * (btnH + gap), btnW, btnH);
        [btn setTitle:[titles objectAtIndex:i] forState:UIControlStateNormal];
        btn.titleLabel.font = (i < 3) ? [UIFont boldSystemFontOfSize:22] : [UIFont systemFontOfSize:18];
        btn.tag = i;
        [btn addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        btn.accessibilityLabel = [codes objectAtIndex:i];
        [self.view addSubview:btn];
    }
}

- (void)buttonTapped:(UIButton *)sender {
    if (sender.tag < 3) {
        // Direct language selection
        NSArray *codes = [NSArray arrayWithObjects:@"uk", @"ro", @"en", nil];
        [self selectLanguage:[codes objectAtIndex:sender.tag]];
    } else {
        [self showAllLanguages];
    }
}

- (void)selectLanguage:(NSString *)lang {
    [SSAPIClient shared].language = lang;
    [[NSUserDefaults standardUserDefaults] setObject:lang forKey:@"lastLanguage"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    SSQuarterliesVC *vc = [[SSQuarterliesVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAllLanguages {
    // Fetch languages from API in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [SSHTTPClient fetchURL:@"https://sabbath-school.adventech.io/api/v2/languages/index.json"];
        NSArray *langs = nil;
        if (data) {
            langs = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (langs && [langs count] > 0) {
                self.allLanguages = langs;
                [self presentLanguagePicker];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Помилка"
                    message:@"Не вдалося завантажити список мов. Перевірте з'єднання з інтернетом."
                    delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
        });
    });
}

- (void)presentLanguagePicker {
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];

    UIViewController *pickerVC = [[UIViewController alloc] init];
    pickerVC.title = @"Оберіть мову";

    UITableView *table = [[UITableView alloc] initWithFrame:pickerVC.view.bounds style:UITableViewStylePlain];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    table.dataSource = self;
    table.delegate = self;
    table.tag = 200;

    if (dark) {
        table.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        table.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    }

    [pickerVC.view addSubview:table];

    pickerVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Закрити" style:UIBarButtonItemStyleDone
        target:self action:@selector(dismissPicker)];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:pickerVC];
    if (dark) {
        nav.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    }
    [self presentModalViewController:nav animated:YES];
}

- (void)dismissPicker {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.allLanguages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LangCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"LangCell"];
    }

    NSDictionary *lang = [self.allLanguages objectAtIndex:indexPath.row];
    cell.textLabel.text = [lang objectForKey:@"name"];
    cell.detailTextLabel.text = [lang objectForKey:@"code"];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
    cell.detailTextLabel.textColor = [UIColor grayColor];

    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    cell.backgroundColor = dark ? [UIColor colorWithWhite:0.13 alpha:1.0] : [UIColor whiteColor];
    cell.textLabel.textColor = dark ? [UIColor colorWithWhite:0.85 alpha:1.0] : [UIColor blackColor];
    cell.detailTextLabel.textColor = dark ? [UIColor colorWithWhite:0.5 alpha:1.0] : [UIColor grayColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *lang = [self.allLanguages objectAtIndex:indexPath.row];
    NSString *code = [lang objectForKey:@"code"];
    [self dismissModalViewControllerAnimated:YES];
    [self selectLanguage:code];
}

@end
