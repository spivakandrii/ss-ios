#import "SSAppDelegate.h"
#import "SSLanguageVC.h"

@implementation SSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    SSLanguageVC *langVC = [[SSLanguageVC alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:langVC];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.18 green:0.25 blue:0.38 alpha:1.0];

    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
