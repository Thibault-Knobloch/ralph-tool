#!/usr/bin/env bash
# Display helpers for Ralph Loop - colors, animations, banners

# Initialize color support
USE_COLOR=0
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; then
  USE_COLOR=1
fi

# Color functions
if [[ $USE_COLOR -eq 1 ]] && [[ -t 1 ]]; then
  ESC="\033["
  RESET="${ESC}0m"
  BOLD="${ESC}1m"
  CYAN="${ESC}36m"
  YELLOW="${ESC}33m"
  GREEN="${ESC}32m"
  RED="${ESC}31m"
  MAG="${ESC}35m"
  BLUE="${ESC}34m"
  DIM="${ESC}2m"
else
  RESET=""
  BOLD=""
  CYAN=""
  YELLOW=""
  GREEN=""
  RED=""
  MAG=""
  BLUE=""
  DIM=""
fi

# Format duration in human-readable format
format_duration() {
  local total_seconds="$1"
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  if [[ $hours -gt 0 ]]; then
    printf "%dh %dm %ds" "$hours" "$minutes" "$seconds"
  elif [[ $minutes -gt 0 ]]; then
    printf "%dm %ds" "$minutes" "$seconds"
  else
    printf "%ds" "$seconds"
  fi
}

# Get a fun name (random selection)
get_ralph_name() {
  local num_names=${#RALPH_NAMES[@]}
  if [[ -z "${RANDOM:-}" ]]; then
    echo "${RALPH_NAMES[0]}"
  else
    local idx=$(( RANDOM % num_names ))
    echo "${RALPH_NAMES[$idx]}"
  fi
}

# Retro thinking animation
show_thinking() {
  local duration=${1:-2}
  local frames=("|" "/" "-" "\\")
  local frame_idx=0
  local start_time=$(date +%s)
  local end_time=$((start_time + duration))

  if [[ $USE_COLOR -eq 1 ]] && [[ -t 1 ]]; then
    while [[ $(date +%s) -lt $end_time ]]; do
      echo -ne "\r${DIM}${CYAN}${frames[$frame_idx]} THINKING...${RESET}"
      frame_idx=$(( (frame_idx + 1) % ${#frames[@]} ))
      sleep 0.2
    done
    echo -ne "\r${RESET}                              \r"
  else
    sleep "$duration"
  fi
}

# Display startup banner
show_startup_banner() {
  local ralph_name="$1"
  local max_iters="$2"
  local model="${3:-}"

  local content=" ${ralph_name} │ Max: ${max_iters} iterations"
  [[ -n "$model" ]] && content+=" │ Model: ${model}"
  content+=" │ Logs: ON "
  local content_len=${#content}

  local border=""
  local border_len=$((content_len - 6))
  for ((j=0; j<border_len; j++)); do
    border+="═"
  done

  printf "%b\n" "${BOLD}${CYAN}╔${border}╗${RESET}"
  printf "%b" "${BOLD}${CYAN}║${RESET} ${BOLD}${ralph_name}${RESET} ${DIM}│${RESET} ${BOLD}Max:${RESET} ${YELLOW}${max_iters}${RESET} ${DIM}iterations${RESET}"
  [[ -n "$model" ]] && printf "%b" " ${DIM}│${RESET} ${BOLD}Model:${RESET} ${MAG}${model}${RESET}"
  printf "%b\n" " ${DIM}│${RESET} ${BOLD}Logs:${RESET} ${GREEN}ON${RESET} ${BOLD}${CYAN}║${RESET}"
  printf "%b\n" "${BOLD}${CYAN}╚${border}╝${RESET}"
}

# Display iteration header
show_iteration_header() {
  local iter_name="$1"
  local iteration="$2"
  local max_iters="$3"
  local tasks_completed="$4"
  echo ""
  printf "%b\n" "${BOLD}${MAG}>>>${RESET} ${BOLD}${iter_name}${RESET} ${DIM}│${RESET} ${BOLD}Iteration ${YELLOW}${iteration}${RESET}${DIM}/${max_iters}${RESET} ${DIM}│${RESET} ${BOLD}Tasks:${RESET} ${GREEN}${tasks_completed}${RESET}"
}

# Display iteration cost summary
show_iteration_cost_summary() {
  local model="$1"
  local cost="$2"
  local input_tokens="$3"
  local output_tokens="$4"
  local cache_read="$5"
  local cache_write="$6"

  local line1="Model: ${model}"
  local line2="Cost: $(format_cost "$cost") │ Tokens: in=$(format_tokens "$input_tokens") │ out=$(format_tokens "$output_tokens")"
  local line3="Cache: read=$(format_tokens "$cache_read") │ write=$(format_tokens "$cache_write")"

  local len1=${#line1}
  local len2=${#line2}
  local len3=${#line3}

  local max_len=$len1
  [[ $len2 -gt $max_len ]] && max_len=$len2
  if [[ "$cache_read" -gt 0 ]] || [[ "$cache_write" -gt 0 ]]; then
    [[ $len3 -gt $max_len ]] && max_len=$len3
  fi

  max_len=$((max_len + 2))

  local top_border="┌─ Cost Summary "
  local remaining=$((max_len - 16))
  for ((i=0; i<remaining; i++)); do top_border+="─"; done
  top_border+="┐"

  local bottom_border="└"
  for ((i=0; i<max_len-2; i++)); do bottom_border+="─"; done
  bottom_border+="┘"

  echo ""
  printf "%b\n" "${DIM}${top_border}${RESET}"
  printf "%b\n" "${DIM}│${RESET} ${BOLD}Model:${RESET} ${CYAN}${model}${RESET}"
  printf "%b\n" "${DIM}│${RESET} ${BOLD}Cost:${RESET} ${GREEN}$(format_cost "$cost")${RESET} ${DIM}│${RESET} ${BOLD}Tokens:${RESET} ${BLUE}in=$(format_tokens "$input_tokens")${RESET} ${DIM}│${RESET} ${BLUE}out=$(format_tokens "$output_tokens")${RESET}"
  if [[ "$cache_read" -gt 0 ]] || [[ "$cache_write" -gt 0 ]]; then
    printf "%b\n" "${DIM}│${RESET} ${DIM}Cache:${RESET} ${DIM}read=$(format_tokens "$cache_read")${RESET} ${DIM}│${RESET} ${DIM}write=$(format_tokens "$cache_write")${RESET}"
  fi
  printf "%b\n" "${DIM}${bottom_border}${RESET}"
}

# Display completion message
show_completion_message() {
  local iterations_run="$1"
  local total_subagents="$2"
  local total_cost="$3"
  local total_input_tokens="$4"
  local total_output_tokens="$5"
  local total_cache_read="$6"
  local total_cache_write="$7"
  local elapsed_seconds="${8:-0}"

  local msg="ALL TASKS COMPLETE - MISSION ACCOMPLISHED"
  local msg_len=${#msg}
  local border_len=$((msg_len + 4))

  local top_border="╔"
  local bottom_border="╚"
  for ((i=0; i<border_len-2; i++)); do
    top_border+="═"
    bottom_border+="═"
  done
  top_border+="╗"
  bottom_border+="╝"

  echo ""
  printf "%b\n" "${BOLD}${GREEN}${top_border}${RESET}"
  printf "%b\n" "${BOLD}${GREEN}║${RESET} ${BOLD}${GREEN}${msg}${RESET} ${BOLD}${GREEN}║${RESET}"
  printf "%b\n" "${BOLD}${GREEN}${bottom_border}${RESET}"
  printf "%b\n" "${DIM}Iterations:${RESET} ${BOLD}${iterations_run}${RESET} ${DIM}│${RESET} ${DIM}Subagents:${RESET} ${BOLD}${BLUE}${total_subagents}${RESET}"
  echo ""
  show_total_cost_summary "$total_cost" "$total_input_tokens" "$total_output_tokens" "$total_cache_read" "$total_cache_write" "$elapsed_seconds"
}

# Display stuck message
show_stuck_message() {
  local iterations_run="$1"
  local total_cost="$2"
  local total_input_tokens="$3"
  local total_output_tokens="$4"
  local total_cache_read="$5"
  local total_cache_write="$6"
  local elapsed_seconds="${7:-0}"

  local msg="RALPH IS STUCK - MANUAL INTERVENTION REQUIRED"
  local msg_len=${#msg}
  local border_len=$((msg_len + 4))

  local top_border="╔"
  local bottom_border="╚"
  for ((i=0; i<border_len-2; i++)); do
    top_border+="═"
    bottom_border+="═"
  done
  top_border+="╗"
  bottom_border+="╝"

  echo ""
  printf "%b\n" "${BOLD}${RED}${top_border}${RESET}"
  printf "%b\n" "${BOLD}${RED}║${RESET} ${BOLD}${RED}${msg}${RESET} ${BOLD}${RED}║${RESET}"
  printf "%b\n" "${BOLD}${RED}${bottom_border}${RESET}"
  printf "%b\n" "${DIM}Iterations before stuck:${RESET} ${BOLD}${iterations_run}${RESET}"
  echo ""
  show_total_cost_summary "$total_cost" "$total_input_tokens" "$total_output_tokens" "$total_cache_read" "$total_cache_write" "$elapsed_seconds"
}

# Display max iterations reached message
show_max_iterations_message() {
  local max_iters="$1"
  local tasks_completed="$2"
  local total_subagents="$3"
  local total_cost="$4"
  local total_input_tokens="$5"
  local total_output_tokens="$6"
  local total_cache_read="$7"
  local total_cache_write="$8"
  local elapsed_seconds="${9:-0}"

  local msg="MAX ITERATIONS REACHED - RALPH NEEDS A BREAK"
  local msg_len=${#msg}
  local border_len=$((msg_len + 4))

  local top_border="╔"
  local bottom_border="╚"
  for ((i=0; i<border_len-2; i++)); do
    top_border+="═"
    bottom_border+="═"
  done
  top_border+="╗"
  bottom_border+="╝"

  echo ""
  printf "%b\n" "${BOLD}${YELLOW}${top_border}${RESET}"
  printf "%b\n" "${BOLD}${YELLOW}║${RESET} ${BOLD}${YELLOW}${msg}${RESET} ${BOLD}${YELLOW}║${RESET}"
  printf "%b\n" "${BOLD}${YELLOW}${bottom_border}${RESET}"
  printf "%b\n" "${DIM}Ran:${RESET} ${BOLD}${max_iters}${RESET} ${DIM}iterations${RESET} ${DIM}│${RESET} ${DIM}Tasks completed:${RESET} ${BOLD}${GREEN}${tasks_completed}${RESET} ${DIM}│${RESET} ${DIM}Subagents:${RESET} ${BOLD}${BLUE}${total_subagents}${RESET}"
  echo ""
  show_total_cost_summary "$total_cost" "$total_input_tokens" "$total_output_tokens" "$total_cache_read" "$total_cache_write" "$elapsed_seconds"
}

# Display total cost summary
show_total_cost_summary() {
  local total_cost="$1"
  local total_input_tokens="$2"
  local total_output_tokens="$3"
  local total_cache_read="$4"
  local total_cache_write="$5"
  local elapsed_seconds="${6:-0}"

  local title="Total Cost Summary"
  local line0="Total Time: $(format_duration "$elapsed_seconds")"
  local line1="Total Cost: $(format_cost "$total_cost")"
  local line2="Total Tokens: in=$(format_tokens "$total_input_tokens") │ out=$(format_tokens "$total_output_tokens")"
  local line3="Cache Tokens: read=$(format_tokens "$total_cache_read") │ write=$(format_tokens "$total_cache_write")"

  local title_len=${#title}
  local len0=${#line0}
  local len1=${#line1}
  local len2=${#line2}
  local len3=${#line3}

  local max_len=$title_len
  [[ $len0 -gt $max_len ]] && max_len=$len0
  [[ $len1 -gt $max_len ]] && max_len=$len1
  [[ $len2 -gt $max_len ]] && max_len=$len2
  if [[ "$total_cache_read" -gt 0 ]] || [[ "$total_cache_write" -gt 0 ]]; then
    [[ $len3 -gt $max_len ]] && max_len=$len3
  fi

  max_len=$((max_len + 4))

  local top_border="╔"
  local mid_border="╠"
  local bottom_border="╚"
  for ((i=0; i<max_len-2; i++)); do
    top_border+="═"
    mid_border+="═"
    bottom_border+="═"
  done
  top_border+="╗"
  mid_border+="╣"
  bottom_border+="╝"

  printf "%b\n" "${BOLD}${CYAN}${top_border}${RESET}"
  printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}${title}${RESET} ${BOLD}${CYAN}║${RESET}"
  printf "%b\n" "${BOLD}${CYAN}${mid_border}${RESET}"
  printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}Total Time:${RESET} ${YELLOW}$(format_duration "$elapsed_seconds")${RESET}"
  printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}Total Cost:${RESET} ${GREEN}$(format_cost "$total_cost")${RESET}"
  printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}Total Tokens:${RESET} ${BLUE}in=$(format_tokens "$total_input_tokens")${RESET} ${DIM}│${RESET} ${BLUE}out=$(format_tokens "$total_output_tokens")${RESET}"
  if [[ "$total_cache_read" -gt 0 ]] || [[ "$total_cache_write" -gt 0 ]]; then
    printf "%b\n" "${BOLD}${CYAN}║${RESET} ${DIM}Cache Tokens:${RESET} ${DIM}read=$(format_tokens "$total_cache_read")${RESET} ${DIM}│${RESET} ${DIM}write=$(format_tokens "$total_cache_write")${RESET}"
  fi
  printf "%b\n" "${BOLD}${CYAN}${bottom_border}${RESET}"
  echo ""
}
