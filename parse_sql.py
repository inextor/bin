#!/usr/bin/env python3
import re
import sys

# Check for an optional table name argument
target_table = sys.argv[1] if len(sys.argv) > 1 else None

# Read the SQL content from stdin
content = sys.stdin.read()

# Find all CREATE TABLE statements
create_tables = re.findall(r'CREATE TABLE `(\w+)` \((.*?)\) ;', content, re.DOTALL)

for table_name, table_content in create_tables:
    # If a target table is specified, skip all others
    if target_table and table_name != target_table:
        continue

    interface_name = "_".join(word.capitalize() for word in table_name.split("_"))
    print(f"export interface {interface_name} {{")

    # Find all column definitions, anchored to the start of the line
    columns = re.findall(r'^\s*`(\w+)`\s+(.*)', table_content, re.MULTILINE)

    for col_name, col_type in columns:
        col_type = col_type.rstrip(',')
        ts_type = "any"
        col_type_lower = col_type.lower()
        if re.search(r'\b(int|decimal)\b', col_type_lower):
            ts_type = "number"
        elif re.search(r'\b(enum)\b', col_type_lower):
            enum_values = re.findall(r"'([^']*)'", col_type)
            ts_type = " | ".join(f"'{v}'" for v in list(dict.fromkeys(enum_values)))
        elif re.search(r'\b(varchar|text|date)\b', col_type_lower):
            ts_type = "string"
        elif re.search(r'\b(timestamp|datetime)\b', col_type_lower):
            ts_type = "string | Date"

        # If 'NOT NULL' is not present, the column is nullable.
        if "not null" not in col_type_lower:
            ts_type += " | null"

        print(f"  {col_name}: {ts_type};")

    print("}")
    print("\n")
