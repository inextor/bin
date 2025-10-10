#!/bin/bash

# This script dumps a MySQL/MariaDB database and converts its tables to TypeScript interfaces.
# It loads credentials from a .env file and takes the database name as an argument.
# Use the -f flag to write the output to a file named after the table (in PascalCase).
# If -f is used without a table name, it will generate files for all tables in the database.

# --- Configuration ---

# Load environment variables from .env file in the script's directory
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "Error: .env file not found at $ENV_FILE" >&2
  exit 1
fi

# --- Argument Parsing ---
WRITE_TO_FILE=false
while getopts "f" opt; do
  case ${opt} in
    f )
      WRITE_TO_FILE=true
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-f] <database_name> [table_name]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# --- Arguments ---

# The first argument is the database name (required)
if [ -z "$1" ]; then
  echo "Usage: $0 [-f] <database_name> [table_name]" >&2
  exit 1
fi

DB_NAME=$1
TABLE_NAME=${2:-""} # The second argument is the optional table name

# --- Validation ---

if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_HOST" ]; then
  echo "Error: MYSQL_USER, MYSQL_PASSWORD, or MYSQL_HOST not set in .env file." >&2
  exit 1
fi

# --- The Pipeline ---

# Function to execute the generation pipeline.
# The python script inside handles whether to generate for one table or all,
# based on whether the second argument is empty or not.
generate_interfaces() {
  local table_to_generate=${1:-""}
  mysqldump --skip-add-drop-table -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -d "$DB_NAME" 2>/dev/null | \
    sed 's/ENGINE=.*/;/' | \
    sed 's/ COLLATE.\\w\\+//' | \
    sed 's/ CHARACTER SET \\w\\+//' | \
    "$(dirname "$0")/parse_sql.py" "$table_to_generate"
}

if [ "$WRITE_TO_FILE" = true ]; then
  if [ -n "$TABLE_NAME" ]; then
    # Case 1: -f flag with a specific table name.
    INTERFACE_NAME=$(echo "$TABLE_NAME" | awk -F'_' '{ for(i=1; i<=NF; i++) { printf "%s%s", toupper(substr($i,1,1)), substr($i,2); if (i < NF) { printf "_" } } printf "\n" }')
    FILE_NAME="${INTERFACE_NAME}.ts"
    generate_interfaces "$TABLE_NAME" > "$FILE_NAME"
    echo "Interface for table '$TABLE_NAME' generated and saved to $FILE_NAME"
  else
    # Case 2: -f flag with no table name. Generate all tables to separate files.
    echo "Generating interfaces for all tables in database '$DB_NAME'..."

    # Get all table names from the database.
    TABLE_LIST=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$DB_NAME" -N -B -e "SHOW TABLES")

    if [ -z "$TABLE_LIST" ]; then
      echo "No tables found in database '$DB_NAME'."
      exit 0
    fi

    for table in $TABLE_LIST; do
      INTERFACE_NAME=$(echo "$table" | awk -F'_' '{ for(i=1; i<=NF; i++) { printf "%s%s", toupper(substr($i,1,1)), substr($i,2); if (i < NF) { printf "_" } } printf "\n" }' )
      FILE_NAME="${INTERFACE_NAME}.ts"
      generate_interfaces "$table" > "$FILE_NAME"
      echo "  - Interface for table '$table' saved to $FILE_NAME"
    done
    echo "All interfaces generated."
  fi
else
  # Case 3: No -f flag. Original behavior.
  # Generate interface(s) for the given table (or all if no table is given) and print to stdout.
  generate_interfaces "$TABLE_NAME"
fi
