#import "SSLessonsVC.h"
#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSLessonsVC ()
@property (nonatomic, strong) NSArray *lessons;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SSLessonsVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.quarterlyTitle ? self.quarterlyTitle : @"Уроки";

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 120);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    [[SSAPIClient shared] fetchLessonsForQuarterly:self.quarterlyId completion:^(id result, NSError *error) {
        [self.spinner stopAnimating];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Помилка"
                                                            message:@"Не вдалося завантажити уроки"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        self.lessons = result;
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.lessons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"LessonCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSDictionary *lesson = [self.lessons objectAtIndex:indexPath.row];
    NSString *lessonId = [lesson objectForKey:@"id"];
    cell.textLabel.text = [NSString stringWithFormat:@"%@. %@", lessonId, [lesson objectForKey:@"title"]];

    // Count read days for this lesson
    NSInteger readCount = 0;
    NSInteger totalDays = 7;
    for (NSInteger d = 1; d <= 7; d++) {
        NSString *dayId = [NSString stringWithFormat:@"%02ld", (long)d];
        NSString *key = [NSString stringWithFormat:@"read_%@_%@_%@", self.quarterlyId, lessonId, dayId];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) readCount++;
    }

    NSString *dates = [NSString stringWithFormat:@"%@ — %@", [lesson objectForKey:@"start_date"], [lesson objectForKey:@"end_date"]];
    if (readCount > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  (%ld/%ld)", dates, (long)readCount, (long)totalDays];
        if (readCount >= totalDays) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
        } else {
            cell.detailTextLabel.textColor = [UIColor grayColor];
        }
    } else {
        cell.detailTextLabel.text = dates;
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }

    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *lesson = [self.lessons objectAtIndex:indexPath.row];
    NSString *lessonId = [lesson objectForKey:@"id"];

    [[SSAPIClient shared] fetchLessonDetailForQuarterly:self.quarterlyId lesson:lessonId completion:^(id result, NSError *error) {
        if (error || !result) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Помилка"
                                                            message:@"Не вдалося завантажити урок"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        NSArray *days = [result objectForKey:@"days"];
        SSReadVC *readVC = [[SSReadVC alloc] init];
        readVC.quarterlyId = self.quarterlyId;
        readVC.lessonId = lessonId;
        readVC.lessonTitle = [lesson objectForKey:@"title"];
        readVC.days = days;
        [self.navigationController pushViewController:readVC animated:YES];
    }];
}

@end
