#import "SSQuarterliesVC.h"
#import "SSLessonsVC.h"
#import "SSAPIClient.h"

@interface SSQuarterliesVC ()
@property (nonatomic, strong) NSArray *quarterlies;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SSQuarterliesVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme {
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    self.tableView.backgroundColor = dark ? [UIColor colorWithWhite:0.1 alpha:1.0] : [UIColor whiteColor];
    self.tableView.separatorColor = dark ? [UIColor colorWithWhite:0.2 alpha:1.0] : nil;
    self.navigationController.navigationBar.tintColor = dark
        ? [UIColor colorWithWhite:0.15 alpha:1.0]
        : [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];
    if (dark) {
        self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    } else {
        self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Суботня Школа";

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 120);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    [[SSAPIClient shared] fetchQuarterlies:^(id result, NSError *error) {
        [self.spinner stopAnimating];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Помилка"
                                                            message:@"Не вдалося завантажити дані"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        self.quarterlies = result;
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.quarterlies.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"QuarterlyCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSDictionary *quarterly = [self.quarterlies objectAtIndex:indexPath.row];
    cell.textLabel.text = [quarterly objectForKey:@"title"];
    cell.detailTextLabel.text = [quarterly objectForKey:@"human_date"];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];

    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    cell.backgroundColor = dark ? [UIColor colorWithWhite:0.13 alpha:1.0] : [UIColor whiteColor];
    cell.textLabel.textColor = dark ? [UIColor colorWithWhite:0.85 alpha:1.0] : [UIColor blackColor];
    cell.detailTextLabel.textColor = dark ? [UIColor colorWithWhite:0.5 alpha:1.0] : [UIColor grayColor];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *quarterly = [self.quarterlies objectAtIndex:indexPath.row];
    SSLessonsVC *lessonsVC = [[SSLessonsVC alloc] init];
    lessonsVC.quarterlyId = [quarterly objectForKey:@"id"];
    lessonsVC.quarterlyTitle = [quarterly objectForKey:@"title"];
    [self.navigationController pushViewController:lessonsVC animated:YES];
}

@end
