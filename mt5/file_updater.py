import os
import time
import subprocess
import json
from datetime import datetime

# Configuration
SOURCE_BASE_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\AppData\Roaming\MetaQuotes\Terminal\7E59B46FD773C6FE7B889FC92951284D\MQL5\Files"
DESTINATION_BASE_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader\data"
GIT_REPO_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader"

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
    """Execute git commands for both files"""
    try:
        os.chdir(GIT_REPO_PATH)
        
        # Add both files
        subprocess.run(["git", "add", "fx_signals_10pair.json"], check=True)
        subprocess.run(["git", "add", "fx_signals_28pair.json"], check=True)
        
        # Commit with timestamp
        commit_message = f"Update forex signals - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Push to remote
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True)
        
        print("Git commands executed successfully for both files")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")
        return False
    except Exception as e:
        print(f"Git error: {e}")
        return False

def run_git_commands_all():
    """Execute git commands for all files at 23:00"""
    try:
        os.chdir(GIT_REPO_PATH)
        
        # Add all changes
        subprocess.run(["git", "add", "."], check=True)
        
        # Commit with timestamp
        commit_message = f"Scheduled commit - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Push to remote
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True)
        
        print("Git commands executed successfully for all files")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")
        return False
    except Exception as e:
        print(f"Git error: {e}")
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
        run_git_commands()
    else:
        print("No files were copied successfully")

def check_file_existence():
    """Check if source files exist and report status"""
    for config in FILES_CONFIG:
        exists = os.path.exists(config["source"])
        status = "EXISTS" if exists else "MISSING"
        print(f"{config['name']} file: {status}")

def main():
    """Main monitoring loop"""
    print("Forex JSON File Monitor Started")
    print("Monitoring for fx_signals_10pair.json and fx_signals_28pair.json")
    print("Checking file sources...")
    check_file_existence()
    print("Will copy files at minute 4 of each hour")
    print("Will execute git commands at 23:00 daily")
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
                move_files()
                last_hour = now.hour
                print("-" * 50)
                
                # Sleep for a minute to avoid duplicate triggers
                time.sleep(60)
            
            # Trigger git commands at 23:00 daily
            if now.hour == 23 and now.minute == 0 and current_date != last_date:
                print(f"\nGit commands triggered at {now.strftime('%Y-%m-%d %H:%M:%S')}")
                run_git_commands_all()
                last_date = current_date
                print("-" * 50)
                
                # Sleep for a minute to avoid duplicate triggers
                time.sleep(60)
            
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