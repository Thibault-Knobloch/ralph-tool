#!/usr/bin/env bash
# Cost calculation helpers for Ralph loop

# Model pricing lookup (bash 3.2 compatible — no associative arrays)
# Returns: input_base cache_write_5m cache_write_1h cache_hit output (per million tokens)
get_model_pricing() {
  case "$1" in
    claude-opus-4-5)    echo "5.0 6.25 10.0 0.50 25.0" ;;
    claude-opus-4-1)    echo "15.0 18.75 30.0 1.50 75.0" ;;
    claude-opus-4)      echo "15.0 18.75 30.0 1.50 75.0" ;;
    claude-sonnet-4-5)  echo "3.0 3.75 6.0 0.30 15.0" ;;
    claude-sonnet-3-5)  echo "3.0 3.75 6.0 0.30 15.0" ;;
    claude-haiku-3)     echo "0.25 0.30 1.25 0.03 1.25" ;;
    *)                  echo "3.0 3.75 6.0 0.30 15.0" ;;  # default to sonnet pricing
  esac
}

# Function to normalize model name for pricing lookup
normalize_model_name() {
  local model="$1"
  echo "$model" | tr '[:upper:]' '[:lower:]' | sed 's/\./-/g' | sed 's/-[0-9]\{8\}$//' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g'
}

# Function to calculate cost based on model and usage
calculate_cost() {
  local model="$1"
  local input_tokens="$2"
  local output_tokens="$3"
  local cache_read_tokens="$4"
  local cache_write_tokens="$5"

  local normalized_model
  normalized_model=$(normalize_model_name "$model")
  local pricing
  pricing=$(get_model_pricing "$normalized_model")

  local input_price cache_write_price cache_hit_price output_price
  input_price=$(echo "$pricing" | awk '{print $1}')
  cache_write_price=$(echo "$pricing" | awk '{print $2}')
  cache_hit_price=$(echo "$pricing" | awk '{print $4}')
  output_price=$(echo "$pricing" | awk '{print $5}')

  local input_cost output_cost cache_read_cost cache_write_cost total_cost
  input_cost=$(echo "scale=6; ($input_tokens * $input_price) / 1000000" | bc)
  output_cost=$(echo "scale=6; ($output_tokens * $output_price) / 1000000" | bc)
  cache_read_cost=$(echo "scale=6; ($cache_read_tokens * $cache_hit_price) / 1000000" | bc)
  cache_write_cost=$(echo "scale=6; ($cache_write_tokens * $cache_write_price) / 1000000" | bc)

  total_cost=$(echo "scale=6; $input_cost + $output_cost + $cache_read_cost + $cache_write_cost" | bc)

  echo "$total_cost"
}

# Function to format token count (add commas)
format_tokens() {
  local tokens="$1"
  if [[ -z "$tokens" ]] || [[ "$tokens" == "null" ]] || [[ "$tokens" == "0" ]]; then
    echo "0"
  else
    echo "$tokens" | awk '{printf "%'"'"'d\n", $1}'
  fi
}

# Function to format cost
format_cost() {
  local cost="$1"
  if [[ -z "$cost" ]] || [[ "$cost" == "null" ]] || [[ "$cost" == "0" ]]; then
    echo "\$0.00"
  else
    local formatted=$(printf "%.4f" "$cost" | sed 's/0*$//' | sed 's/\.$//')
    printf "\$%s\n" "$formatted"
  fi
}
