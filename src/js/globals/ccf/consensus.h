// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the Apache 2.0 License.
#pragma once

#include "ccf/base_endpoint_registry.h"
#include "js/checks.h"
#include "js/core/context.h"
#include "js/global_class_ids.h"

#include <quickjs/quickjs.h>

namespace ccf::js
{
  namespace
  {
    static JSValue js_consensus_get_last_committed_txid(
      JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv)
    {
      if (argc != 0)
      {
        return JS_ThrowTypeError(
          ctx, "Passed %d arguments, but expected 0", argc);
      }

      auto endpoint_registry = static_cast<ccf::BaseEndpointRegistry*>(
        JS_GetOpaque(this_val, consensus_class_id));
      if (endpoint_registry == nullptr)
      {
        return JS_ThrowInternalError(
          ctx, "Failed to get endpoint registry object");
      }

      ccf::View view;
      ccf::SeqNo seqno;
      auto result = endpoint_registry->get_last_committed_txid_v1(view, seqno);
      if (result != ccf::ApiResult::OK)
      {
        return JS_ThrowInternalError(
          ctx,
          "Failed to get last committed txid: %s",
          ccf::api_result_to_str(result));
      }

      js::core::Context& jsctx = *(js::core::Context*)JS_GetContextOpaque(ctx);

      auto obj = jsctx.new_obj();
      JS_CHECK_EXC(obj);
      JS_CHECK_SET(obj.set_int64("view", view));
      JS_CHECK_SET(obj.set_int64("seqno", seqno));
      return obj.take();
    }

    static JSValue js_consensus_get_status_for_txid(
      JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv)
    {
      if (argc != 2)
        return JS_ThrowTypeError(
          ctx, "Passed %d arguments, but expected 2", argc);

      int64_t view;
      int64_t seqno;
      if (JS_ToInt64(ctx, &view, argv[0]) < 0)
      {
        return ccf::js::core::constants::Exception;
      }
      if (JS_ToInt64(ctx, &seqno, argv[1]) < 0)
      {
        return ccf::js::core::constants::Exception;
      }
      if (view < 0 || seqno < 0)
      {
        return JS_ThrowRangeError(
          ctx, "Invalid view or seqno: cannot be negative");
      }

      auto endpoint_registry = static_cast<ccf::BaseEndpointRegistry*>(
        JS_GetOpaque(this_val, consensus_class_id));
      if (endpoint_registry == nullptr)
      {
        return JS_ThrowInternalError(
          ctx, "Failed to get endpoint registry object");
      }

      ccf::TxStatus status;
      auto result =
        endpoint_registry->get_status_for_txid_v1(view, seqno, status);
      if (result != ccf::ApiResult::OK)
      {
        return JS_ThrowInternalError(
          ctx,
          "Failed to get status for txid: %s",
          ccf::api_result_to_str(result));
      }
      auto status_str = ccf::tx_status_to_str(status);
      return JS_NewString(ctx, status_str);
    }

    static JSValue js_consensus_get_view_for_seqno(
      JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv)
    {
      if (argc != 1)
        return JS_ThrowTypeError(
          ctx, "Passed %d arguments, but expected 1", argc);

      int64_t seqno;
      if (JS_ToInt64(ctx, &seqno, argv[0]) < 0)
      {
        return ccf::js::core::constants::Exception;
      }
      if (seqno < 0)
      {
        return JS_ThrowRangeError(ctx, "Invalid seqno: cannot be negative");
      }

      auto endpoint_registry = static_cast<ccf::BaseEndpointRegistry*>(
        JS_GetOpaque(this_val, consensus_class_id));
      if (endpoint_registry == nullptr)
      {
        return JS_ThrowInternalError(
          ctx, "Failed to get endpoint registry object");
      }

      ccf::View view;
      auto result = endpoint_registry->get_view_for_seqno_v1(seqno, view);
      if (result == ccf::ApiResult::NotFound)
      {
        return ccf::js::core::constants::Null;
      }
      if (result != ccf::ApiResult::OK)
      {
        return JS_ThrowInternalError(
          ctx,
          "Failed to get view for seqno: %s",
          ccf::api_result_to_str(result));
      }

      return JS_NewFloat64(ctx, view);
    }
  }

  JSValue create_global_consensus_object(
    ccf::BaseEndpointRegistry* endpoint_registry, JSContext* ctx)
  {
    auto consensus = JS_NewObjectClass(ctx, consensus_class_id);
    JS_SetOpaque(consensus, endpoint_registry);

    JS_SetPropertyStr(
      ctx,
      consensus,
      "getLastCommittedTxId",
      JS_NewCFunction(
        ctx, js_consensus_get_last_committed_txid, "getLastCommittedTxId", 0));
    JS_SetPropertyStr(
      ctx,
      consensus,
      "getStatusForTxId",
      JS_NewCFunction(
        ctx, js_consensus_get_status_for_txid, "getStatusForTxId", 2));
    JS_SetPropertyStr(
      ctx,
      consensus,
      "getViewForSeqno",
      JS_NewCFunction(
        ctx, js_consensus_get_view_for_seqno, "getViewForSeqno", 1));

    return consensus;
  }
}
