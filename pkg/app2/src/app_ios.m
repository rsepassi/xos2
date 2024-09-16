#ifdef APP_PLATFORM_OS_IOS

#include "app.h"
#include "app_internal.h"

#include "base/log.h"
#include "base/file.h"

#import <UIKit/UIKit.h>

extern void app_init(app_state_t* state, app_init_t* init);

#define getapp() [AppDelegate shared].app;

u64 app__gettimems(app_platform_t* app) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return now.tv_sec * 1000 + now.tv_nsec / 1000000LL;
}

// Interfaces
// ============================================================================
@interface TextDelegate : NSObject<UITextFieldDelegate>
- (void)keyboardWasShown:(NSNotification*)notif;
- (void)keyboardDidChangeFrame:(NSNotification*)notif;
- (void)keyboardWillBeHidden:(NSNotification*)notif;
@end

@interface View : UIView
@end

@interface ViewController : UIViewController
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow * window;
@property (strong, nonatomic) View* view;
@property (nonatomic, strong) UITextField* textfield;
@property (nonatomic, strong) TextDelegate* textfield_delegate;
@property (strong, nonatomic) ViewController* view_ctrl;
@property (nonatomic) app_platform_t *app;
+ (AppDelegate *)shared;
- (void)activateKeyboard;
- (void)deactivateKeyboard;
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
    LOG("resize to (%d, %d)", w, h);
    app_platform_t* app = getapp();
    app__resize_fb(app, w, h);
    app__render(app);
  }];
}

@end
// ============================================================================

// TextDelegate
// ============================================================================
@implementation TextDelegate

- (void)keyboardWasShown:(NSNotification*)notif {
  LOG("keyboardWasShown");
  NSDictionary* info = notif.userInfo;
  CGFloat kbd_h = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
  UIView *view = [AppDelegate shared].view;
  CGRect viewBounds = view.bounds;
  viewBounds.size.height -= kbd_h;

  app_platform_t* app = getapp();
  app->state.onscreen_keyboard = true;
  app__resize_fb(app, viewBounds.size.width, viewBounds.size.height);
  app__render(app);
}

- (void)keyboardWillBeHidden:(NSNotification*)notif {
  LOG("keyboardWillBeHidden");
  UIView *view = [AppDelegate shared].view;
  CGRect viewBounds = view.bounds;

  u16 h = viewBounds.size.height;
  u16 w = viewBounds.size.width;

  app_platform_t* app = getapp();
  app->state.onscreen_keyboard = false;
  app__resize_fb(app, w, h);
  app__render(app);
}

- (void)keyboardDidChangeFrame:(NSNotification*)notif {
  LOG("keyboardDidChangeFrame");
  UIView *view = [AppDelegate shared].view;
  CGRect viewBounds = view.bounds;

  app_platform_t* app = getapp();
  u16 w, h;
  if (app->state.onscreen_keyboard) {
    NSDictionary* info = notif.userInfo;
    CGFloat kbd_h = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    h = viewBounds.size.height - kbd_h;
    w = viewBounds.size.width;
  } else {
    h = viewBounds.size.height;
    w = viewBounds.size.width;
  }

  app__resize_fb(app, w, h);
  app__render(app);
}

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string {
  app_platform_t* app = getapp();

  if (range.length > 0 && string.length == 0) {
    app_event_key_t* ev = &app->event.data.key;
    *ev = (app_event_key_t){0};
    ev->key = AppKey_BACKSPACE;
    ev->action = AppKeyPress;
    EV0(Key);
    ev->action = AppKeyRelease;
    EV0(Key);
    return NO;
  }

  for (int i = 0; i < string.length; ++i) {
    unichar c = [string characterAtIndex:i];
    if (c >= 32) {
      if ((c < 0xD800) || (c > 0xDFFF)) {
        EV(Char, xchar, c);
      } else {
        LOG("char dropped %d", c);
      }
    } else if (c == 10) {
      // Enter
      app_event_key_t* ev = &app->event.data.key;
      *ev = (app_event_key_t){0};
      ev->key = AppKey_ENTER;
      ev->action = AppKeyPress;
      EV0(Key);
      ev->action = AppKeyRelease;
      EV0(Key);
    } else {
      LOG("char dropped %d", c);
    }
  }

  return NO;
}

@end
// ============================================================================

