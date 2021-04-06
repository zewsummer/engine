// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/fuchsia/flutter/accessibility_bridge.h"

#include <zircon/status.h>
#include <zircon/types.h>

#include <deque>

#include "flutter/fml/logging.h"
#include "flutter/lib/ui/semantics/semantics_node.h"

namespace flutter_runner {
AccessibilityBridge::AccessibilityBridge(
    Delegate& delegate,
    const std::shared_ptr<sys::ServiceDirectory> services,
    fuchsia::ui::views::ViewRef view_ref)
    : delegate_(delegate), binding_(this) {
  services->Connect(fuchsia::accessibility::semantics::SemanticsManager::Name_,
                    fuchsia_semantics_manager_.NewRequest().TakeChannel());
  fuchsia_semantics_manager_.set_error_handler([](zx_status_t status) {
    FML_LOG(ERROR) << "Flutter cannot connect to SemanticsManager with status: "
                   << zx_status_get_string(status) << ".";
  });
  fidl::InterfaceHandle<fuchsia::accessibility::semantics::SemanticListener>
      listener_handle;
  binding_.Bind(listener_handle.NewRequest());
  fuchsia_semantics_manager_->RegisterViewForSemantics(
      std::move(view_ref), std::move(listener_handle), tree_ptr_.NewRequest());
}

bool AccessibilityBridge::GetSemanticsEnabled() const {
  return semantics_enabled_;
}

void AccessibilityBridge::SetSemanticsEnabled(bool enabled) {
  semantics_enabled_ = enabled;
  if (!enabled) {
    nodes_.clear();
  }
}

fuchsia::ui::gfx::BoundingBox AccessibilityBridge::GetNodeLocation(
    const flutter::SemanticsNode& node) const {
  fuchsia::ui::gfx::BoundingBox box;
  box.min.x = node.rect.fLeft;
  box.min.y = node.rect.fTop;
  box.min.z = static_cast<float>(node.elevation);
  box.max.x = node.rect.fRight;
  box.max.y = node.rect.fBottom;
  box.max.z = static_cast<float>(node.thickness);
  return box;
}

fuchsia::ui::gfx::mat4 AccessibilityBridge::GetNodeTransform(
    const flutter::SemanticsNode& node) const {
  return ConvertSkiaTransformToMat4(node.transform);
}

fuchsia::ui::gfx::mat4 AccessibilityBridge::ConvertSkiaTransformToMat4(
    const SkM44 transform) const {
  fuchsia::ui::gfx::mat4 value;
  float* m = value.matrix.data();
  transform.getColMajor(m);
  return value;
}

fuchsia::accessibility::semantics::Attributes
AccessibilityBridge::GetNodeAttributes(const flutter::SemanticsNode& node,
                                       size_t* added_size) const {
  fuchsia::accessibility::semantics::Attributes attributes;
  // TODO(MI4-2531): Don't truncate.
  if (node.label.size() > fuchsia::accessibility::semantics::MAX_LABEL_SIZE) {
    attributes.set_label(node.label.substr(
        0, fuchsia::accessibility::semantics::MAX_LABEL_SIZE));
    *added_size += fuchsia::accessibility::semantics::MAX_LABEL_SIZE;
  } else {
    attributes.set_label(node.label);
    *added_size += node.label.size();
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsKeyboardKey)) {
    attributes.set_is_keyboard_key(true);
  }

  return attributes;
}

