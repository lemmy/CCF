// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the Apache 2.0 License.
#pragma once

#include "js/extensions/extension_interface.h"

namespace ccf::js::extensions
{
  // Implements Math.random in an enclave-compatible way
  class MathRandomExtension : public ExtensionInterface
  {
  public:
    MathRandomExtension() {}

    void install(js::core::Context& ctx) override;
  };
}
