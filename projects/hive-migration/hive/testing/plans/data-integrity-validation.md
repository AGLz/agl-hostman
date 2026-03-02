# Data Integrity Validation Plan
## API1 to API8 Migration

**Critical Objective**: Ensure zero data loss and corruption during migration
**Risk Level**: CRITICAL
**Validation Scope**: All data operations, migrations, and transformations

---

## Data Integrity Philosophy

> "In God we trust, all others must bring data." - W. Edwards Deming

### Core Principles
1. **Verify Everything**: Trust nothing, verify everything
2. **Checksum All Data**: Use cryptographic hashes to detect changes
3. **Audit All Changes**: Maintain complete audit trails
4. **Test Transactions**: Validate ACID properties
5. **Compare Continuously**: API1 vs API8 data consistency

---

## Data Integrity Test Categories

### 1. Pre-Migration Data Validation
**Objective**: Establish data baseline before migration

**Activities**:
- [ ] Generate complete data inventory
- [ ] Calculate checksums for all tables
- [ ] Document data statistics
- [ ] Identify data quality issues
- [ ] Create data snapshot

**Checklist**:
```bash
#!/bin/bash
# Pre-migration data validation

# 1. Count all records
echo "Counting records per table..."
tables=$(mysql -N -e "SHOW TABLES" api1_db)
for table in $tables; do
  count=$(mysql -N -e "SELECT COUNT(*) FROM $table" api1_db)
  echo "$table: $count" >> pre_migration_counts.txt
done

# 2. Calculate table checksums
echo "Calculating table checksums..."
for table in $tables; do
  checksum=$(mysql -N -e "CHECKSUM TABLE $table" api1_db | awk '{print $2}')
  echo "$table: $checksum" >> pre_migration_checksums.txt
done

# 3. Generate data statistics
echo "Generating data statistics..."
mysql api1_db <<EOF > pre_migration_stats.txt
SELECT 'users' as table_name,
       COUNT(*) as total_records,
       COUNT(DISTINCT id) as unique_ids,
       COUNT(DISTINCT email) as unique_emails,
       MIN(created_at) as earliest_record,
       MAX(created_at) as latest_record
FROM users;
-- Repeat for each critical table
EOF

echo "Pre-migration validation complete"
```

**Output**:
- `/hive/testing/data/pre_migration_counts.txt`
- `/hive/testing/data/pre_migration_checksums.txt`
- `/hive/testing/data/pre_migration_stats.txt`
- `/hive/testing/data/pre_migration_snapshot.sql`

---

### 2. Migration Data Validation
**Objective**: Verify data correctly transferred to API8

**Validation Tests**:

#### DI-001: Record Count Validation
```sql
-- Compare record counts between API1 and API8

-- API1 counts
SELECT
    'API1' as source,
    (SELECT COUNT(*) FROM users) as users_count,
    (SELECT COUNT(*) FROM resources) as resources_count,
    (SELECT COUNT(*) FROM transactions) as transactions_count;

-- API8 counts
SELECT
    'API8' as source,
    (SELECT COUNT(*) FROM users) as users_count,
    (SELECT COUNT(*) FROM resources) as resources_count,
    (SELECT COUNT(*) FROM transactions) as transactions_count;

-- Verification
-- Assert: API1 counts == API8 counts
```

#### DI-002: Primary Key Validation
```sql
-- Verify all primary keys migrated

-- Find missing IDs in API8
SELECT api1.id
FROM api1_db.users api1
LEFT JOIN api8_db.users api8 ON api1.id = api8.id
WHERE api8.id IS NULL;

-- Expected: 0 results (no missing IDs)
```

#### DI-003: Foreign Key Integrity
```sql
-- Verify referential integrity maintained

-- Check orphaned records
SELECT r.id, r.user_id
FROM api8_db.resources r
LEFT JOIN api8_db.users u ON r.user_id = u.id
WHERE u.id IS NULL;

-- Expected: 0 results (no orphaned records)
```

#### DI-004: Data Content Validation
```sql
-- Compare actual data content

-- Sample validation (repeat for all tables)
SELECT
    api1.id,
    api1.name as api1_name,
    api8.name as api8_name,
    CASE WHEN api1.name = api8.name THEN 'MATCH' ELSE 'MISMATCH' END as status
FROM api1_db.users api1
JOIN api8_db.users api8 ON api1.id = api8.id
WHERE api1.name != api8.name;

-- Expected: 0 mismatches
```