fuchsia::accessibility::semantics::States AccessibilityBridge::GetNodeStates(
    const flutter::SemanticsNode& node,
    size_t* additional_size) const {
  fuchsia::accessibility::semantics::States states;
  (*additional_size) += sizeof(fuchsia::accessibility::semantics::States);

  // Set checked state.
  if (!node.HasFlag(flutter::SemanticsFlags::kHasCheckedState)) {
    states.set_checked_state(
        fuchsia::accessibility::semantics::CheckedState::NONE);
  } else {
    states.set_checked_state(
        node.HasFlag(flutter::SemanticsFlags::kIsChecked)
            ? fuchsia::accessibility::semantics::CheckedState::CHECKED
            : fuchsia::accessibility::semantics::CheckedState::UNCHECKED);
  }

  // Set selected state.
  states.set_selected(node.HasFlag(flutter::SemanticsFlags::kIsSelected));

  // Flutter's definition of a hidden node is different from Fuchsia, so it must
  // not be set here.

  // Set value.
  if (node.value.size() > fuchsia::accessibility::semantics::MAX_VALUE_SIZE) {
    states.set_value(node.value.substr(
        0, fuchsia::accessibility::semantics::MAX_VALUE_SIZE));
    (*additional_size) += fuchsia::accessibility::semantics::MAX_VALUE_SIZE;
  } else {
    states.set_value(node.value);
    (*additional_size) += node.value.size();
  }

  // Set toggled state.
  if (node.HasFlag(flutter::SemanticsFlags::kHasToggledState)) {
    states.set_toggled_state(
        node.HasFlag(flutter::SemanticsFlags::kIsToggled)
            ? fuchsia::accessibility::semantics::ToggledState::ON
            : fuchsia::accessibility::semantics::ToggledState::OFF);
  }

  return states;
}

std::vector<fuchsia::accessibility::semantics::Action>
AccessibilityBridge::GetNodeActions(const flutter::SemanticsNode& node,
                                    size_t* additional_size) const {
  std::vector<fuchsia::accessibility::semantics::Action> node_actions;

  if (node.HasAction(flutter::SemanticsAction::kTap)) {
    node_actions.push_back(fuchsia::accessibility::semantics::Action::DEFAULT);
  }
  if (node.HasAction(flutter::SemanticsAction::kLongPress)) {
    node_actions.push_back(
        fuchsia::accessibility::semantics::Action::SECONDARY);
  }
  if (node.HasAction(flutter::SemanticsAction::kShowOnScreen)) {
    node_actions.push_back(
        fuchsia::accessibility::semantics::Action::SHOW_ON_SCREEN);
  }
  if (node.HasAction(flutter::SemanticsAction::kIncrease)) {
    node_actions.push_back(
        fuchsia::accessibility::semantics::Action::INCREMENT);
  }
  if (node.HasAction(flutter::SemanticsAction::kDecrease)) {
    node_actions.push_back(
        fuchsia::accessibility::semantics::Action::DECREMENT);
  }

  *additional_size +=
      node_actions.size() * sizeof(fuchsia::accessibility::semantics::Action);
  return node_actions;
}

fuchsia::accessibility::semantics::Role AccessibilityBridge::GetNodeRole(
    const flutter::SemanticsNode& node) const {
  if (node.HasFlag(flutter::SemanticsFlags::kIsButton)) {
    return fuchsia::accessibility::semantics::Role::BUTTON;
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsTextField)) {
    return fuchsia::accessibility::semantics::Role::TEXT_FIELD;
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsLink)) {
    return fuchsia::accessibility::semantics::Role::LINK;
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsSlider)) {
    return fuchsia::accessibility::semantics::Role::SLIDER;
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsHeader)) {
    return fuchsia::accessibility::semantics::Role::HEADER;
  }
  if (node.HasFlag(flutter::SemanticsFlags::kIsImage)) {
    return fuchsia::accessibility::semantics::Role::IMAGE;
  }

  // If a flutter node supports the kIncrease or kDecrease actions, it can be
  // treated as a slider control by assistive technology. This is important
  // because users have special gestures to deal with sliders, and Fuchsia API
  // requires nodes that can receive this kind of action to be a slider control.
  if (node.HasAction(flutter::SemanticsAction::kIncrease) ||
      node.HasAction(flutter::SemanticsAction::kDecrease)) {
    return fuchsia::accessibility::semantics::Role::SLIDER;
  }

  // If a flutter node has a checked state, then we assume it is either a
  // checkbox or a radio button. We distinguish between checkboxes and
  // radio buttons based on membership in a mutually exclusive group.
  if (node.HasFlag(flutter::SemanticsFlags::kHasCheckedState)) {
    if (node.HasFlag(flutter::SemanticsFlags::kIsInMutuallyExclusiveGroup)) {
      return fuchsia::accessibility::semantics::Role::RADIO_BUTTON;
    } else {
      return fuchsia::accessibility::semantics::Role::CHECK_BOX;
    }
  }

  if (node.HasFlag(flutter::SemanticsFlags::kHasToggledState)) {
    return fuchsia::accessibility::semantics::Role::TOGGLE_SWITCH;
  }
  return fuchsia::accessibility::semantics::Role::UNKNOWN;
}

