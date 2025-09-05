import os
import time
import shutil
import subprocess
from datetime import datetime

# Configuration
SOURCE_PATH = r"C:\Users\thure\AppData\Roaming\MetaQuotes\Terminal\EE0304F13905552AE0B5EAEFB04866EB\MQL5\Files\fx_signals.json"
DESTINATION_PATH = r"C:\Users\thure\CounterTrader\fx_signals.json"
GIT_REPO_PATH = r"C:\Users\thure\CounterTrader"

def run_git_commands():
    try:
        os.chdir(GIT_REPO_PATH)
        
        # Run git commands
        subprocess.run(["git", "add", "."], check=True)
        subprocess.run(["git", "commit", "-m", "Update fx_signals.json"], check=True)
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True)
        
        print("Git commands executed successfully")
        
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")
    except Exception as e:
        print(f"Git error: {e}")

def move_file():
    try:
        if not os.path.exists(SOURCE_PATH):
            print("Source file not found")
            return
        
        os.makedirs(os.path.dirname(DESTINATION_PATH), exist_ok=True)
        shutil.copy2(SOURCE_PATH, DESTINATION_PATH)
        print(f"File moved at {datetime.now().strftime('%H:%M')}")
        
        # Run git commands after successful file move
        run_git_commands()
        
    except Exception as e:
        print(f"Error: {e}")

# Main loop
last_hour = None
while True:
    now = datetime.now()
    if now.minute == 6 and now.hour != last_hour:
        move_file()
        last_hour = now.hour
        time.sleep(60)
    time.sleep(1)