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
    NSString *theme = [[NSUserDefaults standardUserDefaults] stringForKey:@"theme"];
    BOOL dark = [theme isEqualToString:@"dark"];
    BOOL sepia = [theme isEqualToString:@"sepia"];
    if (dark) {
        self.tableView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        self.navigationController.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    } else if (sepia) {
        self.tableView.backgroundColor = [UIColor colorWithRed:0.96 green:0.92 blue:0.84 alpha:1.0];
        self.tableView.separatorColor = [UIColor colorWithRed:0.83 green:0.77 blue:0.66 alpha:1.0];
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.55 green:0.40 blue:0.25 alpha:1.0];
        self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    } else {
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.tableView.separatorColor = nil;
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];
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

    NSString *theme = [[NSUserDefaults standardUserDefaults] stringForKey:@"theme"];
    BOOL dark = [theme isEqualToString:@"dark"];
    BOOL sepia = [theme isEqualToString:@"sepia"];
    if (dark) {
        cell.backgroundColor = [UIColor colorWithWhite:0.13 alpha:1.0];
        cell.textLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    } else if (sepia) {
        cell.backgroundColor = [UIColor colorWithRed:0.94 green:0.89 blue:0.80 alpha:1.0];
        cell.textLabel.textColor = [UIColor colorWithRed:0.36 green:0.25 blue:0.20 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.55 green:0.40 blue:0.25 alpha:1.0];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }

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
