// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoldenTestManager.h"
#import <XCTest/XCTest.h>

@interface GoldenTestManager ()

@property(readwrite, strong, nonatomic) GoldenImage* goldenImage;

@end

@implementation GoldenTestManager

NSDictionary* launchArgsMap;

- (instancetype)initWithLaunchArg:(NSString*)launchArg {
  self = [super init];
  if (self) {
    // The launchArgsMap should match the one in the `PlatformVieGoldenTestManager`.
    static NSDictionary<NSString*, NSString*>* launchArgsMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      launchArgsMap = @{
        @"--platform-view" : @"platform_view",
        @"--platform-view-multiple" : @"platform_view_multiple",
        @"--platform-view-multiple-background-foreground" :
            @"platform_view_multiple_background_foreground",
        @"--platform-view-cliprect" : @"platform_view_cliprect",
        @"--platform-view-cliprrect" : @"platform_view_cliprrect",
        @"--platform-view-clippath" : @"platform_view_clippath",
        @"--platform-view-transform" : @"platform_view_transform",
        @"--platform-view-opacity" : @"platform_view_opacity",
        @"--platform-view-rotate" : @"platform_view_rotate",
        @"--non-full-screen-flutter-view-platform-view" :
            @"non_full_screen_flutter_view_platform_view",
        @"--bogus-font-text" : @"bogus_font_text",
      };
    });
    _identifier = launchArgsMap[launchArg];
    NSString* prefix = [NSString stringWithFormat:@"golden_%@_", _identifier];
    _goldenImage = [[GoldenImage alloc] initWithGoldenNamePrefix:prefix];
    _launchArg = launchArg;
  }
  return self;
}

- (void)checkGoldenForTest:(XCTestCase*)test {
  XCUIScreenshot* screenshot = [[XCUIScreen mainScreen] screenshot];
  if (!_goldenImage.image) {
    XCTAttachment* attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = [_goldenImage.goldenName stringByAppendingString:@"_new"];
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [test addAttachment:attachment];
    // Instead of XCTFail because that definition changed between Xcode 11 and 12 whereas this impl
    // is stable.
    _XCTPrimitiveFail(test,
                      @"This test will fail - no golden named %@ found. "
                      @"Follow the steps in the README to add a new golden.",
                      _goldenImage.goldenName);
  }

  if (![_goldenImage compareGoldenToImage:screenshot.image]) {
    XCTAttachment* screenshotAttachment = [XCTAttachment attachmentWithImage:screenshot.image];
    screenshotAttachment.name = [_goldenImage.goldenName stringByAppendingString:@"_actual"];
    screenshotAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [test addAttachment:screenshotAttachment];

    _XCTPrimitiveFail(test,
                      @"Goldens do not match. Follow the steps in the "
                      @"README to update golden named %@ if needed.",
                      _goldenImage.goldenName);
  }
}

@end
