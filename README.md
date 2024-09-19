## Elasticsearch Index Duplicator Script

This Bash script allows you to duplicate an existing Elasticsearch index, reindex the data to the new index, and optionally move an alias from the old index to the new index. This script provides a convenient way to manage your Elasticsearch indices and aliases with ease.

### Features
- Duplicate an existing Elasticsearch index with all settings and mappings.
- Reindex data from the source index to the new index.
- Update aliases: Move an alias from the old index to the new index.

### Prerequisites
- Elasticsearch running and accessible.
- `jq` installed (optional, for JSON pretty-printing).

### Installation

1. **Clone the Repository** (if this script is part of a repository):
   ```bash
   git clone https://github.com/emreyildirim53/elastic-search-index-duplicator.git
   cd elastic-search-index-duplicator
   ```

2. **Make the Script Executable**:
   ```bash
   chmod +x index_duplicator.sh
   ```

### Usage

```bash
./index_duplicator.sh [old_index_name] [new_index_name] [alias_name]
```

#### Parameters
- `old_index_name`: The name of the existing index (source).
- `new_index_name`: The name of the new index to be created (destination).
- `alias_name`: The alias to be moved to the new index.

#### Example
```bash
./index_duplicator.sh my_old_index my_new_index my_alias
```

### Script Breakdown

1. **Elasticsearch Connection**: Connects to the specified Elasticsearch instance.
2. **Index Existence Check**: Verifies the existence of the source index.
3. **Settings and Mappings Extraction**: Extracts settings and mappings from the source index.
4. **Index Creation**: Creates the new index with the extracted settings and mappings.
5. **Data Reindexing**: Reindexes data from the source index to the new index.
6. **Alias Management**: Moves the alias from the old index to the new index.

### Sample Output
When the script runs successfully, it outputs a summary of operations:
```
==============================================================
                Elasticsearch Index Operation                  
==============================================================
Status                  : SUCCESS

Operation Summary:
--------------------------------------------------------------
Source Index            : my_old_index
Target Index            : my_new_index
Alias Updated           : my_alias
--------------------------------------------------------------
Details:
The alias 'my_alias' has been successfully reassigned from
the old index 'my_old_index' to the new index 'my_new_index'.
All relevant data has been successfully reindexed.

No errors were encountered during this operation.
==============================================================
```

### Requirements

- **Elasticsearch**: Ensure that your Elasticsearch instance is up and running, and accessible via the `ELASTIC_HOST` variable in the script.
- **`jq` (optional)**: Used for pretty-printing JSON responses.

### Error Handling
- The script checks if the Elasticsearch host is reachable and if the specified indices exist.
- Proper error messages are displayed if an index is not found or if there are connectivity issues.

### Customization
- **Elasticsearch Host**: Modify the `ELASTIC_HOST` variable in the script to point to your Elasticsearch instance if different from the default.
- **Index and Alias Names**: Use the script's parameters to specify your index and alias names.

### License
This script is open-source and available under the [MIT License](LICENSE).

### Contributing
Contributions are welcome! Please submit a pull request or open an issue to discuss changes.

---

### Additional Information
- Make sure to have proper backups before running this script on a production Elasticsearch cluster.
- Test the script in a development or staging environment if you're uncertain about its effects.

### Contact
For further questions or support, please open an issue on this repository.
