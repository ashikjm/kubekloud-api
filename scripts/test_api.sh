#!/bin/bash
# API testing script

BASE_URL="http://localhost:8000/api/v1"
TOKEN=""

echo "=== Cloud Management Platform API Test ==="
echo

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# 1. Health check
echo "1. Testing health check..."
response=$(curl -s -w "%{http_code}" -o /tmp/health.json $BASE_URL/../health)
if [ "$response" = "200" ]; then
    print_result 0 "Health check passed"
    cat /tmp/health.json | python3 -m json.tool
else
    print_result 1 "Health check failed (HTTP $response)"
fi
echo

# 2. Create user
echo "2. Creating test user..."
response=$(curl -s -w "%{http_code}" -o /tmp/user.json -X POST "$BASE_URL/users/" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "token": "test-token-123",
    "quota_cpu": 16.0,
    "quota_memory": 64.0
  }')

if [ "$response" = "201" ]; then
    print_result 0 "User created"
    cat /tmp/user.json | python3 -m json.tool
    TOKEN="test-token-123"
else
    print_result 1 "User creation failed (HTTP $response)"
    cat /tmp/user.json
fi
echo

# 3. Get user info
echo "3. Getting user info..."
response=$(curl -s -w "%{http_code}" -o /tmp/userinfo.json -X GET "$BASE_URL/users/me" \
  -H "Authorization: Bearer $TOKEN")

if [ "$response" = "200" ]; then
    print_result 0 "User info retrieved"
    cat /tmp/userinfo.json | python3 -m json.tool
else
    print_result 1 "User info retrieval failed (HTTP $response)"
fi
echo

# 4. Check quota
echo "4. Checking user quota..."
response=$(curl -s -w "%{http_code}" -o /tmp/quota.json -X GET "$BASE_URL/users/me/quota" \
  -H "Authorization: Bearer $TOKEN")

if [ "$response" = "200" ]; then
    print_result 0 "Quota retrieved"
    cat /tmp/quota.json | python3 -m json.tool
else
    print_result 1 "Quota retrieval failed (HTTP $response)"
fi
echo

# 5. Create cluster
echo "5. Creating test cluster..."
response=$(curl -s -w "%{http_code}" -o /tmp/cluster.json -X POST "$BASE_URL/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-cluster",
    "instance_type": "container",
    "cpu_per_instance": 1.0,
    "memory_per_instance": 2.0,
    "instance_count": 2
  }')

if [ "$response" = "201" ]; then
    print_result 0 "Cluster created"
    cat /tmp/cluster.json | python3 -m json.tool
    CLUSTER_ID=$(cat /tmp/cluster.json | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
else
    print_result 1 "Cluster creation failed (HTTP $response)"
    cat /tmp/cluster.json
fi
echo

# 6. List clusters
echo "6. Listing clusters..."
response=$(curl -s -w "%{http_code}" -o /tmp/clusters.json -X GET "$BASE_URL/clusters/" \
  -H "Authorization: Bearer $TOKEN")

if [ "$response" = "200" ]; then
    print_result 0 "Clusters listed"
    cat /tmp/clusters.json | python3 -m json.tool
else
    print_result 1 "Cluster listing failed (HTTP $response)"
fi
echo

# 7. Get cluster details
if [ ! -z "$CLUSTER_ID" ]; then
    echo "7. Getting cluster details..."
    response=$(curl -s -w "%{http_code}" -o /tmp/cluster_detail.json -X GET "$BASE_URL/clusters/$CLUSTER_ID" \
      -H "Authorization: Bearer $TOKEN")

    if [ "$response" = "200" ]; then
        print_result 0 "Cluster details retrieved"
        cat /tmp/cluster_detail.json | python3 -m json.tool
        INSTANCE_ID=$(cat /tmp/cluster_detail.json | python3 -c "import sys, json; print(json.load(sys.stdin)['instances'][0]['id'] if json.load(sys.stdin).get('instances') else '')" 2>/dev/null)
    else
        print_result 1 "Cluster details retrieval failed (HTTP $response)"
    fi
    echo
fi

# 8. Check quota after creation
echo "8. Checking quota after cluster creation..."
response=$(curl -s -w "%{http_code}" -o /tmp/quota2.json -X GET "$BASE_URL/users/me/quota" \
  -H "Authorization: Bearer $TOKEN")

if [ "$response" = "200" ]; then
    print_result 0 "Quota retrieved"
    cat /tmp/quota2.json | python3 -m json.tool
else
    print_result 1 "Quota retrieval failed (HTTP $response)"
fi
echo

# 9. Operate on instance (if available)
if [ ! -z "$INSTANCE_ID" ]; then
    echo "9. Testing instance operations..."
    
    # Get instance info
    response=$(curl -s -w "%{http_code}" -o /tmp/instance.json -X GET "$BASE_URL/instances/$INSTANCE_ID" \
      -H "Authorization: Bearer $TOKEN")
    
    if [ "$response" = "200" ]; then
        print_result 0 "Instance info retrieved"
        cat /tmp/instance.json | python3 -m json.tool
    else
        print_result 1 "Instance info retrieval failed (HTTP $response)"
    fi
    echo
fi

# 10. Delete cluster
if [ ! -z "$CLUSTER_ID" ]; then
    echo "10. Deleting cluster..."
    response=$(curl -s -w "%{http_code}" -o /tmp/delete.json -X DELETE "$BASE_URL/clusters/$CLUSTER_ID" \
      -H "Authorization: Bearer $TOKEN")

    if [ "$response" = "200" ]; then
        print_result 0 "Cluster deleted"
        cat /tmp/delete.json | python3 -m json.tool
    else
        print_result 1 "Cluster deletion failed (HTTP $response)"
        cat /tmp/delete.json
    fi
    echo
fi

# 11. Final quota check
echo "11. Final quota check..."
response=$(curl -s -w "%{http_code}" -o /tmp/quota3.json -X GET "$BASE_URL/users/me/quota" \
  -H "Authorization: Bearer $TOKEN")

if [ "$response" = "200" ]; then
    print_result 0 "Quota retrieved"
    cat /tmp/quota3.json | python3 -m json.tool
else
    print_result 1 "Quota retrieval failed (HTTP $response)"
fi
echo

echo "=== Test Complete ==="