// View
// ============================================================================
@implementation View

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];

  UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  tapGesture.delaysTouchesBegan = YES;
  [self addGestureRecognizer:tapGesture];

  UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
  swipeGesture.delaysTouchesBegan = YES;
  [self addGestureRecognizer:swipeGesture];

  UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  longPressGesture.delaysTouchesBegan = YES;
  [self addGestureRecognizer:longPressGesture];

  return self;
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
  CGPoint location = [gesture locationInView:self];
  LOG("Tap detected at position: (%f, %f)", location.x, location.y);
  app_platform_t* app = getapp();
  if (app->state.onscreen_keyboard) {
    LOG("deactivate");
    [[AppDelegate shared] deactivateKeyboard];
  } else {
    LOG("activate");
    [[AppDelegate shared] activateKeyboard];
  }
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gesture {
  CGPoint location = [gesture locationInView:self];
  LOG("Swipe detected at position: (%f, %f)", location.x, location.y);
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
  if (gesture.state == UIGestureRecognizerStateBegan) {
    CGPoint location = [gesture locationInView:self];
    LOG("Long-press detected at position: (%f, %f)", location.x, location.y);
  }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesBegan:touches withEvent:event];

  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    LOG("Touch began at position: (%f, %f)", location.x, location.y);
  }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesMoved:touches withEvent:event];

  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    CGPoint previousLocation = [touch previousLocationInView:self];
    LOG("Touch moved from (%f, %f) to (%f, %f)",
          previousLocation.x, previousLocation.y,
          location.x, location.y);
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesEnded:touches withEvent:event];

  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    LOG("Touch ended at position: (%f, %f)", location.x, location.y);
  }
}

@end
// ============================================================================

// AppDelegate
// ============================================================================

@implementation AppDelegate

- (void)dealloc {
  [super dealloc];
  [[NSNotificationCenter defaultCenter] removeObserver:self.textfield_delegate
                                                  name:UIKeyboardDidShowNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.textfield_delegate
                                                  name:UIKeyboardWillHideNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.textfield_delegate
                                                  name:UIKeyboardDidChangeFrameNotification
                                                object:nil];
  nativefb_deinit(&app->platform);
  text_atlas_deinit(&app->atlas);
  free(app->atlas.buf);
  hb_buffer_destroy(app->hb_buf);
  hb_font_destroy(app->hb_font);
  FT_Done_Face(app->ft_face);
  free((void*)font_data.bytes);
  FT_Done_FreeType(app->ft_library);
  free(self.app->bump.buf);
  free(self.app);
}

+ (AppDelegate *)shared {
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
  CHECK(!FT_Init_FreeType(&app->ft_library));
  CHECK(!FT_New_Memory_Face(app->ft_library, (const FT_Byte*)font_data.bytes, font_data.len, 0, &app->ft_face));
  FT_Set_Char_Size(app->ft_face, 0, font_size << 6, 72, 72);
  app->lineh = text_line_height(app->ft_face);
  app->hb_font = hb_ft_font_create(app->ft_face, NULL);
  app->hb_buf = text_english_buf();
  int atlash = (int)(app->lineh + 0.5);
  int atlasw = (1 << 20) / atlash;
  app->atlas = text_atlas_init(malloc(atlash * atlasw), atlasw, atlash);

  // Main view setup
  CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
  self.window = [[UIWindow alloc] initWithFrame:mainScreenBounds];
  self.view = [[View alloc] initWithFrame:self.window.bounds];
  self.view.userInteractionEnabled = YES;
  self.view.multipleTouchEnabled = YES;
  self.view_ctrl = [[ViewController alloc] init];
  self.view_ctrl.view = self.view;

  // Keyboard setup with a hidden UITextField
  self.textfield = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, 100, 50)];
  self.textfield.hidden = YES;
  self.textfield.text = @" ";
  self.textfield.keyboardType = UIKeyboardTypeDefault;
  self.textfield.autocapitalizationType = UITextAutocapitalizationTypeNone;
  self.textfield_delegate = [[TextDelegate alloc] init];
  self.textfield.delegate = self.textfield_delegate;
  [self.view addSubview:self.textfield];
  [[NSNotificationCenter defaultCenter] addObserver:self.textfield_delegate
      selector:@selector(keyboardWasShown:)
      name:UIKeyboardDidShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self.textfield_delegate
      selector:@selector(keyboardWillBeHidden:)
      name:UIKeyboardWillHideNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self.textfield_delegate
      selector:@selector(keyboardDidChangeFrame:)
      name:UIKeyboardDidChangeFrameNotification object:nil];

  // Framebuffer setup
  u16 w = self.view.bounds.size.width;
  u16 h = self.view.bounds.size.height;
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

- (void)activateKeyboard {
  [self.textfield becomeFirstResponder];
}

- (void)deactivateKeyboard {
  [self.textfield resignFirstResponder];
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