std::unordered_set<int32_t> AccessibilityBridge::GetDescendants(
    int32_t node_id) const {
  std::unordered_set<int32_t> descendents;
  std::deque<int32_t> to_process = {node_id};
  while (!to_process.empty()) {
    int32_t id = to_process.front();
    to_process.pop_front();
    descendents.emplace(id);

    auto it = nodes_.find(id);
    if (it != nodes_.end()) {
      const auto& node = it->second;
      for (const auto& child : node.children_in_hit_test_order) {
        if (descendents.find(child) == descendents.end()) {
          to_process.push_back(child);
        } else {
          // This indicates either a cycle or a child with multiple parents.
          // Flutter should never let this happen, but the engine API does not
          // explicitly forbid it right now.
          FML_LOG(ERROR) << "Semantics Node " << child
                         << " has already been listed as a child of another "
                            "node, ignoring for parent "
                         << id << ".";
        }
      }
    }
  }
  return descendents;
}

// The only known usage of a negative number for a node ID is in the embedder
// API as a sentinel value, which is not expected here. No valid producer of
// nodes should give us a negative ID.
static uint32_t FlutterIdToFuchsiaId(int32_t flutter_node_id) {
  FML_DCHECK(flutter_node_id >= 0)
      << "Unexpectedly received a negative semantics node ID.";
  return static_cast<uint32_t>(flutter_node_id);
}

void AccessibilityBridge::PruneUnreachableNodes() {
  const auto& reachable_nodes = GetDescendants(kRootNodeId);
  std::vector<uint32_t> nodes_to_remove;
  auto iter = nodes_.begin();
  while (iter != nodes_.end()) {
    int32_t id = iter->first;
    if (reachable_nodes.find(id) == reachable_nodes.end()) {
      // TODO(MI4-2531): This shouldn't be strictly necessary at this level.
      if (sizeof(nodes_to_remove) + (nodes_to_remove.size() * kNodeIdSize) >=
          kMaxMessageSize) {
        tree_ptr_->DeleteSemanticNodes(std::move(nodes_to_remove));
        nodes_to_remove.clear();
      }
      nodes_to_remove.push_back(FlutterIdToFuchsiaId(id));
      iter = nodes_.erase(iter);
    } else {
      iter++;
    }
  }
  if (!nodes_to_remove.empty()) {
    tree_ptr_->DeleteSemanticNodes(std::move(nodes_to_remove));
  }
}

// TODO(FIDL-718) - remove this, handle the error instead in something like
// set_error_handler.
static void PrintNodeSizeError(uint32_t node_id) {
  FML_LOG(ERROR) << "Semantics node with ID " << node_id
                 << " exceeded the maximum FIDL message size and may not "
                    "be delivered to the accessibility manager service.";
}

