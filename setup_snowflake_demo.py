#!/usr/bin/env python3
"""
Snowflake GDPR Demo Setup Script
Automates the setup of the GDPR compliance demo in Snowflake
"""

import os
import sys
import time
import snowflake.connector
from pathlib import Path
import click
from colorama import init, Fore, Back, Style

# Initialize colorama for cross-platform colored output
init(autoreset=True)


class SnowflakeSetup:
    """Setup class for initializing the GDPR demo in Snowflake"""
    
    def __init__(self, account: str, user: str, password: str, role: str = "SYSADMIN"):
        self.account = account
        self.user = user
        self.password = password
        self.role = role
        self.connection = None
        
    def connect(self) -> bool:
        """Connect to Snowflake"""
        try:
            self.connection = snowflake.connector.connect(
                account=self.account,
                user=self.user,
                password=self.password,
                role=self.role
            )
            print(f"{Fore.GREEN}✅ Connected to Snowflake successfully{Style.RESET_ALL}")
            return True
        except Exception as e:
            print(f"{Fore.RED}❌ Failed to connect to Snowflake: {e}{Style.RESET_ALL}")
            return False
    
    def disconnect(self):
        """Disconnect from Snowflake"""
        if self.connection:
            self.connection.close()
            print(f"{Fore.GREEN}✅ Disconnected from Snowflake{Style.RESET_ALL}")
    
    def execute_sql_file(self, file_path: Path, description: str) -> bool:
        """Execute a SQL file"""
        print(f"\n{Fore.CYAN}📄 Executing {description}...{Style.RESET_ALL}")
        
        try:
            with open(file_path, 'r') as file:
                sql_content = file.read()
            
            # Smart SQL statement parsing that handles stored procedures
            statements = self._parse_sql_statements(sql_content)
            
            cursor = self.connection.cursor()
            
            for i, statement in enumerate(statements, 1):
                if not statement or statement.upper().startswith(('--', '/*')):
                    continue
                    
                try:
                    cursor.execute(statement)
                    print(f"   ✓ Statement {i}/{len(statements)} executed")
                except Exception as e:
                    print(f"   ⚠️  Statement {i} warning: {e}")
                    # Continue with other statements
            
            cursor.close()
            print(f"{Fore.GREEN}✅ {description} completed successfully{Style.RESET_ALL}")
            return True
            
        except FileNotFoundError:
            print(f"{Fore.RED}❌ File not found: {file_path}{Style.RESET_ALL}")
            return False
        except Exception as e:
            print(f"{Fore.RED}❌ Failed to execute {description}: {e}{Style.RESET_ALL}")
            return False
    
    def _parse_sql_statements(self, sql_content: str) -> list:
        """Parse SQL content into individual statements, handling stored procedures properly"""
        statements = []
        current_statement = ""
        in_procedure = False
        lines = sql_content.split('\n')
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments at the start of a line
            if not line or line.startswith('--'):
                continue
            
            current_statement += line + '\n'
            
            # Check for procedure start/end markers
            if '$$' in line:
                if not in_procedure:
                    in_procedure = True
                else:
                    # End of procedure
                    in_procedure = False
                    statements.append(current_statement.strip())
                    current_statement = ""
            elif not in_procedure and line.endswith(';'):
                # Regular statement ending with semicolon (not inside a procedure)
                statements.append(current_statement.strip())
                current_statement = ""
        
        # Add any remaining statement
        if current_statement.strip():
            statements.append(current_statement.strip())
        
        return [stmt for stmt in statements if stmt]
    
    def setup_databases_and_schemas(self) -> bool:
        """Setup databases, schemas, and tables"""
        setup_file = Path("setup/snowflake_setup.sql")
        return self.execute_sql_file(setup_file, "Database and Schema Setup")
    
    def setup_procedures_and_functions(self) -> bool:
        """Setup GDPR procedures and functions"""
        procedures_file = Path("setup/gdpr_procedures.sql")
        return self.execute_sql_file(procedures_file, "GDPR Procedures and Functions")
    
    def setup_security_policies(self) -> bool:
        """Setup security policies and views"""
        security_file = Path("setup/security_policies.sql")
        return self.execute_sql_file(security_file, "Security Policies and Views")
    
    def setup_demo_data(self) -> bool:
        """Setup demo data"""
        demo_data_file = Path("setup/demo_data.sql")
        return self.execute_sql_file(demo_data_file, "Demo Data")
    
    def verify_setup(self) -> bool:
        """Verify that the setup was successful"""
        print(f"\n{Fore.CYAN}🔍 Verifying setup...{Style.RESET_ALL}")
        
        verification_queries = [
            ("Databases", "SHOW DATABASES LIKE '%_DB'"),
            ("Warehouses", "SHOW WAREHOUSES LIKE 'GDPR_%'"),
            ("Procedures", "SHOW PROCEDURES LIKE 'SP_%'"),
            ("Views", "SHOW VIEWS LIKE 'VW_%'"),
            ("Demo Customers", "SELECT COUNT(*) as customer_count FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS"),
            ("Erasure Requests", "SELECT COUNT(*) as request_count FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS"),
        ]
        
        cursor = self.connection.cursor()
        all_passed = True
        
        for check_name, query in verification_queries:
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                
                if check_name in ["Demo Customers", "Erasure Requests"]:
                    count = result[0][0] if result else 0
                    print(f"   ✓ {check_name}: {count} records")
                else:
                    count = len(result)
                    print(f"   ✓ {check_name}: {count} items found")
                    
            except Exception as e:
                print(f"   ❌ {check_name}: Failed - {e}")
                all_passed = False
        
        cursor.close()
        
        if all_passed:
            print(f"{Fore.GREEN}✅ Setup verification completed successfully{Style.RESET_ALL}")
        else:
            print(f"{Fore.YELLOW}⚠️  Setup verification completed with warnings{Style.RESET_ALL}")
        
        return all_passed
    
    def run_full_setup(self) -> bool:
        """Run the complete setup process"""
        print(f"\n{Back.BLUE}{Fore.WHITE} 🛡️  SNOWFLAKE GDPR DEMO SETUP {Style.RESET_ALL}")
        print(f"{Fore.CYAN}Setting up GDPR Right to be Forgotten demo in Snowflake...{Style.RESET_ALL}")
        print("=" * 60)
        
        setup_steps = [
            ("1. Databases and Schemas", self.setup_databases_and_schemas),
            ("2. GDPR Procedures", self.setup_procedures_and_functions),
            ("3. Security Policies", self.setup_security_policies),
            ("4. Demo Data", self.setup_demo_data),
            ("5. Setup Verification", self.verify_setup),
        ]
        
        for step_name, step_function in setup_steps:
            print(f"\n{Fore.YELLOW}{step_name}{Style.RESET_ALL}")
            
            if not step_function():
                print(f"{Fore.RED}❌ Setup failed at: {step_name}{Style.RESET_ALL}")
                return False
            
            # Add a small delay for better UX
            time.sleep(1)
        
        print(f"\n{Back.GREEN}{Fore.WHITE} ✅ SNOWFLAKE GDPR DEMO SETUP COMPLETED SUCCESSFULLY! {Style.RESET_ALL}")
        print(f"\n{Fore.CYAN}Next steps:{Style.RESET_ALL}")
        print("  1. Run: python gdpr_demo.py interactive")
        print("  2. Or try: python gdpr_demo.py full-demo -e anna.mueller@email.de")
        print("  3. View dashboard: python gdpr_demo.py dashboard")
        
        return True


