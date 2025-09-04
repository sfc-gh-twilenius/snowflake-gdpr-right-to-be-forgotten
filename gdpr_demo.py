#!/usr/bin/env python3
"""
Snowflake GDPR Right to be Forgotten Demo
Main orchestration script for demonstrating GDPR compliance workflows
"""

import os
import sys
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import pandas as pd
import snowflake.connector
from snowflake.connector import DictCursor
import click
from tabulate import tabulate
import structlog
from colorama import init, Fore, Back, Style

# Initialize colorama for cross-platform colored output
init(autoreset=True)

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.dev.ConsoleRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()


@dataclass
class SnowflakeConfig:
    """Snowflake connection configuration"""
    account: str
    user: str
    password: str
    warehouse: str = "GDPR_PROCESSING_WH"
    database: str = "COMPLIANCE_DB"
    schema: str = "REQUESTS"
    role: str = "SYSADMIN"


class SnowflakeGDPRDemo:
    """Main class for orchestrating Snowflake GDPR compliance demo"""
    
    def __init__(self, config: SnowflakeConfig):
        self.config = config
        self.connection = None
        self.logger = structlog.get_logger("gdpr_demo")
    
    def connect(self) -> bool:
        """Connect to Snowflake"""
        try:
            self.connection = snowflake.connector.connect(
                account=self.config.account,
                user=self.config.user,
                password=self.config.password,
                warehouse=self.config.warehouse,
                database=self.config.database,
                schema=self.config.schema,
                role=self.config.role
            )
            self.logger.info("Connected to Snowflake successfully")
            return True
        except Exception as e:
            self.logger.error(f"Failed to connect to Snowflake: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from Snowflake"""
        if self.connection:
            self.connection.close()
            self.logger.info("Disconnected from Snowflake")
    
    def execute_query(self, query: str, params: Optional[Dict] = None) -> List[Dict]:
        """Execute a query and return results"""
        try:
            cursor = self.connection.cursor(DictCursor)
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            results = cursor.fetchall()
            cursor.close()
            return results
        except Exception as e:
            self.logger.error(f"Query execution failed: {e}")
            self.logger.error(f"Query: {query}")
            raise
    
    def execute_procedure(self, procedure_name: str, params: List = None) -> Any:
        """Execute a stored procedure"""
        try:
            cursor = self.connection.cursor()
            if params:
                result = cursor.call(procedure_name, params)
            else:
                result = cursor.call(procedure_name)
            cursor.close()
            return result
        except Exception as e:
            self.logger.error(f"Procedure execution failed: {e}")
            self.logger.error(f"Procedure: {procedure_name}")
            raise
    
    def discover_customer_data(self, customer_email: str) -> pd.DataFrame:
        """Discover all personal data for a customer"""
        print(f"\n{Fore.CYAN}🔍 Discovering personal data for: {customer_email}{Style.RESET_ALL}")
        
        try:
            # Call the data discovery procedure
            query = "CALL SP_DISCOVER_CUSTOMER_DATA(%s)"
            results = self.execute_query(
                "SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))",
                []
            )
            
            # Execute the procedure first
            cursor = self.connection.cursor()
            cursor.call("SP_DISCOVER_CUSTOMER_DATA", [customer_email])
            
            # Get the results
            results = cursor.fetchall()
            cursor.close()
            
            if results:
                df = pd.DataFrame(results)
                print(f"\n{Fore.GREEN}✅ Data Discovery Results:{Style.RESET_ALL}")
                print(tabulate(df, headers='keys', tablefmt='grid'))
                
                # Summary statistics
                total_records = df['RECORDS_FOUND'].sum()
                systems_affected = df['DATABASE_NAME'].nunique()
                high_sensitivity = len(df[df['SENSITIVITY_LEVEL'] == 'HIGH'])
                
                print(f"\n{Fore.YELLOW}📊 Discovery Summary:{Style.RESET_ALL}")
                print(f"  • Total records found: {total_records}")
                print(f"  • Systems affected: {systems_affected}")
                print(f"  • High sensitivity items: {high_sensitivity}")
                
                return df
            else:
                print(f"{Fore.RED}❌ No personal data found for {customer_email}{Style.RESET_ALL}")
                return pd.DataFrame()
                
        except Exception as e:
            self.logger.error(f"Data discovery failed: {e}")
            print(f"{Fore.RED}❌ Data discovery failed: {e}{Style.RESET_ALL}")
            return pd.DataFrame()
    
    def submit_erasure_request(self, customer_email: str, reason: str = "WITHDRAWN_CONSENT") -> Optional[str]:
        """Submit a GDPR erasure request"""
        print(f"\n{Fore.CYAN}📝 Submitting erasure request for: {customer_email}{Style.RESET_ALL}")
        print(f"   Reason: {reason}")
        
        try:
            # Call the erasure request procedure
            cursor = self.connection.cursor()
            result = cursor.call("SP_SUBMIT_ERASURE_REQUEST", [customer_email, reason, "API"])
            cursor.close()
            
            # Parse the result
            result_message = str(result[0]) if result else "Unknown result"
            
            if "SUCCESS" in result_message:
                # Extract request ID from the message
                request_id = result_message.split("ID: ")[-1] if "ID: " in result_message else "Unknown"
                print(f"{Fore.GREEN}✅ Erasure request submitted successfully{Style.RESET_ALL}")
                print(f"   Request ID: {request_id}")
                return request_id
            else:
                print(f"{Fore.RED}❌ Failed to submit erasure request: {result_message}{Style.RESET_ALL}")
                return None
                
        except Exception as e:
            self.logger.error(f"Erasure request submission failed: {e}")
            print(f"{Fore.RED}❌ Erasure request submission failed: {e}{Style.RESET_ALL}")
            return None
    
    def process_erasure_request(self, request_id: str) -> bool:
        """Process an erasure request"""
        print(f"\n{Fore.CYAN}⚙️ Processing erasure request: {request_id}{Style.RESET_ALL}")
        
        try:
            # Call the erasure processing procedure
            cursor = self.connection.cursor()
            result = cursor.call("SP_PROCESS_ERASURE_REQUEST", [request_id])
            cursor.close()
            
            result_message = str(result[0]) if result else "Unknown result"
            
            if "SUCCESS" in result_message:
                print(f"{Fore.GREEN}✅ Erasure request processed successfully{Style.RESET_ALL}")
                return True
            else:
                print(f"{Fore.RED}❌ Failed to process erasure request: {result_message}{Style.RESET_ALL}")
                return False
                
        except Exception as e:
            self.logger.error(f"Erasure request processing failed: {e}")
            print(f"{Fore.RED}❌ Erasure request processing failed: {e}{Style.RESET_ALL}")
            return False
    
    def verify_deletion(self, customer_email: str, hours_back: int = 24) -> pd.DataFrame:
        """Verify that customer data has been properly deleted"""
        print(f"\n{Fore.CYAN}🔎 Verifying deletion for: {customer_email}{Style.RESET_ALL}")
        
        try:
            # Call the verification procedure
            cursor = self.connection.cursor()
            cursor.call("SP_VERIFY_DELETION", [customer_email, hours_back])
            
            # Get the results
            results = cursor.fetchall()
            cursor.close()
            
            if results:
                df = pd.DataFrame(results)
                print(f"\n{Fore.GREEN}📋 Deletion Verification Results:{Style.RESET_ALL}")
                print(tabulate(df, headers='keys', tablefmt='grid'))
                
                # Check if all deletions were successful
                all_verified = df['DELETION_VERIFIED'].all()
                if all_verified:
                    print(f"\n{Fore.GREEN}✅ All data successfully deleted and verified{Style.RESET_ALL}")
                else:
                    failed_tables = df[~df['DELETION_VERIFIED']]['TABLE_NAME'].tolist()
                    print(f"\n{Fore.RED}❌ Verification failed for tables: {failed_tables}{Style.RESET_ALL}")
                
                return df
            else:
                print(f"{Fore.YELLOW}⚠️ No verification data available{Style.RESET_ALL}")
                return pd.DataFrame()
                
        except Exception as e:
            self.logger.error(f"Deletion verification failed: {e}")
            print(f"{Fore.RED}❌ Deletion verification failed: {e}{Style.RESET_ALL}")
            return pd.DataFrame()
    
    def get_compliance_dashboard(self) -> Dict[str, Any]:
        """Get GDPR compliance dashboard data"""
        print(f"\n{Fore.CYAN}📊 Loading GDPR Compliance Dashboard{Style.RESET_ALL}")
        
        try:
            query = "SELECT * FROM VW_GDPR_COMPLIANCE_DASHBOARD"
            results = self.execute_query(query)
            
            if results:
                dashboard_data = results[0]
                
                print(f"\n{Fore.GREEN}📈 GDPR Compliance Status:{Style.RESET_ALL}")
                print(f"  • Pending Requests: {dashboard_data.get('PENDING_REQUESTS', 0)}")
                print(f"  • In Progress: {dashboard_data.get('IN_PROGRESS_REQUESTS', 0)}")
                print(f"  • Completed: {dashboard_data.get('COMPLETED_REQUESTS', 0)}")
                print(f"  • Overdue (>30 days): {dashboard_data.get('OVERDUE_REQUESTS', 0)}")
                print(f"  • Average Processing Time: {dashboard_data.get('AVG_PROCESSING_DAYS', 0):.1f} days")
                
                compliance_status = dashboard_data.get('OVERALL_COMPLIANCE_STATUS', 'UNKNOWN')
                status_color = Fore.GREEN if compliance_status == 'COMPLIANT' else Fore.RED
                print(f"  • Overall Status: {status_color}{compliance_status}{Style.RESET_ALL}")
                
                return dashboard_data
            else:
                print(f"{Fore.YELLOW}⚠️ No compliance data available{Style.RESET_ALL}")
                return {}
                
        except Exception as e:
            self.logger.error(f"Failed to load compliance dashboard: {e}")
            print(f"{Fore.RED}❌ Failed to load compliance dashboard: {e}{Style.RESET_ALL}")
            return {}
    
    def get_erasure_requests(self, limit: int = 10) -> pd.DataFrame:
        """Get recent erasure requests"""
        try:
            query = f"""
            SELECT request_id, customer_email, status, erasure_reason, 
                   requested_at, estimated_completion_date, 
                   DATEDIFF('day', requested_at, CURRENT_TIMESTAMP()) as days_since_request
            FROM ERASURE_REQUESTS 
            ORDER BY requested_at DESC 
            LIMIT {limit}
            """
            results = self.execute_query(query)
            
            if results:
                df = pd.DataFrame(results)
                print(f"\n{Fore.GREEN}📋 Recent Erasure Requests:{Style.RESET_ALL}")
                print(tabulate(df, headers='keys', tablefmt='grid'))
                return df
            else:
                print(f"{Fore.YELLOW}⚠️ No erasure requests found{Style.RESET_ALL}")
                return pd.DataFrame()
                
        except Exception as e:
            self.logger.error(f"Failed to get erasure requests: {e}")
            return pd.DataFrame()
    
    def coordinate_third_party_deletion(self, customer_email: str) -> bool:
        """Coordinate deletion with third-party systems"""
        print(f"\n{Fore.CYAN}🔗 Coordinating third-party deletion for: {customer_email}{Style.RESET_ALL}")
        
        try:
            # Call the third-party coordination procedure
            cursor = self.connection.cursor()
            result = cursor.call("SP_COORDINATE_THIRD_PARTY_DELETION", [customer_email])
            cursor.close()
            
            result_message = str(result[0]) if result else "Unknown result"
            
            if "SUCCESS" in result_message:
                print(f"{Fore.GREEN}✅ Third-party coordination initiated{Style.RESET_ALL}")
                print(f"   {result_message}")
                return True
            else:
                print(f"{Fore.RED}❌ Third-party coordination failed: {result_message}{Style.RESET_ALL}")
                return False
                
        except Exception as e:
            self.logger.error(f"Third-party coordination failed: {e}")
            print(f"{Fore.RED}❌ Third-party coordination failed: {e}{Style.RESET_ALL}")
            return False
    
    def check_customer_compliance_status(self, customer_email: str) -> Dict[str, Any]:
        """Check GDPR compliance status for a specific customer"""
        try:
            query = "SELECT FN_CHECK_GDPR_COMPLIANCE_STATUS(%s) as compliance_status"
            results = self.execute_query(query, [customer_email])
            
            if results:
                compliance_data = json.loads(results[0]['COMPLIANCE_STATUS'])
                
                print(f"\n{Fore.GREEN}👤 GDPR Compliance Status for {customer_email}:{Style.RESET_ALL}")
                print(f"  • Has Active Request: {compliance_data.get('has_active_request', False)}")
                print(f"  • Deletion Completed: {compliance_data.get('deletion_completed', False)}")
                print(f"  • Last Request Date: {compliance_data.get('last_request_date', 'None')}")
                print(f"  • Data Retention Until: {compliance_data.get('data_retention_until', 'Not set')}")
                
                consent_status = compliance_data.get('consent_status', {})
                if consent_status:
                    print(f"  • Marketing Consent: {consent_status.get('marketing', 'Unknown')}")
                    print(f"  • Analytics Consent: {consent_status.get('analytics', 'Unknown')}")
                
                return compliance_data
            else:
                print(f"{Fore.YELLOW}⚠️ No compliance data found for {customer_email}{Style.RESET_ALL}")
                return {}
                
        except Exception as e:
            self.logger.error(f"Failed to check compliance status: {e}")
            print(f"{Fore.RED}❌ Failed to check compliance status: {e}{Style.RESET_ALL}")
            return {}
    
    def run_full_demo_scenario(self, customer_email: str):
        """Run a complete GDPR erasure scenario"""
        print(f"\n{Back.BLUE}{Fore.WHITE} 🛡️  GDPR RIGHT TO BE FORGOTTEN - FULL DEMO SCENARIO {Style.RESET_ALL}")
        print(f"{Fore.CYAN}Customer: {customer_email}{Style.RESET_ALL}")
        print("=" * 70)
        
        # Step 1: Check initial compliance status
        print(f"\n{Fore.YELLOW}Step 1: Initial Compliance Status{Style.RESET_ALL}")
        self.check_customer_compliance_status(customer_email)
        
        # Step 2: Discover customer data
        print(f"\n{Fore.YELLOW}Step 2: Data Discovery{Style.RESET_ALL}")
        discovery_df = self.discover_customer_data(customer_email)
        
        if discovery_df.empty:
            print(f"{Fore.RED}❌ No data found for customer. Demo cannot continue.{Style.RESET_ALL}")
            return
        
        # Step 3: Submit erasure request
        print(f"\n{Fore.YELLOW}Step 3: Submit Erasure Request{Style.RESET_ALL}")
        request_id = self.submit_erasure_request(customer_email, "WITHDRAWN_CONSENT")
        
        if not request_id:
            print(f"{Fore.RED}❌ Failed to submit erasure request. Demo cannot continue.{Style.RESET_ALL}")
            return
        
        # Step 4: Process erasure request
        print(f"\n{Fore.YELLOW}Step 4: Process Erasure Request{Style.RESET_ALL}")
        processing_success = self.process_erasure_request(request_id)
        
        if not processing_success:
            print(f"{Fore.RED}❌ Failed to process erasure request.{Style.RESET_ALL}")
            return
        
        # Step 5: Coordinate third-party deletion
        print(f"\n{Fore.YELLOW}Step 5: Third-Party Coordination{Style.RESET_ALL}")
        self.coordinate_third_party_deletion(customer_email)
        
        # Step 6: Verify deletion
        print(f"\n{Fore.YELLOW}Step 6: Verify Deletion{Style.RESET_ALL}")
        self.verify_deletion(customer_email)
        
        # Step 7: Final compliance status
        print(f"\n{Fore.YELLOW}Step 7: Final Compliance Status{Style.RESET_ALL}")
        self.check_customer_compliance_status(customer_email)
        
        # Step 8: Updated dashboard
        print(f"\n{Fore.YELLOW}Step 8: Updated Compliance Dashboard{Style.RESET_ALL}")
        self.get_compliance_dashboard()
        
        print(f"\n{Back.GREEN}{Fore.WHITE} ✅ GDPR ERASURE SCENARIO COMPLETED SUCCESSFULLY! {Style.RESET_ALL}")


def load_config() -> SnowflakeConfig:
    """Load Snowflake configuration from environment or user input"""
    
    # Try to load from environment variables first
    account = os.getenv('SNOWFLAKE_ACCOUNT')
    user = os.getenv('SNOWFLAKE_USER')
    password = os.getenv('SNOWFLAKE_PASSWORD')
    warehouse = os.getenv('SNOWFLAKE_WAREHOUSE', 'GDPR_PROCESSING_WH')
    
    # If not in environment, prompt user
    if not all([account, user, password]):
        print(f"\n{Fore.CYAN}🔐 Snowflake Configuration Required{Style.RESET_ALL}")
        print("Please provide your Snowflake connection details:")
        
        if not account:
            account = input("Account (e.g., abc12345.us-east-1): ").strip()
        if not user:
            user = input("Username: ").strip()
        if not password:
            import getpass
            password = getpass.getpass("Password: ")
    
    return SnowflakeConfig(
        account=account,
        user=user,
        password=password,
        warehouse=warehouse
    )


@click.group()
def cli():
    """Snowflake GDPR Right to be Forgotten Demo"""
    pass


@cli.command()
@click.option('--customer-email', '-e', required=True, help='Customer email to discover data for')
def discover(customer_email: str):
    """Discover personal data for a customer"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if demo.connect():
        try:
            demo.discover_customer_data(customer_email)
        finally:
            demo.disconnect()


@cli.command()
@click.option('--customer-email', '-e', required=True, help='Customer email for erasure request')
@click.option('--reason', '-r', default='WITHDRAWN_CONSENT', 
              help='GDPR erasure reason', 
              type=click.Choice(['WITHDRAWN_CONSENT', 'NO_LONGER_NECESSARY', 'UNLAWFUL_PROCESSING', 'OBJECTION']))
def request_erasure(customer_email: str, reason: str):
    """Submit a GDPR erasure request"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if demo.connect():
        try:
            demo.submit_erasure_request(customer_email, reason)
        finally:
            demo.disconnect()


@cli.command()
@click.option('--customer-email', '-e', required=True, help='Customer email for full demo scenario')
def full_demo(customer_email: str):
    """Run complete GDPR erasure demo scenario"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if demo.connect():
        try:
            demo.run_full_demo_scenario(customer_email)
        finally:
            demo.disconnect()


@cli.command()
def dashboard():
    """Show GDPR compliance dashboard"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if demo.connect():
        try:
            demo.get_compliance_dashboard()
            demo.get_erasure_requests()
        finally:
            demo.disconnect()


@cli.command()
@click.option('--customer-email', '-e', required=True, help='Customer email to verify deletion for')
def verify(customer_email: str):
    """Verify data deletion for a customer"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if demo.connect():
        try:
            demo.verify_deletion(customer_email)
        finally:
            demo.disconnect()


@cli.command()
def interactive():
    """Interactive demo mode"""
    config = load_config()
    demo = SnowflakeGDPRDemo(config)
    
    if not demo.connect():
        print(f"{Fore.RED}❌ Failed to connect to Snowflake{Style.RESET_ALL}")
        return
    
    try:
        print(f"\n{Back.BLUE}{Fore.WHITE} 🛡️  SNOWFLAKE GDPR COMPLIANCE DEMO - INTERACTIVE MODE {Style.RESET_ALL}")
        print("\nAvailable demo customers (from demo data):")
        print("  • anna.mueller@email.de (German customer with full consent)")
        print("  • jean.dupont@email.fr (French customer, consent withdrawn)")
        print("  • maria.garcia@email.es (Spanish customer, partial consent)")
        print("  • consent.withdrawn@email.de (Customer with withdrawn consent)")
        
        while True:
            print(f"\n{Fore.CYAN}Choose an action:{Style.RESET_ALL}")
            print("1. 🔍 Discover customer data")
            print("2. 📝 Submit erasure request")
            print("3. 📊 View compliance dashboard")
            print("4. 🔎 Verify customer deletion")
            print("5. 🎭 Run full demo scenario")
            print("6. 👤 Check customer compliance status")
            print("7. 📋 List erasure requests")
            print("0. 🚪 Exit")
            
            choice = input(f"\n{Fore.YELLOW}Enter your choice (0-7): {Style.RESET_ALL}").strip()
            
            if choice == '0':
                print(f"{Fore.GREEN}Goodbye! 👋{Style.RESET_ALL}")
                break
            elif choice == '1':
                email = input("Enter customer email: ").strip()
                demo.discover_customer_data(email)
            elif choice == '2':
                email = input("Enter customer email: ").strip()
                reason = input("Enter erasure reason (WITHDRAWN_CONSENT/NO_LONGER_NECESSARY/OBJECTION): ").strip() or "WITHDRAWN_CONSENT"
                demo.submit_erasure_request(email, reason)
            elif choice == '3':
                demo.get_compliance_dashboard()
            elif choice == '4':
                email = input("Enter customer email: ").strip()
                demo.verify_deletion(email)
            elif choice == '5':
                email = input("Enter customer email: ").strip()
                demo.run_full_demo_scenario(email)
            elif choice == '6':
                email = input("Enter customer email: ").strip()
                demo.check_customer_compliance_status(email)
            elif choice == '7':
                demo.get_erasure_requests()
            else:
                print(f"{Fore.RED}Invalid choice. Please try again.{Style.RESET_ALL}")
                
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Demo interrupted by user{Style.RESET_ALL}")
    finally:
        demo.disconnect()


if __name__ == '__main__':
    print(f"{Back.BLUE}{Fore.WHITE} 🛡️  SNOWFLAKE GDPR RIGHT TO BE FORGOTTEN DEMO {Style.RESET_ALL}")
    print(f"{Fore.CYAN}Demonstrating GDPR Article 17 compliance using Snowflake Data Cloud{Style.RESET_ALL}")
    print("=" * 70)
    cli()

