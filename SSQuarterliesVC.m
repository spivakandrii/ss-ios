#import "SSQuarterliesVC.h"
#import "SSLessonsVC.h"
#import "SSAPIClient.h"

@interface SSQuarterliesVC ()
@property (nonatomic, strong) NSArray *quarterlies;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SSQuarterliesVC

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
    cell.detailTextLabel.textColor = [UIColor grayColor];

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
