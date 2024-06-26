// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the Apache 2.0 License.

#include "js/global_class_ids.h"

#include "js/core/context.h"
#include "js/globals/ccf/kv.h"

namespace ccf::js
{
  JSClassID kv_class_id = 0;
  JSClassID kv_historical_class_id = 0;
  JSClassID kv_map_handle_class_id = 0;
  JSClassID body_class_id = 0;
  JSClassID node_class_id = 0;
  JSClassID network_class_id = 0;
  JSClassID rpc_class_id = 0;
  JSClassID host_class_id = 0;
  JSClassID consensus_class_id = 0;
  JSClassID historical_class_id = 0;
  JSClassID historical_state_class_id = 0;

  JSClassDef kv_class_def = {};
  JSClassExoticMethods kv_exotic_methods = {};
  JSClassDef kv_historical_class_def = {};
  JSClassExoticMethods kv_historical_exotic_methods = {};
  JSClassDef kv_map_handle_class_def = {};
  JSClassDef kv_historical_map_handle_class_def = {};
  JSClassDef body_class_def = {};
  JSClassDef node_class_def = {};
  JSClassDef network_class_def = {};
  JSClassDef rpc_class_def = {};
  JSClassDef host_class_def = {};
  JSClassDef consensus_class_def = {};
  JSClassDef historical_class_def = {};
  JSClassDef historical_state_class_def = {};

  void register_class_ids()
  {
    JS_NewClassID(&kv_class_id);
    kv_exotic_methods.get_own_property = js_kv_lookup;
    kv_class_def.class_name = "KV Tables";
    kv_class_def.exotic = &kv_exotic_methods;

    JS_NewClassID(&kv_historical_class_id);
    kv_historical_exotic_methods.get_own_property = js_historical_kv_lookup;
    kv_historical_class_def.class_name = "Read-only Historical KV Tables";
    kv_historical_class_def.exotic = &kv_historical_exotic_methods;

    JS_NewClassID(&kv_map_handle_class_id);
    kv_map_handle_class_def.class_name = "KV Map Handle";

    JS_NewClassID(&body_class_id);
    body_class_def.class_name = "Current Request Body";

    JS_NewClassID(&node_class_id);
    node_class_def.class_name = "Node";

    JS_NewClassID(&network_class_id);
    network_class_def.class_name = "Network";

    JS_NewClassID(&rpc_class_id);
    rpc_class_def.class_name = "RPC";

    JS_NewClassID(&host_class_id);
    host_class_def.class_name = "Host";

    JS_NewClassID(&consensus_class_id);
    consensus_class_def.class_name = "Consensus";

    JS_NewClassID(&historical_class_id);
    historical_class_def.class_name = "Historical";

    JS_NewClassID(&historical_state_class_id);
    historical_state_class_def.class_name = "HistoricalState";
  }
}
