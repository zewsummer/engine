// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_UI_DART_STATE_H_
#define FLUTTER_LIB_UI_UI_DART_STATE_H_

#include <memory>
#include <string>
#include <utility>

#include "flutter/common/settings.h"
#include "flutter/common/task_runners.h"
#include "flutter/flow/skia_gpu_object.h"
#include "flutter/fml/build_config.h"
#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/synchronization/waitable_event.h"
#include "flutter/lib/ui/hint_freed_delegate.h"
#include "flutter/lib/ui/io_manager.h"
#include "flutter/lib/ui/isolate_name_server/isolate_name_server.h"
#include "flutter/lib/ui/painting/image_decoder.h"
#include "flutter/lib/ui/snapshot_delegate.h"
#include "flutter/lib/ui/volatile_path_tracker.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "third_party/skia/include/gpu/GrDirectContext.h"
#include "third_party/tonic/dart_microtask_queue.h"
#include "third_party/tonic/dart_persistent_value.h"
#include "third_party/tonic/dart_state.h"

namespace flutter {
class FontSelector;
class PlatformConfiguration;

class UIDartState : public tonic::DartState {
 public:
  static UIDartState* Current();

  Dart_Port main_port() const { return main_port_; }
  // Root isolate of the VM application
  bool IsRootIsolate() const { return is_root_isolate_; }
  static void ThrowIfUIOperationsProhibited();

  void SetDebugName(const std::string name);

  const std::string& debug_name() const { return debug_name_; }

  const std::string& logger_prefix() const { return logger_prefix_; }

  PlatformConfiguration* platform_configuration() const {
    return platform_configuration_.get();
  }

  const TaskRunners& GetTaskRunners() const;

  void ScheduleMicrotask(Dart_Handle handle);

  void FlushMicrotasksNow();

  fml::WeakPtr<IOManager> GetIOManager() const;

  fml::RefPtr<flutter::SkiaUnrefQueue> GetSkiaUnrefQueue() const;

  std::shared_ptr<VolatilePathTracker> GetVolatilePathTracker() const;

  fml::WeakPtr<SnapshotDelegate> GetSnapshotDelegate() const;

  fml::WeakPtr<HintFreedDelegate> GetHintFreedDelegate() const;

  fml::WeakPtr<GrDirectContext> GetResourceContext() const;

  fml::WeakPtr<ImageDecoder> GetImageDecoder() const;

  std::shared_ptr<IsolateNameServer> GetIsolateNameServer() const;

  tonic::DartErrorHandleType GetLastError();

  void ReportUnhandledException(const std::string& error,
                                const std::string& stack_trace);

  // Logs `print` messages from the application via an embedder-specified
  // logging mechanism.
  //
  // @param[in]  tag      A component name or tag that identifies the logging
  //                      application.
  // @param[in]  message  The message to be logged.
  void LogMessage(const std::string& tag, const std::string& message) const;

  bool enable_skparagraph() const;

  template <class T>
  static flutter::SkiaGPUObject<T> CreateGPUObject(sk_sp<T> object) {
    if (!object) {
      return {};
    }
    auto* state = UIDartState::Current();
    FML_DCHECK(state);
    auto queue = state->GetSkiaUnrefQueue();
    return {std::move(object), std::move(queue)};
  };

 protected:
  UIDartState(TaskRunners task_runners,
              TaskObserverAdd add_callback,
              TaskObserverRemove remove_callback,
              fml::WeakPtr<SnapshotDelegate> snapshot_delegate,
              fml::WeakPtr<HintFreedDelegate> hint_freed_delegate,
              fml::WeakPtr<IOManager> io_manager,
              fml::RefPtr<SkiaUnrefQueue> skia_unref_queue,
              fml::WeakPtr<ImageDecoder> image_decoder,
              std::string advisory_script_uri,
              std::string advisory_script_entrypoint,
              std::string logger_prefix,
              UnhandledExceptionCallback unhandled_exception_callback,
              LogMessageCallback log_message_callback,
              std::shared_ptr<IsolateNameServer> isolate_name_server,
              bool is_root_isolate_,
              std::shared_ptr<VolatilePathTracker> volatile_path_tracker,
              bool enable_skparagraph);

  ~UIDartState() override;

  void SetPlatformConfiguration(
      std::unique_ptr<PlatformConfiguration> platform_configuration);

  const std::string& GetAdvisoryScriptURI() const;

  const std::string& GetAdvisoryScriptEntrypoint() const;

 private:
  void DidSetIsolate() override;

  const TaskRunners task_runners_;
  const TaskObserverAdd add_callback_;
  const TaskObserverRemove remove_callback_;
  fml::WeakPtr<SnapshotDelegate> snapshot_delegate_;
  fml::WeakPtr<HintFreedDelegate> hint_freed_delegate_;
  fml::WeakPtr<IOManager> io_manager_;
  fml::RefPtr<SkiaUnrefQueue> skia_unref_queue_;
  fml::WeakPtr<ImageDecoder> image_decoder_;
  std::shared_ptr<VolatilePathTracker> volatile_path_tracker_;
  const std::string advisory_script_uri_;
  const std::string advisory_script_entrypoint_;
  const std::string logger_prefix_;
  Dart_Port main_port_ = ILLEGAL_PORT;
  const bool is_root_isolate_;
  std::string debug_name_;
  std::unique_ptr<PlatformConfiguration> platform_configuration_;
  tonic::DartMicrotaskQueue microtask_queue_;
  UnhandledExceptionCallback unhandled_exception_callback_;
  LogMessageCallback log_message_callback_;
  const std::shared_ptr<IsolateNameServer> isolate_name_server_;
  const bool enable_skparagraph_;

  void AddOrRemoveTaskObserver(bool add);
};

}  // namespace flutter

#endif  // FLUTTER_LIB_UI_UI_DART_STATE_H_