void AccessibilityBridge::AddSemanticsNodeUpdate(
    const flutter::SemanticsNodeUpdates update,
    float view_pixel_ratio) {
  if (update.empty()) {
    return;
  }
  FML_DCHECK(nodes_.find(kRootNodeId) != nodes_.end() ||
             update.find(kRootNodeId) != update.end())
      << "AccessibilityBridge received an update with out ever getting a root "
         "node.";

  std::vector<fuchsia::accessibility::semantics::Node> nodes;
  size_t current_size = 0;
  bool has_root_node_update = false;
  // TODO(MI4-2498): Actions, Roles, hit test children, additional
  // flags/states/attr

  // TODO(MI4-1478): Support for partial updates for nodes > 64kb
  // e.g. if a node has a long label or more than 64k children.
  for (const auto& value : update) {
    size_t this_node_size = sizeof(fuchsia::accessibility::semantics::Node);
    const auto& flutter_node = value.second;
    // We handle root update separately in GetRootNodeUpdate.
    // TODO(chunhtai): remove this special case after we remove the inverse
    // view pixel ratio transformation in scenic view.
    if (flutter_node.id == kRootNodeId) {
      root_flutter_semantics_node_ = flutter_node;
      has_root_node_update = true;
      continue;
    }
    // Store the nodes for later hit testing.
    nodes_[flutter_node.id] = {
        .id = flutter_node.id,
        .flags = flutter_node.flags,
        .is_focusable = IsFocusable(flutter_node),
        .rect = flutter_node.rect,
        .transform = flutter_node.transform,
        .children_in_hit_test_order = flutter_node.childrenInHitTestOrder,
    };
    fuchsia::accessibility::semantics::Node fuchsia_node;
    std::vector<uint32_t> child_ids;
    // Send the nodes in traversal order, so the manager can figure out
    // traversal.
    for (int32_t flutter_child_id : flutter_node.childrenInTraversalOrder) {
      child_ids.push_back(FlutterIdToFuchsiaId(flutter_child_id));
    }
    fuchsia_node.set_node_id(flutter_node.id)
        .set_role(GetNodeRole(flutter_node))
        .set_location(GetNodeLocation(flutter_node))
        .set_transform(GetNodeTransform(flutter_node))
        .set_attributes(GetNodeAttributes(flutter_node, &this_node_size))
        .set_states(GetNodeStates(flutter_node, &this_node_size))
        .set_actions(GetNodeActions(flutter_node, &this_node_size))
        .set_role(GetNodeRole(flutter_node))
        .set_child_ids(child_ids);
    this_node_size +=
        kNodeIdSize * flutter_node.childrenInTraversalOrder.size();

    // TODO(MI4-2531, FIDL-718): Remove this
    // This is defensive. If, despite our best efforts, we ended up with a node
    // that is larger than the max fidl size, we send no updates.
    if (this_node_size >= kMaxMessageSize) {
      PrintNodeSizeError(flutter_node.id);
      return;
    }
    current_size += this_node_size;

    // If we would exceed the max FIDL message size by appending this node,
    // we should delete/update/commit now.
    if (current_size >= kMaxMessageSize) {
      tree_ptr_->UpdateSemanticNodes(std::move(nodes));
      nodes.clear();
      current_size = this_node_size;
    }
    nodes.push_back(std::move(fuchsia_node));
  }

  if (current_size > kMaxMessageSize) {
    PrintNodeSizeError(nodes.back().node_id());
  }

  // Handles root node update.
  if (has_root_node_update || last_seen_view_pixel_ratio_ != view_pixel_ratio) {
    last_seen_view_pixel_ratio_ = view_pixel_ratio;
    size_t root_node_size;
    fuchsia::accessibility::semantics::Node root_update =
        GetRootNodeUpdate(root_node_size);
    // TODO(MI4-2531, FIDL-718): Remove this
    // This is defensive. If, despite our best efforts, we ended up with a node
    // that is larger than the max fidl size, we send no updates.
    if (root_node_size >= kMaxMessageSize) {
      PrintNodeSizeError(kRootNodeId);
      return;
    }
    current_size += root_node_size;
    // If we would exceed the max FIDL message size by appending this node,
    // we should delete/update/commit now.
    if (current_size >= kMaxMessageSize) {
      tree_ptr_->UpdateSemanticNodes(std::move(nodes));
      nodes.clear();
    }
    nodes.push_back(std::move(root_update));
  }

  PruneUnreachableNodes();
  UpdateScreenRects();

  tree_ptr_->UpdateSemanticNodes(std::move(nodes));
  // TODO(dnfield): Implement the callback here
  // https://bugs.fuchsia.dev/p/fuchsia/issues/detail?id=35718.
  tree_ptr_->CommitUpdates([]() {});
}

