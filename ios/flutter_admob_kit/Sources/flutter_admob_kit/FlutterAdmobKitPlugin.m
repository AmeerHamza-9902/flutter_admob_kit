#import "./include/flutter_admob_kit/FlutterAdmobKitPlugin.h"

#import <GoogleMobileAds/GoogleMobileAds.h>

@protocol AdMobKitNativeAdFactory <NSObject>
- (GADNativeAdView *)createNativeAd:(GADNativeAd *)nativeAd
                      customOptions:(NSDictionary *)customOptions;
@end

static Class AdsPluginClass(void) {
  return NSClassFromString(@"FLTGoogleMobileAdsPlugin");
}

static BOOL RegisterFactory(FlutterEngine *engine, NSString *factoryId,
                            id<AdMobKitNativeAdFactory> factory) {
  Class plugin = AdsPluginClass();
  SEL selector = NSSelectorFromString(@"registerNativeAdFactory:factoryId:nativeAdFactory:");
  if (![plugin respondsToSelector:selector]) return NO;
  BOOL (*invoke)(id, SEL, id<FlutterPluginRegistry>, NSString *, id) =
      (void *)[plugin methodForSelector:selector];
  return invoke(plugin, selector, engine, factoryId, factory);
}

static void UnregisterFactory(FlutterEngine *engine, NSString *factoryId) {
  Class plugin = AdsPluginClass();
  SEL selector = NSSelectorFromString(@"unregisterNativeAdFactory:factoryId:");
  if (![plugin respondsToSelector:selector]) return;
  void (*invoke)(id, SEL, id<FlutterPluginRegistry>, NSString *) =
      (void *)[plugin methodForSelector:selector];
  invoke(plugin, selector, engine, factoryId);
}

static NSString *const kMediumFactoryId = @"flutter_admob_kit/medium_native";

@interface AdMobKitNativeView : GADNativeAdView
@property(nonatomic, strong) UILabel *optionalBody;
@property(nonatomic, strong) UIButton *ctaButton;
@property(nonatomic, strong) UIView *bodyLimitView;
@property(nonatomic, assign) CGSize lastMeasuredSize;
@end

@implementation AdMobKitNativeView
- (void)layoutSubviews {
  [super layoutSubviews];
  if (!self.optionalBody || self.optionalBody.text.length == 0) return;
  if (!CGSizeEqualToSize(self.lastMeasuredSize, self.bounds.size)) {
    self.lastMeasuredSize = self.bounds.size;
    self.optionalBody.hidden = NO;
  }
  if (self.optionalBody.hidden || self.optionalBody.bounds.size.width <= 0) return;
  NSString *requiredCopy = [self.optionalBody.text substringToIndex:
      MIN((NSUInteger)90, self.optionalBody.text.length)];
  CGRect requiredBounds = [requiredCopy boundingRectWithSize:
      CGSizeMake(self.optionalBody.bounds.size.width, CGFLOAT_MAX)
      options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
      attributes:@{NSFontAttributeName: self.optionalBody.font}
      context:nil];
  UIView *limit = self.bodyLimitView ?: self.ctaButton;
  CGRect bodyFrame = [self.optionalBody.superview convertRect:self.optionalBody.frame toView:self];
  CGRect limitFrame = [limit.superview convertRect:limit.frame toView:self];
  if (ceil(requiredBounds.size.height) > ceil(self.optionalBody.font.lineHeight * 2)
      || CGRectGetMaxY(bodyFrame) > CGRectGetMinY(limitFrame)) {
    // The body is optional; show it only when its first 90 characters fit.
    self.optionalBody.hidden = YES;
  }
}
@end

@interface AdMobKitMediumNativeFactory : NSObject <AdMobKitNativeAdFactory>
@end

@implementation AdMobKitMediumNativeFactory