#### DI-005: Data Type Validation
```sql
-- Verify data types preserved

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'api8_db'
  AND TABLE_NAME = 'users';

-- Compare against API1 schema
-- Assert: Schemas match or safely compatible
```

#### DI-006: Timestamp Preservation
```sql
-- Verify timestamps not altered during migration

SELECT COUNT(*) as timestamp_mismatches
FROM api1_db.users api1
JOIN api8_db.users api8 ON api1.id = api8.id
WHERE api1.created_at != api8.created_at
   OR api1.updated_at != api8.updated_at;

-- Expected: 0 (timestamps preserved exactly)
```

#### DI-007: NULL Value Handling
```sql
-- Verify NULL values preserved

SELECT
    'users' as table_name,
    COUNT(*) as null_in_api1_not_in_api8
FROM api1_db.users api1
JOIN api8_db.users api8 ON api1.id = api8.id
WHERE api1.optional_field IS NULL
  AND api8.optional_field IS NOT NULL;

-- Expected: 0 (NULLs preserved)
```

#### DI-008: Special Characters and Encoding
```sql
-- Verify special characters preserved

SELECT
    api1.id,
    api1.name,
    api8.name,
    HEX(api1.name) as api1_hex,
    HEX(api8.name) as api8_hex
FROM api1_db.users api1
JOIN api8_db.users api8 ON api1.id = api8.id
WHERE api1.name REGEXP '[^A-Za-z0-9 ]'  -- Has special chars
  AND api1.name != api8.name;

-- Expected: 0 (special characters preserved)
```

---

### 3. CRUD Operation Data Integrity
**Objective**: Verify all CRUD operations maintain data integrity

#### DI-100: CREATE Operation Integrity
**Test**: Create resource and verify data stored correctly

```bash
#!/bin/bash
test_create_integrity() {
  echo "Testing CREATE operation integrity..."

  # Create resource via API
  create_response=$(curl -s -X POST "$API_URL/api/resources" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
      "name": "Test Resource",
      "description": "Test Description",
      "value": 123.45,
      "tags": ["test", "integrity"],
      "metadata": {"key": "value"}
    }')

  resource_id=$(echo "$create_response" | jq -r '.data.id')

  # Verify in database
  db_result=$(mysql -N -e "
    SELECT name, description, value
    FROM resources
    WHERE id = $resource_id
  " api8_db)

  db_name=$(echo "$db_result" | awk '{print $1}')
  db_value=$(echo "$db_result" | awk '{print $3}')

  # Assertions
  assert_equals "Test Resource" "$db_name" || return 1
  assert_equals "123.45" "$db_value" || return 1

  echo "PASS: CREATE operation maintains data integrity"
  return 0
}
```

#### DI-101: READ Operation Integrity
**Test**: Verify read operations return correct data

```bash
test_read_integrity() {
  echo "Testing READ operation integrity..."

  # Read directly from database
  db_data=$(mysql -N -e "
    SELECT id, name, description, value
    FROM resources
    WHERE id = $KNOWN_ID
  " api8_db)

  # Read via API
  api_response=$(curl -s "$API_URL/api/resources/$KNOWN_ID" \
    -H "Authorization: Bearer $TOKEN")

  api_name=$(echo "$api_response" | jq -r '.data.name')
  api_value=$(echo "$api_response" | jq -r '.data.value')

  db_name=$(echo "$db_data" | awk '{print $2}')
  db_value=$(echo "$db_data" | awk '{print $4}')

  # Assertions
  assert_equals "$db_name" "$api_name" || return 1
  assert_equals "$db_value" "$api_value" || return 1

  echo "PASS: READ operation returns accurate data"
  return 0
}
```

#### DI-102: UPDATE Operation Integrity
**Test**: Verify updates preserve non-updated fields

