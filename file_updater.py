import os
import time
import subprocess
import json
from datetime import datetime

# Configuration
SOURCE_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\AppData\Roaming\MetaQuotes\Terminal\7E59B46FD773C6FE7B889FC92951284D\MQL5\Files\fx_signals.json"
DESTINATION_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader\fx_signals.json"
GIT_REPO_PATH = r"C:\Users\MT4ver2-e18-AZIzrF0D\CounterTrader\counter_trader"

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

def copy_file_safely():
    """Copy file with robust encoding handling"""
    try:
        if not os.path.exists(SOURCE_PATH):
            print("Source file not found")
            return False
        
        # Create destination folder if needed
        os.makedirs(os.path.dirname(DESTINATION_PATH), exist_ok=True)
        
        # Read with multiple encoding attempts
        data = read_with_multiple_encodings(SOURCE_PATH)
        
        if data is None:
            print("Failed to read source file with any encoding")
            return False
        
        # Validate JSON structure
        if 'forexData' not in data:
            print("Invalid JSON structure - missing 'forexData'")
            return False
        
        # Write as clean UTF-8 to destination
        with open(DESTINATION_PATH, 'w', encoding='utf-8') as dest:
            json.dump(data, dest, ensure_ascii=False, indent=2)
        
        print(f"File copied and converted at {datetime.now().strftime('%H:%M')}")
        return True
        
    except Exception as e:
        print(f"Copy error: {e}")
        return False

def run_git_commands():
    try:
        os.chdir(GIT_REPO_PATH)
        
        #subprocess.run(["git", "add", "fx_signals.json"], check=True)
        subprocess.run(["git", "add", "."], check=True)
        subprocess.run(["git", "commit", "-m", "Update fx_signals.json"], check=True)
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True)

        print("Git commands executed successfully")
        
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")
    except Exception as e:
        print(f"Git error: {e}")

def move_file():
    if copy_file_safely():
        run_git_commands()

# Main loop
last_hour = None
while True:
    now = datetime.now()
    if now.minute == 15 and now.hour != last_hour:
        move_file()
        last_hour = now.hour
        time.sleep(60)
    time.sleep(1)