fuchsia::accessibility::semantics::Node AccessibilityBridge::GetRootNodeUpdate(
    size_t& node_size) {
  fuchsia::accessibility::semantics::Node root_fuchsia_node;
  std::vector<uint32_t> child_ids;
  node_size = sizeof(fuchsia::accessibility::semantics::Node);
  for (int32_t flutter_child_id :
       root_flutter_semantics_node_.childrenInTraversalOrder) {
    child_ids.push_back(FlutterIdToFuchsiaId(flutter_child_id));
  }
  // Applies the inverse view pixel ratio transformation to the root node.
  float inverse_view_pixel_ratio = 1.f / last_seen_view_pixel_ratio_;
  SkM44 inverse_view_pixel_ratio_transform;
  inverse_view_pixel_ratio_transform.setScale(inverse_view_pixel_ratio,
                                              inverse_view_pixel_ratio, 1.f);

  SkM44 result = root_flutter_semantics_node_.transform *
                 inverse_view_pixel_ratio_transform;
  nodes_[root_flutter_semantics_node_.id] = {
      .id = root_flutter_semantics_node_.id,
      .flags = root_flutter_semantics_node_.flags,
      .is_focusable = IsFocusable(root_flutter_semantics_node_),
      .rect = root_flutter_semantics_node_.rect,
      .transform = result,
      .children_in_hit_test_order =
          root_flutter_semantics_node_.childrenInHitTestOrder,
  };
  root_fuchsia_node.set_node_id(root_flutter_semantics_node_.id)
      .set_role(GetNodeRole(root_flutter_semantics_node_))
      .set_location(GetNodeLocation(root_flutter_semantics_node_))
      .set_transform(ConvertSkiaTransformToMat4(result))
      .set_attributes(
          GetNodeAttributes(root_flutter_semantics_node_, &node_size))
      .set_states(GetNodeStates(root_flutter_semantics_node_, &node_size))
      .set_actions(GetNodeActions(root_flutter_semantics_node_, &node_size))
      .set_child_ids(child_ids);
  node_size += kNodeIdSize *
               root_flutter_semantics_node_.childrenInTraversalOrder.size();
  return root_fuchsia_node;
}

void AccessibilityBridge::RequestAnnounce(const std::string message) {
  fuchsia::accessibility::semantics::SemanticEvent semantic_event;
  fuchsia::accessibility::semantics::AnnounceEvent announce_event;
  announce_event.set_message(message);
  semantic_event.set_announce(std::move(announce_event));

  tree_ptr_->SendSemanticEvent(std::move(semantic_event), []() {});
}

void AccessibilityBridge::UpdateScreenRects() {
  std::unordered_set<int32_t> visited_nodes;
  UpdateScreenRects(kRootNodeId, SkM44{}, &visited_nodes);
}

void AccessibilityBridge::UpdateScreenRects(
    int32_t node_id,
    SkM44 parent_transform,
    std::unordered_set<int32_t>* visited_nodes) {
  auto it = nodes_.find(node_id);
  if (it == nodes_.end()) {
    FML_LOG(ERROR) << "UpdateScreenRects called on unknown node";
    return;
  }
  auto& node = it->second;
  const auto& current_transform = parent_transform * node.transform;

  const auto& rect = node.rect;
  SkV4 dst[2] = {
      current_transform.map(rect.left(), rect.top(), 0, 1),
      current_transform.map(rect.right(), rect.bottom(), 0, 1),
  };
  node.screen_rect.setLTRB(dst[0].x, dst[0].y, dst[1].x, dst[1].y);
  node.screen_rect.sort();

  visited_nodes->emplace(node_id);

  for (uint32_t child_id : node.children_in_hit_test_order) {
    if (visited_nodes->find(child_id) == visited_nodes->end()) {
      UpdateScreenRects(child_id, current_transform, visited_nodes);
    }
  }
}

