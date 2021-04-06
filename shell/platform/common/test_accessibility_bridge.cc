// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "test_accessibility_bridge.h"

namespace flutter {

std::unique_ptr<FlutterPlatformNodeDelegate>
TestAccessibilityBridgeDelegate::CreateFlutterPlatformNodeDelegate() {
  return std::make_unique<FlutterPlatformNodeDelegate>();
};

void TestAccessibilityBridgeDelegate::OnAccessibilityEvent(
    ui::AXEventGenerator::TargetedEvent targeted_event) {
  accessibilitiy_events.push_back(targeted_event);
}

void TestAccessibilityBridgeDelegate::DispatchAccessibilityAction(
    AccessibilityNodeId target,
    FlutterSemanticsAction action,
    const std::vector<uint8_t>& data) {
  performed_actions.push_back(action);
}

}  // namespace flutter
