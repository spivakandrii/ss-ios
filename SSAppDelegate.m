#import "SSAppDelegate.h"
#import "SSLanguageVC.h"
#import "SSQuarterliesVC.h"
#import "SSLessonsVC.h"
#import "SSReadVC.h"
#import "SSAPIClient.h"

@implementation SSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    SSLanguageVC *langVC = [[SSLanguageVC alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:langVC];

    // Apply theme to nav bar based on dark mode preference
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    if (dark) {
        self.navigationController.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    } else {
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];
    }

    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    // Auto-open today's lesson if language was previously selected
    NSString *lastLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"lastLanguage"];
    if (lastLang) {
        [self autoOpenTodayForLanguage:lastLang];
    }

    return YES;
}

- (void)autoOpenTodayForLanguage:(NSString *)lang {
    [SSAPIClient shared].language = lang;

    // Load quarterlies to find current one
    [[SSAPIClient shared] fetchQuarterlies:^(id quarterlies, NSError *error) {
        if (error || ![quarterlies isKindOfClass:[NSArray class]] || [quarterlies count] == 0) return;

        // Find quarterly that contains today
        NSString *quarterlyId = nil;
        NSString *quarterlyTitle = nil;
        for (NSDictionary *q in quarterlies) {
            quarterlyId = [q objectForKey:@"id"];
            quarterlyTitle = [q objectForKey:@"title"];
            break; // First (most recent) quarterly
        }
        if (!quarterlyId) return;

        // Load lessons to find current one
        [[SSAPIClient shared] fetchLessonsForQuarterly:quarterlyId completion:^(id lessons, NSError *err2) {
            if (err2 || ![lessons isKindOfClass:[NSArray class]]) return;

            NSDate *today = [NSDate date];
            NSDictionary *currentLesson = nil;

            for (NSDictionary *lesson in lessons) {
                NSDate *start = [self parseDate:[lesson objectForKey:@"start_date"]];
                NSDate *end = [self parseDate:[lesson objectForKey:@"end_date"]];
                if (start && end) {
                    // Add 1 day to end to make it inclusive
                    end = [end dateByAddingTimeInterval:86400];
                    if ([today compare:start] != NSOrderedAscending && [today compare:end] == NSOrderedAscending) {
                        currentLesson = lesson;
                        break;
                    }
                }
            }
            if (!currentLesson) currentLesson = [lessons lastObject]; // fallback

            NSString *lessonId = [currentLesson objectForKey:@"id"];

            // Load lesson detail to get days
            [[SSAPIClient shared] fetchLessonDetailForQuarterly:quarterlyId lesson:lessonId completion:^(id detail, NSError *err3) {
                if (err3 || !detail) return;
                NSArray *days = [detail objectForKey:@"days"];
                if (!days) return;

                // Calculate today's day index (Sat=1, Sun=2, ..., Fri=7)
                NSCalendar *cal = [NSCalendar currentCalendar];
                // NSCalendar: Sun=1, Mon=2, ..., Sat=7
                // Adventist week: Sat=1, Sun=2, Mon=3, ..., Fri=7
                NSInteger nsCal = [[cal components:NSWeekdayCalendarUnit fromDate:today] weekday];
                NSInteger adventistDay;
                if (nsCal == 7) adventistDay = 1; // Saturday
                else adventistDay = nsCal + 1; // Sun=2, Mon=3, ..., Fri=7

                // Push navigation stack: Language -> Quarterlies -> Lessons -> Read
                SSQuarterliesVC *qVC = [[SSQuarterliesVC alloc] init];
                SSLessonsVC *lVC = [[SSLessonsVC alloc] init];
                lVC.quarterlyId = quarterlyId;
                lVC.quarterlyTitle = quarterlyTitle;

                SSReadVC *readVC = [[SSReadVC alloc] init];
                readVC.quarterlyId = quarterlyId;
                readVC.lessonId = lessonId;
                readVC.lessonTitle = [currentLesson objectForKey:@"title"];
                readVC.days = days;
                readVC.initialDayIndex = adventistDay - 1; // 0-based

                [self.navigationController setViewControllers:
                    [NSArray arrayWithObjects:
                        [self.navigationController.viewControllers objectAtIndex:0], // LanguageVC
                        qVC, lVC, readVC, nil]
                    animated:YES];
            }];
        }];
    }];
}

- (NSDate *)parseDate:(NSString *)str {
    if (!str) return nil;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"dd/MM/yyyy"];
    return [fmt dateFromString:str];
}

@end