std::optional<flutter::SemanticsAction>
AccessibilityBridge::GetFlutterSemanticsAction(
    fuchsia::accessibility::semantics::Action fuchsia_action,
    uint32_t node_id) {
  switch (fuchsia_action) {
    // The default action associated with the element.
    case fuchsia::accessibility::semantics::Action::DEFAULT:
      return flutter::SemanticsAction::kTap;
    // The secondary action associated with the element. This may correspond to
    // a long press (touchscreens) or right click (mouse).
    case fuchsia::accessibility::semantics::Action::SECONDARY:
      return flutter::SemanticsAction::kLongPress;
    // Set (input/non-accessibility) focus on this element.
    case fuchsia::accessibility::semantics::Action::SET_FOCUS:
      FML_DLOG(WARNING)
          << "Unsupported action SET_FOCUS sent for accessibility node "
          << node_id;
      return {};
    // Set the element's value.
    case fuchsia::accessibility::semantics::Action::SET_VALUE:
      FML_DLOG(WARNING)
          << "Unsupported action SET_VALUE sent for accessibility node "
          << node_id;
      return {};
    // Scroll node to make it visible.
    case fuchsia::accessibility::semantics::Action::SHOW_ON_SCREEN:
      return flutter::SemanticsAction::kShowOnScreen;
    case fuchsia::accessibility::semantics::Action::INCREMENT:
      return flutter::SemanticsAction::kIncrease;
    case fuchsia::accessibility::semantics::Action::DECREMENT:
      return flutter::SemanticsAction::kDecrease;
    default:
      FML_DLOG(WARNING) << "Unexpected action "
                        << static_cast<int32_t>(fuchsia_action)
                        << " sent for accessibility node " << node_id;
      return {};
  }
}

// |fuchsia::accessibility::semantics::SemanticListener|
void AccessibilityBridge::OnAccessibilityActionRequested(
    uint32_t node_id,
    fuchsia::accessibility::semantics::Action action,
    fuchsia::accessibility::semantics::SemanticListener::
        OnAccessibilityActionRequestedCallback callback) {
  if (nodes_.find(node_id) == nodes_.end()) {
    FML_LOG(ERROR) << "Attempted to send accessibility action "
                   << static_cast<int32_t>(action)
                   << " to unknown node id: " << node_id;
    callback(false);
    return;
  }

  std::optional<flutter::SemanticsAction> flutter_action =
      GetFlutterSemanticsAction(action, node_id);
  if (!flutter_action.has_value()) {
    callback(false);
    return;
  }
  delegate_.DispatchSemanticsAction(static_cast<int32_t>(node_id),
                                    flutter_action.value());
  callback(true);
}

// |fuchsia::accessibility::semantics::SemanticListener|
void AccessibilityBridge::HitTest(
    fuchsia::math::PointF local_point,
    fuchsia::accessibility::semantics::SemanticListener::HitTestCallback
        callback) {
  auto hit_node_id = GetHitNode(kRootNodeId, local_point.x, local_point.y);
  FML_DCHECK(hit_node_id.has_value());
  fuchsia::accessibility::semantics::Hit hit;
  hit.set_node_id(hit_node_id.value_or(kRootNodeId));
  callback(std::move(hit));
}

std::optional<int32_t> AccessibilityBridge::GetHitNode(int32_t node_id,
                                                       float x,
                                                       float y) {
  auto it = nodes_.find(node_id);
  if (it == nodes_.end()) {
    FML_LOG(ERROR) << "Attempted to hit test unknown node id: " << node_id;
    return {};
  }
  auto const& node = it->second;
  if (node.flags &
          static_cast<int32_t>(flutter::SemanticsFlags::kIsHidden) ||  //
      !node.screen_rect.contains(x, y)) {
    return {};
  }
  for (int32_t child_id : node.children_in_hit_test_order) {
    auto candidate = GetHitNode(child_id, x, y);
    if (candidate) {
      return candidate;
    }
  }

  if (node.is_focusable) {
    return node_id;
  }

  return {};
}

bool AccessibilityBridge::IsFocusable(
    const flutter::SemanticsNode& node) const {
  if (node.HasFlag(flutter::SemanticsFlags::kScopesRoute)) {
    return false;
  }

  if (node.HasFlag(flutter::SemanticsFlags::kIsFocusable)) {
    return true;
  }

  // Always consider platform views focusable.
  if (node.IsPlatformViewNode()) {
    return true;
  }

  // Always conider actionable nodes focusable.
  if (node.actions != 0) {
    return true;
  }

  // Consider text nodes focusable.
  return !node.label.empty() || !node.value.empty() || !node.hint.empty();
}

// |fuchsia::accessibility::semantics::SemanticListener|
void AccessibilityBridge::OnSemanticsModeChanged(
    bool enabled,
    OnSemanticsModeChangedCallback callback) {
  delegate_.SetSemanticsEnabled(enabled);
}

}  // namespace flutter_runner
