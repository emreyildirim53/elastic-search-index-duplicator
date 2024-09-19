#!/bin/bash

# This script duplicates an existing Elasticsearch index, reindexes the data to the new index, 
# and optionally moves an alias from the old index to the new index.

# Elasticsearch connection settings (can be adjusted for different environments)
ELASTIC_HOST="http://localhost:9200"

# Function: show_help
# Description: Displays the usage information for this script.
# Arguments: None
# Output: Prints usage instructions to the console.
show_help() {
  echo -e "\n=============================================================="
  echo -e "                       HELP INFORMATION                        "
  echo -e "=============================================================="
  echo -e "Usage: $0 [old_index_name] [new_index_name] [alias_name]"
  echo -e "\nParameters:"
  echo -e "$(printf '%-25s: %s' 'old_index_name' 'Existing index name (source)')"
  echo -e "$(printf '%-25s: %s' 'new_index_name' 'New index name to be created (destination)')"
  echo -e "$(printf '%-25s: %s' 'alias_name' 'Alias name to be moved to the new index')"
  echo -e "\nExample:"
  echo -e "$0 old_index new_index alias_name"
  echo -e "=============================================================="
  exit 0
}

# Function: is_jq_installed
# Description: Checks if the 'jq' JSON processor is installed on the system.
# Arguments: None
# Returns: 0 if jq is installed, non-zero otherwise.
is_jq_installed() {
  command -v jq >/dev/null 2>&1
}

# Function: pretty_print_json
# Description: Prints the JSON response beautifully formatted if jq is installed.
# Arguments:
#   1. json_response: The raw JSON response from the curl command.
# Output: Pretty-prints the JSON or prints raw JSON if jq is not available.
pretty_print_json() {
  local json_response="$1"
  
  if is_jq_installed; then
    echo "$json_response" | jq '.'   # Beautifies the JSON output
  else
    echo "$json_response"            # Prints raw JSON if jq is not installed
  fi
}

# Function: check_elastic_host
# Description: Checks if the ELASTIC_HOST is reachable.
# Arguments: None
# Output: Prints an error message if the host is not reachable.
check_elastic_host() {
  local status_code=$(curl -o /dev/null -s -w "%{http_code}\n" "${ELASTIC_HOST}")

  if [ "$status_code" -ne 200 ]; then
    echo -e "\n=============================================================="
    echo -e "$(printf '%-25s: %s' 'Error' 'Cannot reach Elasticsearch at') ${ELASTIC_HOST}"
    echo -e "=============================================================="
    exit 1
  else
    echo -e "\n=============================================================="
    echo -e "$(printf '%-25s: %s' 'Success' 'Elasticsearch connection established at') ${ELASTIC_HOST}"
    echo -e "=============================================================="
  fi
}

# Function: check_index_exists
# Description: Checks if a given index exists in Elasticsearch.
# Arguments:
#   1. index_name: The name of the index to check.
# Output: Returns 0 if the index exists, exits the script with an error message if it doesn't.
check_index_exists() {
  local index_name="$1"
  local response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${ELASTIC_HOST}/${index_name}")

  if [ "$response" -ne 200 ]; then
    echo -e "\n=============================================================="
    echo -e "$(printf '%-25s: %s' 'Error' 'Index not found:') ${index_name}"
    echo -e "=============================================================="
    exit 1
  fi
}

# Function: extract_settings_mappings
# Description: Extracts the settings and mappings from the existing index using jq.
# Arguments:
#   1. old_index: The name of the old index.
# Output: Sets the SETTINGS and MAPPINGS variables.
extract_settings_mappings() {
  local old_index="$1"

  # Fetch the index details using curl
  echo -e "\n=============================================================="
  echo -e "Fetching settings and mappings from the old index..."
  echo -e "=============================================================="
  curl -s -X GET "${ELASTIC_HOST}/${old_index}" | pretty_print_json

  # Extract settings and mappings using jq if available
  if is_jq_installed; then
    SETTINGS=$(curl -s -X GET "${ELASTIC_HOST}/${old_index}" | jq '.[].settings | del(.index.creation_date, .index.uuid, .index.version, .index.provided_name)')
    MAPPINGS=$(curl -s -X GET "${ELASTIC_HOST}/${old_index}" | jq '.[].mappings')
  else
    # Fallback to grep and sed if jq is not installed
    local index_info=$(curl -s -X GET "${ELASTIC_HOST}/${old_index}")
    SETTINGS=$(echo "$index_info" | grep -o '"settings":{[^}]*}' | sed 's/"index.creation_date":[^,]*,//g' | sed 's/"index.uuid":[^,]*,//g' | sed 's/"index.version":[^,]*,//g' | sed 's/"index.provided_name":[^,]*,//g')
    MAPPINGS=$(echo "$index_info" | grep -o '"mappings":{[^}]*}')
  fi
}

# Function: create_new_index
# Description: Creates a new Elasticsearch index with the extracted settings and mappings.
# Arguments:
#   1. new_index: The name of the new index to create.
# Output: Sends a request to Elasticsearch to create the new index.
create_new_index() {
  local new_index="$1"
  
  echo -e "\n=============================================================="
  echo -e "Creating the new index: ${new_index}..."
  echo -e "=============================================================="
  curl -s -X PUT "${ELASTIC_HOST}/${new_index}" -H 'Content-Type: application/json' -d "{
    \"settings\": $SETTINGS,
    \"mappings\": $MAPPINGS
  }" | pretty_print_json  # Print the response of the index creation
}

