// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_COMMON_TEST_ACCESSIBILITY_BRIDGE_H_
#define FLUTTER_SHELL_PLATFORM_COMMON_TEST_ACCESSIBILITY_BRIDGE_H_

#include "accessibility_bridge.h"

namespace flutter {

class TestAccessibilityBridgeDelegate
    : public AccessibilityBridge::AccessibilityBridgeDelegate {
 public:
  TestAccessibilityBridgeDelegate() = default;

  void OnAccessibilityEvent(
      ui::AXEventGenerator::TargetedEvent targeted_event) override;
  void DispatchAccessibilityAction(AccessibilityNodeId target,
                                   FlutterSemanticsAction action,
                                   const std::vector<uint8_t>& data) override;
  std::unique_ptr<FlutterPlatformNodeDelegate>
  CreateFlutterPlatformNodeDelegate();

  std::vector<ui::AXEventGenerator::TargetedEvent> accessibilitiy_events;
  std::vector<FlutterSemanticsAction> performed_actions;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_COMMON_TEST_ACCESSIBILITY_BRIDGE_H_
