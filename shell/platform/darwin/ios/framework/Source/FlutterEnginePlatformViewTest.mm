// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#define FML_USED_ON_EMBEDDER

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#include "flutter/fml/message_loop.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/ios/platform_view_ios.h"

FLUTTER_ASSERT_NOT_ARC

namespace flutter {
namespace {

class MockDelegate : public PlatformView::Delegate {
  void OnPlatformViewCreated(std::unique_ptr<Surface> surface) override {}
  void OnPlatformViewDestroyed() override {}
  void OnPlatformViewSetNextFrameCallback(const fml::closure& closure) override {}
  void OnPlatformViewSetViewportMetrics(const ViewportMetrics& metrics) override {}
  void OnPlatformViewDispatchPlatformMessage(fml::RefPtr<PlatformMessage> message) override {}
  void OnPlatformViewDispatchPointerDataPacket(std::unique_ptr<PointerDataPacket> packet) override {
  }
  void OnPlatformViewDispatchKeyDataPacket(std::unique_ptr<KeyDataPacket> packet,
                                           std::function<void(bool)> callback) override {}
  void OnPlatformViewDispatchSemanticsAction(int32_t id,
                                             SemanticsAction action,
                                             std::vector<uint8_t> args) override {}
  void OnPlatformViewSetSemanticsEnabled(bool enabled) override {}
  void OnPlatformViewSetAccessibilityFeatures(int32_t flags) override {}
  void OnPlatformViewRegisterTexture(std::shared_ptr<Texture> texture) override {}
  void OnPlatformViewUnregisterTexture(int64_t texture_id) override {}
  void OnPlatformViewMarkTextureFrameAvailable(int64_t texture_id) override {}

  void LoadDartDeferredLibrary(intptr_t loading_unit_id,
                               std::unique_ptr<const fml::Mapping> snapshot_data,
                               std::unique_ptr<const fml::Mapping> snapshot_instructions) override {
  }
  void LoadDartDeferredLibraryError(intptr_t loading_unit_id,
                                    const std::string error_message,
                                    bool transient) override {}
  void UpdateAssetResolverByType(std::unique_ptr<AssetResolver> updated_asset_resolver,
                                 AssetResolver::AssetResolverType type) override {}
};

}  // namespace
}  // namespace flutter

@interface FlutterEnginePlatformViewTest : XCTestCase
@end

@implementation FlutterEnginePlatformViewTest

- (void)setUp {
  fml::MessageLoop::EnsureInitializedForCurrentThread();
}

- (void)tearDown {
}

- (void)testCallsNotifyLowMemory {
  flutter::MockDelegate mock_delegate;
  auto thread_task_runner = fml::MessageLoop::GetCurrent().GetTaskRunner();
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/nil,
      /*task_runners=*/runners);

  id project = OCMClassMock([FlutterDartProject class]);
  FlutterEngine* engine = [[FlutterEngine alloc] initWithName:@"tester" project:project];
  XCTAssertNotNil(engine);
  id mockEngine = OCMPartialMock(engine);
  OCMStub([mockEngine notifyLowMemory]);
  OCMStub([mockEngine iosPlatformView]).andReturn(platform_view.get());

  [engine setViewController:nil];
  OCMVerify([mockEngine notifyLowMemory]);
  OCMReject([mockEngine notifyLowMemory]);

  XCTNSNotificationExpectation* memoryExpectation = [[XCTNSNotificationExpectation alloc]
      initWithName:UIApplicationDidReceiveMemoryWarningNotification];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
                    object:nil];
  [self waitForExpectations:@[ memoryExpectation ] timeout:5.0];
  OCMVerify([mockEngine notifyLowMemory]);
  OCMReject([mockEngine notifyLowMemory]);

  XCTNSNotificationExpectation* backgroundExpectation = [[XCTNSNotificationExpectation alloc]
      initWithName:UIApplicationDidEnterBackgroundNotification];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidEnterBackgroundNotification
                    object:nil];
  [self waitForExpectations:@[ backgroundExpectation ] timeout:5.0];

  OCMVerify([mockEngine notifyLowMemory]);
  [mockEngine stopMocking];
}

@end