def get_snowflake_credentials():
    """Get Snowflake credentials from user"""
    print(f"\n{Fore.CYAN}🔐 Snowflake Connection Details{Style.RESET_ALL}")
    print("Please provide your Snowflake connection information:")
    
    account = input("Account (e.g., abc12345.us-east-1): ").strip()
    user = input("Username: ").strip()
    
    import getpass
    password = getpass.getpass("Password: ")
    
    role = input("Role (default: SYSADMIN): ").strip() or "SYSADMIN"
    
    return account, user, password, role


@click.command()
@click.option('--account', '-a', help='Snowflake account identifier')
@click.option('--user', '-u', help='Snowflake username')
@click.option('--password', '-p', help='Snowflake password')
@click.option('--role', '-r', default='SYSADMIN', help='Snowflake role')
@click.option('--interactive', '-i', is_flag=True, help='Interactive setup mode')
def main(account, user, password, role, interactive):
    """Setup the Snowflake GDPR Right to be Forgotten demo"""
    
    # Check if setup files exist
    setup_dir = Path("setup")
    required_files = [
        "snowflake_setup.sql",
        "gdpr_procedures.sql", 
        "security_policies.sql",
        "demo_data.sql"
    ]
    
    missing_files = []
    for file_name in required_files:
        file_path = setup_dir / file_name
        if not file_path.exists():
            missing_files.append(str(file_path))
    
    if missing_files:
        print(f"{Fore.RED}❌ Missing required setup files:{Style.RESET_ALL}")
        for file in missing_files:
            print(f"   • {file}")
        print(f"\n{Fore.YELLOW}Please ensure you're running this script from the project root directory.{Style.RESET_ALL}")
        sys.exit(1)
    
    # Get credentials
    if interactive or not all([account, user, password]):
        account, user, password, role = get_snowflake_credentials()
    
    if not all([account, user, password]):
        print(f"{Fore.RED}❌ Missing required connection parameters{Style.RESET_ALL}")
        sys.exit(1)
    
    # Create setup instance and run
    setup = SnowflakeSetup(account, user, password, role)
    
    if not setup.connect():
        sys.exit(1)
    
    try:
        if setup.run_full_setup():
            # Create environment file for future runs
            env_content = f"""# Snowflake GDPR Demo Configuration
SNOWFLAKE_ACCOUNT={account}
SNOWFLAKE_USER={user}
SNOWFLAKE_PASSWORD={password}
SNOWFLAKE_WAREHOUSE=GDPR_PROCESSING_WH
SNOWFLAKE_DATABASE=COMPLIANCE_DB
SNOWFLAKE_SCHEMA=REQUESTS
SNOWFLAKE_ROLE={role}
"""
            
            with open('.env', 'w') as f:
                f.write(env_content)
            
            print(f"\n{Fore.GREEN}✅ Configuration saved to .env file{Style.RESET_ALL}")
            print(f"{Fore.CYAN}You can now run the demo without entering credentials again!{Style.RESET_ALL}")
            
        else:
            print(f"\n{Fore.RED}❌ Setup failed. Please check the errors above.{Style.RESET_ALL}")
            sys.exit(1)
            
    finally:
        setup.disconnect()


if __name__ == '__main__':
    main()

