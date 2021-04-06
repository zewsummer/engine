// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_WINDOWS_WINDOW_BINDING_HANDLER_DELEGATE_H_
#define FLUTTER_SHELL_PLATFORM_WINDOWS_WINDOW_BINDING_HANDLER_DELEGATE_H_

#include "flutter/shell/platform/common/geometry.h"
#include "flutter/shell/platform/embedder/embedder.h"

namespace flutter {

class WindowBindingHandlerDelegate {
 public:
  // Notifies delegate that backing window size has changed.
  // Typically called by currently configured WindowBindingHandler, this is
  // called on the platform thread.
  virtual void OnWindowSizeChanged(size_t width, size_t height) = 0;

  // Notifies delegate that backing window mouse has moved.
  // Typically called by currently configured WindowBindingHandler
  virtual void OnPointerMove(double x, double y) = 0;

  // Notifies delegate that backing window mouse pointer button has been
  // pressed. Typically called by currently configured WindowBindingHandler
  virtual void OnPointerDown(double x,
                             double y,
                             FlutterPointerMouseButtons button) = 0;

  // Notifies delegate that backing window mouse pointer button has been
  // released. Typically called by currently configured WindowBindingHandler
  virtual void OnPointerUp(double x,
                           double y,
                           FlutterPointerMouseButtons button) = 0;

  // Notifies delegate that backing window mouse pointer has left the window.
  // Typically called by currently configured WindowBindingHandler
  virtual void OnPointerLeave() = 0;

  // Notifies delegate that backing window has received text.
  // Typically called by currently configured WindowBindingHandler
  virtual void OnText(const std::u16string&) = 0;

  // TODO(clarkezone) refactor delegate to avoid needing win32 magic values in
  // UWP implementation https://github.com/flutter/flutter/issues/70202 Notifies
  // delegate that backing window size has received key press. Should return
  // true if the event was handled and should not be propagated. Typically
  // called by currently configured WindowBindingHandler.
  virtual bool OnKey(int key,
                     int scancode,
                     int action,
                     char32_t character,
                     bool extended,
                     bool was_down) = 0;

  // Notifies the delegate that IME composing mode has begun.
  //
  // Triggered when the user begins editing composing text using a multi-step
  // input method such as in CJK text input.
  virtual void OnComposeBegin() = 0;

  // Notifies the delegate that IME composing region have been committed.
  //
  // Triggered when the user commits the current composing text while using a
  // multi-step input method such as in CJK text input. Composing continues with
  // the next keypress.
  virtual void OnComposeCommit() = 0;

  // Notifies the delegate that IME composing mode has ended.
  //
  // Triggered when the user commits the composing text while using a multi-step
  // input method such as in CJK text input.
  virtual void OnComposeEnd() = 0;

  // Notifies the delegate that IME composing region contents have changed.
  //
  // Triggered when the user edits the composing text while using a multi-step
  // input method such as in CJK text input.
  virtual void OnComposeChange(const std::u16string& text, int cursor_pos) = 0;

  // Notifies delegate that backing window size has recevied scroll.
  // Typically called by currently configured WindowBindingHandler
  virtual void OnScroll(double x,
                        double y,
                        double delta_x,
                        double delta_y,
                        int scroll_offset_multiplier) = 0;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_WINDOWS_WINDOW_BINDING_HANDLER_DELEGATE_H_
