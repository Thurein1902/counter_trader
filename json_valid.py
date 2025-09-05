import os
import json

# Your file paths
SOURCE_PATH = r"C:\Users\thure\AppData\Roaming\MetaQuotes\Terminal\EE0304F13905552AE0B5EAEFB04866EB\MQL5\Files\fx_signals.json"
DESTINATION_PATH = r"C:\Users\thure\CounterTrader\fx_signals.json"

def debug_files():
    print("=== File Debug Analysis ===\n")
    
    # Check source file
    print("1. Checking SOURCE file:")
    print(f"   Path: {SOURCE_PATH}")
    
    if os.path.exists(SOURCE_PATH):
        print("   ✅ Source file exists")
        
        # Check file size
        size = os.path.getsize(SOURCE_PATH)
        print(f"   📏 File size: {size} bytes")
        
        if size == 0:
            print("   ❌ File is empty!")
        else:
            # Read first 100 characters
            try:
                with open(SOURCE_PATH, 'r', encoding='utf-8') as f:
                    content = f.read(100)
                    print(f"   📝 First 100 chars: '{content}'")
            except Exception as e:
                print(f"   ❌ Error reading file: {e}")
                
                # Try reading as binary
                try:
                    with open(SOURCE_PATH, 'rb') as f:
                        content = f.read(20)
                        print(f"   📝 First 20 bytes (hex): {content.hex()}")
                except Exception as e2:
                    print(f"   ❌ Error reading binary: {e2}")
    else:
        print("   ❌ Source file does not exist")
        
        # Check if the directory exists
        source_dir = os.path.dirname(SOURCE_PATH)
        if os.path.exists(source_dir):
            print(f"   📁 Source directory exists: {source_dir}")
            print("   📁 Files in source directory:")
            try:
                files = os.listdir(source_dir)
                for file in files[:10]:  # Show first 10 files
                    print(f"      - {file}")
                if len(files) > 10:
                    print(f"      ... and {len(files) - 10} more files")
            except Exception as e:
                print(f"   ❌ Error listing directory: {e}")
        else:
            print(f"   ❌ Source directory does not exist: {source_dir}")
    
    print("\n" + "="*50 + "\n")
    
    # Check destination file
    print("2. Checking DESTINATION file:")
    print(f"   Path: {DESTINATION_PATH}")
    
    if os.path.exists(DESTINATION_PATH):
        print("   ✅ Destination file exists")
        
        # Check file size
        size = os.path.getsize(DESTINATION_PATH)
        print(f"   📏 File size: {size} bytes")
        
        if size == 0:
            print("   ❌ File is empty!")
        else:
            # Try to read and validate JSON
            try:
                with open(DESTINATION_PATH, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                print("   ✅ Valid JSON file")
                
                if 'forexData' in data:
                    pairs = len(data['forexData'])
                    print(f"   ✅ Contains {pairs} currency pairs")
                else:
                    print("   ❌ Missing 'forexData' key")
                    
            except json.JSONDecodeError as e:
                print(f"   ❌ Invalid JSON: {e}")
            except Exception as e:
                print(f"   ❌ Error reading: {e}")
    else:
        print("   ❌ Destination file does not exist")
    
    print("\n" + "="*50 + "\n")
    
    # Suggest solutions
    print("3. RECOMMENDATIONS:")
    
    if not os.path.exists(SOURCE_PATH):
        print("   🔧 Source file missing - Check MetaTrader EA/script is running")
        print("   🔧 Verify MetaTrader terminal ID in path")
        print("   🔧 Check if fx_signals.json is being created by MT5")
    elif os.path.getsize(SOURCE_PATH) == 0:
        print("   🔧 Source file empty - MetaTrader script may not be writing data")
        print("   🔧 Check MetaTrader Expert Advisor logs")
    
    if not os.path.exists(DESTINATION_PATH):
        print("   🔧 Create a test destination file first")
        print("   🔧 Run the copy function manually")

def create_test_file():
    """Create a test JSON file with sample data"""
    test_data = {
        "forexData": {
            "USDJPY": {
                "Currency_Strength_Rank_all_pair": "4/8",
                "CCI_Currency_Strength_Rank_all_pair": "4/3", 
                "BB_percent_ranking": "7/4",
                "RSI_breakout": 53,
                "Overall_Ranking": "4/5",
                "Confidence": 14
            },
            "EURJPY": {
                "Currency_Strength_Rank_all_pair": "2/8",
                "CCI_Currency_Strength_Rank_all_pair": "1/3",
                "BB_percent_ranking": "2/4", 
                "RSI_breakout": 59,
                "Overall_Ranking": "1/5",
                "Confidence": 31
            }
        }
    }
    
    try:
        with open(DESTINATION_PATH, 'w', encoding='utf-8') as f:
            json.dump(test_data, f, indent=2, ensure_ascii=False)
        print(f"✅ Test file created: {DESTINATION_PATH}")
        return True
    except Exception as e:
        print(f"❌ Error creating test file: {e}")
        return False

if __name__ == "__main__":
    debug_files()
    
    print("\n4. CREATE TEST FILE? (y/n): ", end="")
    if input().lower().startswith('y'):
        create_test_file()
        print("\nNow try opening your HTML file to test if it works with the test data.")