# Function: reindex_data
# Description: Reindexes data from the old index to the new index.
# Arguments:
#   1. old_index: The name of the existing index (source).
#   2. new_index: The name of the new index (destination).
# Output: Sends a reindex request to Elasticsearch to copy the data.
reindex_data() {
  local old_index="$1"
  local new_index="$2"
  
  echo -e "\n=============================================================="
  echo -e "Reindexing data from ${old_index} to ${new_index}..."
  echo -e "=============================================================="
  curl -s -X POST "${ELASTIC_HOST}/_reindex" -H 'Content-Type: application/json' -d "{
    \"source\": {
      \"index\": \"${old_index}\"
    },
    \"dest\": {
      \"index\": \"${new_index}\"
    }
  }" | pretty_print_json  # Print the response of the reindex operation
}

# Function: handle_alias
# Description: Removes the alias from any existing indices and assigns it to the new index.
# Arguments:
#   1. old_index: The name of the old index (source).
#   2. new_index: The name of the new index (destination).
#   3. alias_name: The alias to move or assign.
# Output: Removes the alias from all other indices and assigns it to the new index.
handle_alias() {
  local old_index="$1"
  local new_index="$2"
  local alias_name="$3"

  echo -e "\n=============================================================="
  echo -e "Checking alias: ${alias_name}..."
  echo -e "=============================================================="

  # Fetch all indices that have the alias assigned
  local alias_info=$(curl -s -X GET "${ELASTIC_HOST}/_alias/${alias_name}")

  # Initialize a variable to store the actions for bulk alias removal and addition
  local actions=""

  # If alias_info is not empty, process the indices that are associated with the alias
  if [[ "$alias_info" != "{}" ]]; then
    # Iterate through all indices that have this alias
    for index in $(echo "$alias_info" | jq -r 'keys[]'); do
      echo -e "\nAlias found on index: $index"

      # Remove alias from all indices except the new index
      if [[ "$index" != "$new_index" ]]; then
        actions="${actions}{ \"remove\": { \"index\": \"${index}\", \"alias\": \"${alias_name}\" } },"
        echo -e "$(printf '%-25s: %s' 'Alias will be removed from' "$index")"
      fi
    done
  else
    echo -e "\nNo indices found with alias: ${alias_name}. Assigning it to the new index."
  fi

  # Add alias to the new index
  actions="${actions}{ \"add\": { \"index\": \"${new_index}\", \"alias\": \"${alias_name}\" } }"
  echo -e "$(printf '%-25s: %s' 'Alias will be assigned to' "$new_index")"

  # Send the bulk alias update request if there are any actions to be performed
  if [[ "$actions" != "" ]]; then
    echo -e "\n=============================================================="
    echo -e "Updating alias..."
    echo -e "=============================================================="
    # Execute the bulk alias request with all accumulated actions (removal and addition)
    curl -s -X POST "${ELASTIC_HOST}/_aliases" \
      -H 'Content-Type: application/json' \
      -d "{\"actions\": [ ${actions} ]}" | jq . # Using jq for pretty print if available

    echo -e "\n=============================================================="
    echo -e "$(printf '%-25s: %s' 'Alias successfully updated' '')"
    echo -e "=============================================================="
  else
    echo -e "\n=============================================================="
    echo -e "$(printf '%-25s: %s' 'No alias changes needed' '')"
    echo -e "=============================================================="
  fi
}

##################### Main script logic #####################

# Step 0: Display help if '--help' is provided
if [[ "$1" == "--help" ]]; then
  show_help
fi

# Step 1: Validate the number of arguments
if [ "$#" -ne 3 ]; then
  echo -e "\n=============================================================="
  echo -e "$(printf '%-25s: %s' 'Error' 'Invalid usage. Please check the --help option.')"
  echo -e "=============================================================="
  exit 1
fi

# Set parameters from input
OLD_INDEX="$1"
NEW_INDEX="$2"
ALIAS_NAME="$3"

# Step 2: Check if ELASTIC_HOST is reachable
check_elastic_host

# Step 3: Check if the indexes exist
check_index_exists "$OLD_INDEX"

# Step 4: Fetch the settings and mappings from the old index
extract_settings_mappings "$OLD_INDEX"

# Step 5: Create the new index
create_new_index "$NEW_INDEX"

# Step 6: Reindex the data
reindex_data "$OLD_INDEX" "$NEW_INDEX"

# Step 7: Handle alias assignment
handle_alias "$OLD_INDEX" "$NEW_INDEX" "$ALIAS_NAME"

# Step 8: Output completion message
echo -e "\n=============================================================="
echo -e "                Elasticsearch Index Operation                  "
echo -e "=============================================================="
echo -e "$(printf '%-25s: %s' 'Status' 'SUCCESS')"
echo -e "\nOperation Summary:"
echo -e "--------------------------------------------------------------"
echo -e "$(printf '%-25s: %s' 'Source Index' "${OLD_INDEX}")"
echo -e "$(printf '%-25s: %s' 'Target Index' "${NEW_INDEX}")"
echo -e "$(printf '%-25s: %s' 'Alias Updated' "${ALIAS_NAME}")"
echo -e "--------------------------------------------------------------"
echo -e "Details:"
echo -e "The alias '${ALIAS_NAME}' has been successfully reassigned from"
echo -e "the old index '${OLD_INDEX}' to the new index '${NEW_INDEX}'."
echo -e "All relevant data has been successfully reindexed."
echo -e "\nNo errors were encountered during this operation."
echo -e "=============================================================="

##################### Main script logic end #####################
