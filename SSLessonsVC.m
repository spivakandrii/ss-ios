#import "SSLessonsVC.h"
#import "SSReadVC.h"
#import "SSAPIClient.h"

@interface SSLessonsVC ()
@property (nonatomic, strong) NSArray *lessons;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SSLessonsVC

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
    cell.textLabel.text = [NSString stringWithFormat:@"%@. %@", [lesson objectForKey:@"id"], [lesson objectForKey:@"title"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@", [lesson objectForKey:@"start_date"], [lesson objectForKey:@"end_date"]];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.detailTextLabel.textColor = [UIColor grayColor];

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
