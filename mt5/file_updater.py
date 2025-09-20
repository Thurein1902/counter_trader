import os
import time
import subprocess
import json
import smtplib
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Configuration
SOURCE_BASE_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\AppData\Roaming\MetaQuotes\Terminal\7E59B46FD773C6FE7B889FC92951284D\MQL5\Files"
DESTINATION_BASE_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader\data"
GIT_REPO_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader"

# Gmail Alert Configuration for Git Commands
GMAIL_CONFIG = {
    "enabled": True,
    "sender_email": "thurein@1902.jp",
    "app_password": "dwjs virx tpyb olyh",
    "recipient_email": "thurein@1902.jp",
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587
}

# File configurations
FILES_CONFIG = [
    {
        "source": os.path.join(SOURCE_BASE_PATH, "fx_signals_10pair.json"),
        "destination": os.path.join(DESTINATION_BASE_PATH, "fx_signals_10pair.json"),
        "name": "10pair"
    },
    {
        "source": os.path.join(SOURCE_BASE_PATH, "fx_signals_28pair.json"),
        "destination": os.path.join(DESTINATION_BASE_PATH, "fx_signals_28pair.json"),
        "name": "28pair"
    }
]

def is_weekend_block_time():
    """Check if current time is within the weekend block period (Saturday 6 AM to Monday 6 AM)"""
    now = datetime.now()
    current_weekday = now.weekday()  # 0=Monday, 1=Tuesday, ..., 6=Sunday
    current_hour = now.hour
    
    # Saturday (weekday 5) from 6 AM onwards
    if current_weekday == 5 and current_hour >= 6:
        return True
    
    # Sunday (weekday 6) - entire day
    if current_weekday == 6:
        return True
    
    # Monday (weekday 0) before 6 AM
    if current_weekday == 0 and current_hour < 6:
        return True
    
    return False

def send_git_failure_alert(error_message, operation_type="Git Command"):
    """Send immediate email alert for git command failures"""
    if not GMAIL_CONFIG["enabled"]:
        return False
    
    try:
        msg = MIMEMultipart()
        msg['From'] = GMAIL_CONFIG["sender_email"]
        msg['To'] = GMAIL_CONFIG["recipient_email"]
        msg['Subject'] = f"🚨 URGENT: Git Command Failed - File Updater [{datetime.now().strftime('%H:%M:%S')}]"
        
        body = f"""
🚨 GIT COMMAND FAILURE ALERT 🚨

TIME: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
OPERATION: {operation_type}
REPOSITORY: {GIT_REPO_PATH}

💥 ERROR DETAILS:
{error_message}

📁 FILES BEING UPDATED:
- fx_signals_10pair.json
- fx_signals_28pair.json

⚡ IMMEDIATE ACTIONS:
1. Check internet connection
2. Verify GitHub repository access
3. Check repository status manually
4. Review file updater console for more details

SYSTEM INFO:
- Source Path: {SOURCE_BASE_PATH}
- Destination Path: {DESTINATION_BASE_PATH}
- Trigger: File copy at minute 4 of each hour

This alert is for GIT COMMANDS ONLY from the File Updater system.

---
File Updater Automated Monitor
        """
        
        msg.attach(MIMEText(body, 'plain'))
        
        server = smtplib.SMTP(GMAIL_CONFIG["smtp_server"], GMAIL_CONFIG["smtp_port"])
        server.starttls()
        server.login(GMAIL_CONFIG["sender_email"], GMAIL_CONFIG["app_password"])
        server.sendmail(GMAIL_CONFIG["sender_email"], GMAIL_CONFIG["recipient_email"], msg.as_string())
        server.quit()
        
        print("✅ Git failure email alert sent!")
        return True
        
    except Exception as e:
        print(f"❌ Failed to send git failure email: {e}")
        return False

def clean_json_content(content):
    """Clean and normalize JSON content"""
    # Remove UTF-8 BOM if present
    if content.startswith('\ufeff'):
        content = content[1:]
    
    # Remove any other BOMs
    content = content.lstrip('\ufeff\ufffe\u0000')
    
    # Strip whitespace
    content = content.strip()
    
    return content

