#ifdef APP_PLATFORM_OS_IOS

#include "app.h"
#include "app_internal.h"

#include "base/log.h"
#include "base/file.h"

#import <UIKit/UIKit.h>

extern void app_init(app_state_t* state, app_init_t* init);

u64 app__gettimems(app_platform_t* app) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return now.tv_sec * 1000 + now.tv_nsec / 1000000LL;
}

// Interfaces
// ============================================================================
@interface ViewController : UIViewController
@end

@interface View : UIView
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow * window;
@property (strong, nonatomic) View* view;
@property (strong, nonatomic) ViewController* view_ctrl;
@property (nonatomic) app_platform_t *app;
+ (AppDelegate *)sharedInstance;
@end
// ============================================================================

// ViewController
// ============================================================================
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Before transition
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // After transition
        u16 w = size.width;
        u16 h = size.height;
        app_platform_t* app = [AppDelegate sharedInstance].app;
        app__resize_fb(app, w, h);
        app__render(app);
    }];
}

@end
// ============================================================================


// View
// ============================================================================
@implementation View

@end
// ============================================================================

// AppDelegate
// ============================================================================

@implementation AppDelegate

- (void)dealloc {
  [super dealloc];
  free(self.app);
}

+ (AppDelegate *)sharedInstance {
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.app = calloc(1, sizeof(app_platform_t));
  app_platform_t* app = self.app;

  LOG("app init");
  app_init(&app->state, &app->init);
  app->bump.buf = malloc(1 << 20);
  app->bump.len = 1 << 20;
  app->state.frame_allocator = allocator_bump(&app->bump);
  app->state.platform = &app;
  app->state.fb = &app->fb;

  LOG("text init");
  int font_size = 32;
  str_t font_data = fs_resource_read(cstr("CourierPrime-Regular.ttf"));
  FT_Library ft_library;
  CHECK(!FT_Init_FreeType(&ft_library));
  CHECK(!FT_New_Memory_Face(ft_library, (const FT_Byte*)font_data.bytes, font_data.len, 0, &app->ft_face));
  FT_Set_Char_Size(app->ft_face, 0, font_size << 6, 72, 72);
  app->lineh = text_line_height(app->ft_face);
  app->hb_font = hb_ft_font_create(app->ft_face, NULL);
  app->hb_buf = text_english_buf();
  int atlash = (int)(app->lineh + 0.5);
  int atlasw = (1 << 20) / atlash;
  app->atlas = text_atlas_init(malloc(atlash * atlasw), atlasw, atlash);

  CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
  self.window = [[UIWindow alloc] initWithFrame:mainScreenBounds];
  self.view = [[View alloc] initWithFrame:self.window.bounds];
  self.view.userInteractionEnabled = YES;
  self.view.multipleTouchEnabled = YES;
  self.view_ctrl = [[ViewController alloc] init];
  self.view_ctrl.view = self.view;

  u16 w = self.window.bounds.size.width;
  u16 h = self.window.bounds.size.height;
  app__resize_fb(app, w, h);
  nativefb_init(&app->platform, self.view, &app->fb);
  EV0(GfxInit);
  app__render(app);

  [self.window setRootViewController:self.view_ctrl];
  [self.window makeKeyAndVisible];

  return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  app_platform_t* app = self.app;
  EV0(Resume);
}

- (void)applicationWillResignActive:(UIApplication *)application {
  app_platform_t* app = self.app;
  EV0(Suspend);
}

- (void)applicationWillTerminate:(UIApplication *)application {
  app_platform_t* app = self.app;
  EV0(Exit);
}

@end
// ============================================================================

int main(int argc, char * argv[]) {
  LOG("hello world!");
  @autoreleasepool {
    UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
  LOG("goodbye");
}

#endif
