#!/usr/bin/env bash
# Iteration processing helpers for Ralph Loop

# Process iteration cost and usage data
process_iteration_cost() {
  local raw_log="$1"
  local default_model="$2"

  local iter_model=$(jq -r 'select(.type=="system" and .subtype=="init") | .model // empty' "$raw_log" 2>/dev/null | head -1)
  local iter_result=$(jq -c 'select(.type=="result")' "$raw_log" 2>/dev/null | head -1)

  if [[ -z "$iter_result" ]] || [[ "$iter_result" == "null" ]]; then
    return 1
  fi

  local iter_cost=$(echo "$iter_result" | jq -r '.total_cost_usd // 0' 2>/dev/null || echo "0")
  local iter_input_tokens=$(echo "$iter_result" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo "0")
  local iter_output_tokens=$(echo "$iter_result" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo "0")
  local iter_cache_read=$(echo "$iter_result" | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null || echo "0")
  local iter_cache_write=$(echo "$iter_result" | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null || echo "0")

  iter_cost=${iter_cost:-0}
  iter_input_tokens=${iter_input_tokens:-0}
  iter_output_tokens=${iter_output_tokens:-0}
  iter_cache_read=${iter_cache_read:-0}
  iter_cache_write=${iter_cache_write:-0}

  if [[ -z "$iter_model" ]] || [[ "$iter_model" == "null" ]]; then
    iter_model="$default_model"
  fi

  echo "$iter_model $iter_cost $iter_input_tokens $iter_output_tokens $iter_cache_read $iter_cache_write"
}

# Process subagent mapping from raw log
process_subagent_mapping() {
  local raw_log="$1"
  local subagent_map_file="$2"
  local extract_subagent_map="$3"

  if jq -n -f "$extract_subagent_map" < "$raw_log" > "$subagent_map_file" 2>/dev/null; then
    local subagent_count=$(jq 'length' "$subagent_map_file" 2>/dev/null || echo "0")
    echo "$subagent_count"
  else
    echo "0"
  fi
}

# Re-format pretty log with subagent numbers
reformat_pretty_log() {
  local raw_log="$1"
  local pretty_log="$2"
  local subagent_map_file="$3"
  local jq_filter="$4"
  local max_chars="$5"
  local use_color="$6"
  local max_lines="$7"

  if [[ -f "$subagent_map_file" ]] && [[ -s "$subagent_map_file" ]]; then
    local subagent_map_json=$(cat "$subagent_map_file")
    jq -R -r . "$raw_log" | jq -rj -f "$jq_filter" \
      --argjson MAX "$max_chars" \
      --argjson COLOR "$use_color" \
      --argjson MAX_LINES "$max_lines" \
      --argjson SUBAGENT_MAP "$subagent_map_json" \
      > "${pretty_log}.numbered" 2>/dev/null && \
    mv "${pretty_log}.numbered" "$pretty_log" 2>/dev/null || true
  fi
}