def read_with_multiple_encodings(file_path):
    """Try multiple encoding methods to read the file"""
    encodings = ['utf-16-le', 'utf-16-be', 'utf-16', 'utf-8-sig', 'utf-8', 'cp1252', 'latin-1']
    
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
            
            # Clean the content
            content = clean_json_content(content)
            
            if content:
                # Try to parse as JSON
                data = json.loads(content)
                return data
                
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        except Exception:
            continue
    
    return None

def copy_file_safely(source_path, destination_path, file_name):
    """Copy file with robust encoding handling"""
    try:
        if not os.path.exists(source_path):
            print(f"{file_name} source file not found: {source_path}")
            return False
        
        # Create destination folder if needed
        os.makedirs(os.path.dirname(destination_path), exist_ok=True)
        
        # Read with multiple encoding attempts
        data = read_with_multiple_encodings(source_path)
        
        if data is None:
            print(f"Failed to read {file_name} source file with any encoding")
            return False
        
        # Validate JSON structure
        if 'forexData' not in data:
            print(f"Invalid JSON structure in {file_name} - missing 'forexData'")
            return False
        
        # Write as clean UTF-8 to destination
        with open(destination_path, 'w', encoding='utf-8') as dest:
            json.dump(data, dest, ensure_ascii=False, indent=2)
        
        print(f"{file_name} file copied and converted at {datetime.now().strftime('%H:%M')}")
        return True
        
    except Exception as e:
        print(f"Copy error for {file_name}: {e}")
        return False

def run_git_commands():
    """Execute git commands for both files - WITH EMAIL ALERTS ON FAILURE"""
    # Check if we're in weekend block time
    if is_weekend_block_time():
        print("Weekend block time - skipping git commit (Saturday 6 AM to Monday 6 AM)")
        return False
    
    try:
        os.chdir(GIT_REPO_PATH)
        
        # Check if there are changes to commit
        result = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, check=True)
        if not result.stdout.strip():
            print("No changes to commit")
            return True
        
        # Add both files
        subprocess.run(["git", "add", "data/fx_signals_10pair.json"], check=True)
        subprocess.run(["git", "add", "data/fx_signals_28pair.json"], check=True)
        
        # Commit with timestamp
        commit_message = f"Update forex signals - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Push to remote with timeout
        try:
            subprocess.run(["git", "push", "-u", "origin", "main"], check=True, timeout=30)
        except subprocess.TimeoutExpired:
            error_msg = "Git push timed out after 30 seconds - check internet connection"
            print(f"❌ {error_msg}")
            send_git_failure_alert(error_msg, "Hourly Git Push Timeout")
            return False
        
        print("Git commands executed successfully for both files")
        return True
        
    except subprocess.CalledProcessError as e:
        error_msg = f"Git command failed: '{' '.join(e.cmd)}' (exit code: {e.returncode})"
        if e.stderr:
            error_msg += f"\nError output: {e.stderr}"
        
        print(f"❌ {error_msg}")
        # SEND EMAIL ALERT FOR GIT FAILURE
        send_git_failure_alert(error_msg, "Hourly Git Commands")
        return False
        
    except Exception as e:
        error_msg = f"Git error: {e}"
        print(f"❌ {error_msg}")
        # SEND EMAIL ALERT FOR GIT ERROR
        send_git_failure_alert(error_msg, "Hourly Git Commands")
        return False