```bash
test_update_integrity() {
  echo "Testing UPDATE operation integrity..."

  # Get original data
  original=$(curl -s "$API_URL/api/resources/$TEST_ID" \
    -H "Authorization: Bearer $TOKEN")

  original_created_at=$(echo "$original" | jq -r '.data.created_at')
  original_description=$(echo "$original" | jq -r '.data.description')

  # Update only name
  update_response=$(curl -s -X PUT "$API_URL/api/resources/$TEST_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"name": "Updated Name"}')

  # Get updated data
  updated=$(curl -s "$API_URL/api/resources/$TEST_ID" \
    -H "Authorization: Bearer $TOKEN")

  updated_name=$(echo "$updated" | jq -r '.data.name')
  updated_created_at=$(echo "$updated" | jq -r '.data.created_at')
  updated_description=$(echo "$updated" | jq -r '.data.description')

  # Assertions
  assert_equals "Updated Name" "$updated_name" || return 1
  assert_equals "$original_created_at" "$updated_created_at" || return 1
  assert_equals "$original_description" "$updated_description" || return 1

  echo "PASS: UPDATE preserves non-updated fields"
  return 0
}
```

#### DI-103: DELETE Operation Integrity
**Test**: Verify cascade deletes and soft deletes

```bash
test_delete_integrity() {
  echo "Testing DELETE operation integrity..."

  # Create parent with children
  parent_id=$(create_test_parent)
  child1_id=$(create_test_child $parent_id)
  child2_id=$(create_test_child $parent_id)

  # Delete parent
  curl -s -X DELETE "$API_URL/api/resources/$parent_id" \
    -H "Authorization: Bearer $TOKEN"

  # Verify parent deleted/soft-deleted
  parent_exists=$(mysql -N -e "
    SELECT COUNT(*) FROM resources WHERE id = $parent_id
  " api8_db)

  # Verify children handled correctly (cascade or orphan protection)
  children_exist=$(mysql -N -e "
    SELECT COUNT(*) FROM resource_children
    WHERE parent_id = $parent_id
  " api8_db)

  # Assertions depend on delete strategy
  if [ "$DELETE_STRATEGY" == "cascade" ]; then
    assert_equals "0" "$parent_exists" || return 1
    assert_equals "0" "$children_exist" || return 1
  elif [ "$DELETE_STRATEGY" == "soft" ]; then
    deleted_at=$(mysql -N -e "
      SELECT deleted_at FROM resources WHERE id = $parent_id
    " api8_db)
    assert_not_null "$deleted_at" || return 1
  fi

  echo "PASS: DELETE maintains referential integrity"
  return 0
}
```

---

### 4. Transaction Integrity Tests
**Objective**: Verify ACID properties

#### DI-200: Atomicity Test
**Test**: Verify all-or-nothing transaction behavior

```bash
test_transaction_atomicity() {
  echo "Testing transaction atomicity..."

  # Start transaction that will fail midway
  response=$(curl -s -w "%{http_code}" -X POST "$API_URL/api/transactions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
      "operations": [
        {"type": "create", "resource": "order", "data": {...}},
        {"type": "update", "resource": "inventory", "data": {...}},
        {"type": "create", "resource": "invalid", "data": {...}}  // Will fail
      ]
    }')

  status="${response: -3}"

  # Verify no partial data committed
  order_count=$(mysql -N -e "
    SELECT COUNT(*) FROM orders
    WHERE created_at > NOW() - INTERVAL 1 MINUTE
  " api8_db)

  inventory_changes=$(mysql -N -e "
    SELECT COUNT(*) FROM inventory_log
    WHERE created_at > NOW() - INTERVAL 1 MINUTE
  " api8_db)

  # Assertions
  assert_equals "0" "$order_count" "No partial order created" || return 1
  assert_equals "0" "$inventory_changes" "No inventory changes" || return 1

  echo "PASS: Atomicity maintained"
  return 0
}
```

#### DI-201: Consistency Test
**Test**: Verify database constraints enforced

```bash
test_transaction_consistency() {
  echo "Testing transaction consistency..."

  # Attempt to create record violating constraint
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
      "email": "existing@example.com",  // Duplicate email
      "name": "Test User"
    }')

  status=$(echo "$response" | tail -n 1)

  # Assert constraint enforced
  assert_equals "422" "$status" "Constraint violation detected" || return 1

  # Verify database still consistent
  email_count=$(mysql -N -e "
    SELECT COUNT(*) FROM users WHERE email = 'existing@example.com'
  " api8_db)

  assert_equals "1" "$email_count" "No duplicate created" || return 1

  echo "PASS: Consistency maintained"
  return 0
}
```

#### DI-202: Isolation Test
**Test**: Verify concurrent transactions don't interfere

