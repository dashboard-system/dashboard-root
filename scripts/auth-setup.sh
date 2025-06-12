#!/bin/bash

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"

# Configuration
DB_FILE="./db/sqlite.db"
SALT_ROUNDS=12

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if [ ! -d "node_modules/better-sqlite3" ]; then
        missing_deps+=("better-sqlite3")
    fi
    
    if [ ! -d "node_modules/bcryptjs" ]; then
        missing_deps+=("bcryptjs")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: npm install ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Check database exists
check_database() {
    if [ ! -f "$DB_FILE" ]; then
        print_error "Database not found: $DB_FILE"
        log_info "Please run the webserver setup first"
        return 1
    fi
    
    print_success "Database found: $DB_FILE"
    return 0
}

# Create default users
create_default_users() {
    print_section "Creating Default Users"
    
    if ! check_database || ! check_dependencies; then
        return 1
    fi
    
    log_info "Creating default users with encrypted passwords..."
    
    # Create users using Node.js script
    node -e "
        const Database = require('better-sqlite3');
        const bcrypt = require('bcryptjs');
        
        const db = new Database('$DB_FILE');
        
        async function createUsers() {
            try {
                // Admin user
                const adminPassword = 'admin123';
                const adminHash = await bcrypt.hash(adminPassword, $SALT_ROUNDS);
                
                const adminStmt = db.prepare(\`
                    INSERT OR REPLACE INTO users (username, password, created_at, updated_at)
                    VALUES (?, ?, datetime('now'), datetime('now'))
                \`);
                adminStmt.run('admin', adminHash);
                console.log('✅ Admin user created (username: admin, password: admin123)');
                
                // Test user
                const testPassword = 'test123';
                const testHash = await bcrypt.hash(testPassword, $SALT_ROUNDS);
                
                const testStmt = db.prepare(\`
                    INSERT OR REPLACE INTO users (username, password, created_at, updated_at)
                    VALUES (?, ?, datetime('now'), datetime('now'))
                \`);
                testStmt.run('testuser', testHash);
                console.log('✅ Test user created (username: testuser, password: test123)');
                
                // Developer user
                const devPassword = 'dev123';
                const devHash = await bcrypt.hash(devPassword, $SALT_ROUNDS);
                
                const devStmt = db.prepare(\`
                    INSERT OR REPLACE INTO users (username, password, created_at, updated_at)
                    VALUES (?, ?, datetime('now'), datetime('now'))
                \`);
                devStmt.run('developer', devHash);
                console.log('✅ Developer user created (username: developer, password: dev123)');
                
                console.log('');
                console.log('🎉 Default users created successfully!');
                console.log('🔐 All passwords are encrypted using bcrypt with $SALT_ROUNDS salt rounds');
                console.log('⚠️  Please change these default passwords in production!');
                
            } catch (error) {
                console.error('❌ Error creating users:', error.message);
                process.exit(1);
            } finally {
                db.close();
            }
        }
        
        createUsers();
    "
    
    if [ $? -eq 0 ]; then
        print_success "Default users created successfully"
        show_default_credentials
        return 0
    else
        print_error "Failed to create default users"
        return 1
    fi
}

# Show default credentials
show_default_credentials() {
    print_section "Default Login Credentials"
    
    echo -e "${BLUE}Administrator:${NC}"
    echo -e "  Username: ${GREEN}admin${NC}"
    echo -e "  Password: ${GREEN}admin123${NC}"
    echo ""
    echo -e "${BLUE}Test User:${NC}"
    echo -e "  Username: ${GREEN}testuser${NC}"
    echo -e "  Password: ${GREEN}test123${NC}"
    echo ""
    echo -e "${BLUE}Developer:${NC}"
    echo -e "  Username: ${GREEN}developer${NC}"
    echo -e "  Password: ${GREEN}dev123${NC}"
    echo ""
    print_warning "Change these passwords in production!"
}

# Add custom user
add_user() {
    print_section "Adding Custom User"
    
    if ! check_database || ! check_dependencies; then
        return 1
    fi
    
    # Get username
    read -p "$(echo -e "${BLUE}Enter username: ${NC}")" username
    if [ -z "$username" ]; then
        print_error "Username cannot be empty"
        return 1
    fi
    
    # Get password (hidden input)
    echo -n -e "${BLUE}Enter password: ${NC}"
    read -s password
    echo
    if [ -z "$password" ]; then
        print_error "Password cannot be empty"
        return 1
    fi
    
    # Confirm password
    echo -n -e "${BLUE}Confirm password: ${NC}"
    read -s confirm_password
    echo
    if [ "$password" != "$confirm_password" ]; then
        print_error "Passwords do not match"
        return 1
    fi
    
    # Create user
    log_info "Creating user: $username"
    
    node -e "
        const Database = require('better-sqlite3');
        const bcrypt = require('bcryptjs');
        
        const db = new Database('$DB_FILE');
        
        async function addUser() {
            try {
                const username = '$username';
                const password = '$password';
                
                // Check if user already exists
                const existingUser = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
                if (existingUser) {
                    console.error('❌ User already exists');
                    process.exit(1);
                }
                
                // Hash password
                const hashedPassword = await bcrypt.hash(password, $SALT_ROUNDS);
                
                // Insert user
                const insert = db.prepare(\`
                    INSERT INTO users (username, password, created_at, updated_at)
                    VALUES (?, ?, datetime('now'), datetime('now'))
                \`);
                const result = insert.run(username, hashedPassword);
                
                console.log(\`✅ User '\${username}' created with ID: \${result.lastInsertRowid}\`);
                
            } catch (error) {
                console.error('❌ Error creating user:', error.message);
                process.exit(1);
            } finally {
                db.close();
            }
        }
        
        addUser();
    "
    
    if [ $? -eq 0 ]; then
        print_success "User '$username' created successfully"
        return 0
    else
        print_error "Failed to create user '$username'"
        return 1
    fi
}

# List all users
list_users() {
    print_section "Current Users"
    
    if ! check_database; then
        return 1
    fi
    
    node -e "
        const Database = require('better-sqlite3');
        const db = new Database('$DB_FILE');
        
        try {
            const users = db.prepare('SELECT id, username, created_at, updated_at FROM users ORDER BY id').all();
            
            if (users.length === 0) {
                console.log('No users found in database.');
                console.log('Run \"./scripts/auth-setup.sh create\" to create default users.');
            } else {
                console.log('');
                console.log('ID | Username     | Created    | Updated    | Status');
                console.log('---|--------------|------------|------------|--------');
                users.forEach(user => {
                    const createdDate = new Date(user.created_at).toISOString().split('T')[0];
                    const updatedDate = new Date(user.updated_at).toISOString().split('T')[0];
                    console.log(\`\${user.id.toString().padEnd(2)} | \${user.username.padEnd(12)} | \${createdDate} | \${updatedDate} | Active\`);
                });
                console.log('');
                console.log(\`Total users: \${users.length}\`);
                console.log('🔐 All passwords are encrypted using bcrypt');
            }
        } catch (error) {
            console.error('❌ Error listing users:', error.message);
            process.exit(1);
        } finally {
            db.close();
        }
    "
}

# Delete user
delete_user() {
    print_section "Delete User"
    
    if ! check_database; then
        return 1
    fi
    
    # First list users
    list_users
    
    read -p "$(echo -e "${YELLOW}Enter username to delete: ${NC}")" username
    if [ -z "$username" ]; then
        print_error "Username cannot be empty"
        return 1
    fi
    
    if [ "$(confirm "Are you sure you want to delete user '$username'?")" = "yes" ]; then
        node -e "
            const Database = require('better-sqlite3');
            const db = new Database('$DB_FILE');
            
            try {
                const username = '$username';
                
                // Check if user exists
                const user = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
                if (!user) {
                    console.error('❌ User not found');
                    process.exit(1);
                }
                
                // Delete related dashboard data first
                const deleteData = db.prepare('DELETE FROM dashboard_data WHERE user_id = ?');
                const dataResult = deleteData.run(user.id);
                console.log(\`✅ Deleted \${dataResult.changes} dashboard data records\`);
                
                // Delete user
                const deleteUser = db.prepare('DELETE FROM users WHERE username = ?');
                const userResult = deleteUser.run(username);
                
                if (userResult.changes > 0) {
                    console.log(\`✅ User '\${username}' deleted successfully\`);
                } else {
                    console.error('❌ Failed to delete user');
                    process.exit(1);
                }
                
            } catch (error) {
                console.error('❌ Error deleting user:', error.message);
                process.exit(1);
            } finally {
                db.close();
            }
        "
        
        if [ $? -eq 0 ]; then
            print_success "User '$username' deleted successfully"
        else
            print_error "Failed to delete user '$username'"
        fi
    else
        log_info "User deletion cancelled"
    fi
}

# Reset all users
reset_users() {
    print_section "Reset All Users"
    
    if ! check_database; then
        return 1
    fi
    
    print_warning "This will delete ALL users and related data!"
    
    if [ "$(confirm "Are you sure you want to reset all users?")" = "yes" ]; then
        log_info "Clearing users table..."
        
        node -e "
            const Database = require('better-sqlite3');
            const db = new Database('$DB_FILE');
            
            try {
                db.exec('DELETE FROM users');
                db.exec('DELETE FROM dashboard_data');
                console.log('✅ All users and related data removed');
            } catch (error) {
                console.error('❌ Error removing users:', error.message);
                process.exit(1);
            } finally {
                db.close();
            }
        "
        
        if [ $? -eq 0 ]; then
            print_success "Users table cleared"
            
            # Recreate default users
            if [ "$(confirm "Create default users?")" = "yes" ]; then
                create_default_users
            fi
        else
            print_error "Failed to reset users"
        fi
    else
        log_info "Reset cancelled"
    fi
}

# Test authentication
test_auth() {
    print_section "Testing Authentication"
    
    # Check if server is running
    if ! curl -s http://localhost:3000/health > /dev/null; then
        print_warning "Server is not running on localhost:3000"
        log_info "Start the server with 'npm run start' to test authentication"
        return 1
    fi
    
    print_success "Server is running - testing authentication..."
    
    # Test admin login
    log_info "Testing admin login..."
    ADMIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username": "admin", "password": "admin123"}')
    
    if echo "$ADMIN_RESPONSE" | grep -q "token"; then
        print_success "Admin login test passed"
        log_debug "Response: $ADMIN_RESPONSE"
    else
        print_error "Admin login test failed"
        log_error "Response: $ADMIN_RESPONSE"
    fi
    
    # Test testuser login
    log_info "Testing testuser login..."
    USER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username": "testuser", "password": "test123"}')
    
    if echo "$USER_RESPONSE" | grep -q "token"; then
        print_success "Test user login test passed"
        log_debug "Response: $USER_RESPONSE"
    else
        print_error "Test user login test failed"
        log_error "Response: $USER_RESPONSE"
    fi
}

# Main auth setup function
setup_auth() {
    print_header "Authentication Setup"
    
    if ! check_database || ! check_dependencies; then
        print_error "Prerequisites not met"
        return 1
    fi
    
    create_default_users
    
    print_success "Authentication setup completed successfully"
    return 0
}

# CLI interface
case "${1:-setup}" in
    "check")
        print_header "Authentication Requirements Check"
        check_database && check_dependencies
        ;;
    "create"|"setup")
        setup_auth
        ;;
    "add")
        add_user
        ;;
    "list")
        list_users
        ;;
    "delete")
        delete_user
        ;;
    "reset")
        reset_users
        ;;
    "test")
        test_auth
        ;;
    "creds"|"credentials")
        show_default_credentials
        ;;
    *)
        echo "Usage: $0 {check|create|add|list|delete|reset|test|credentials}"
        echo ""
        echo "Commands:"
        echo "  check       - Check requirements"
        echo "  create      - Create default users"
        echo "  add         - Add custom user"
        echo "  list        - List all users"
        echo "  delete      - Delete a user"
        echo "  reset       - Reset all users"
        echo "  test        - Test authentication"
        echo "  credentials - Show default credentials"
        exit 1
        ;;
esac