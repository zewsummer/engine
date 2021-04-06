// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/AccessibilityBridgeMacDelegate.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterPlatformNodeDelegateMac.h"
#include "flutter/shell/platform/embedder/embedder.h"

namespace flutter {

inline constexpr int32_t kRootNode = 0;

// Native mac notifications fired. These notifications are not publicly documented.
// We have to define them ourselves.
static NSString* const AccessibilityLoadCompleteNotification = @"AXLoadComplete";
static NSString* const AccessibilityInvalidStatusChangedNotification = @"AXInvalidStatusChanged";
static NSString* const AccessibilityLiveRegionCreatedNotification = @"AXLiveRegionCreated";
static NSString* const AccessibilityLiveRegionChangedNotification = @"AXLiveRegionChanged";
static NSString* const AccessibilityExpandedChanged = @"AXExpandedChanged";
static NSString* const AccessibilityMenuItemSelectedNotification = @"AXMenuItemSelected";

AccessibilityBridgeMacDelegate::AccessibilityBridgeMacDelegate(__weak FlutterEngine* flutter_engine)
    : flutter_engine_(flutter_engine) {}

void AccessibilityBridgeMacDelegate::OnAccessibilityEvent(
    ui::AXEventGenerator::TargetedEvent targeted_event) {
  ui::AXNode* ax_node = targeted_event.node;
  std::vector<AccessibilityBridgeMacDelegate::NSAccessibilityEvent> events =
      MacOSEventsFromAXEvent(targeted_event.event_params.event, *ax_node);
  for (AccessibilityBridgeMacDelegate::NSAccessibilityEvent event : events) {
    if (event.user_info != nil) {
      DispatchMacOSNotificationWithUserInfo(event.target, event.name, event.user_info);
    } else {
      DispatchMacOSNotification(event.target, event.name);
    }
  }
}

std::vector<AccessibilityBridgeMacDelegate::NSAccessibilityEvent>
AccessibilityBridgeMacDelegate::MacOSEventsFromAXEvent(ui::AXEventGenerator::Event event_type,
                                                       const ui::AXNode& ax_node) const {
  // Gets the native_node with the node_id.
  NSCAssert(flutter_engine_, @"Flutter engine should not be deallocated");
  auto bridge = flutter_engine_.accessibilityBridge.lock();
  NSCAssert(bridge, @"Accessibility bridge in flutter engine must not be null.");
  auto platform_node_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(ax_node.id()).lock();
  NSCAssert(platform_node_delegate, @"Event target must exist in accessibility bridge.");
  auto mac_platform_node_delegate =
      std::static_pointer_cast<FlutterPlatformNodeDelegateMac>(platform_node_delegate);
  gfx::NativeViewAccessible native_node = mac_platform_node_delegate->GetNativeViewAccessible();

  std::vector<AccessibilityBridgeMacDelegate::NSAccessibilityEvent> events;
  switch (event_type) {
    case ui::AXEventGenerator::Event::ACTIVE_DESCENDANT_CHANGED:
      if (ax_node.data().role == ax::mojom::Role::kTree) {
        events.push_back({
            .name = NSAccessibilitySelectedRowsChangedNotification,
            .target = native_node,
            .user_info = nil,
        });
      } else if (ax_node.data().role == ax::mojom::Role::kTextFieldWithComboBox) {
        // Even though the selected item in the combo box has changed, we don't
        // want to post a focus change because this will take the focus out of
        // the combo box where the user might be typing.
        events.push_back({
            .name = NSAccessibilitySelectedChildrenChangedNotification,
            .target = native_node,
            .user_info = nil,
        });
      }
      // In all other cases we should post
      // |NSAccessibilityFocusedUIElementChangedNotification|, but this is
      // handled elsewhere.
      break;
    case ui::AXEventGenerator::Event::LOAD_COMPLETE:
      events.push_back({
          .name = AccessibilityLoadCompleteNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::INVALID_STATUS_CHANGED:
      events.push_back({
          .name = AccessibilityInvalidStatusChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::SELECTED_CHILDREN_CHANGED:
      if (ui::IsTableLike(ax_node.data().role)) {
        events.push_back({
            .name = NSAccessibilitySelectedRowsChangedNotification,
            .target = native_node,
            .user_info = nil,
        });
      } else {
        // VoiceOver does not read anything if selection changes on the
        // currently focused object, and the focus did not move. Fire a
        // selection change if the focus did not change.
        NSAccessibilityElement* native_accessibility_node = (NSAccessibilityElement*)native_node;
        if (native_accessibility_node.accessibilityFocusedUIElement &&
            ax_node.data().HasState(ax::mojom::State::kMultiselectable) &&
            !HasPendingEvent(ui::AXEventGenerator::Event::ACTIVE_DESCENDANT_CHANGED) &&
            !HasPendingEvent(ui::AXEventGenerator::Event::FOCUS_CHANGED)) {
          // Don't fire selected children change, it will sometimes override
          // announcement of current focus.
          break;
        }
        events.push_back({
            .name = NSAccessibilitySelectedChildrenChangedNotification,
            .target = native_node,
            .user_info = nil,
        });
      }
      break;
    case ui::AXEventGenerator::Event::DOCUMENT_SELECTION_CHANGED: {
      // This event always fires at root
      events.push_back({
          .name = NSAccessibilitySelectedTextChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      // WebKit fires a notification both on the focused object and the page
      // root.
      const ui::AXTreeData& tree_data = bridge->GetAXTreeData();
      int32_t focus = tree_data.focus_id;
      if (focus == ui::AXNode::kInvalidAXID || focus != tree_data.sel_anchor_object_id) {
        break;  // Just fire a notification on the root.
      }
      auto focus_node = bridge->GetFlutterPlatformNodeDelegateFromID(focus).lock();
      if (!focus_node) {
        break;  // Just fire a notification on the root.
      }
      events.push_back({
          .name = NSAccessibilitySelectedTextChangedNotification,
          .target = focus_node->GetNativeViewAccessible(),
          .user_info = nil,
      });
      break;
    }
    case ui::AXEventGenerator::Event::CHECKED_STATE_CHANGED:
      events.push_back({
          .name = NSAccessibilityValueChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::VALUE_CHANGED:
      events.push_back({
          .name = NSAccessibilityValueChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      if (@available(macOS 10.11, *)) {
        if (ax_node.data().HasState(ax::mojom::State::kEditable)) {
          events.push_back({
              .name = NSAccessibilityValueChangedNotification,
              .target = bridge->GetFlutterPlatformNodeDelegateFromID(kRootNode)
                            .lock()
                            ->GetNativeViewAccessible(),
              .user_info = nil,
          });
        }
      }
      break;
    case ui::AXEventGenerator::Event::LIVE_REGION_CREATED:
      events.push_back({
          .name = AccessibilityLiveRegionCreatedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::ALERT: {
      events.push_back({
          .name = AccessibilityLiveRegionCreatedNotification,
          .target = native_node,
          .user_info = nil,
      });
      // Voiceover requires a live region changed notification to actually
      // announce the live region.
      auto live_region_events =
          MacOSEventsFromAXEvent(ui::AXEventGenerator::Event::LIVE_REGION_CHANGED, ax_node);
      events.insert(events.end(), live_region_events.begin(), live_region_events.end());
      break;
    }
    case ui::AXEventGenerator::Event::LIVE_REGION_CHANGED: {
      if (@available(macOS 10.14, *)) {
        // Do nothing on macOS >=10.14.
      } else {
        // Uses the announcement API to get around OS <= 10.13 VoiceOver bug
        // where it stops announcing live regions after the first time focus
        // leaves any content area.
        // Unfortunately this produces an annoying boing sound with each live
        // announcement, but the alternative is almost no live region support.
        NSString* announcement = [[NSString alloc]
            initWithUTF8String:mac_platform_node_delegate->GetLiveRegionText().c_str()];
        NSDictionary* notification_info = @{
          NSAccessibilityAnnouncementKey : announcement,
          NSAccessibilityPriorityKey : @(NSAccessibilityPriorityLow)
        };
        // Triggers VoiceOver speech and show on Braille display, if available.
        // The Braille will only appear for a few seconds, and then will be replaced
        // with the previous announcement.
        events.push_back({
            .name = NSAccessibilityAnnouncementRequestedNotification,
            .target = [NSApp mainWindow],
            .user_info = notification_info,
        });
        break;
      }
      // Uses native VoiceOver support for live regions.
      events.push_back({
          .name = AccessibilityLiveRegionChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    }
    case ui::AXEventGenerator::Event::ROW_COUNT_CHANGED:
      events.push_back({
          .name = NSAccessibilityRowCountChangedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::EXPANDED: {
      NSAccessibilityNotificationName mac_notification;
      if (ax_node.data().role == ax::mojom::Role::kRow ||
          ax_node.data().role == ax::mojom::Role::kTreeItem) {
        mac_notification = NSAccessibilityRowExpandedNotification;
      } else {
        mac_notification = AccessibilityExpandedChanged;
      }
      events.push_back({
          .name = mac_notification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    }
    case ui::AXEventGenerator::Event::COLLAPSED: {
      NSAccessibilityNotificationName mac_notification;
      if (ax_node.data().role == ax::mojom::Role::kRow ||
          ax_node.data().role == ax::mojom::Role::kTreeItem) {
        mac_notification = NSAccessibilityRowCollapsedNotification;
      } else {
        mac_notification = AccessibilityExpandedChanged;
      }
      events.push_back({
          .name = mac_notification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    }
    case ui::AXEventGenerator::Event::MENU_ITEM_SELECTED:
      events.push_back({
          .name = AccessibilityMenuItemSelectedNotification,
          .target = native_node,
          .user_info = nil,
      });
      break;
    case ui::AXEventGenerator::Event::CHILDREN_CHANGED: {
      // NSAccessibilityCreatedNotification seems to be the only way to let
      // Voiceover pick up layout changes.
      events.push_back({
          .name = NSAccessibilityCreatedNotification,
          .target = [NSApp mainWindow],
          .user_info = nil,
      });
      break;
    }
    case ui::AXEventGenerator::Event::SUBTREE_CREATED:
    case ui::AXEventGenerator::Event::ACCESS_KEY_CHANGED:
    case ui::AXEventGenerator::Event::ATK_TEXT_OBJECT_ATTRIBUTE_CHANGED:
    case ui::AXEventGenerator::Event::ATOMIC_CHANGED:
    case ui::AXEventGenerator::Event::AUTO_COMPLETE_CHANGED:
    case ui::AXEventGenerator::Event::BUSY_CHANGED:
    case ui::AXEventGenerator::Event::CONTROLS_CHANGED:
    case ui::AXEventGenerator::Event::CLASS_NAME_CHANGED:
    case ui::AXEventGenerator::Event::DESCRIBED_BY_CHANGED:
    case ui::AXEventGenerator::Event::DESCRIPTION_CHANGED:
    case ui::AXEventGenerator::Event::DOCUMENT_TITLE_CHANGED:
    case ui::AXEventGenerator::Event::DROPEFFECT_CHANGED:
    case ui::AXEventGenerator::Event::ENABLED_CHANGED:
    case ui::AXEventGenerator::Event::FOCUS_CHANGED:
    case ui::AXEventGenerator::Event::FLOW_FROM_CHANGED:
    case ui::AXEventGenerator::Event::FLOW_TO_CHANGED:
    case ui::AXEventGenerator::Event::GRABBED_CHANGED:
    case ui::AXEventGenerator::Event::HASPOPUP_CHANGED:
    case ui::AXEventGenerator::Event::HIERARCHICAL_LEVEL_CHANGED:
    case ui::AXEventGenerator::Event::IGNORED_CHANGED:
    case ui::AXEventGenerator::Event::IMAGE_ANNOTATION_CHANGED:
    case ui::AXEventGenerator::Event::KEY_SHORTCUTS_CHANGED:
    case ui::AXEventGenerator::Event::LABELED_BY_CHANGED:
    case ui::AXEventGenerator::Event::LANGUAGE_CHANGED:
    case ui::AXEventGenerator::Event::LAYOUT_INVALIDATED:
    case ui::AXEventGenerator::Event::LIVE_REGION_NODE_CHANGED:
    case ui::AXEventGenerator::Event::LIVE_RELEVANT_CHANGED:
    case ui::AXEventGenerator::Event::LIVE_STATUS_CHANGED:
    case ui::AXEventGenerator::Event::LOAD_START:
    case ui::AXEventGenerator::Event::MULTILINE_STATE_CHANGED:
    case ui::AXEventGenerator::Event::MULTISELECTABLE_STATE_CHANGED:
    case ui::AXEventGenerator::Event::NAME_CHANGED:
    case ui::AXEventGenerator::Event::OBJECT_ATTRIBUTE_CHANGED:
    case ui::AXEventGenerator::Event::OTHER_ATTRIBUTE_CHANGED:
    case ui::AXEventGenerator::Event::PLACEHOLDER_CHANGED:
    case ui::AXEventGenerator::Event::PORTAL_ACTIVATED:
    case ui::AXEventGenerator::Event::POSITION_IN_SET_CHANGED:
    case ui::AXEventGenerator::Event::READONLY_CHANGED:
    case ui::AXEventGenerator::Event::RELATED_NODE_CHANGED:
    case ui::AXEventGenerator::Event::REQUIRED_STATE_CHANGED:
    case ui::AXEventGenerator::Event::ROLE_CHANGED:
    case ui::AXEventGenerator::Event::SCROLL_HORIZONTAL_POSITION_CHANGED:
    case ui::AXEventGenerator::Event::SCROLL_VERTICAL_POSITION_CHANGED:
    case ui::AXEventGenerator::Event::SELECTED_CHANGED:
    case ui::AXEventGenerator::Event::SET_SIZE_CHANGED:
    case ui::AXEventGenerator::Event::SORT_CHANGED:
    case ui::AXEventGenerator::Event::STATE_CHANGED:
    case ui::AXEventGenerator::Event::TEXT_ATTRIBUTE_CHANGED:
    case ui::AXEventGenerator::Event::VALUE_MAX_CHANGED:
    case ui::AXEventGenerator::Event::VALUE_MIN_CHANGED:
    case ui::AXEventGenerator::Event::VALUE_STEP_CHANGED:
    case ui::AXEventGenerator::Event::WIN_IACCESSIBLE_STATE_CHANGED:
      // There are some notifications that aren't meaningful on Mac.
      // It's okay to skip them.
      break;
  }
  return events;
}

void AccessibilityBridgeMacDelegate::DispatchAccessibilityAction(ui::AXNode::AXID target,
                                                                 FlutterSemanticsAction action,
                                                                 const std::vector<uint8_t>& data) {
  NSCAssert(flutter_engine_, @"Flutter engine should not be deallocated");
  [flutter_engine_ dispatchSemanticsAction:action toTarget:target withData:data];
}

std::unique_ptr<FlutterPlatformNodeDelegate>
AccessibilityBridgeMacDelegate::CreateFlutterPlatformNodeDelegate() {
  return std::make_unique<FlutterPlatformNodeDelegateMac>(flutter_engine_);
}

// Private method
void AccessibilityBridgeMacDelegate::DispatchMacOSNotification(
    gfx::NativeViewAccessible native_node,
    NSAccessibilityNotificationName mac_notification) {
  NSCAssert(mac_notification, @"The notification must not be null.");
  NSCAssert(native_node, @"The notification target must not be null.");
  NSAccessibilityPostNotification(native_node, mac_notification);
}

void AccessibilityBridgeMacDelegate::DispatchMacOSNotificationWithUserInfo(
    gfx::NativeViewAccessible native_node,
    NSAccessibilityNotificationName mac_notification,
    NSDictionary* user_info) {
  NSCAssert(mac_notification, @"The notification must not be null.");
  NSCAssert(native_node, @"The notification target must not be null.");
  NSCAssert(user_info, @"The notification data must not be null.");
  NSAccessibilityPostNotificationWithUserInfo(native_node, mac_notification, user_info);
}

bool AccessibilityBridgeMacDelegate::HasPendingEvent(ui::AXEventGenerator::Event event) const {
  NSCAssert(flutter_engine_, @"Flutter engine should not be deallocated");
  auto bridge = flutter_engine_.accessibilityBridge.lock();
  NSCAssert(bridge, @"Accessibility bridge in flutter engine must not be null.");
  std::vector<ui::AXEventGenerator::TargetedEvent> pending_events = bridge->GetPendingEvents();
  for (const auto& pending_event : bridge->GetPendingEvents()) {
    if (pending_event.event_params.event == event) {
      return true;
    }
  }
  return false;
}

}  // namespace flutter