static UIColor *ColorFromOption(NSDictionary *options, NSString *key, uint32_t fallback) {
  NSNumber *value = [options[key] isKindOfClass:NSNumber.class] ? options[key] : nil;
  uint32_t argb = value ? value.unsignedIntValue : fallback;
  return [UIColor colorWithRed:((argb >> 16) & 255) / 255.0
                         green:((argb >> 8) & 255) / 255.0
                          blue:(argb & 255) / 255.0
                         alpha:((argb >> 24) & 255) / 255.0];
}

static void Add(UIView *child, UIView *parent) {
  child.translatesAutoresizingMaskIntoConstraints = NO;
  [parent addSubview:child];
}

- (GADNativeAdView *)createNativeAd:(GADNativeAd *)nativeAd
                      customOptions:(NSDictionary *)customOptions {
  NSDictionary *options = customOptions ?: @{};
  AdMobKitNativeView *view = [[AdMobKitNativeView alloc] initWithFrame:CGRectMake(0, 0, 320, 128)];
  view.backgroundColor = ColorFromOption(options, @"backgroundColor", 0xFFFFFFFF);
  CGFloat radius = [options[@"cornerRadius"] isKindOfClass:NSNumber.class]
      ? MAX(0, [options[@"cornerRadius"] doubleValue]) : 10;
  view.layer.cornerRadius = radius;
  view.clipsToBounds = YES;

  GADMediaView *media = [[GADMediaView alloc] init];
  media.contentMode = UIViewContentModeScaleAspectFit;
  media.mediaContent = nativeAd.mediaContent;
  Add(media, view);
  view.mediaView = media;

  UIView *details = [[UIView alloc] init];
  Add(details, view);

  UILabel *badge = [[UILabel alloc] init];
  badge.text = @"Ad";
  badge.font = [UIFont boldSystemFontOfSize:11];
  badge.textAlignment = NSTextAlignmentCenter;
  badge.textColor = UIColor.whiteColor;
  badge.backgroundColor = ColorFromOption(options, @"callToActionColor", 0xFF2563EB);
  badge.layer.cornerRadius = 3;
  badge.clipsToBounds = YES;
  Add(badge, details);

  UILabel *headline = [[UILabel alloc] init];
  headline.text = nativeAd.headline;
  headline.textColor = ColorFromOption(options, @"primaryTextColor", 0xFF111827);
  headline.font = [UIFont boldSystemFontOfSize:13];
  headline.numberOfLines = 1;
  headline.lineBreakMode = NSLineBreakByTruncatingTail;
  Add(headline, details);
  view.headlineView = headline;

  UILabel *advertiser = [[UILabel alloc] init];
  advertiser.text = nativeAd.advertiser;
  advertiser.textColor = ColorFromOption(options, @"secondaryTextColor", 0xFF4B5563);
  advertiser.font = [UIFont boldSystemFontOfSize:10];
  advertiser.numberOfLines = 1;
  advertiser.hidden = nativeAd.advertiser.length == 0;
  Add(advertiser, details);
  if (!advertiser.hidden) view.advertiserView = advertiser;

  UILabel *body = [[UILabel alloc] init];
  body.text = nativeAd.body;
  body.textColor = ColorFromOption(options, @"secondaryTextColor", 0xFF4B5563);
  body.font = [UIFont systemFontOfSize:11];
  body.numberOfLines = 2;
  body.lineBreakMode = NSLineBreakByTruncatingTail;
  body.hidden = nativeAd.body.length == 0;
  Add(body, details);
  if (!body.hidden) view.bodyView = body;
  view.optionalBody = body;

  UIButton *cta = [UIButton buttonWithType:UIButtonTypeCustom];
  [cta setTitle:nativeAd.callToAction forState:UIControlStateNormal];
  [cta setTitleColor:ColorFromOption(options, @"callToActionTextColor", 0xFFFFFFFF)
            forState:UIControlStateNormal];
  cta.backgroundColor = ColorFromOption(options, @"callToActionColor", 0xFF2563EB);
  cta.titleLabel.font = [UIFont boldSystemFontOfSize:14];
  cta.layer.cornerRadius = radius;
  cta.userInteractionEnabled = NO;
  cta.hidden = nativeAd.callToAction.length == 0;
  Add(cta, details);
  if (!cta.hidden) view.callToActionView = cta;
  view.ctaButton = cta;

  GADAdChoicesView *adChoices = [[GADAdChoicesView alloc] init];
  Add(adChoices, view);
  view.adChoicesView = adChoices;

  [NSLayoutConstraint activateConstraints:@[
    [media.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:4],
    [media.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
    [media.widthAnchor constraintEqualToConstant:120],
    [media.heightAnchor constraintEqualToConstant:120],
    [details.leadingAnchor constraintEqualToAnchor:media.trailingAnchor constant:8],
    [details.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8],
    [details.topAnchor constraintEqualToAnchor:view.topAnchor constant:4],
    [details.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-4],
    [badge.leadingAnchor constraintEqualToAnchor:details.leadingAnchor],
    [badge.topAnchor constraintEqualToAnchor:details.topAnchor],
    [badge.widthAnchor constraintGreaterThanOrEqualToConstant:24],
    [badge.heightAnchor constraintEqualToConstant:16],
    [headline.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:4],
    [headline.trailingAnchor constraintEqualToAnchor:details.trailingAnchor constant:-24],
    [headline.topAnchor constraintEqualToAnchor:details.topAnchor],
    [advertiser.leadingAnchor constraintEqualToAnchor:details.leadingAnchor],
    [advertiser.trailingAnchor constraintEqualToAnchor:details.trailingAnchor],
    [advertiser.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:2],
    [body.leadingAnchor constraintEqualToAnchor:details.leadingAnchor],
    [body.trailingAnchor constraintEqualToAnchor:details.trailingAnchor],
    [body.topAnchor constraintEqualToAnchor:advertiser.bottomAnchor constant:2],
    [body.bottomAnchor constraintLessThanOrEqualToAnchor:cta.topAnchor constant:-2],
    [cta.leadingAnchor constraintEqualToAnchor:details.leadingAnchor],
    [cta.trailingAnchor constraintEqualToAnchor:details.trailingAnchor],
    [cta.bottomAnchor constraintEqualToAnchor:details.bottomAnchor],
    [cta.heightAnchor constraintEqualToConstant:37],
    [adChoices.topAnchor constraintEqualToAnchor:view.topAnchor constant:2],
    [adChoices.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-2],
    [adChoices.widthAnchor constraintEqualToConstant:20],
    [adChoices.heightAnchor constraintEqualToConstant:20],
  ]];

  view.nativeAd = nativeAd;
  return view;
}
@end

@interface AdMobKitBigNativeFactory : NSObject <AdMobKitNativeAdFactory>
@end

@implementation AdMobKitBigNativeFactory
- (GADNativeAdView *)createNativeAd:(GADNativeAd *)nativeAd
                      customOptions:(NSDictionary *)customOptions {
  NSDictionary *options = customOptions ?: @{};
  AdMobKitNativeView *view = [[AdMobKitNativeView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
  view.backgroundColor = ColorFromOption(options, @"backgroundColor", 0xFFFFFFFF);
  CGFloat radius = [options[@"cornerRadius"] isKindOfClass:NSNumber.class]
      ? MAX(0, [options[@"cornerRadius"] doubleValue]) : 10;
  view.layer.cornerRadius = radius;
  view.clipsToBounds = YES;

  GADMediaView *media = [[GADMediaView alloc] init];
  media.contentMode = UIViewContentModeScaleAspectFit;
  media.mediaContent = nativeAd.mediaContent;
  Add(media, view);
  view.mediaView = media;

  UIView *details = [[UIView alloc] init];
  Add(details, view);
  UIImageView *icon = [[UIImageView alloc] initWithImage:nativeAd.icon.image];
  icon.contentMode = UIViewContentModeScaleAspectFit;
  icon.layer.cornerRadius = radius;
  icon.clipsToBounds = YES;
  icon.hidden = nativeAd.icon == nil;
  Add(icon, details);
  if (!icon.hidden) view.iconView = icon;

  UILabel *headline = [[UILabel alloc] init];
  headline.text = nativeAd.headline;
  headline.font = [UIFont boldSystemFontOfSize:16];
  headline.textColor = ColorFromOption(options, @"primaryTextColor", 0xFF111827);
  headline.numberOfLines = 3;
  Add(headline, details);
  view.headlineView = headline;

  UILabel *body = [[UILabel alloc] init];
  body.text = nativeAd.body;
  body.font = [UIFont systemFontOfSize:13];
  body.textColor = ColorFromOption(options, @"secondaryTextColor", 0xFF4B5563);
  body.numberOfLines = 2;
  body.lineBreakMode = NSLineBreakByTruncatingTail;
  body.hidden = nativeAd.body.length == 0;
  Add(body, details);
  if (!body.hidden) view.bodyView = body;
  view.optionalBody = body;

  UILabel *badge = [[UILabel alloc] init];
  badge.text = @"Ad";
  badge.font = [UIFont boldSystemFontOfSize:11];
  badge.textColor = ColorFromOption(options, @"primaryTextColor", 0xFF111827);
  Add(badge, details);
  view.bodyLimitView = badge;

  UILabel *rating = [[UILabel alloc] init];
  NSNumber *stars = nativeAd.starRating;
  rating.hidden = stars == nil;
  if (stars) {
    NSInteger filled = MIN(5, MAX(0, (NSInteger)round(stars.doubleValue)));
    rating.text = [NSString stringWithFormat:@"%@%@ %.1f",
        [@"★★★★★" substringToIndex:filled],
        [@"☆☆☆☆☆" substringToIndex:5 - filled], stars.doubleValue];
  }
  rating.font = [UIFont systemFontOfSize:12];
  rating.textColor = ColorFromOption(options, @"secondaryTextColor", 0xFF4B5563);
  Add(rating, details);
  if (!rating.hidden) view.starRatingView = rating;

  UILabel *advertiser = [[UILabel alloc] init];
  advertiser.text = nativeAd.advertiser ?: nativeAd.store;
  advertiser.font = [UIFont systemFontOfSize:12];
  advertiser.textColor = ColorFromOption(options, @"secondaryTextColor", 0xFF4B5563);
  advertiser.hidden = advertiser.text.length == 0;
  Add(advertiser, details);
  if (!advertiser.hidden) {
    if (nativeAd.advertiser.length > 0) {
      view.advertiserView = advertiser;
    } else {
      view.storeView = advertiser;
    }
  }

  UIButton *cta = [UIButton buttonWithType:UIButtonTypeCustom];
  [cta setTitle:nativeAd.callToAction forState:UIControlStateNormal];
  [cta setTitleColor:ColorFromOption(options, @"callToActionTextColor", 0xFFFFFFFF)
            forState:UIControlStateNormal];
  cta.backgroundColor = ColorFromOption(options, @"callToActionColor", 0xFF2563EB);
  cta.titleLabel.font = [UIFont boldSystemFontOfSize:17];
  cta.layer.cornerRadius = radius;
  cta.userInteractionEnabled = NO;
  cta.hidden = nativeAd.callToAction.length == 0;
  Add(cta, view);
  if (!cta.hidden) view.callToActionView = cta;
  view.ctaButton = cta;

  GADAdChoicesView *adChoices = [[GADAdChoicesView alloc] init];
  Add(adChoices, view);
  view.adChoicesView = adChoices;

  [NSLayoutConstraint activateConstraints:@[
    [media.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
    [media.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:12],
    [media.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12],
    [media.bottomAnchor constraintEqualToAnchor:details.topAnchor constant:-3],
    [media.heightAnchor constraintGreaterThanOrEqualToConstant:120],
    [details.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:12],
    [details.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12],
    [details.heightAnchor constraintEqualToConstant:95],
    [details.bottomAnchor constraintEqualToAnchor:cta.topAnchor constant:-3],
    [icon.leadingAnchor constraintEqualToAnchor:details.leadingAnchor],
    [icon.topAnchor constraintEqualToAnchor:details.topAnchor],
    [icon.widthAnchor constraintEqualToConstant:52],
    [icon.heightAnchor constraintEqualToConstant:52],
    [headline.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:5],
    [headline.trailingAnchor constraintEqualToAnchor:details.trailingAnchor constant:-24],
    [headline.topAnchor constraintEqualToAnchor:details.topAnchor],
    [body.leadingAnchor constraintEqualToAnchor:headline.leadingAnchor],
    [body.trailingAnchor constraintEqualToAnchor:details.trailingAnchor],
    [body.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:2],
    [body.bottomAnchor constraintLessThanOrEqualToAnchor:badge.topAnchor constant:-2],
    [badge.leadingAnchor constraintEqualToAnchor:headline.leadingAnchor],
    [badge.bottomAnchor constraintEqualToAnchor:details.bottomAnchor constant:-4],
    [badge.widthAnchor constraintGreaterThanOrEqualToConstant:15],
    [badge.heightAnchor constraintGreaterThanOrEqualToConstant:15],
    [rating.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:4],
    [rating.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
    [advertiser.leadingAnchor constraintEqualToAnchor:rating.trailingAnchor constant:4],
    [advertiser.trailingAnchor constraintLessThanOrEqualToAnchor:details.trailingAnchor],
    [advertiser.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
    [cta.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:12],
    [cta.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12],
    [cta.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-4],
    [cta.heightAnchor constraintEqualToConstant:50],
    [adChoices.topAnchor constraintEqualToAnchor:details.topAnchor],
    [adChoices.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-3],
    [adChoices.widthAnchor constraintEqualToConstant:24],
    [adChoices.heightAnchor constraintEqualToConstant:24],
  ]];

  view.nativeAd = nativeAd;
  return view;
}
@end

@interface FlutterAdmobKitPlugin ()
@property(nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, weak) FlutterEngine *engine;
@property(nonatomic, assign) BOOL ownsMediumFactory;
@property(nonatomic, assign) BOOL ownsBigFactory;
@end

@implementation FlutterAdmobKitPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterAdmobKitPlugin *plugin = [[FlutterAdmobKitPlugin alloc] init];
  plugin.registrar = registrar;
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_admob_kit/native_templates"
            binaryMessenger:registrar.messenger];
  [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if (![call.method isEqualToString:@"ensureRegistered"]) {
    result(FlutterMethodNotImplemented);
    return;
  }
  if (self.ownsMediumFactory && self.ownsBigFactory) {
    result(nil);
    return;
  }
  FlutterViewController *controller =
      [self.registrar.viewController isKindOfClass:FlutterViewController.class]
          ? (FlutterViewController *)self.registrar.viewController : nil;
  FlutterEngine *engine = controller.engine;
  if (!engine || ![engine valuePublishedByPlugin:@"FLTGoogleMobileAdsPlugin"]) {
    result([FlutterError errorWithCode:@"ads_plugin_missing"
                             message:@"Google Mobile Ads is unavailable on this engine."
                             details:nil]);
    return;
  }
  if (!self.ownsMediumFactory) {
    self.ownsMediumFactory = RegisterFactory(
        engine, kMediumFactoryId, [[AdMobKitMediumNativeFactory alloc] init]);
  }
  if (!self.ownsBigFactory) {
    self.ownsBigFactory = RegisterFactory(
        engine, @"flutter_admob_kit/big_native", [[AdMobKitBigNativeFactory alloc] init]);
  }
  if (self.ownsMediumFactory && self.ownsBigFactory) {
    self.engine = engine;
    result(nil);
  } else {
    result([FlutterError errorWithCode:@"factory_conflict"
                             message:@"AdMob Kit medium native factory is already registered."
                             details:nil]);
  }
}

- (void)dealloc {
  if (self.ownsMediumFactory && self.engine) {
    UnregisterFactory(self.engine, kMediumFactoryId);
  }
  if (self.ownsBigFactory && self.engine) {
    UnregisterFactory(self.engine, @"flutter_admob_kit/big_native");
  }
}
@end
