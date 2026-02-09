# Extract unique parent_tool_use_ids and create a mapping to sequential numbers

# Helper function to extract parent_tool_use_id from various locations
def extract_parent_id:
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

# Collect all unique parent_tool_use_ids
reduce inputs as $line (
  {};
  ($line | extract_parent_id) as $id
  | if $id and ($id | type == "string") and ($id != "") then
      .[$id] = 1
    else
      .
    end
)
# Convert to numbered mapping
| keys
| sort
| to_entries
| map({key: .value, value: (.key + 1)})
| from_entries