```bash
test_transaction_isolation() {
  echo "Testing transaction isolation..."

  initial_balance=$(get_account_balance $TEST_ACCOUNT)

  # Start two concurrent transactions
  transfer1_pid=$(transfer_funds $TEST_ACCOUNT 100 & echo $!)
  transfer2_pid=$(transfer_funds $TEST_ACCOUNT 50 & echo $!)

  # Wait for completion
  wait $transfer1_pid
  wait $transfer2_pid

  # Verify final balance correct
  final_balance=$(get_account_balance $TEST_ACCOUNT)
  expected_balance=$((initial_balance - 150))

  assert_equals "$expected_balance" "$final_balance" || return 1

  echo "PASS: Isolation maintained"
  return 0
}
```

#### DI-203: Durability Test
**Test**: Verify committed data persists

```bash
test_transaction_durability() {
  echo "Testing transaction durability..."

  # Create record
  resource_id=$(create_test_resource)

  # Verify created
  assert_resource_exists $resource_id || return 1

  # Simulate server restart (if safe)
  # restart_service

  # Verify still exists after restart
  sleep 2
  assert_resource_exists $resource_id || return 1

  echo "PASS: Durability maintained"
  return 0
}
```

---

### 5. Data Validation Rules
**Objective**: Verify input validation maintains data quality

#### DI-300: Required Field Validation
```bash
test_required_fields() {
  # Attempt to create without required field
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/resources" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"description": "Missing name field"}')

  status=$(echo "$response" | tail -n 1)
  assert_equals "422" "$status" || return 1

  echo "PASS: Required field validation"
}
```

#### DI-301: Data Type Validation
```bash
test_data_type_validation() {
  # Attempt to create with wrong type
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/resources" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"name": "Test", "value": "not-a-number"}')

  status=$(echo "$response" | tail -n 1)
  assert_equals "422" "$status" || return 1

  echo "PASS: Data type validation"
}
```

#### DI-302: Range Validation
```bash
test_range_validation() {
  # Attempt with out-of-range value
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/resources" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"name": "Test", "quantity": -5}')  # Negative not allowed

  status=$(echo "$response" | tail -n 1)
  assert_equals "422" "$status" || return 1

  echo "PASS: Range validation"
}
```

---

## Data Integrity Monitoring

### Real-Time Monitoring
```bash
#!/bin/bash
# Continuous data integrity monitoring

monitor_data_integrity() {
  while true; do
    # Check record counts
    api1_count=$(mysql -N -e "SELECT COUNT(*) FROM users" api1_db)
    api8_count=$(mysql -N -e "SELECT COUNT(*) FROM users" api8_db)

    if [ "$api1_count" -ne "$api8_count" ]; then
      alert "Data count mismatch: API1=$api1_count, API8=$api8_count"
    fi

    # Check for orphaned records
    orphans=$(mysql -N -e "
      SELECT COUNT(*) FROM resources r
      LEFT JOIN users u ON r.user_id = u.id
      WHERE u.id IS NULL
    " api8_db)

    if [ "$orphans" -gt 0 ]; then
      alert "Found $orphans orphaned records"
    fi

    # Check data quality metrics
    invalid_emails=$(mysql -N -e "
      SELECT COUNT(*) FROM users
      WHERE email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    " api8_db)

    if [ "$invalid_emails" -gt 0 ]; then
      alert "Found $invalid_emails invalid email addresses"
    fi

    sleep 60  # Check every minute
  done
}
```

---

## Data Integrity Reporting

### Daily Integrity Report
```markdown
# Data Integrity Report
**Date**: 2025-10-13
**Status**: ✅ PASS / ❌ FAIL

## Record Counts
| Table | API1 | API8 | Match |
|-------|------|------|-------|
| users | 10,234 | 10,234 | ✅ |
| resources | 45,678 | 45,678 | ✅ |
| transactions | 123,456 | 123,456 | ✅ |

## Integrity Checks
- [ ] Primary keys migrated: ✅ 100%
- [ ] Foreign keys valid: ✅ 100%
- [ ] No orphaned records: ✅
- [ ] Timestamps preserved: ✅
- [ ] Data types correct: ✅

## Issues Found
- None

## Recommendations
- Continue monitoring
- Schedule full validation weekly
```

---

**Document Version**: 1.0
**Author**: Hive Mind TESTER Agent
**Date**: 2025-10-13
**Status**: Ready for Implementation
