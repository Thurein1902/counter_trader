import os
import time
import subprocess
from datetime import datetime

# Configuration
SOURCE_PATH = r"C:\Users\thure\AppData\Roaming\MetaQuotes\Terminal\EE0304F13905552AE0B5EAEFB04866EB\MQL5\Files\fx_signals.json"
DESTINATION_PATH = r"C:\Users\thure\CounterTrader\fx_signals.json"
GIT_REPO_PATH = r"C:\Users\thure\CounterTrader"

def copy_file_safely():
    """Copy file preserving encoding and format"""
    try:
        if not os.path.exists(SOURCE_PATH):
            print("Source file not found")
            return False
        
        # Create destination folder if needed
        os.makedirs(os.path.dirname(DESTINATION_PATH), exist_ok=True)
        
        # Read as binary to preserve exact encoding
        with open(SOURCE_PATH, 'rb') as source:
            content = source.read()
        
        # Write as binary to preserve exact format
        with open(DESTINATION_PATH, 'wb') as dest:
            dest.write(content)
        
        print(f"File copied at {datetime.now().strftime('%H:%M')}")
        return True
        
    except Exception as e:
        print(f"Copy error: {e}")
        return False

def run_git_commands():
    try:
        os.chdir(GIT_REPO_PATH)
        
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
    if now.minute == 19 and now.hour != last_hour:
        move_file()
        last_hour = now.hour
        time.sleep(60)
    time.sleep(1)