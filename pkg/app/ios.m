#import <UIKit/UIKit.h>
#import <Metal/MTLDevice.h>
#import <MetalKit/MetalKit.h>
#import <os/log.h>

#pragma clang diagnostic ignored "-Wunguarded-availability"

void _xos_ios_provide_metal_layer(void*, double, double);
void _xos_ios_handle_resize(double, double);
void _xos_handle_shutdown(void);

@interface OurMetalView : MTKView;
@end

@implementation OurMetalView

- (BOOL)isOpaque {
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent*)event {
  
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent*)event {
  
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent*)event {

}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent*)event {

}

@end

@interface ViewController : UIViewController


@end

@interface ViewController ()

@end

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
        _xos_ios_handle_resize(size.width, size.height);
    }];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow* window;
@property (strong, nonatomic) id<MTLDevice> mtl_device;
@property (strong, nonatomic) OurMetalView* view;
@property (strong, nonatomic) ViewController* view_ctrl;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:mainScreenBounds];

    self.mtl_device = MTLCreateSystemDefaultDevice();
    self.view = [[OurMetalView alloc] initWithFrame:self.window.bounds device:self.mtl_device];
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = YES;
    self.view.paused = YES;

    self.view_ctrl = [[ViewController alloc] init];
    self.view_ctrl.view = self.view;
    CAMetalLayer* layer = (CAMetalLayer*)self.view.layer;
    _xos_ios_provide_metal_layer(layer, self.window.bounds.size.width, self.window.bounds.size.height);
    
    [self.window setRootViewController:self.view_ctrl];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

void doiOSLog(char* msg) {
  os_log(OS_LOG_DEFAULT, "%s", msg);
}

int main(int argc, char** argv) {
  doiOSLog("hello world!");
  @autoreleasepool {
    UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
  _xos_handle_shutdown();
  doiOSLog("goodbye");
}

// UITextInput
// https://developer.apple.com/documentation/uikit/uitextinput?language=objc
//
// https://developer.apple.com/documentation/uikit/mac_catalyst/handling_key_presses_made_on_a_physical_keyboard?language=objc
// To detect a key press that a person makes on a physical keyboard, override pressesBegan:withEvent: in a responder object of your app such as the app delegate or main view controller.
//
// https://developer.apple.com/documentation/uikit/uikeycommand/navigating_an_app_s_user_interface_using_a_keyboard?language=objc