def run_git_commands_all():
    """Execute git commands for all files at 23:00 - WITH EMAIL ALERTS ON FAILURE"""
    # Check if we're in weekend block time
    if is_weekend_block_time():
        print("Weekend block time - skipping scheduled git commit (Saturday 6 AM to Monday 6 AM)")
        return False
    
    try:
        os.chdir(GIT_REPO_PATH)
        
        # Check if there are changes to commit
        result = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, check=True)
        if not result.stdout.strip():
            print("No changes to commit")
            return True
        
        # Add all changes
        subprocess.run(["git", "add", "."], check=True)
        
        # Commit with timestamp
        commit_message = f"Scheduled commit - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Push to remote with timeout
        try:
            subprocess.run(["git", "push", "-u", "origin", "main"], check=True, timeout=30)
        except subprocess.TimeoutExpired:
            error_msg = "Scheduled git push timed out after 30 seconds - check internet connection"
            print(f"❌ {error_msg}")
            send_git_failure_alert(error_msg, "Scheduled Git Push Timeout (23:00)")
            return False
        
        print("Git commands executed successfully for all files")
        return True
        
    except subprocess.CalledProcessError as e:
        error_msg = f"Scheduled git command failed: '{' '.join(e.cmd)}' (exit code: {e.returncode})"
        if e.stderr:
            error_msg += f"\nError output: {e.stderr}"
        
        print(f"❌ {error_msg}")
        # SEND EMAIL ALERT FOR SCHEDULED GIT FAILURE
        send_git_failure_alert(error_msg, "Scheduled Git Commands (23:00)")
        return False
        
    except Exception as e:
        error_msg = f"Scheduled git error: {e}"
        print(f"❌ {error_msg}")
        # SEND EMAIL ALERT FOR SCHEDULED GIT ERROR
        send_git_failure_alert(error_msg, "Scheduled Git Commands (23:00)")
        return False

def move_files():
    """Process both JSON files"""
    success_count = 0
    
    for config in FILES_CONFIG:
        if copy_file_safely(config["source"], config["destination"], config["name"]):
            success_count += 1
    
    if success_count > 0:
        print(f"Successfully copied {success_count}/{len(FILES_CONFIG)} files")
        
        # Only run git commands if at least one file was copied successfully
        run_git_commands()  # This now has email alerts and weekend blocking
    else:
        print("No files were copied successfully")

def check_file_existence():
    """Check if source files exist and report status"""
    for config in FILES_CONFIG:
        exists = os.path.exists(config["source"])
        status = "EXISTS" if exists else "MISSING"
        print(f"{config['name']} file: {status}")

def get_weekend_status():
    """Get current weekend block status for display"""
    if is_weekend_block_time():
        return "ACTIVE (No commits will be made)"
    else:
        return "INACTIVE (Commits allowed)"

def main():
    """Main monitoring loop"""
    print("Forex JSON File Monitor Started")
    print("📧 Gmail alerts ENABLED for GIT COMMANDS ONLY")
    print(f"📧 Alert email: {GMAIL_CONFIG['recipient_email']}")
    print("🚫 Weekend commit block: Saturday 6 AM to Monday 6 AM")
    print(f"🚫 Weekend block status: {get_weekend_status()}")
    print("Monitoring for fx_signals_10pair.json and fx_signals_28pair.json")
    print("Checking file sources...")
    check_file_existence()
    print("Will copy files at minute 4 of each hour")
    print("Will execute git commands at 23:00 daily (except during weekend block)")
    print("Email alerts will be sent ONLY for git command failures")
    print("-" * 50)
    
    last_hour = None
    last_date = None
    
    while True:
        try:
            now = datetime.now()
            current_date = now.date()
            
            # Trigger file copying at minute 4 of each hour
            if now.minute == 4 and now.hour != last_hour:
                print(f"\nFile copy triggered at {now.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"Weekend block status: {get_weekend_status()}")
                move_files()  # This calls git commands, which have email alerts and weekend blocking
                last_hour = now.hour
                print("-" * 50)
                
                # Sleep for a minute to avoid duplicate triggers
                time.sleep(60)
            
            # Trigger git commands at 23:00 daily (commented out in your original)
            #if now.hour == 23 and now.minute == 0 and current_date != last_date:
            #    print(f"\nGit commands triggered at {now.strftime('%Y-%m-%d %H:%M:%S')}")
            #    print(f"Weekend block status: {get_weekend_status()}")
            #    run_git_commands_all()  # This has email alerts and weekend blocking
            #    last_date = current_date
            #    print("-" * 50)
            #    
            #    # Sleep for a minute to avoid duplicate triggers
            #    time.sleep(60)
            
            # Sleep for 1 second between checks
            time.sleep(1)
            
        except KeyboardInterrupt:
            print("\nStopping monitor...")
            break
        except Exception as e:
            print(f"Unexpected error in main loop: {e}")
            time.sleep(10)  # Wait 10 seconds before retrying

if __name__ == "__main__":
    main()