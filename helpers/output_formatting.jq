# Output formatting filter for ralph loop
# This file contains the jq filter for formatting Claude's JSON stream output

# Color escape codes
def esc(s): "\u001b[" + s + "m";
def reset:  if $COLOR==1 then esc("0")    else "" end;
def bold:   if $COLOR==1 then esc("1")    else "" end;
def cyan:   if $COLOR==1 then esc("36")   else "" end;
def yellow: if $COLOR==1 then esc("33")   else "" end;
def green:  if $COLOR==1 then esc("32")   else "" end;
def red:    if $COLOR==1 then esc("31")   else "" end;
def mag:    if $COLOR==1 then esc("35")   else "" end;
def dim:    if $COLOR==1 then esc("2")    else "" end;
def blue:   if $COLOR==1 then esc("34")   else "" end;

def hr: "────────────────────────────────────────────────────────────\n";

# Extract file path from tool input
def extract_file_path(input):
  if input.file_path? then input.file_path
  elif input.target_file? then input.target_file
  elif input.file? then input.file
  elif input.path? then input.path
  else null
  end;

# Check if command is ralph status
def is_ralph_status_cmd(cmd):
  (cmd | test("ralph\\s+status"));

# Extract minimal tool info for display (main agent)
def tool_info_minimal(input; name):
  if input.command? then
    (input.command|tostring) as $cmd
    | if is_ralph_status_cmd($cmd) then
        "BASH: " + $cmd
      else
        ($cmd | split("\n")) as $lines
        | if ($lines | length) > 4 then
            (($lines[0:4] | join("\n")) + "\n...")
          else
            $cmd
          end
        | "BASH: " + .
      end
  else
    (extract_file_path(input) // "") as $file
    | if $file != null and $file != "" then
        name + " " + $file
      else
        name
      end
  end;

# Extract tool info for subagents (more detailed)
def tool_info_subagent(input; name):
  if input.command? then
    (input.command|tostring) as $cmd
    | if is_ralph_status_cmd($cmd) then
        "BASH: " + $cmd
      else
        ($cmd | split("\n")) as $lines
        | if ($lines | length) > 4 then
            (($lines[0:4] | join("\n")) + "\n...")
          else
            $cmd
          end
        | "BASH: " + .
      end
  else
    (extract_file_path(input) // "") as $file
    | if $file != null and $file != "" then
        name + " → " + $file
      elif input.pattern? then
        name + " → pattern: " + (input.pattern|tostring)
      elif input.query? then
        name + " → query: " + (input.query|tostring)
      elif input.glob_pattern? then
        name + " → glob: " + (input.glob_pattern|tostring)
      else
        name
      end
  end;

# Extract parent_tool_use_id from various possible locations
def get_parent_id:
  if .parent_tool_use_id? and (.parent_tool_use_id != "") then
    .parent_tool_use_id
  elif .event?.parent_tool_use_id? and (.event.parent_tool_use_id != "") then
    .event.parent_tool_use_id
  elif .event?.content_block?.parent_tool_use_id? and (.event.content_block.parent_tool_use_id != "") then
    .event.content_block.parent_tool_use_id
  elif .message?.parent_tool_use_id? and (.message.parent_tool_use_id != "") then
    .message.parent_tool_use_id
  else
    null
  end;

# Check if this is a subagent task
def is_subagent: (get_parent_id != null);

# Get subagent number from mapping
def get_subagent_num:
  if is_subagent and ($SUBAGENT_MAP | type == "object") then
    get_parent_id as $id
    | if $id and $SUBAGENT_MAP[$id] then
        $SUBAGENT_MAP[$id]
      else
        null
      end
  else
    null
  end;

# Subagent name list
def subagent_names:
  ["BOB", "BEN", "TIBO", "ALONSO", "JULIAN", "JULIA", "MELISSA", "TALIA", "CENK", "VIKRAM", "ANKIT", "JULIETTE", "ANICA", "CHUBS", "STILGARD", "GERARD"];

# Get short ID suffix from parent_tool_use_id
def get_short_id:
  get_parent_id as $id
  | if $id and ($id | length) > 4 then
      $id[-4:]
    elif $id then
      $id
    else
      null
    end;

# Get deterministic name from parent_tool_use_id
def get_subagent_name:
  get_parent_id as $id
  | if $id then
      ($id | explode | add) as $hash
      | subagent_names[$hash % (subagent_names | length)]
    else
      null
    end;

# Format subagent label
def subagent_label:
  if is_subagent then
    get_subagent_num as $num
    | if $num then
        blue + bold + "[SUBAGENT #\($num)] " + reset
      else
        get_subagent_name as $name
        | get_short_id as $short
        | if $name and $short then
            blue + bold + "[\($name) @\($short)] " + reset
          elif $name then
            blue + bold + "[\($name)] " + reset
          elif $short then
            blue + bold + "[SUBAGENT @\($short)] " + reset
          else
            blue + bold + "[SUBAGENT] " + reset
          end
      end
  else
    ""
  end;

# Format tool result content
def format_tool_result(content; is_ralph_status):
  if content | type == "string" then
    if is_ralph_status then
      (content | split("\n") | .[0:4] | join("\n"))
    else
      (content | split("\n") | .[0]) as $first
      | if ($first|length) > 100 then
          $first[0:100] + "..."
        else
          $first
        end
    end
  else
    "[OK]"
  end;

# Format duration from milliseconds
def format_duration(ms):
  if ms == null or ms == 0 then
    "0s"
  else
    (ms / 1000 | floor) as $total_secs
    | ($total_secs / 3600 | floor) as $hours
    | (($total_secs % 3600) / 60 | floor) as $minutes
    | ($total_secs % 60) as $seconds
    | (if $hours > 0 then "\($hours)h " else "" end) +
      (if $minutes > 0 then "\($minutes)m " else "" end) +
      "\($seconds)s"
  end;

# Format cost to 2 decimal places
def format_cost(cost):
  if cost == null then
    "$0.00"
  else
    (cost * 100 | round / 100) as $rounded
    | ($rounded | tostring) as $str
    | if ($str | contains(".")) then
        ($str | split(".")) as $parts
        | "$" + $parts[0] + "." + (($parts[1] // "") | .[0:2] | if length < 2 then . + ("0" * (2 - length)) else . end)
      else
        "$" + $str + ".00"
      end
  end;

# Main filter
try
  if .type=="system" and .subtype=="init" then
    bold + cyan + "[MODEL] " + reset + bold + (.model // "unknown") + reset + "\n"

  elif .type=="stream_event"
    and .event.type=="content_block_start"
    and .event.content_block.type=="text"
    and .event.index == 0 then
    "\n" + dim + ">>>    " + reset

  elif .type=="stream_event"
    and .event.type=="content_block_start"
    and .event.content_block.type=="tool_use" then
    subagent_label +
    mag + bold + "TOOL: " + reset + mag +
    (if (is_subagent) then
      tool_info_subagent(.event.content_block.input; .event.content_block.name)
    else
      tool_info_minimal(.event.content_block.input; .event.content_block.name)
    end) +
    reset + "\n"

  elif .type=="assistant"
    and (.message | type == "object")
    and (.message.content | type == "array")
    and (.message.content[]?.type=="tool_use") then
    subagent_label +
    (.message.content[]
      | select(.type=="tool_use")
      | if (.input.command? != null) then
          yellow + bold + "BASH: " + reset + yellow +
          (.input.command|tostring) + reset + "\n"
        elif (is_subagent) then
          yellow + bold + "TOOL: " + reset + yellow +
          tool_info_subagent(.input; .name) + reset + "\n"
        elif (.input.file_path? or .input.target_file? or .input.file?) then
          yellow + bold + "TOOL: " + reset + yellow +
          tool_info_minimal(.input; .name) + reset + "\n"
        else empty end)

  elif .type=="user"
    and (.message | type == "object")
    and (.message.content | type == "array")
    and (.message.content[0]?.type=="tool_result") then
    (if (is_subagent) then
      empty
    else
      (.message.content[0].content | type == "string" and test("╔|╗|╚|╝|║|═|Feature:|Task:|Status:")) as $is_ralph_status
      | cyan + bold + "RESULT:" + reset +
      (if $is_ralph_status then
        "\n" + format_tool_result(.message.content[0].content; $is_ralph_status)
      elif (.message.content[0].content | type == "string") then
        " " + format_tool_result(.message.content[0].content; false)
      else
        " [OK]"
      end) + "\n"
    end)

  elif .type=="stream_event"
    and .event.type=="content_block_delta"
    and .event.delta.type=="text_delta"
    and .event.index == 0 then
    .event.delta.text | gsub("\n"; "\n       ")

  elif .type=="stream_event"
    and .event.type=="content_block_stop"
    and .event.index == 0 then
    "\n\n"

  elif .type=="stream_event" and .event.type=="message_stop" then
    empty

  elif .type=="result" then
    hr +
    green + bold + "[COMPLETE] ITERATION COMPLETED" + reset + "\n" +
    "  Turns:    \(.num_turns)  |  Duration:  \(format_duration(.duration_ms))  |  Cost:  \(format_cost(.total_cost_usd))\n" +
    dim +
    "  Tokens:   in=\(.usage.input_tokens)  out=\(.usage.output_tokens)  cache_read=\(.usage.cache_read_input_tokens)  cache_write=\(.usage.cache_creation_input_tokens)\n" +
    reset +
    hr

  else
    empty
  end
catch empty
