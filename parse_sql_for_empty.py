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
    function_name = interface_name.lower()
    print(f"import {{ {interface_name} }} from '../RestModels/{interface_name}';\n")
    print(f"export function {function_name}(): {interface_name} {{")
    print(f"\treturn {{")

    # Find all column definitions, anchored to the start of the line
    columns = re.findall(r'^\s*`(\w+)`\s+(.*)', table_content, re.MULTILINE)

    for col_name, col_type in columns:
        col_type = col_type.rstrip(',')
        col_type_lower = col_type.lower()

        is_nullable = "not null" not in col_type_lower

        if col_name == 'id':
            if re.search(r'\b(int|decimal)\b', col_type_lower):
                default_value = "0"
            elif re.search(r'\b(varchar|text|char)\b', col_type_lower):
                default_value = "''"
            else:
                default_value = "0"  # Default to 0 if not a recognized string type
        elif col_name == 'currency_id':
            default_value = "'MXN'"
        elif col_name in ['created_by_user_id', 'updated_by_user_id']:
            if is_nullable:
                default_value = "null"
            else:
                default_value = "0"
        elif is_nullable:
            default_value = "null"
        elif re.search(r'\b(int|decimal|tinyint)\b', col_type_lower):
            default_value = "0"
        elif re.search(r'\b(enum)\b', col_type_lower):
            enum_values = re.findall(r"'([^']*)'", col_type)
            if enum_values:
                default_value = f"'{enum_values[0]}'"
            else:
                default_value = "''"
        elif re.search(r'\b(varchar|text|date)\b', col_type_lower):
            default_value = "''"
        elif re.search(r'\b(timestamp|datetime)\b', col_type_lower):
            default_value = "new Date()"
        else:
            default_value = "''"

        print(f"\t\t{col_name}: {default_value}, ")

    print("\t};")
    print("}")
